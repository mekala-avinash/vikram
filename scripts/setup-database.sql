-- ============================================================================
-- SQL Database Setup Script
-- ============================================================================
-- This script creates the necessary table for storing canonical XML data
-- Run this script after deploying the Azure SQL Database
-- ============================================================================

-- Create the CanonicalXmlData table
CREATE TABLE CanonicalXmlData (
    id INT PRIMARY KEY IDENTITY(1,1),
    xml_data NVARCHAR(MAX) NOT NULL,
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    processed BIT DEFAULT 0,
    processed_at DATETIME2 NULL,
    error_message NVARCHAR(MAX) NULL
);

-- Create index on processed flag for faster queries
CREATE INDEX IX_CanonicalXmlData_Processed 
ON CanonicalXmlData(processed, created_at);

-- Create index on created_at for time-based queries
CREATE INDEX IX_CanonicalXmlData_CreatedAt 
ON CanonicalXmlData(created_at DESC);

-- ============================================================================
-- Sample data insertion (for testing)
-- ============================================================================
-- Uncomment and modify the sample data below for testing

/*
INSERT INTO CanonicalXmlData (xml_data) VALUES 
(N'<CanonicalData id="1" timestamp="2024-01-01T10:00:00Z">
    <SourceField1>Value1</SourceField1>
    <SourceField2>Value2</SourceField2>
    <SourceField3>Value3</SourceField3>
</CanonicalData>'),
(N'<CanonicalData id="2" timestamp="2024-01-01T11:00:00Z">
    <SourceField1>ValueA</SourceField1>
    <SourceField2>ValueB</SourceField2>
    <SourceField3>ValueC</SourceField3>
</CanonicalData>');
*/

-- ============================================================================
-- Verify table creation
-- ============================================================================
SELECT 
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'CanonicalXmlData'
ORDER BY ORDINAL_POSITION;

-- Check row count
SELECT COUNT(*) AS TotalRecords FROM CanonicalXmlData;
SELECT COUNT(*) AS UnprocessedRecords FROM CanonicalXmlData WHERE processed = 0;
SELECT COUNT(*) AS ProcessedRecords FROM CanonicalXmlData WHERE processed = 1;
