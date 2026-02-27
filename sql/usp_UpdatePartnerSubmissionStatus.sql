-- ============================================================================
-- SP: usp_UpdatePartnerSubmissionStatus
-- Phase 4: Called by SubmitToPartner function after KSeF API call
-- Updates PartnerSubmission status to 2 (Success) or 3 (Failed)
-- ============================================================================
CREATE OR ALTER PROCEDURE [dbo].[usp_UpdatePartnerSubmissionStatus]
    @PartnerSubmissionId    INT,
    @Status                 INT,            -- 2 = Success, 3 = Failed
    @KSeFReferenceNumber    NVARCHAR(200) = NULL,  -- Returned by KSeF on success
    @ErrorMessage           NVARCHAR(MAX) = NULL   -- Populated on failure
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [EDI].[PartnerSubmission]
    SET
        IntegrationStatusId = @Status,
        KSeFReferenceNumber = @KSeFReferenceNumber,
        ErrorMessage        = @ErrorMessage,
        SubmittedAt         = CASE WHEN @Status = 2 THEN GETUTCDATE() ELSE SubmittedAt END,
        LastUpdateDate      = GETUTCDATE()
    WHERE PartnerSubmissionId = @PartnerSubmissionId;

    -- Also update the parent EDIIntegrationTable status
    UPDATE [EDI].[EDIIntegrationTable]
    SET
        IntegrationStatusId = CASE WHEN @Status = 2 THEN 80 ELSE 90 END,
            -- 80 = Done (submitted successfully)
            -- 90 = Failed (temporary, may retry)
        LastUpdateDate = GETUTCDATE()
    WHERE EDIIntegrationId = (
        SELECT EDIIntegrationId
        FROM [EDI].[PartnerSubmission]
        WHERE PartnerSubmissionId = @PartnerSubmissionId
    );

    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- ============================================================================
-- SP: usp_GetPendingPartnerSubmissions
-- Phase 4: Called by SubmitToPartner function to fetch ready submissions
-- ============================================================================
CREATE OR ALTER PROCEDURE [dbo].[usp_GetPendingPartnerSubmissions]
    @BatchSize INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    -- Return up to @BatchSize submissions with Status = 1 (Ready to Submit)
    -- Ordered by creation date (oldest first)
    SELECT TOP (@BatchSize)
        ps.PartnerSubmissionId,
        ps.EDIIntegrationId,
        ps.PartnerCode,
        CAST(ps.PartnerXML AS NVARCHAR(MAX)) AS PartnerXML,   -- cast XML to string for Python
        ps.InsertDate
    FROM [EDI].[PartnerSubmission] ps
    WHERE ps.IntegrationStatusId = 1
    ORDER BY ps.InsertDate ASC;
END;
GO
