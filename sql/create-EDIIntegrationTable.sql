-- ============================================================================
-- DDL: EDIIntegrationTable
-- ============================================================================
-- Run this FIRST before running usp_InsertPartnerSubmission.sql
-- or usp_UpdatePartnerSubmissionStatus.sql
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'EDIIntegrationTable')
BEGIN
    CREATE TABLE [dbo].[EDIIntegrationTable]
    (
        EDIIntegrationId    INT IDENTITY(1,1) PRIMARY KEY,

        -- Status lifecycle:
        --   1 = Raw XML Received
        --   2 = Canonical XML Generated  ← Stage 3 reads rows at this status
        --   3 = KSeF XML Generated       ← Stage 3 sets this after transform
        --   4 = Submitted to KSeF        ← Stage 4 sets this
        Status              INT NOT NULL DEFAULT 1,

        -- The internal canonical XML (input to XSLT transform)
        CanonicalXml        NVARCHAR(MAX) NULL,

        -- Raw source data (optional, for audit)
        RawXml              NVARCHAR(MAX) NULL,

        CreatedAt           DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt           DATETIME2 NOT NULL DEFAULT GETUTCDATE()
    );

    CREATE INDEX IX_EDIIntegration_Status
        ON [dbo].[EDIIntegrationTable] (Status)
        INCLUDE (EDIIntegrationId, CreatedAt);

    PRINT 'EDIIntegrationTable created.';
END
ELSE
BEGIN
    PRINT 'EDIIntegrationTable already exists.';
END
GO

-- ============================================================================
-- TEST DATA — Insert a sample record at Status=2 (ready for Stage 3)
-- The CanonicalXml matches the XPath mappings in KsefFa3.xslt
-- ============================================================================
INSERT INTO [dbo].[EDIIntegrationTable] (Status, CanonicalXml)
VALUES (
    2,  -- Canonical XML Generated: ready for Logic App to pick up
    N'<?xml version="1.0" encoding="UTF-8"?>
<Invoice>
  <Header>
    <InvoiceNumber>FV/2026/001</InvoiceNumber>
    <InvoiceDate>2026-02-19</InvoiceDate>
    <DueDate>2026-03-19</DueDate>
  </Header>
  <Seller>
    <TaxId>1234567890</TaxId>
    <CompanyName>Acme Sp. z o.o.</CompanyName>
    <AddressLine1>ul. Testowa 1</AddressLine1>
    <City>Warszawa</City>
    <PostalCode>00-001</PostalCode>
  </Seller>
  <Buyer>
    <TaxId>0987654321</TaxId>
    <CompanyName>Buyer Corp Sp. z o.o.</CompanyName>
    <AddressLine1>ul. Kupiecka 5</AddressLine1>
    <City>Krakow</City>
    <PostalCode>30-001</PostalCode>
  </Buyer>
  <Lines>
    <Line>
      <LineNumber>1</LineNumber>
      <Description>Consulting Services</Description>
      <UnitOfMeasure>szt</UnitOfMeasure>
      <Quantity>10</Quantity>
      <UnitPrice>100.00</UnitPrice>
      <NetAmount>1000.00</NetAmount>
      <VatRate>23</VatRate>
    </Line>
    <Line>
      <LineNumber>2</LineNumber>
      <Description>Software License</Description>
      <UnitOfMeasure>szt</UnitOfMeasure>
      <Quantity>1</Quantity>
      <UnitPrice>500.00</UnitPrice>
      <NetAmount>500.00</NetAmount>
      <VatRate>23</VatRate>
    </Line>
  </Lines>
  <Totals>
    <NetAmount23>1500.00</NetAmount23>
    <VatAmount23>345.00</VatAmount23>
    <GrossAmount>1845.00</GrossAmount>
  </Totals>
</Invoice>'
);

PRINT 'Test record inserted.';
GO

-- ============================================================================
-- VERIFY: Run this to confirm the record is ready for Stage 3
-- ============================================================================
SELECT
    EDIIntegrationId,
    Status,
    CreatedAt,
    LEFT(CanonicalXml, 200) AS CanonicalXml_Preview
FROM [dbo].[EDIIntegrationTable]
WHERE Status = 2
ORDER BY CreatedAt DESC;
