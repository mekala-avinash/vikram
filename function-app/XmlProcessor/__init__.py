import logging
import os
import json
from datetime import datetime
import pyodbc
from lxml import etree
import requests
from azure.storage.blob import BlobServiceClient
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
import azure.functions as func


def main(timer: func.TimerRequest) -> None:
    """
    Azure Function to process XML data from SQL Database,
    transform to FA(3) format, and send to vendor API.
    
    Triggered every hour based on TIMER_SCHEDULE configuration.
    """
    logging.info('XML Processor function started at %s', datetime.utcnow())
    
    try:
        # Initialize Azure clients
        credential = DefaultAzureCredential()
        
        # Get configuration from environment variables
        key_vault_uri = os.environ['KEY_VAULT_URI']
        sql_server_fqdn = os.environ['SQL_SERVER_FQDN']
        sql_database_name = os.environ['SQL_DATABASE_NAME']
        sql_table_name = os.environ['SQL_TABLE_NAME']
        storage_account_name = os.environ['STORAGE_ACCOUNT_NAME']
        fa3_container_name = os.environ['FA3_CONTAINER_NAME']
        vendor_api_url = os.environ['VENDOR_API_URL']
        vendor_api_auth_type = os.environ['VENDOR_API_AUTH_TYPE']
        
        # Initialize Key Vault client
        secret_client = SecretClient(vault_url=key_vault_uri, credential=credential)
        
        # Get SQL connection string from Key Vault
        sql_connection_string = secret_client.get_secret("sql-connection-string").value
        
        # Step 1: Connect to SQL Database and retrieve XML data
        logging.info('Connecting to SQL Database: %s', sql_database_name)
        xml_records = fetch_xml_from_database(sql_connection_string, sql_table_name)
        logging.info('Retrieved %d XML records from database', len(xml_records))
        
        if not xml_records:
            logging.warning('No XML records found to process')
            return
        
        # Step 2: Transform each XML record to FA(3) format
        logging.info('Starting XSLT transformation to FA(3) format')
        fa3_records = []
        
        # Load XSLT transformation template
        xslt_path = os.path.join(os.path.dirname(__file__), 'transform.xslt')
        with open(xslt_path, 'rb') as xslt_file:
            xslt_root = etree.XML(xslt_file.read())
            transform = etree.XSLT(xslt_root)
        
        for record in xml_records:
            try:
                record_id = record['id']
                xml_data = record['xml_data']
                
                # Parse XML
                xml_doc = etree.fromstring(xml_data.encode('utf-8'))
                
                # Apply XSLT transformation
                fa3_doc = transform(xml_doc)
                fa3_data = etree.tostring(fa3_doc, pretty_print=True, encoding='unicode')
                
                fa3_records.append({
                    'id': record_id,
                    'fa3_data': fa3_data,
                    'timestamp': datetime.utcnow().isoformat()
                })
                
                logging.info('Transformed record ID: %s', record_id)
                
            except Exception as e:
                logging.error('Error transforming record ID %s: %s', record.get('id'), str(e))
                continue
        
        logging.info('Successfully transformed %d records to FA(3) format', len(fa3_records))
        
        # Step 3: Save FA(3) data to Blob Storage
        logging.info('Saving FA(3) data to Blob Storage')
        blob_service_client = BlobServiceClient(
            account_url=f"https://{storage_account_name}.blob.core.windows.net",
            credential=credential
        )
        
        container_client = blob_service_client.get_container_client(fa3_container_name)
        
        saved_blobs = []
        for fa3_record in fa3_records:
            blob_name = f"fa3_{fa3_record['id']}_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.xml"
            blob_client = container_client.get_blob_client(blob_name)
            
            blob_client.upload_blob(
                fa3_record['fa3_data'],
                overwrite=True,
                metadata={
                    'record_id': str(fa3_record['id']),
                    'processed_at': fa3_record['timestamp']
                }
            )
            
            saved_blobs.append(blob_name)
            logging.info('Saved FA(3) data to blob: %s', blob_name)
        
        # Step 4: Send FA(3) data to Vendor API
        logging.info('Sending FA(3) data to vendor API: %s', vendor_api_url)
        
        # Get API credentials from Key Vault
        api_headers = {'Content-Type': 'application/xml'}
        
        if vendor_api_auth_type == 'apikey':
            api_key = secret_client.get_secret("vendor-api-key").value
            api_headers['X-API-Key'] = api_key
        
        # Send each FA(3) record to vendor API
        successful_sends = 0
        for fa3_record in fa3_records:
            try:
                response = requests.post(
                    vendor_api_url,
                    data=fa3_record['fa3_data'].encode('utf-8'),
                    headers=api_headers,
                    timeout=30
                )
                
                if response.status_code in [200, 201, 202]:
                    successful_sends += 1
                    logging.info(
                        'Successfully sent record ID %s to vendor API. Response: %s',
                        fa3_record['id'],
                        response.text[:200]
                    )
                    
                    # Log acknowledgment
                    log_acknowledgment(
                        blob_service_client,
                        fa3_container_name,
                        fa3_record['id'],
                        response.text
                    )
                else:
                    logging.error(
                        'Failed to send record ID %s. Status: %d, Response: %s',
                        fa3_record['id'],
                        response.status_code,
                        response.text
                    )
                    
            except Exception as e:
                logging.error('Error sending record ID %s to vendor API: %s', fa3_record['id'], str(e))
                continue
        
        logging.info(
            'XML Processor function completed. Processed: %d, Sent: %d',
            len(fa3_records),
            successful_sends
        )
        
    except Exception as e:
        logging.error('Fatal error in XML Processor function: %s', str(e), exc_info=True)
        raise


