import logging
import os
import json
from datetime import datetime
import pyodbc
import requests
import azure.functions as func


def main(timer: func.TimerRequest) -> None:
    """
    Phase 4: SubmitToPartner
    ========================
    Timer-triggered Azure Function that:
    1. Fetches pending KSeF submissions (Status=1) from PartnerSubmission table
    2. POSTs each KSeF XML to the KSeF Partner API
    3. Updates PartnerSubmission status to 2 (Success) or 3 (Failed)
    4. Saves KSeF reference number on success, error details on failure

    Runs every 5 minutes by default (configurable via SUBMIT_TIMER_SCHEDULE).
    """
    logging.info("SubmitToPartner function started at %s", datetime.utcnow())

    try:
        # ── Configuration ────────────────────────────────────────────────────
        sql_connection_string = os.environ["SQL_CONNECTION_STRING"]
        ksef_api_url          = os.environ["KSEF_API_URL"]
        ksef_api_key          = os.environ.get("KSEF_API_KEY", "")
        batch_size            = int(os.environ.get("SUBMIT_BATCH_SIZE", "10"))

        # ── Fetch pending submissions ─────────────────────────────────────────
        pending = _get_pending_submissions(sql_connection_string, batch_size)

        if not pending:
            logging.info("No pending KSeF submissions found.")
            return

        logging.info("Found %d pending submission(s) to process.", len(pending))

        # ── Process each submission ───────────────────────────────────────────
        success_count = 0
        failure_count = 0

        for row in pending:
            submission_id = row["PartnerSubmissionId"]
            edi_id        = row["EDIIntegrationId"]
            ksef_xml      = row["PartnerXML"]

            logging.info(
                "Processing PartnerSubmissionId=%d (EDIIntegrationId=%d)",
                submission_id, edi_id
            )

            try:
                ksef_ref, error = _submit_to_ksef_api(ksef_xml, ksef_api_url, ksef_api_key)

                if ksef_ref:
                    # ── Success ───────────────────────────────────────────────
                    _update_submission_status(
                        sql_connection_string,
                        submission_id=submission_id,
                        status=2,
                        ksef_reference_number=ksef_ref
                    )
                    logging.info(
                        "SUCCESS: PartnerSubmissionId=%d | KSeF Ref=%s",
                        submission_id, ksef_ref
                    )
                    success_count += 1
                else:
                    # ── Failure ───────────────────────────────────────────────
                    _update_submission_status(
                        sql_connection_string,
                        submission_id=submission_id,
                        status=3,
                        error_message=error
                    )
                    logging.error(
                        "FAILED: PartnerSubmissionId=%d | Error=%s",
                        submission_id, error
                    )
                    failure_count += 1

            except Exception as exc:
                logging.error(
                    "Unexpected error for PartnerSubmissionId=%d: %s",
                    submission_id, str(exc), exc_info=True
                )
                _update_submission_status(
                    sql_connection_string,
                    submission_id=submission_id,
                    status=3,
                    error_message=f"Unexpected error: {str(exc)}"
                )
                failure_count += 1

        logging.info(
            "SubmitToPartner completed. Total=%d | Success=%d | Failed=%d",
            len(pending), success_count, failure_count
        )

    except Exception as exc:
        logging.error("Fatal error in SubmitToPartner: %s", str(exc), exc_info=True)
        raise


# ═══════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

def _get_pending_submissions(connection_string: str, batch_size: int) -> list:
    """
    Calls usp_GetPendingPartnerSubmissions to fetch rows with Status=1.

    Returns a list of dicts with keys:
        PartnerSubmissionId, EDIIntegrationId, PartnerCode, PartnerXML, InsertDate
    """
    results = []
    try:
        conn   = pyodbc.connect(connection_string)
        cursor = conn.cursor()

        cursor.execute(
            "EXEC [dbo].[usp_GetPendingPartnerSubmissions] @BatchSize = ?",
            batch_size
        )

        columns = [col[0] for col in cursor.description]
        for row in cursor.fetchall():
            results.append(dict(zip(columns, row)))

        cursor.close()
        conn.close()

    except Exception as exc:
        logging.error("Error fetching pending submissions: %s", str(exc))
        raise

    return results


def _submit_to_ksef_api(
    ksef_xml: str,
    api_url: str,
    api_key: str
) -> tuple:
    """
    POSTs KSeF FA(3) XML to the KSeF Partner API.

    Returns:
        (ksef_reference_number, None)  on success
        (None, error_message)          on failure
    """
    headers = {
        "Content-Type": "application/xml; charset=utf-8",
        "Accept":        "application/json",
    }

    # API key authentication (update if using OAuth/certificate)
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"

    try:
        response = requests.post(
            api_url,
            data=ksef_xml.encode("utf-8"),
            headers=headers,
            timeout=30
        )

        if response.status_code in (200, 201, 202):
            # Parse KSeF reference number from response
            # KSeF typically returns JSON with a referenceNumber field
            ksef_ref = _extract_ksef_reference(response)
            return ksef_ref, None
        else:
            error_msg = (
                f"HTTP {response.status_code}: "
                f"{response.text[:500]}"
            )
            return None, error_msg

    except requests.exceptions.Timeout:
        return None, "API call timed out after 30 seconds"
    except requests.exceptions.ConnectionError as exc:
        return None, f"Connection error: {str(exc)}"
    except Exception as exc:
        return None, f"Unexpected API error: {str(exc)}"


def _extract_ksef_reference(response: requests.Response) -> str:
    """
    Extracts the KSeF reference number from the API response.
    Handles both JSON and XML responses.
    """
    try:
        # Try JSON first (most common)
        data = response.json()
        # KSeF API typically returns: { "referenceNumber": "...", ... }
        return (
            data.get("referenceNumber")
            or data.get("ReferenceNumber")
            or data.get("ksef_reference")
            or f"REF-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}"
        )
    except (ValueError, KeyError):
        # Fallback: use response text truncated as reference
        return response.text[:200] if response.text else "SUBMITTED"


def _update_submission_status(
    connection_string: str,
    submission_id: int,
    status: int,
    ksef_reference_number: str = None,
    error_message: str = None
) -> None:
    """
    Calls usp_UpdatePartnerSubmissionStatus to update the DB record.

    status: 2 = Success, 3 = Failed
    """
    try:
        conn   = pyodbc.connect(connection_string)
        cursor = conn.cursor()

        cursor.execute(
            """
            EXEC [dbo].[usp_UpdatePartnerSubmissionStatus]
                @PartnerSubmissionId = ?,
                @Status              = ?,
                @KSeFReferenceNumber = ?,
                @ErrorMessage        = ?
            """,
            submission_id,
            status,
            ksef_reference_number,
            error_message
        )

        conn.commit()
        cursor.close()
        conn.close()

    except Exception as exc:
        logging.error(
            "Error updating submission status for ID=%d: %s",
            submission_id, str(exc)
        )
        raise
