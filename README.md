 ---
  Azure XML Integration — Multi-Country Invoice Transformation Pipeline
  v2.0 (March 2026)

  ---

  Architecture Overview

  This system transforms internal CanonicalInvoice XML documents into
  country-specific e-invoicing formats and submits them to the appropriate
  government/partner APIs.

  Phase 3: TransformToKsefXml Logic App (now multi-country)
  Phase 4: SubmitToPartner Logic App (KSeF submission, future: per-country routing)

  CanonicalInvoice → [Service Bus] → Transform Workflow → [Service Bus] → Submit Workflow

  ---

  Multi-Country Routing (v2.0)

  The Service Bus payload now includes a ConversionType field:

  {"CanonicalId": 123, "ConversionType": "PL_KSEF"}

  The TransformToKsefXml workflow uses a Switch action to route to the correct
  XSLT map and XSD schema based on ConversionType:

  ConversionType    XSLT Map              XSD Schema              Status
  ─────────────────────────────────────────────────────────────────────────
  PL_KSEF           KsefFa3.xslt          FA3_schemat.xsd         Active
  BE_UBL            BelgiumUBL.xslt       UBL-Invoice-2.1.xsd     Planned
  DE_XRECHNUNG      GermanyXRechnung.xslt  XRechnung-Invoice.xsd   Planned
  FR_FACTURX        FranceFacturX.xslt    Factur-X.xsd            Planned
  IT_SDI            ItalySDI.xslt         FatturaPA.xsd           Planned

  Default: Terminates with error "UnsupportedConversionType"

  The outbound queue message also carries ConversionType for downstream routing:
  {"PartnerSubmissionId": 456, "ConversionType": "PL_KSEF"}

  ---

  What is KsefFa3.xslt?

  It is an XSLT transformation map — a program written in XML that reads one XML
  document (your internal invoice format) and converts it into a completely
  different XML document (the Polish government's KSeF FA(3) invoice format).

  Your System XML          XSLT Engine           KSeF FA(3) XML
  ─────────────────   →   (KsefFa3.xslt)   →   ────────────────
  <CanonicalInvoice>                             <Faktura>
    <Header>                                       <Naglowek>
    <Parties>                                      <Podmiot1>
    <Lines>                                        <Podmiot2>
    <Summary>                                      <Fa>
  </CanonicalInvoice>                            </Faktura>

  ---

  KsefFa3.xslt v7.0 — Changelog

  Aligned with KSeF Excel spec v2.2 (eLIMS Legacy). Key additions:

  Corrective Invoices:
  - DaneFaKorygowanej section (DataWystFaKorygowanej, NrFaKorygowanej, NrKSeF, NrKSeFN)
  - Podmiot2K (corrected buyer data)
  - PrzyczynaKorekty (default: "Korekta całkowita – wycofanie faktury")
  - TypKorekty (default: 1)
  - "cancellation" mapped to KOR invoice type
  - StanPrzed (quantity before correction) in FaWiersz

  New Fields:
  - PrefiksPodatnika: Hardcoded to PL (per Excel spec)
  - P_1M: Invoice issue location (Malbork, Katowice, Łódź per branch)
  - TP: Entity relationship indicator (related party / Eurofins group)
  - FP: Cash register transaction flag
  - KursWalutyZ: Foreign currency exchange rate
  - P_13_10: Reverse charge net amount
  - P_13_6_3: Explicit 0% VAT export bucket
  - P_13_9: np (outside scope) in TaxBreakdown path

  Payment Enhancements:
  - TerminOpis: Structured payment term (Ilosc/Jednostka/ZdarzeniePoczatkowe)
  - Zaplacono: Always emitted (0 or 1)
  - ZnacznikZaplatyCzesciowej: Partial payment flag
  - ZaplataCzesciowa: Partial payment details (amount, date, method)
  - PlatnoscInna/OpisPlatnosci: Other payment method description

  Orders:
  - Zamowienia: Customer order/PO numbers with dates (multiple supported)
  - Backward-compatible with Header/PurchaseOrderNumber

  Line Items:
  - P_12_Zal_15: Annex 15 goods/services classification
  - KursWaluty: Line-level exchange rate
  - StanPrzed: Pre-correction quantity

  Podmiot3 (Third Party) Enhancements:
  - KodUE/NrVatUE path for EU third parties
  - IDWew (internal ID) for Polish entities
  - RolaInna/OpisRoli for custom roles

  Advance Invoices:
  - ZaliczkaCzesciowa (P_6Z, P_15Z) for advance receipt
  - FakturaZaliczkowa (NrKSeFZN, NrFaZaliczkowej, NrKSeFFaZaliczkowej)

  Stopka (Footer):
  - Structured Rejestry (KRS, REGON as separate elements)
  - Informacje for additional text

  ---

  Complete Data Flow Diagram

  CanonicalInvoice XML
  ├── Header/IssueDate         → Naglowek/DataWytworzeniaFa  (+ T00:00:00Z if no time)
  ├── Header/InvoiceNumber     → Fa/P_2
  ├── Header/IssuePlace        → Fa/P_1M  (NEW: issue location)
  ├── Header/Currency          → Fa/KodWaluty  (default: PLN)
  ├── Header/ExchangeRate      → Fa/KursWalutyZ  (if foreign currency)
  ├── Header/SaleDate          → Fa/P_6
  ├── Header/InvoiceType       → Fa/RodzajFaktury  (VAT, KOR, ZAL, ROZ, UPR)
  ├── Header/RelatedParty      → Fa/TP  (NEW: entity relationship)
  ├── Header/CashRegisterFlag  → Fa/FP  (NEW: cash register)
  ├── Header/Corrected*        → Fa/DaneFaKorygowanej/*  (NEW: corrective invoice)
  ├── Header/CorrectionReason  → Fa/PrzyczynaKorekty  (NEW)
  ├── Header/CorrectionType    → Fa/TypKorekty  (NEW)
  ├── Parties/Seller/TaxId     → Podmiot1/DaneIdentyfikacyjne/NIP  (validated)
  ├── Parties/Seller/VATPrefix → Podmiot1/PrefiksPodatnika  (NEW: default PL)
  ├── Parties/Seller/KRS       → Stopka/Rejestry/KRS  (NEW: structured)
  ├── Parties/Seller/REGON     → Stopka/Rejestry/REGON  (NEW: structured)
  ├── Parties/Seller/Name      → Podmiot1/DaneIdentyfikacyjne/Nazwa
  ├── Parties/Buyer/TaxId      → Podmiot2 → NIP or KodUE+NrVatUE or KodKraju+NrID or BrakID
  ├── Parties/ThirdParty       → Podmiot3  (enhanced: KodUE/NrVatUE, IDWew, RolaInna)
  ├── Lines/LineItem[@Number]  → Fa/FaWiersz  (enhanced: P_12_Zal_15, KursWaluty, StanPrzed)
  ├── Summary/TaxBreakdown     → Fa/P_13_x + P_14_x  (enhanced: P_13_10, P_13_6_3, P_13_9)
  ├── Payment/DueDate          → Fa/Platnosc/TerminPlatnosci/Termin
  ├── Payment/TermDescription  → Fa/Platnosc/TerminPlatnosci/TerminOpis  (NEW)
  ├── Payment/PartialPayment   → Fa/Platnosc/ZaplataCzesciowa  (NEW)
  └── Orders/Order             → Fa/WarunkiTransakcji/Zamowienia  (NEW)

  ---

  Tax Rate Mapping

  Rate            KSeF Net Field       KSeF Tax Field     Notes
  ──────────────────────────────────────────────────────────────────
  23% / 22%       P_13_1               P_14_1             Standard rate
  8% / 7%         P_13_2               P_14_2             Reduced rate
  5%              P_13_3               P_14_3             Special reduced
  0% KR           P_13_6_1             (none)             Domestic zero-rate
  0% WDT          P_13_6_2             (none)             Intra-EU delivery
  0% EX (export)  P_13_8               (none)             Export outside EU
  0% EX (bucket3) P_13_6_3             (none)             Export (explicit)
  zw (exempt)     P_13_7               (none)             VAT exempt
  np I / np II    P_13_9               (none)             Outside scope
  oo (rev.charge) P_13_10              (none)             Reverse charge (NEW)

  ---

  Service Bus Message Formats

  Trigger message (topic: invoice-ready-for-transformation):
  {
    "CanonicalId": 123,
    "ConversionType": "PL_KSEF"
  }

  Output message (queue: partner-xml-ready-for-submission):
  {
    "PartnerSubmissionId": 456,
    "ConversionType": "PL_KSEF"
  }

  Supported ConversionType values: PL_KSEF, BE_UBL, DE_XRECHNUNG, FR_FACTURX, IT_SDI

  ---

  SQL Schema Changes

  The InsertPartnerDocument stored procedure now accepts ConversionType:
  EXEC [EDI].[InsertPartnerDocument]
    @CanonicalId = @CanonicalId,
    @PartnerDocumentData = @PartnerDocumentData,
    @ConversionType = @ConversionType

  ---

  Testing

  Run the test suite:
    cd logic-app-v2
    python test/test_transform.py

  Tests:
  1. Standard invoice (EUR, non-EU buyer, 0% export) — structural + XSD validation
  2. Corrective invoice (KOR, PLN, Polish buyer) — corrective fields + XSD validation

  ---

  Adding a New Country

  1. Create XSLT: logic-app-v2/maps/{CountryFormat}.xslt
  2. Add XSD schema: logic-app-v2/schemas/{Format}.xsd
  3. Add Switch case in TransformToKsefXml/workflow.json with new ConversionType
  4. Add test cases in logic-app-v2/test/
  5. (Future) Add submission routing in SubmitToPartner/workflow.json

  ---

  File Structure

  azure-xml-integration/
  ├── logic-app-v2/
  │   ├── TransformToKsefXml/workflow.json   ← Multi-country routing (Switch on ConversionType)
  │   ├── SubmitToPartner/workflow.json      ← KSeF API submission (future: per-country)
  │   ├── maps/
  │   │   └── KsefFa3.xslt                  ← Polish KSeF FA(3) v7.0 (Excel spec aligned)
  │   │   └── (future: BelgiumUBL.xslt, GermanyXRechnung.xslt, etc.)
  │   ├── schemas/
  │   │   ├── FA3_schemat.xsd
  │   │   ├── StrukturyDanych_v10-0E.xsd
  │   │   ├── ElementarneTypyDanych_v10-0E.xsd
  │   │   └── KodyKrajow_v10-0E.xsd
  │   └── test/
  │       ├── test_transform.py              ← Test suite (standard + corrective)
  │       ├── input_corrective.xml           ← Corrective invoice test input
  │       └── sample XMLs
  ├── input.xml                              ← Sample canonical invoice (enhanced)
  ├── output.xml                             ← Expected transformation output
  └── README.md                              ← This file