def fetch_xml_from_database(connection_string: str, table_name: str) -> list:
    """
    Fetch XML data from SQL Database table.
    
    Args:
        connection_string: SQL Server connection string
        table_name: Name of the table containing XML data
        
    Returns:
        List of dictionaries containing id and xml_data
    """
    records = []
    
    try:
        conn = pyodbc.connect(connection_string)
        cursor = conn.cursor()
        
        # Query to fetch unprocessed XML records
        # Adjust the query based on your table schema
        query = f"""
            SELECT id, xml_data, created_at
            FROM {table_name}
            WHERE processed = 0
            ORDER BY created_at ASC
        """
        
        cursor.execute(query)
        
        for row in cursor.fetchall():
            records.append({
                'id': row.id,
                'xml_data': row.xml_data,
                'created_at': row.created_at
            })
        
        # Mark records as processed
        if records:
            record_ids = [str(r['id']) for r in records]
            update_query = f"""
                UPDATE {table_name}
                SET processed = 1, processed_at = GETUTCDATE()
                WHERE id IN ({','.join(record_ids)})
            """
            cursor.execute(update_query)
            conn.commit()
        
        cursor.close()
        conn.close()
        
    except Exception as e:
        logging.error('Error fetching data from database: %s', str(e))
        raise
    
    return records


def log_acknowledgment(blob_service_client, container_name: str, record_id: int, acknowledgment: str):
    """
    Log vendor API acknowledgment to blob storage.
    
    Args:
        blob_service_client: Azure Blob Service Client
        container_name: Container name for FA(3) data
        record_id: Record ID
        acknowledgment: Acknowledgment response from vendor API
    """
    try:
        container_client = blob_service_client.get_container_client(container_name)
        blob_name = f"ack_{record_id}_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.json"
        
        ack_data = {
            'record_id': record_id,
            'acknowledgment': acknowledgment,
            'received_at': datetime.utcnow().isoformat()
        }
        
        blob_client = container_client.get_blob_client(blob_name)
        blob_client.upload_blob(
            json.dumps(ack_data, indent=2),
            overwrite=True
        )
        
        logging.info('Logged acknowledgment for record ID %s', record_id)
        
    except Exception as e:
        logging.error('Error logging acknowledgment: %s', str(e))
