-- ksef_invoice_xml_query.sql
-- Purpose: Generate a single KSeF FA(3) XML payload per invoice (header once, lines from two sources, summary once)
-- Notes:
--  * Uses FA(3) structure: <Faktura> -> <Naglowek> -> <Podmiot1/2> -> <Fa>(lines) -> <Rozliczenie>
--  * Ensures one-row header by isolating it in CTE [inv]
--  * Merges line items from InvoiceLineItems and InvoiceGroupItemCharges via UNION ALL in CTE [lines]
--  * Escapes XML text using FOR XML PATH(''), TYPE where needed
--  * Computes rate-level summaries and invoice totals
--  * Strips 'PL' from buyer NIP
--  * Builds net unit price as (NetLine + Discount)/Qty to maintain: Qty*P_9A - P_10 = P_11

DECLARE @LabSiteCode  nvarchar(50) = N'EUPL007';
DECLARE @InvoiceNumber nvarchar(50) = N'IV-CPL018-25-000695';

;WITH inv AS (
    SELECT TOP (1)
        CI.CustomerInvoiceId,
        CI.InvoiceNumber,
        InvoiceIssueDate = FORMAT(CI.InvoiceIssueDate, 'yyyy-MM-dd'),
        InvoiceDueDate   = FORMAT(CI.InvoiceDueDate,   'yyyy-MM-dd'),
        SellerNIP        = CI.VATNumber,
        SellerName       = CI.LegalEntityName,
        SellerAddressL1  = CI.InvoiceContactAddress,
        CurrencyCode     = CI.Currency,
        PaymentMethodCode = '1',
        IBAN             = CI.InternationalBankAccountNumber,
        PONumber         = NULLIF(CI.PurchaseOrderNumber, ''),
        BuyerNIP  = CASE WHEN LEFT(CI.AccountTaxCode,2)='PL'
                         THEN SUBSTRING(CI.AccountTaxCode,3,LEN(CI.AccountTaxCode)-2)
                         ELSE CI.AccountTaxCode END,
        BuyerName = CI.ClientName,
        SellerEmail = (SELECT TOP (1) LEID.Email
                       FROM Global.LegalEntityInvoicingDetails LEID
                       JOIN Global.Labsites L ON L.LegalEntityId = LEID.LegalEntityId
                       WHERE L.Code = CI.LabSiteCode),
        SellerPhone = (SELECT TOP (1)
                          CONCAT(P.InternationalCountryCode, P.PhoneNumber)
                       FROM Global.LegalEntityInvoicingDetails LEID
                       JOIN Global.LegalEntityInvoicingDetailPhones LEP
                         ON LEP.LegalEntityInvoicingDetailId = LEID.LegalEntityInvoicingDetailId
                       JOIN Global.Labsites L ON L.LegalEntityId = LEID.LegalEntityId
                       JOIN Global.Phones P ON P.PhoneId = LEP.PhoneId
                       WHERE L.Code = CI.LabSiteCode
                       ORDER BY P.PhoneId),
        BuyerEmail = (SELECT TOP (1) IC.Email
                      FROM Silver.InvoiceContacts IC
                      WHERE IC.CustomerInvoiceId = CI.CustomerInvoiceId
                        AND IC.ContactTypeEnum = '1'
                      ORDER BY IC.ContactId),
        BuyerCountry  = (SELECT TOP (1) AD.Country
                         FROM Silver.InvoiceContacts IC
                         JOIN Silver.Addresses AD ON AD.ContactId = IC.ContactId
                         WHERE IC.CustomerInvoiceId = CI.CustomerInvoiceId
                           AND IC.ContactTypeEnum = '1'
                         ORDER BY AD.AddressId),
        BuyerAddressL1 = (SELECT TOP (1) AD.AddressLine1
                          FROM Silver.InvoiceContacts IC
                          JOIN Silver.Addresses AD ON AD.ContactId = IC.ContactId
                          WHERE IC.CustomerInvoiceId = CI.CustomerInvoiceId
                            AND IC.ContactTypeEnum = '1'
                          ORDER BY AD.AddressId),
        InvoiceNet   = CI.InvoiceTotalWithoutVat,
        InvoiceVat   = CI.PrimaryTaxAmount,
        InvoiceGross = CI.InvoiceTotal
    FROM Silver.CustomerInvoices CI
    WHERE CI.LabSiteCode = @LabSiteCode
      AND CI.InvoiceNumber = @InvoiceNumber
),
lines_ili AS (
    SELECT
        CI.CustomerInvoiceId,
        P7 = LEFT(CONCAT(
                'Batch# ', IGI.InvoiceGroupItemName,
                ' Project ', IGI.ProjectName,
                ' -- Sample# ', SGI.SampleNumber, ' ', SGI.InvoiceSubGroupSummary,
                ' -- ', ILI.TestCode, ' - ', ILI.TestName
             ), 512),
        UnitOfMeasure = 'szt',
        Indeks        = T.InstrumentSequenceId,
        Qty           = ILI.Quantity,
        DiscountAmt   = ISNULL(ILI.DiscountAmount,0.00),
        NetLine       = ILI.NetAmount,
        KodStawki     = '23'
    FROM Silver.CustomerInvoices CI
    JOIN Silver.InvoiceGroupItems IGI   ON IGI.CustomerInvoiceId = CI.CustomerInvoiceId
    JOIN Silver.InvoiceSubGroupItems SGI ON SGI.InvoiceGroupItemId = IGI.InvoiceGroupItemId
    JOIN Silver.InvoiceLineItems ILI     ON ILI.InvoiceSubGroupItemId = SGI.InvoiceSubGroupItemId
    JOIN CoreLab.Tests T                ON T.TestId = ILI.TestId
    WHERE CI.LabSiteCode   = @LabSiteCode
      AND CI.InvoiceNumber = @InvoiceNumber
),
lines_igic AS (
    SELECT
        CI.CustomerInvoiceId,
        P7 = LEFT(CONCAT(
                'Batch# ', IGI.InvoiceGroupItemName,
                ' Project ', IGI.ProjectName,
                ' -- ', IGIC.TestCode, ' - ', IGIC.[Description]
             ), 512),
        UnitOfMeasure = 'szt',
        Indeks        = BC.BatchChargeCode,
        Qty           = IGIC.Quantity,
        DiscountAmt   = ISNULL(IGIC.DiscountAmount,0.00),
        NetLine       = IGIC.NetAmount,
        KodStawki     = '23'
    FROM Silver.CustomerInvoices CI
    JOIN Silver.InvoiceGroupItems IGI        ON IGI.CustomerInvoiceId = CI.CustomerInvoiceId
    JOIN Silver.InvoiceGroupItemCharges IGIC ON IGIC.InvoiceGroupItemId = IGI.InvoiceGroupItemId
    JOIN CoreLab.BatchCharges BC            ON BC.BatchChargeId = IGIC.BatchChargeId
    WHERE CI.LabSiteCode   = @LabSiteCode
      AND CI.InvoiceNumber = @InvoiceNumber
),
lines AS (
    SELECT *,
           RowNo = ROW_NUMBER() OVER (ORDER BY (SELECT 1)),
           UnitPriceNet = CASE WHEN NULLIF(Qty,0) IS NOT NULL
                               THEN CAST((NetLine + DiscountAmt) / NULLIF(Qty,0) AS decimal(18,2))
                               ELSE CAST(NetLine AS decimal(18,2)) END
    FROM (
        SELECT * FROM lines_ili
        UNION ALL
        SELECT * FROM lines_igic
    ) x
),
sum_by_rate AS (
    SELECT
        KodStawki,
        NetBase = SUM(NetLine),
        VatAmt  = SUM( ROUND( NetLine * (CASE WHEN TRY_CONVERT(decimal(9,4), KodStawki) IS NOT NULL
                                              THEN TRY_CONVERT(decimal(9,4), KodStawki)/100.0
                                              ELSE 0 END), 2) )
    FROM lines
    GROUP BY KodStawki
),
sum_invoice AS (
    SELECT NetTotal = SUM(NetBase), VatTotal = SUM(VatAmt) FROM sum_by_rate
)
SELECT
    '<?xml version="1.0" encoding="UTF-8"?>' +
    '<Faktura xmlns="http://ksef.mf.gov.pl/schema/FA/3-0E">' +
    '<Naglowek><KodFormularza kodSystemowy="FA(3)" wersjaSchemy="1-0E">3</KodFormularza>' +
    '<DataWytworzeniaFa>' + CONVERT(varchar(19), SYSUTCDATETIME(), 126) + 'Z</DataWytworzeniaFa>' +
    '<SystemInfo>ITAAG002eLIMS-BPT_EUPL007</SystemInfo></Naglowek>' +

    '<!-- SELLER -->' +
    '<Podmiot1><DaneIdentyfikacyjne><NIP>' + inv.SellerNIP + '</NIP>' +
    '<Nazwa>' + inv.SellerName + '</Nazwa></DaneIdentyfikacyjne>' +
    '<Adres><KodKraju>PL</KodKraju><AdresL1>' +
        (SELECT inv.SellerAddressL1 FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)') +
    '</AdresL1></Adres>' +
    '<DaneKontaktowe><Email>' + inv.SellerEmail + '</Email>' +
    '<Telefon>' + inv.SellerPhone + '</Telefon></DaneKontaktowe></Podmiot1>' +

    '<!-- BUYER -->' +
    '<Podmiot2><DaneIdentyfikacyjne><NIP>' + inv.BuyerNIP + '</NIP>' +
    '<Nazwa>' + inv.BuyerName + '</Nazwa></DaneIdentyfikacyjne>' +
    '<Adres><KodKraju>' + inv.BuyerCountry + '</KodKraju><AdresL1>' +
        (SELECT inv.BuyerAddressL1 FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)') +
    '</AdresL1></Adres>' +
    '<DaneKontaktowe><Email>' + inv.BuyerEmail + '</Email></DaneKontaktowe></Podmiot2>' +

    '<!-- INVOICE CORE -->' +
    '<Fa><P_1>' + inv.InvoiceIssueDate + '</P_1>' +
    '<P_2>' + inv.InvoiceNumber + '</P_2>' +
    '<Waluta><KodWaluty>' + inv.CurrencyCode + '</KodWaluty></Waluta>' +
    '<Platnosc><TerminPlatnosci>' + inv.InvoiceDueDate + '</TerminPlatnosci>' +
    '<FormaPlatnosci>' + inv.PaymentMethodCode + '</FormaPlatnosci>' +
    '<RachunekBankowy><NrRB>' + inv.IBAN + '</NrRB></RachunekBankowy></Platnosc>' +
    CASE WHEN inv.PONumber IS NOT NULL
         THEN '<WarunkiTransakcji><Uwagi>' +
                (SELECT inv.PONumber FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)') +
              '</Uwagi></WarunkiTransakcji>'
         ELSE '' END +

    -- LINES
    (
        SELECT
              '<FaWiersz>' +
              '<NrWierszaFa>' + CONVERT(varchar(10), l.RowNo) + '</NrWierszaFa>' +
              '<P_7>' + (SELECT l.P7 FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)') + '</P_7>' +
              '<P_8A>' + l.UnitOfMeasure + '</P_8A>' +
              '<Indeks>' + (SELECT l.Indeks FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)') + '</Indeks>' +
              '<P_8B>' + CONVERT(varchar(50), l.Qty) + '</P_8B>' +
              '<P_9A>' + CONVERT(varchar(50), l.UnitPriceNet) + '</P_9A>' +
              '<P_10>' + CONVERT(varchar(50), CAST(l.DiscountAmt AS decimal(18,2))) + '</P_10>' +
              '<P_11>' + CONVERT(varchar(50), CAST(l.NetLine     AS decimal(18,2))) + '</P_11>' +
              '<P_12>' + l.KodStawki + '</P_12>' +
              '</FaWiersz>'
        FROM lines l
        ORDER BY l.RowNo
        FOR XML PATH(''), TYPE
    ).value('.', 'nvarchar(max)') +

    -- SUMMARY
    '<Rozliczenie>' +
      '<StawkiPodatku>' +
      (
        SELECT
            '<StawkaPodatku>' +
            '<KodStawki>' + sbr.KodStawki + '</KodStawki>' +
            '<PodstawaOpodatkowania>' + CONVERT(varchar(50), CAST(sbr.NetBase AS decimal(18,2))) + '</PodstawaOpodatkowania>' +
            '<KwotaPodatku>' + CONVERT(varchar(50), CAST(sbr.VatAmt  AS decimal(18,2))) + '</KwotaPodatku>' +
            '</StawkaPodatku>'
        FROM sum_by_rate sbr
        FOR XML PATH(''), TYPE
      ).value('.', 'nvarchar(max)') +
      '<KwotaPodatkuNaleznego>' + CONVERT(varchar(50), CAST(sinv.VatTotal AS decimal(18,2))) + '</KwotaPodatkuNaleznego>' +
      '<KwotaDoZaplaty>'      + CONVERT(varchar(50), CAST(inv.InvoiceGross AS decimal(18,2))) + '</KwotaDoZaplaty>' +
    '</Rozliczenie>' +
    '</Fa></Faktura>' AS KSeF_XML
FROM inv
CROSS APPLY sum_invoice sinv;