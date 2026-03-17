 ---                                                                             
  What is KsefFa3.xslt?                                                           
                                                                                  
  It is an XSLT transformation map — a program written in XML that reads one XML
  document (your internal invoice format) and converts it into a completely       
  different XML document (the Polish government's KSeF FA(3) invoice format).

  Think of it like a translation dictionary: your system speaks
  "CanonicalInvoice", the Polish tax authority (KSeF) speaks "Faktura". This file
  translates between the two.

  Your System XML          XSLT Engine           KSeF FA(3) XML
  ─────────────────   →   (KsefFa3.xslt)   →   ────────────────
  <CanonicalInvoice>                             <Faktura>
    <Header>                                       <Naglowek>
    <Parties>                                      <Podmiot1>
    <Lines>                                        <Podmiot2>
    <Summary>                                      <Fa>
  </CanonicalInvoice>                            </Faktura>

  ---
  File Structure — Section by Section

  1. File Declaration (lines 1–16)

  <xsl:stylesheet version="1.0"
      xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
      xmlns="http://ksef.mf.gov.pl/schema/FA/3-0E"
      exclude-result-prefixes="xsl">

  What: version="1.0"
  Why: Tells the XSLT engine which spec to follow. Azure Logic Apps supports XSLT
    1.0.
  ────────────────────────────────────────
  What: xmlns:xsl=...
  Why: Declares the XSLT instruction namespace — every xsl: tag is an instruction
  ────────────────────────────────────────
  What: xmlns="http://ksef.mf.gov.pl/schema/FA/3-0E"
  Why: Sets the default output namespace — every output element automatically
    belongs to the KSeF namespace, matching what the XSD requires
  ────────────────────────────────────────
  What: exclude-result-prefixes="xsl"
  Why: Prevents the xsl: namespace from appearing in the output XML

  ---
  2. Root Template (line 19–279)

  <xsl:template match="/">
      <Faktura> ... </Faktura>
  </xsl:template>

  - match="/" means "start here — at the very root of the input document"
  - <Faktura> is the root element required by FA3_schemat.xsd
  - Everything inside builds the output document

  The root template has 4 major sections, each mapping to a section of the XSD:

  ---
  3. NAGLOWEK — Invoice Header (lines 22–45)

  Maps to XSD type TNaglowek. Contains metadata about the invoice form itself.

  <Naglowek>
      <KodFormularza kodSystemowy="FA (3)" wersjaSchemy="1-0E">FA</KodFormularza>
      <WariantFormularza>3</WariantFormularza>
      <DataWytworzeniaFa> ... </DataWytworzeniaFa>
      <SystemInfo> ... </SystemInfo>
  </Naglowek>

  ┌────────────────┬───────────────────────────────┬─────────────────────────┐
  │  Output Field  │            Source             │          Logic          │
  ├────────────────┼───────────────────────────────┼─────────────────────────┤
  │ KodFormularza  │ Hardcoded FA with attributes  │ XSD requires exactly    │
  │                │                               │ these values for FA(3)  │
  ├────────────────┼───────────────────────────────┼─────────────────────────┤
  │ WariantFormula │ Hardcoded 3                   │ Always 3 for FA(3)      │
  │ rza            │                               │                         │
  ├────────────────┼───────────────────────────────┼─────────────────────────┤
  │                │                               │ If date lacks a T (time │
  │ DataWytworzeni │ CanonicalInvoice/Header/Issue │  part), appends         │
  │ aFa            │ Date                          │ T00:00:00Z to make it   │
  │                │                               │ ISO 8601 datetime       │
  ├────────────────┼───────────────────────────────┼─────────────────────────┤
  │                │ CanonicalInvoice/Header/Syste │ Falls back to Standard_ │
  │ SystemInfo     │ mInfo                         │ Integration_System if   │
  │                │                               │ blank                   │
  └────────────────┴───────────────────────────────┴─────────────────────────┘

  ---
  4. PODMIOT1 — Seller (lines 47–85)

  Maps to XSD type TPodmiot1. The seller is strictly required to have a Polish NIP
   (tax ID).

  <Podmiot1>
      <DaneIdentyfikacyjne>
          <NIP> ... </NIP>        <!-- Polish 10-digit tax ID -->
          <Nazwa> ... </Nazwa>    <!-- Company name -->
      </DaneIdentyfikacyjne>
      <Adres> ... </Adres>        <!-- Address -->
      <DaneKontaktowe> ... </DaneKontaktowe>   <!-- Optional: email/phone -->
  </Podmiot1>

  Key logic — NIP validation (lines 54–59):
  <xsl:when test="string-length($sellerTaxId) = 10
      and not(contains($sellerTaxId, '-'))
      and not(contains($sellerTaxId, ' '))
      and translate($sellerTaxId, '0123456789', '') = ''">
  This checks: exactly 10 characters, no dashes, no spaces, only digits. If
  invalid, falls back to 1111111111 (test dummy). This mirrors what the XSD
  pattern restriction requires.

  ---
  5. PODMIOT2 — Buyer (lines 87–138)

  Maps to XSD type TPodmiot2. The buyer is more flexible — can use NIP, a foreign
  tax ID (NrID), or BrakID (no ID at all).

  <xsl:choose>
      <!-- Polish NIP → <NIP> -->
      <xsl:when test="[10 digits check]"> <NIP>...</NIP> </xsl:when>
      <!-- Foreign ID → <KodKraju> + <NrID> -->
      <xsl:when test="$buyerTaxId != ''"> <NrID>...</NrID> </xsl:when>
      <!-- No ID at all → <BrakID>1</BrakID> -->
      <xsl:otherwise> <BrakID>1</BrakID> </xsl:otherwise>
  </xsl:choose>

  Two hardcoded fields at the end (lines 134–137):
  - <JST>2</JST> — not a local government unit
  - <GV>2</GV> — not a VAT group member

  These are required by the XSD with no equivalent in your CanonicalInvoice.

  ---
  6. FA — Invoice Core (lines 140–277)

  The main invoice body. Maps to XSD type TFa.

  6a. Simple field mappings

  <KodWaluty>PLN</KodWaluty>          <!-- Currency, default PLN -->
  <P_1>2024-01-15</P_1>               <!-- Issue date -->
  <P_2>FV/2024/001</P_2>              <!-- Invoice number -->
  <P_15>1230.00</P_15>                <!-- Total gross amount -->

  6b. Tax summaries — named template call (line 159)

  <xsl:call-template name="emit-tax-summaries"/>
  Delegates to a separate named template (lines 282–316) to keep the main template
   clean. See section 7 below.

  6c. ADNOTACJE — Required annotations (lines 164–188)

  All hardcoded to 2 (No) or 1 (Not applicable). These are regulatory flags
  required by KSeF but not present in CanonicalInvoice:
  <P_16>2</P_16>   <!-- No cash accounting method -->
  <P_17>2</P_17>   <!-- No self-billing -->
  <P_18>2</P_18>   <!-- No reverse charge -->
  <P_18A>2</P_18A> <!-- No split payment -->

  6d. FaWiersz — Line items (lines 200–251)

  <xsl:for-each select="/CanonicalInvoice/Lines/LineItem">
      <FaWiersz>
          <NrWierszaFa>...</NrWierszaFa>  <!-- Line number from @Number attribute
  -->
          <P_7>...</P_7>                   <!-- Product name -->
          <P_8A>...</P_8A>                 <!-- Unit of measure -->
          <P_8B>...</P_8B>                 <!-- Quantity -->
          <P_9A>...</P_9A>                 <!-- Unit price -->
          <P_11>...</P_11>                 <!-- Net amount -->
          <P_12>...</P_12>                 <!-- VAT rate (mapped to KSeF enum) -->
      </FaWiersz>
  </xsl:for-each>
  xsl:for-each loops over every LineItem and creates one FaWiersz per item.

  VAT rate mapping (lines 229–247): Raw rate values like "23", "8", "5" are passed
   through as-is. "0" is mapped to "zw" (exempt). Unknown rates fall back to "np
  I" (out of scope).

  6e. PLATNOSC — Payment terms (lines 253–276)

  Rendered only if DueDate or PaymentMethod is present:
  <Platnosc>
      <TerminPlatnosci><Termin>2024-02-15</Termin></TerminPlatnosci>
      <FormaPlatnosci>6</FormaPlatnosci>   <!-- 6 = bank transfer -->
      <RachunekBankowy><NrRB>PL61...</NrRB></RachunekBankowy>
  </Platnosc>

  ---
  7. Named Template: emit-tax-summaries (lines 282–316)

  This is a reusable subroutine called by <xsl:call-template>. It maps tax
  breakdown rows to KSeF's P_13_x/P_14_x field naming convention:

  ┌──────────────┬──────────────────────────┬─────────────────┐
  │   Tax Rate   │      KSeF Net Field      │ KSeF Tax Field  │
  ├──────────────┼──────────────────────────┼─────────────────┤
  │ 23% or 22%   │ P_13_1                   │ P_14_1          │
  ├──────────────┼──────────────────────────┼─────────────────┤
  │ 8% or 7%     │ P_13_2                   │ P_14_2          │
  ├──────────────┼──────────────────────────┼─────────────────┤
  │ 5%           │ P_13_3                   │ P_14_3          │
  ├──────────────┼──────────────────────────┼─────────────────┤
  │ 0%           │ P_13_6_1                 │ (no tax amount) │
  ├──────────────┼──────────────────────────┼─────────────────┤
  │ No breakdown │ Falls back to 23% bucket │                 │
  └──────────────┴──────────────────────────┴─────────────────┘

  ---
  Complete Data Flow Diagram

  CanonicalInvoice XML
  ├── Header/IssueDate        → Naglowek/DataWytworzeniaFa  (+ time suffix if needed)
  ├── Header/InvoiceNumber    → Fa/P_2
  ├── Header/Currency         → Fa/KodWaluty                (default: PLN)
  ├── Header/DueDate          → Fa/Platnosc/TerminPlatnosci
  ├── Header/PaymentMethod    → Fa/Platnosc/FormaPlatnosci   (default: 6)
  ├── Header/BankAccount      → Fa/Platnosc/RachunekBankowy
  ├── Parties/Seller/TaxId    → Podmiot1/DaneIdentyfikacyjne/NIP  (validated)
  ├── Parties/Seller/Name     → Podmiot1/DaneIdentyfikacyjne/Nazwa
  ├── Parties/Buyer/TaxId     → Podmiot2 → NIP or NrID or BrakID (3-way logic)
  ├── Lines/LineItem[@Number] → Fa/FaWiersz (one per item, via for-each)
  └── Summary/Taxes/Tax       → Fa/P_13_x + P_14_x          (per rate)

  ---
  Online References

  XSLT Language

  ┌────────────┬─────────────────────────────────────────────┬────────────────┐
  │  Resource  │                     URL                     │ What it covers │
  ├────────────┼─────────────────────────────────────────────┼────────────────┤
  │ W3Schools  │                                             │ Beginner-frien │
  │ XSLT       │ https://www.w3schools.com/xml/xsl_intro.asp │ dly, all major │
  │ Tutorial   │                                             │  instructions  │
  ├────────────┼─────────────────────────────────────────────┼────────────────┤
  │ W3C XSLT   │                                             │ The            │
  │ 1.0 Specif │ https://www.w3.org/TR/xslt                  │ authoritative  │
  │ ication    │                                             │ spec           │
  ├────────────┼─────────────────────────────────────────────┼────────────────┤
  │ XSLT &     │                                             │                │
  │ XPath      │ https://developer.mozilla.org/en-US/docs/We │ Good function  │
  │ Reference  │ b/XSLT                                      │ reference      │
  │ (MDN)      │                                             │                │
  ├────────────┼─────────────────────────────────────────────┼────────────────┤
  │ Zvon XSLT  │ http://www.zvon.org/xxl/XSLTreference/Outpu │ Quick lookup   │
  │ Reference  │ t/index.html                                │ per            │
  │            │                                             │ instruction    │
  └────────────┴─────────────────────────────────────────────┴────────────────┘

  Azure Logic Apps — Maps/XSLT

  Resource: Microsoft Docs: Transform XML with maps
  URL: https://learn.microsoft.com/en-us/azure/logic-apps/logic-apps-enterprise-in
  tegration-transform
  What it covers: How maps work in Logic Apps
  ────────────────────────────────────────
  Resource: Microsoft Docs: Add XSLT maps
  URL: https://learn.microsoft.com/en-us/azure/logic-apps/logic-apps-enterprise-in
  tegration-maps
  What it covers: Uploading/using maps in integration accounts

  KSeF (Polish e-invoicing system)

  ┌────────────┬─────────────────────────────────────────────────┬────────────┐
  │  Resource  │                       URL                       │  What it   │
  │            │                                                 │   covers   │
  ├────────────┼─────────────────────────────────────────────────┼────────────┤
  │ KSeF       │ https://www.podatki.gov.pl/ksef/dokumenty-do-po │ FA(3) XSD  │
  │ official   │ brania-ksef/                                    │ schema     │
  │ schemas    │                                                 │ downloads  │
  ├────────────┼─────────────────────────────────────────────────┼────────────┤
  │ KSeF       │                                                 │ Full API   │
  │ technical  │ https://www.podatki.gov.pl/ksef/                │ and schema │
  │ documentat │                                                 │  documenta │
  │ ion        │                                                 │ tion       │
  └────────────┴─────────────────────────────────────────────────┴────────────┘

  XSD → XSLT Tools

  Resource: Oxygen XML Editor
  URL: https://www.oxygenxml.com
  What it covers: Best IDE for XSLT development, has visual mapper
  ────────────────────────────────────────
  Resource: Altova MapForce
  URL: https://www.altova.com/mapforce
  What it covers: Drag-and-drop XML-to-XML mapping that generates XSLT
  ────────────────────────────────────────
  Resource: XSLT Fiddle (online tester)
  URL: https://xsltfiddle.liberty-development.net
  What it covers: Paste input XML + XSLT and test instantly
  ────────────────────────────────────────
  Resource: FreeFormatter XSLT tester
  URL: https://www.freeformatter.com/xsl-transformer.html
  What it covers: Quick online transform testing

  ---
  Summary for Your Manager

  What this file does: It is the "translation engine" between our internal invoice
   data format and the Polish government's mandatory KSeF FA(3) invoice format.
  Without this transformation, we cannot submit invoices to the KSeF system.

  Why it is complex: The KSeF XSD schema has strict rules — certain fields must be
   exact 10-digit numbers, tax rates must use specific codes, and many regulatory
  flags are required even when they don't apply to us. The XSLT handles all of
  this mapping, validation, and defaulting logic in one place.

  Where it runs: Inside Azure Logic Apps as a "Transform XML" action — Azure
  applies this file automatically during the invoice submission workflow.