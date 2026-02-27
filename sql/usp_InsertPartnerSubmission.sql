-- ============================================================================
-- SP: usp_InsertPartnerSubmission
-- Phase 3: Called by Logic App after XSLT transformation
-- Saves the Partner XML to EDI.PartnerSubmission, IntegrationStatusId = 1 (Ready)
-- Then updates EDI.EDIIntegrationTable to IntegrationStatusId = 30 (PartnerXMLGenerated)
-- ============================================================================
CREATE OR ALTER PROCEDURE [EDI].[usp_InsertPartnerSubmission]
    @EDIIntegrationId   BIGINT,
    @PartnerXML         NVARCHAR(MAX),
    @PartnerCode        NVARCHAR(50) = 'KSEF'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PartnerSubmissionId BIGINT;

    -- Strip XML declaration if present to avoid encoding mismatch
    -- when inserting into XML column (SQL Server stores XML as UTF-16 internally)
    -- e.g. removes: <?xml version="1.0" encoding="utf-8"?>
    IF LEFT(LTRIM(@PartnerXML), 5) = '<?xml'
        SET @PartnerXML = LTRIM(SUBSTRING(@PartnerXML, CHARINDEX('?>', @PartnerXML) + 2, LEN(@PartnerXML)));

    -- Insert the Partner XML into EDI.PartnerSubmission
    INSERT INTO [EDI].[PartnerSubmission]
    (
        EDIIntegrationId,
        PartnerCode,
        PartnerXML,
        IntegrationStatusId,   -- 1 = Ready to Submit
        InsertDate,
        LastUpdateDate
    )
    VALUES
    (
        @EDIIntegrationId,
        @PartnerCode,
        TRY_CAST(@PartnerXML AS XML),   -- TRY_CAST: returns NULL instead of crashing on bad XML
        1,
        GETUTCDATE(),
        GETUTCDATE()
    );

    SET @PartnerSubmissionId = SCOPE_IDENTITY();

    -- Update EDIIntegrationTable to 30 = PartnerXMLGenerated
    UPDATE [EDI].[EDIIntegrationTable]
    SET
        IntegrationStatusId = 30,
        LastUpdateDate      = GETUTCDATE()
    WHERE EDIIntegrationId = @EDIIntegrationId;

    -- Return the new submission ID
    SELECT @PartnerSubmissionId AS PartnerSubmissionId;
END;
GO
