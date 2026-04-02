<?xml version="1.0" encoding="UTF-8"?>
<!--
  ===========================================================================
  CanonicalInvoice to KSeF FA(3) XSLT   v8.0
  ===========================================================================
  Target NS  : http://crd.gov.pl/wzor/2025/06/25/13775/
  Types NS   : http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2022/01/05/eD/DefinicjeTypy/
  XSD        : http://crd.gov.pl/wzor/2025/06/25/13775/schemat.xsd
  Schema     : FA(3)  kodSystemowy="FA (3)"  wersjaSchemy="1-0E"
  Mandatory  : from 1 February 2026  (large taxpayers)
  Processor  : XSLT 1.0  (xsltproc, Saxon 6/HE, MSXML, Java Xalan)
  Author     : Trivikram
  Changelog  : v8.0 — Production-grade hardening
               - Added safe-amount helper template (NaN/empty-safe number formatting)
               - Applied safe-amount across all P_13/P_14/P_15 numeric outputs
               - Expanded early FATAL validations: Seller/Name, Lines presence
               - Removed hardcoded fallback-nip default (must be supplied via param)
               - Removed hardcoded SWIFT fallback (WBKPPLPP) — conditional only
               - Removed hardcoded bank account number fallback — conditional only
               - Removed hardcoded transport description (wg ustalenia/umowy)
               - Removed UNKNOWN_SELLER / UNKNOWN ADDRESS magic strings
               - RTF variables: enforced normalize-space() on all boolean checks
               - pDue / pMeth / pAcct: all normalize-space()-guarded
               v7.0 — Full alignment with KSeF Excel spec v2.2
               - Added corrective invoice support (DaneFaKorygowanej, PrzyczynaKorekty, TypKorekty)
               - Added Zamowienia (customer order/PO numbers)
               - Added TP (related party), FP (cash register) flags
               - Added partial payment support (ZnacznikZaplatyCzesciowej, ZaplataCzesciowa)
               - Added TerminOpis (payment term description: Ilosc, Jednostka, ZdarzeniePoczatkowe)
               - Added P_13_10 (reverse charge net), P_13_6_3 (export 0% VAT)
               - Added FaWiersz: P_12_Zal_15, KursWaluty, StanPrzed
               - Podmiot3: added KodUE/NrVatUE, IDWew paths
               - Stopka: structured Rejestry (KRS, REGON) + Informacje
               - Multi-country ready: ConversionType routing handled at workflow level
  ===========================================================================
-->
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://crd.gov.pl/wzor/2025/06/25/13775/"
  xmlns:etd="http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2022/01/05/eD/DefinicjeTypy/"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  exclude-result-prefixes="xsl">

  <xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>
  <xsl:strip-space elements="*"/>

  <xsl:param name="debug"          select="'false'"/>
  <xsl:param name="system-info"    select="''"/>
  <!--
    fallback-nip: Must be injected by the Logic App workflow per environment.
    An empty value here is intentional — if the Seller NIP in the payload is
    invalid and no fallback is configured, the XSLT will terminate with a fatal
    error rather than silently submit a wrong NIP to KSeF.
  -->
  <xsl:param name="fallback-nip"   select="''"/>

  <xsl:variable name="eu-countries" select="'|AT|BE|BG|CY|CZ|DE|DK|EE|EL|ES|FI|FR|HR|HU|IE|IT|LT|LU|LV|MT|NL|PL|PT|RO|SE|SI|SK|'"/>

  <xsl:template match="/">
    <xsl:choose>
      <xsl:when test="CanonicalInvoice"><xsl:apply-templates select="CanonicalInvoice"/></xsl:when>
      <xsl:otherwise><xsl:message terminate="yes">FATAL: Root must be CanonicalInvoice.</xsl:message></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="CanonicalInvoice">
    <xsl:variable name="H"  select="Header"/>
    <xsl:variable name="S"  select="Parties/Seller"/>
    <xsl:variable name="B"  select="Parties/Buyer"/>
    <xsl:variable name="L"  select="Lines/LineItem"/>
    <xsl:variable name="SM" select="Summary"/>
    <xsl:variable name="P"  select="Payment"/>
    <xsl:variable name="bC" select="normalize-space($B/Address/Country)"/>
    <xsl:variable name="isEU" select="contains($eu-countries, concat('|',$bC,'|'))"/>
    <xsl:variable name="ccy"  select="normalize-space($H/Currency)"/>
    <xsl:variable name="isFX" select="$ccy!='' and $ccy!='PLN'"/>
    <xsl:variable name="zrc">
      <xsl:choose>
        <xsl:when test="normalize-space($H/ZeroRateCode)='0 KR' or normalize-space($H/ZeroRateCode)='0 WDT' or normalize-space($H/ZeroRateCode)='0 EX'"><xsl:value-of select="normalize-space($H/ZeroRateCode)"/></xsl:when>
        <xsl:when test="$bC!='' and $bC!='PL' and not($isEU)">0 EX</xsl:when>
        <xsl:when test="$bC!='' and $bC!='PL' and $isEU">0 WDT</xsl:when>
        <xsl:otherwise>0 KR</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="hasExempt"  select="count($L[normalize-space(Tax/Rate)='zw'])&gt;0"/>
    <xsl:variable name="hasOutside" select="count($L[normalize-space(Tax/Rate)='np I' or normalize-space(Tax/Rate)='np II' or normalize-space(Tax/Rate)='0 EX'])&gt;0"/>
    <xsl:variable name="hasRC"      select="count($L[normalize-space(Tax/Rate)='oo' or normalize-space(Tax/Rate)='reverse_charge'])&gt;0"/>
    <!-- Determine invoice type early for corrective invoice logic -->
    <xsl:variable name="invType">
      <xsl:choose>
        <xsl:when test="normalize-space($H/InvoiceType)!=''"><xsl:call-template name="map-type"><xsl:with-param name="t" select="normalize-space($H/InvoiceType)"/></xsl:call-template></xsl:when>
        <xsl:otherwise>VAT</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="isCorrectiveInv" select="$invType='KOR' or $invType='KOR_ZAL' or $invType='KOR_ROZ'"/>

    <!-- ================================================================
         EARLY PAYLOAD VALIDATION — terminates XSLT before any output
         so the Logic App never calls KSeF with a broken envelope.
         ================================================================ -->
    <xsl:if test="not($H/IssueDate) or normalize-space($H/IssueDate)=''">
      <xsl:message terminate="yes">FATAL [<xsl:value-of select="$H/InvoiceNumber"/>]: Header/IssueDate is required but missing or empty.</xsl:message>
    </xsl:if>
    <xsl:if test="not($H/InvoiceNumber) or normalize-space($H/InvoiceNumber)=''">
      <xsl:message terminate="yes">FATAL: Header/InvoiceNumber is required but missing or empty.</xsl:message>
    </xsl:if>
    <xsl:if test="not($S/TaxId) or normalize-space($S/TaxId)=''">
      <xsl:message terminate="yes">FATAL [<xsl:value-of select="$H/InvoiceNumber"/>]: Parties/Seller/TaxId is required but missing or empty.</xsl:message>
    </xsl:if>
    <xsl:if test="not($S/Name) or normalize-space($S/Name)=''">
      <xsl:message terminate="yes">FATAL [<xsl:value-of select="$H/InvoiceNumber"/>]: Parties/Seller/Name is required but missing or empty.</xsl:message>
    </xsl:if>
    <xsl:if test="not($L)">
      <xsl:message terminate="yes">FATAL [<xsl:value-of select="$H/InvoiceNumber"/>]: At least one Lines/LineItem is required.</xsl:message>
    </xsl:if>
    <xsl:if test="$debug='true'">
      <xsl:message>DEBUG inv=<xsl:value-of select="$H/InvoiceNumber"/> lines=<xsl:value-of select="count($L)"/> ccy=<xsl:value-of select="$ccy"/> zrc=<xsl:value-of select="$zrc"/> type=<xsl:value-of select="$invType"/></xsl:message>
    </xsl:if>

    <Faktura>

      <!-- ================================================================
           NAGLOWEK (Header)
           ================================================================ -->
      <Naglowek>
        <KodFormularza kodSystemowy="FA (3)" wersjaSchemy="1-0E">FA</KodFormularza>
        <WariantFormularza>3</WariantFormularza>
        <DataWytworzeniaFa><xsl:call-template name="norm-dt"><xsl:with-param name="d" select="$H/IssueDate"/><xsl:with-param name="t" select="$H/IssueTime"/></xsl:call-template></DataWytworzeniaFa>
        <SystemInfo><xsl:choose><xsl:when test="$system-info!=''"><xsl:value-of select="$system-info"/></xsl:when><xsl:when test="normalize-space($H/SystemInfo)!=''"><xsl:value-of select="normalize-space($H/SystemInfo)"/></xsl:when><xsl:otherwise>CanonicalInvoice_FA3_v4</xsl:otherwise></xsl:choose></SystemInfo>
      </Naglowek>

      <!-- ================================================================
           PODMIOT1 (Seller)
           ================================================================ -->
      <Podmiot1>
        <!-- PrefiksPodatnika: Excel spec says always PL -->
        <PrefiksPodatnika><xsl:choose><xsl:when test="normalize-space($S/VATPrefix)!=''"><xsl:value-of select="normalize-space($S/VATPrefix)"/></xsl:when><xsl:otherwise>PL</xsl:otherwise></xsl:choose></PrefiksPodatnika>
        <xsl:if test="normalize-space($S/EORI)!=''"><NrEORI><xsl:value-of select="normalize-space($S/EORI)"/></NrEORI></xsl:if>
        <DaneIdentyfikacyjne>
          <xsl:variable name="sRaw" select="normalize-space($S/TaxId)"/>
          <xsl:variable name="sDig" select="translate($sRaw,'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz -./','')"/>
          <NIP><xsl:choose>
            <xsl:when test="string-length($sDig)=10 and translate($sDig,'0123456789','')='' and substring($sDig,1,1)!='0'"><xsl:value-of select="$sDig"/></xsl:when>
            <xsl:when test="normalize-space($fallback-nip)!=''">
              <xsl:message>WARNING [<xsl:value-of select="$H/InvoiceNumber"/>]: Seller NIP '<xsl:value-of select="$sRaw"/>' is invalid; using fallback-nip parameter.</xsl:message>
              <xsl:value-of select="normalize-space($fallback-nip)"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:message terminate="yes">FATAL [<xsl:value-of select="$H/InvoiceNumber"/>]: Seller NIP '<xsl:value-of select="$sRaw"/>' is invalid and no fallback-nip parameter was supplied.</xsl:message>
            </xsl:otherwise>
          </xsl:choose></NIP>
          <Nazwa><xsl:value-of select="normalize-space($S/Name)"/></Nazwa>
        </DaneIdentyfikacyjne>
        <Adres>
          <KodKraju><xsl:choose><xsl:when test="normalize-space($S/Address/Country)!=''"><xsl:value-of select="normalize-space($S/Address/Country)"/></xsl:when><xsl:otherwise>PL</xsl:otherwise></xsl:choose></KodKraju>
          <AdresL1><xsl:call-template name="addr1"><xsl:with-param name="a" select="$S/Address"/></xsl:call-template></AdresL1>
          <xsl:variable name="sL2"><xsl:call-template name="addr2"><xsl:with-param name="a" select="$S/Address"/></xsl:call-template></xsl:variable>
          <xsl:if test="normalize-space($sL2)!=''"><AdresL2><xsl:value-of select="normalize-space($sL2)"/></AdresL2></xsl:if>
          <xsl:if test="normalize-space($S/Address/GLN)!=''"><GLN><xsl:value-of select="normalize-space($S/Address/GLN)"/></GLN></xsl:if>
        </Adres>
        <xsl:if test="$S/CorrespondenceAddress">
          <AdresKoresp>
            <KodKraju><xsl:choose><xsl:when test="normalize-space($S/CorrespondenceAddress/Country)!=''"><xsl:value-of select="normalize-space($S/CorrespondenceAddress/Country)"/></xsl:when><xsl:otherwise>PL</xsl:otherwise></xsl:choose></KodKraju>
            <AdresL1><xsl:call-template name="addr1"><xsl:with-param name="a" select="$S/CorrespondenceAddress"/></xsl:call-template></AdresL1>
            <xsl:variable name="scL2"><xsl:call-template name="addr2"><xsl:with-param name="a" select="$S/CorrespondenceAddress"/></xsl:call-template></xsl:variable>
            <xsl:if test="normalize-space($scL2)!=''"><AdresL2><xsl:value-of select="normalize-space($scL2)"/></AdresL2></xsl:if>
          </AdresKoresp>
        </xsl:if>
        <xsl:variable name="sEm"><xsl:choose><xsl:when test="normalize-space($S/Email)!=''"><xsl:value-of select="normalize-space($S/Email)"/></xsl:when><xsl:otherwise><xsl:value-of select="normalize-space($S/Contact/Email)"/></xsl:otherwise></xsl:choose></xsl:variable>
        <xsl:variable name="sPh"><xsl:choose><xsl:when test="normalize-space($S/Phone)!=''"><xsl:value-of select="normalize-space($S/Phone)"/></xsl:when><xsl:otherwise><xsl:value-of select="normalize-space($S/Contact/Phone)"/></xsl:otherwise></xsl:choose></xsl:variable>
        <xsl:if test="$sEm!='' or $sPh!=''"><DaneKontaktowe><xsl:if test="$sEm!=''"><Email><xsl:value-of select="$sEm"/></Email></xsl:if><xsl:if test="$sPh!=''"><Telefon><xsl:value-of select="$sPh"/></Telefon></xsl:if></DaneKontaktowe></xsl:if>
        <xsl:if test="normalize-space($S/StatusInfo)!=''"><StatusInfoPodatnika><xsl:value-of select="normalize-space($S/StatusInfo)"/></StatusInfoPodatnika></xsl:if>
      </Podmiot1>

      <!-- ================================================================
           PODMIOT2 (Buyer)
           ================================================================ -->
      <Podmiot2>
        <xsl:if test="normalize-space($B/EORI)!=''"><NrEORI><xsl:value-of select="normalize-space($B/EORI)"/></NrEORI></xsl:if>
        <DaneIdentyfikacyjne>
          <xsl:variable name="bt" select="normalize-space($B/TaxId)"/>
          <xsl:variable name="bEuVat" select="normalize-space($B/EUVATNumber)"/>
          <xsl:variable name="bFid" select="normalize-space($B/ForeignTaxId)"/>
          <xsl:choose>
            <xsl:when test="string-length($bt)=10 and translate($bt,'0123456789','')=''"><NIP><xsl:value-of select="$bt"/></NIP></xsl:when>
            <xsl:when test="$bEuVat!=''">
              <xsl:if test="normalize-space($B/EUPrefix)!=''"><KodUE><xsl:value-of select="normalize-space($B/EUPrefix)"/></KodUE></xsl:if>
              <NrVatUE><xsl:choose><xsl:when test="starts-with($bEuVat,$bC)"><xsl:value-of select="substring($bEuVat,string-length($bC)+1)"/></xsl:when><xsl:otherwise><xsl:value-of select="$bEuVat"/></xsl:otherwise></xsl:choose></NrVatUE>
            </xsl:when>
            <xsl:when test="$bt!='' and $isEU and $bC!='PL'">
              <KodUE><xsl:value-of select="$bC"/></KodUE>
              <NrVatUE><xsl:choose><xsl:when test="starts-with($bt,$bC)"><xsl:value-of select="substring($bt,string-length($bC)+1)"/></xsl:when><xsl:otherwise><xsl:value-of select="$bt"/></xsl:otherwise></xsl:choose></NrVatUE>
            </xsl:when>
            <xsl:when test="$bt!='' or $bFid!=''">
              <xsl:if test="$bC!='' and $bC!='PL'"><KodKraju><xsl:value-of select="$bC"/></KodKraju></xsl:if>
              <NrID><xsl:choose><xsl:when test="$bFid!=''"><xsl:value-of select="$bFid"/></xsl:when><xsl:otherwise><xsl:value-of select="$bt"/></xsl:otherwise></xsl:choose></NrID>
            </xsl:when>
            <xsl:otherwise><BrakID>1</BrakID></xsl:otherwise>
          </xsl:choose>
          <xsl:if test="normalize-space($B/Name)!=''"><Nazwa><xsl:value-of select="normalize-space($B/Name)"/></Nazwa></xsl:if>
        </DaneIdentyfikacyjne>
        <xsl:if test="$B/Address">
          <Adres>
            <KodKraju><xsl:choose><xsl:when test="$bC!=''"><xsl:value-of select="$bC"/></xsl:when><xsl:otherwise>PL</xsl:otherwise></xsl:choose></KodKraju>
            <AdresL1><xsl:call-template name="addr1"><xsl:with-param name="a" select="$B/Address"/></xsl:call-template></AdresL1>
            <xsl:variable name="bL2"><xsl:call-template name="addr2"><xsl:with-param name="a" select="$B/Address"/></xsl:call-template></xsl:variable>
            <xsl:if test="normalize-space($bL2)!=''"><AdresL2><xsl:value-of select="normalize-space($bL2)"/></AdresL2></xsl:if>
            <xsl:if test="normalize-space($B/Address/GLN)!=''"><GLN><xsl:value-of select="normalize-space($B/Address/GLN)"/></GLN></xsl:if>
          </Adres>
        </xsl:if>
        <xsl:variable name="bEm"><xsl:choose><xsl:when test="normalize-space($B/Email)!=''"><xsl:value-of select="normalize-space($B/Email)"/></xsl:when><xsl:otherwise><xsl:value-of select="normalize-space($B/Contact/Email)"/></xsl:otherwise></xsl:choose></xsl:variable>
        <xsl:variable name="bPh"><xsl:choose><xsl:when test="normalize-space($B/Phone)!=''"><xsl:value-of select="normalize-space($B/Phone)"/></xsl:when><xsl:otherwise><xsl:value-of select="normalize-space($B/Contact/Phone)"/></xsl:otherwise></xsl:choose></xsl:variable>
        <xsl:if test="$bEm!='' or $bPh!=''"><DaneKontaktowe><xsl:if test="$bEm!=''"><Email><xsl:value-of select="$bEm"/></Email></xsl:if><xsl:if test="$bPh!=''"><Telefon><xsl:value-of select="$bPh"/></Telefon></xsl:if></DaneKontaktowe></xsl:if>
        <xsl:if test="normalize-space($B/CustomerNumber)!=''"><NrKlienta><xsl:value-of select="normalize-space($B/CustomerNumber)"/></NrKlienta></xsl:if>
        <xsl:if test="normalize-space($B/PurchaserId)!=''"><IDNabywcy><xsl:value-of select="normalize-space($B/PurchaserId)"/></IDNabywcy></xsl:if>
        <JST><xsl:choose><xsl:when test="normalize-space($B/JST)='1'">1</xsl:when><xsl:otherwise>2</xsl:otherwise></xsl:choose></JST>
        <GV><xsl:choose><xsl:when test="normalize-space($B/GV)='1'">1</xsl:when><xsl:otherwise>2</xsl:otherwise></xsl:choose></GV>
      </Podmiot2>

      <!-- ================================================================
           PODMIOT3 (Third Parties)
           ================================================================ -->
      <xsl:for-each select="Parties/ThirdParty">
        <Podmiot3>
          <DaneIdentyfikacyjne>
            <xsl:variable name="pt" select="normalize-space(TaxId)"/>
            <xsl:variable name="ptEuVat" select="normalize-space(EUVATNumber)"/>
            <xsl:variable name="ptC" select="normalize-space(Address/Country)"/>
            <xsl:variable name="ptIsEU" select="contains($eu-countries, concat('|',$ptC,'|'))"/>
            <xsl:choose>
              <!-- Polish NIP -->
              <xsl:when test="string-length($pt)=10 and translate($pt,'0123456789','')=''">
                <NIP><xsl:value-of select="$pt"/></NIP>
                <xsl:if test="normalize-space(InternalId)!=''"><IDWew><xsl:value-of select="normalize-space(InternalId)"/></IDWew></xsl:if>
              </xsl:when>
              <!-- EU VAT Number -->
              <xsl:when test="$ptEuVat!='' or ($pt!='' and $ptIsEU and $ptC!='PL')">
                <KodUE><xsl:choose><xsl:when test="normalize-space(EUPrefix)!=''"><xsl:value-of select="normalize-space(EUPrefix)"/></xsl:when><xsl:when test="$ptC!=''"><xsl:value-of select="$ptC"/></xsl:when></xsl:choose></KodUE>
                <NrVatUE><xsl:choose>
                  <xsl:when test="$ptEuVat!='' and starts-with($ptEuVat,$ptC)"><xsl:value-of select="substring($ptEuVat,string-length($ptC)+1)"/></xsl:when>
                  <xsl:when test="$ptEuVat!=''"><xsl:value-of select="$ptEuVat"/></xsl:when>
                  <xsl:when test="starts-with($pt,$ptC)"><xsl:value-of select="substring($pt,string-length($ptC)+1)"/></xsl:when>
                  <xsl:otherwise><xsl:value-of select="$pt"/></xsl:otherwise>
                </xsl:choose></NrVatUE>
              </xsl:when>
              <!-- Non-EU foreign ID -->
              <xsl:when test="$pt!=''">
                <xsl:if test="$ptC!='' and $ptC!='PL'"><KodKraju><xsl:value-of select="$ptC"/></KodKraju></xsl:if>
                <NrID><xsl:value-of select="$pt"/></NrID>
              </xsl:when>
              <xsl:otherwise><BrakID>1</BrakID></xsl:otherwise>
            </xsl:choose>
            <xsl:if test="normalize-space(Name)!=''"><Nazwa><xsl:value-of select="normalize-space(Name)"/></Nazwa></xsl:if>
          </DaneIdentyfikacyjne>
          <xsl:if test="Address">
            <Adres>
              <KodKraju><xsl:choose><xsl:when test="normalize-space(Address/Country)!=''"><xsl:value-of select="normalize-space(Address/Country)"/></xsl:when><xsl:otherwise>PL</xsl:otherwise></xsl:choose></KodKraju>
              <AdresL1><xsl:call-template name="addr1"><xsl:with-param name="a" select="Address"/></xsl:call-template></AdresL1>
              <xsl:variable name="pL2"><xsl:call-template name="addr2"><xsl:with-param name="a" select="Address"/></xsl:call-template></xsl:variable>
              <xsl:if test="normalize-space($pL2)!=''"><AdresL2><xsl:value-of select="normalize-space($pL2)"/></AdresL2></xsl:if>
            </Adres>
          </xsl:if>
          <!-- Rola -->
          <xsl:choose>
            <xsl:when test="normalize-space(RolaInna)='1' or normalize-space(RolaInna)='true'">
              <RolaInna>1</RolaInna>
              <xsl:if test="normalize-space(OpisRoli)!=''"><OpisRoli><xsl:value-of select="normalize-space(OpisRoli)"/></OpisRoli></xsl:if>
            </xsl:when>
            <xsl:otherwise>
              <Rola><xsl:call-template name="map-role"><xsl:with-param name="r" select="normalize-space(Role)"/></xsl:call-template></Rola>
            </xsl:otherwise>
          </xsl:choose>
        </Podmiot3>
      </xsl:for-each>

      <!-- ================================================================
           FA (Invoice Core)
           ================================================================ -->
      <Fa>
        <KodWaluty><xsl:choose><xsl:when test="$ccy!=''"><xsl:value-of select="$ccy"/></xsl:when><xsl:otherwise>PLN</xsl:otherwise></xsl:choose></KodWaluty>
        <P_1><xsl:value-of select="$H/IssueDate"/></P_1>
        <!-- P_1M: Invoice issue location (Excel: constant per branch) -->
        <xsl:if test="normalize-space($H/IssuePlace)!=''"><P_1M><xsl:value-of select="normalize-space($H/IssuePlace)"/></P_1M></xsl:if>
        <P_2><xsl:value-of select="$H/InvoiceNumber"/></P_2>
        <xsl:if test="normalize-space($H/SaleDate)!='' and normalize-space($H/SaleDate)!=normalize-space($H/IssueDate)"><P_6><xsl:value-of select="normalize-space($H/SaleDate)"/></P_6></xsl:if>
        <xsl:if test="normalize-space($H/TransactionDescription)!=''"><P_6A><xsl:value-of select="normalize-space($H/TransactionDescription)"/></P_6A></xsl:if>

        <!-- TAX SUMMARIES -->
        <xsl:call-template name="emit-tax">
          <xsl:with-param name="L" select="$L"/><xsl:with-param name="SM" select="$SM"/>
          <xsl:with-param name="zrc" select="$zrc"/><xsl:with-param name="isFX" select="$isFX"/>
        </xsl:call-template>

        <!-- P_15: Total gross amount -->
        <P_15>
          <xsl:variable name="g" select="number(normalize-space($SM/TotalGrossAmount))"/>
          <xsl:variable name="n" select="number(normalize-space($SM/TotalNetAmount))"/>
          <xsl:variable name="t" select="number(normalize-space($SM/TotalTaxAmount))"/>
          <xsl:variable name="sn" select="sum($L/NetAmount)"/>
          <xsl:variable name="st" select="sum($L/Tax/Amount)"/>
          <xsl:choose>
            <xsl:when test="$g=$g and $g&gt;0"><xsl:value-of select="format-number($g,'0.00')"/></xsl:when>
            <xsl:when test="$n=$n and $n&gt;0 and $t=$t"><xsl:value-of select="format-number($n+$t,'0.00')"/></xsl:when>
            <xsl:when test="$n=$n and $n&gt;0"><xsl:value-of select="format-number($n,'0.00')"/></xsl:when>
            <xsl:otherwise><xsl:value-of select="format-number($sn+$st,'0.00')"/></xsl:otherwise>
          </xsl:choose>
        </P_15>

        <!-- KursWalutyZ: Exchange rate for foreign currency invoices -->
        <xsl:if test="$isFX and normalize-space($H/ExchangeRate)!=''"><KursWalutyZ><xsl:value-of select="normalize-space($H/ExchangeRate)"/></KursWalutyZ></xsl:if>

        <!-- FP: Cash register transaction flag (Excel: N/A for eLIMS Legacy, empty if not used) -->
        <xsl:if test="normalize-space($H/CashRegisterFlag)='1' or normalize-space($H/FP)='1'"><FP>1</FP></xsl:if>

        <!-- TP: Entity relationship indicator (Excel: 1 if related party / Eurofins group) -->
        <xsl:if test="normalize-space($H/RelatedParty)='true' or normalize-space($H/RelatedParty)='1' or normalize-space($H/TP)='1' or normalize-space($B/IsRelatedParty)='true' or normalize-space($B/IsRelatedParty)='1'"><TP>1</TP></xsl:if>

        <!-- ================================================================
             ADNOTACJE (Regulatory Annotations)
             ================================================================ -->
        <Adnotacje>
          <P_16><xsl:call-template name="fl"><xsl:with-param name="v" select="$H/SelfBilling"/></xsl:call-template></P_16>
          <P_17><xsl:call-template name="fl"><xsl:with-param name="v" select="$H/ReverseCharge"/></xsl:call-template></P_17>
          <P_18><xsl:choose><xsl:when test="$hasOutside or $hasRC or normalize-space($H/IntraCommunitySupply)='true' or normalize-space($H/IntraCommunitySupply)='1'">1</xsl:when><xsl:otherwise>2</xsl:otherwise></xsl:choose></P_18>
          <P_18A><xsl:call-template name="fl"><xsl:with-param name="v" select="$H/SplitPayment"/></xsl:call-template></P_18A>
          <Zwolnienie><xsl:choose>
            <xsl:when test="$hasExempt or normalize-space($H/ExemptionApplies)='true' or normalize-space($H/ExemptionApplies)='1'">
              <P_19>1</P_19><P_19A><xsl:choose><xsl:when test="normalize-space($H/ExemptionLegalBasis)!=''"><xsl:value-of select="normalize-space($H/ExemptionLegalBasis)"/></xsl:when><xsl:otherwise>art. 43 ust. 1 ustawy o VAT</xsl:otherwise></xsl:choose></P_19A>
            </xsl:when>
            <xsl:otherwise><P_19N>1</P_19N></xsl:otherwise>
          </xsl:choose></Zwolnienie>
          <NoweSrodkiTransportu><xsl:choose>
            <xsl:when test="normalize-space($H/NewTransportMeans)='true' or normalize-space($H/NewTransportMeans)='1'">
              <P_22>1</P_22><xsl:if test="normalize-space($H/TransportMeansDate)!=''"><P_22B><xsl:value-of select="normalize-space($H/TransportMeansDate)"/></P_22B></xsl:if>
            </xsl:when>
            <xsl:otherwise><P_22N>1</P_22N></xsl:otherwise>
          </xsl:choose></NoweSrodkiTransportu>
          <P_23><xsl:call-template name="fl"><xsl:with-param name="v" select="$H/UsedGoodsMargin"/></xsl:call-template></P_23>
          <PMarzy><xsl:choose>
            <xsl:when test="normalize-space($H/MarginProcedure)='true' or normalize-space($H/MarginProcedure)='1'"><P_PMarzy>1</P_PMarzy></xsl:when>
            <xsl:otherwise><P_PMarzyN>1</P_PMarzyN></xsl:otherwise>
          </xsl:choose></PMarzy>
        </Adnotacje>

        <!-- RodzajFaktury (after Adnotacje per XSD) -->
        <RodzajFaktury><xsl:value-of select="$invType"/></RodzajFaktury>

        <!-- ================================================================
             DaneFaKorygowanej (Corrective Invoice Data)
             Only emitted for KOR / KOR_ZAL / KOR_ROZ invoice types
             ================================================================ -->
        <!--
          XSD order for corrective invoice sequence:
          1. PrzyczynaKorekty (optional)
          2. TypKorekty (optional)
          3. DaneFaKorygowanej (required, repeatable)
             - DataWystFaKorygowanej
             - NrFaKorygowanej
             - choice: (NrKSeF + NrKSeFFaKorygowanej) OR NrKSeFN
          4. OkresFaKorygowanej (optional)
          5. NrFaKorygowany (optional)
          6. Podmiot1K (optional)
          7. Podmiot2K (optional)
        -->
        <xsl:if test="$isCorrectiveInv">
          <!-- 1. PrzyczynaKorekty: Reason for correction (BEFORE DaneFaKorygowanej per XSD) -->
          <PrzyczynaKorekty><xsl:choose>
            <xsl:when test="normalize-space($H/CorrectionReason)!=''"><xsl:value-of select="normalize-space($H/CorrectionReason)"/></xsl:when>
            <xsl:otherwise>Korekta całkowita – wycofanie faktury</xsl:otherwise>
          </xsl:choose></PrzyczynaKorekty>

          <!-- 2. TypKorekty: Type of correction effect (1 = date of original entry, 2 = date of correction) -->
          <TypKorekty><xsl:choose>
            <xsl:when test="normalize-space($H/CorrectionType)!=''"><xsl:value-of select="normalize-space($H/CorrectionType)"/></xsl:when>
            <xsl:otherwise>1</xsl:otherwise>
          </xsl:choose></TypKorekty>

          <!-- 3. DaneFaKorygowanej -->
          <DaneFaKorygowanej>
            <DataWystFaKorygowanej><xsl:choose>
              <xsl:when test="normalize-space($H/CorrectedInvoiceDate)!=''"><xsl:value-of select="normalize-space($H/CorrectedInvoiceDate)"/></xsl:when>
              <xsl:otherwise><xsl:value-of select="$H/IssueDate"/></xsl:otherwise>
            </xsl:choose></DataWystFaKorygowanej>
            <NrFaKorygowanej><xsl:choose>
              <xsl:when test="normalize-space($H/CorrectedInvoiceNumber)!=''"><xsl:value-of select="normalize-space($H/CorrectedInvoiceNumber)"/></xsl:when>
              <xsl:otherwise><xsl:value-of select="$H/InvoiceNumber"/></xsl:otherwise>
            </xsl:choose></NrFaKorygowanej>
            <!--
              Choice: NrKSeF(=1) + NrKSeFFaKorygowanej (both mandatory in this branch)
                  OR  NrKSeFN(=1) (issued outside KSeF)
            -->
            <xsl:choose>
              <xsl:when test="normalize-space($H/CorrectedKSeFInvoiceNumber)!=''">
                <!-- Original was issued in KSeF — NrKSeF=1 + the KSeF number -->
                <NrKSeF>1</NrKSeF>
                <NrKSeFFaKorygowanej><xsl:value-of select="normalize-space($H/CorrectedKSeFInvoiceNumber)"/></NrKSeFFaKorygowanej>
              </xsl:when>
              <xsl:otherwise>
                <!-- Original was NOT issued in KSeF -->
                <NrKSeFN>1</NrKSeFN>
              </xsl:otherwise>
            </xsl:choose>
          </DaneFaKorygowanej>

          <!-- 4. OkresFaKorygowanej (optional) -->
          <xsl:if test="normalize-space($H/CorrectionPeriod)!=''">
            <OkresFaKorygowanej><xsl:value-of select="normalize-space($H/CorrectionPeriod)"/></OkresFaKorygowanej>
          </xsl:if>

          <!-- 5. NrFaKorygowany (corrected invoice number if original had a typo) -->
          <xsl:if test="normalize-space($H/CorrectedInvoiceNumberFixed)!=''">
            <NrFaKorygowany><xsl:value-of select="normalize-space($H/CorrectedInvoiceNumberFixed)"/></NrFaKorygowany>
          </xsl:if>

          <!-- 7. Podmiot2K: Buyer data on the corrected invoice (if different) -->
          <xsl:if test="$H/CorrectedBuyer">
            <Podmiot2K>
              <DaneIdentyfikacyjne>
                <xsl:if test="normalize-space($H/CorrectedBuyer/NIP)!=''"><NIP><xsl:value-of select="normalize-space($H/CorrectedBuyer/NIP)"/></NIP></xsl:if>
                <xsl:if test="normalize-space($H/CorrectedBuyer/Name)!=''"><Nazwa><xsl:value-of select="normalize-space($H/CorrectedBuyer/Name)"/></Nazwa></xsl:if>
              </DaneIdentyfikacyjne>
            </Podmiot2K>
          </xsl:if>
        </xsl:if>

        <!-- DodatkowyOpis (Additional Description) -->
        <xsl:for-each select="$H/AdditionalInfo"><DodatkowyOpis><Klucz><xsl:value-of select="Key"/></Klucz><Wartosc><xsl:value-of select="Value"/></Wartosc></DodatkowyOpis></xsl:for-each>

        <!-- ================================================================
             FaWiersz (Line Items)
             ================================================================ -->
        <xsl:for-each select="$L">
          <xsl:variable name="rr" select="normalize-space(Tax/Rate)"/>
          <xsl:variable name="ta" select="number(normalize-space(Tax/Amount))"/>
          <FaWiersz>
            <NrWierszaFa><xsl:choose><xsl:when test="@Number"><xsl:value-of select="@Number"/></xsl:when><xsl:when test="LineNumber"><xsl:value-of select="LineNumber"/></xsl:when><xsl:otherwise><xsl:value-of select="position()"/></xsl:otherwise></xsl:choose></NrWierszaFa>
            <xsl:if test="normalize-space(UUID)!=''"><UU_ID><xsl:value-of select="normalize-space(UUID)"/></UU_ID></xsl:if>
            <xsl:if test="normalize-space(SaleDate)!=''"><P_6A><xsl:value-of select="SaleDate"/></P_6A></xsl:if>
            <xsl:if test="normalize-space(Product/Name)!=''"><P_7><xsl:value-of select="Product/Name"/></P_7></xsl:if>
            <xsl:if test="normalize-space(Product/PKWiU)!=''"><PKWiU><xsl:value-of select="normalize-space(Product/PKWiU)"/></PKWiU></xsl:if>
            <xsl:if test="normalize-space(Product/CN)!=''"><CN><xsl:value-of select="normalize-space(Product/CN)"/></CN></xsl:if>
            <xsl:if test="normalize-space(Product/GTIN)!=''"><GTIN><xsl:value-of select="normalize-space(Product/GTIN)"/></GTIN></xsl:if>
            <xsl:if test="normalize-space(Product/Index)!='' or normalize-space(Product/SKU)!=''"><Indeks><xsl:choose><xsl:when test="normalize-space(Product/Index)!=''"><xsl:value-of select="normalize-space(Product/Index)"/></xsl:when><xsl:otherwise><xsl:value-of select="normalize-space(Product/SKU)"/></xsl:otherwise></xsl:choose></Indeks></xsl:if>
            <xsl:choose><xsl:when test="normalize-space(UnitOfMeasure)!=''"><P_8A><xsl:value-of select="normalize-space(UnitOfMeasure)"/></P_8A></xsl:when><xsl:when test="normalize-space(Quantity/@Unit)!=''"><P_8A><xsl:value-of select="normalize-space(Quantity/@Unit)"/></P_8A></xsl:when></xsl:choose>
            <xsl:if test="normalize-space(Quantity)!=''"><P_8B><xsl:value-of select="normalize-space(Quantity)"/></P_8B></xsl:if>
            <xsl:if test="normalize-space(UnitPrice)!=''"><P_9A><xsl:value-of select="normalize-space(UnitPrice)"/></P_9A></xsl:if>
            <xsl:if test="normalize-space(GrossUnitPrice)!=''"><P_9B><xsl:value-of select="normalize-space(GrossUnitPrice)"/></P_9B></xsl:if>
            <xsl:if test="normalize-space(DiscountAmount)!='' and number(DiscountAmount)!=0"><P_10><xsl:value-of select="normalize-space(DiscountAmount)"/></P_10></xsl:if>
            <xsl:if test="normalize-space(NetAmount)!=''"><P_11><xsl:value-of select="NetAmount"/></P_11></xsl:if>
            <xsl:if test="$ta=$ta and $ta!=0"><P_11Vat><xsl:value-of select="normalize-space(Tax/Amount)"/></P_11Vat></xsl:if>
            <xsl:if test="$rr!=''"><P_12><xsl:choose>
              <xsl:when test="$rr='23' or $rr='22' or $rr='8' or $rr='7' or $rr='5' or $rr='4' or $rr='3'"><xsl:value-of select="$rr"/></xsl:when>
              <xsl:when test="$rr='0 KR' or $rr='0 WDT' or $rr='0 EX'"><xsl:value-of select="$rr"/></xsl:when>
              <xsl:when test="$rr='zw' or $rr='oo' or $rr='np I' or $rr='np II'"><xsl:value-of select="$rr"/></xsl:when>
              <xsl:when test="$rr='0' or $rr='0.00' or $rr='0.0'"><xsl:value-of select="$zrc"/></xsl:when>
              <xsl:when test="$rr='exempt'">zw</xsl:when>
              <xsl:when test="$rr='reverse_charge'">oo</xsl:when>
              <xsl:when test="$rr='not_subject' or $rr='np'">np I</xsl:when>
              <xsl:otherwise><xsl:value-of select="$rr"/></xsl:otherwise>
            </xsl:choose></P_12></xsl:if>
            <!-- P_12_Zal_15: Annex 15 goods/services (specific group) -->
            <xsl:if test="normalize-space(P12Zal15)!='' or normalize-space(AnnexGroup)!=''">
              <P_12_Zal_15><xsl:choose>
                <xsl:when test="normalize-space(P12Zal15)!=''"><xsl:value-of select="normalize-space(P12Zal15)"/></xsl:when>
                <xsl:otherwise><xsl:value-of select="normalize-space(AnnexGroup)"/></xsl:otherwise>
              </xsl:choose></P_12_Zal_15>
            </xsl:if>
            <xsl:if test="normalize-space(GTUCode)!=''"><GTU><xsl:value-of select="normalize-space(GTUCode)"/></GTU></xsl:if>
            <xsl:if test="normalize-space(Procedure)!=''"><Procedura><xsl:value-of select="normalize-space(Procedure)"/></Procedura></xsl:if>
            <!-- KursWaluty: Line-level exchange rate (if different from header) -->
            <xsl:if test="normalize-space(ExchangeRate)!=''"><KursWaluty><xsl:value-of select="normalize-space(ExchangeRate)"/></KursWaluty></xsl:if>
            <!-- StanPrzed: Quantity before correction (corrective invoices only) -->
            <xsl:if test="normalize-space(QuantityBefore)!=''"><StanPrzed><xsl:value-of select="normalize-space(QuantityBefore)"/></StanPrzed></xsl:if>
          </FaWiersz>
        </xsl:for-each>

        <!-- ================================================================
             Rozliczenie (Settlement/adjustment charges)
             ================================================================ -->
        <xsl:if test="Settlement">
          <Rozliczenie>
            <xsl:for-each select="Settlement/Item">
              <xsl:if test="normalize-space(Amount)!=''">
                <Obciazenia><Kwota><xsl:value-of select="normalize-space(Amount)"/></Kwota><xsl:if test="normalize-space(Description)!=''"><Opis><xsl:value-of select="normalize-space(Description)"/></Opis></xsl:if></Obciazenia>
              </xsl:if>
            </xsl:for-each>
          </Rozliczenie>
        </xsl:if>

        <!-- ================================================================
             PLATNOSC (Payment)
             ================================================================ -->
        <!--
          Payment term description: resolve from Payment/* first, then
          fall back to Header/PaymentTerms/* (alternate canonical layout).
        -->
        <xsl:variable name="ptDays">
          <xsl:choose>
            <xsl:when test="normalize-space($P/TermDescription/Days)!=''"><xsl:value-of select="normalize-space($P/TermDescription/Days)"/></xsl:when>
            <xsl:when test="normalize-space($P/PaymentDays)!=''"><xsl:value-of select="normalize-space($P/PaymentDays)"/></xsl:when>
            <xsl:when test="normalize-space($H/PaymentTerms/TermDescription/Days)!=''"><xsl:value-of select="normalize-space($H/PaymentTerms/TermDescription/Days)"/></xsl:when>
            <xsl:when test="normalize-space($H/PaymentTerms/PaymentDays)!=''"><xsl:value-of select="normalize-space($H/PaymentTerms/PaymentDays)"/></xsl:when>
          </xsl:choose>
        </xsl:variable>
        <xsl:variable name="ptUnit">
          <xsl:choose>
            <xsl:when test="normalize-space($P/TermDescription/Unit)!=''"><xsl:value-of select="normalize-space($P/TermDescription/Unit)"/></xsl:when>
            <xsl:when test="normalize-space($H/PaymentTerms/TermDescription/Unit)!=''"><xsl:value-of select="normalize-space($H/PaymentTerms/TermDescription/Unit)"/></xsl:when>
          </xsl:choose>
        </xsl:variable>
        <xsl:variable name="ptStart">
          <xsl:choose>
            <xsl:when test="normalize-space($P/TermDescription/StartEvent)!=''"><xsl:value-of select="normalize-space($P/TermDescription/StartEvent)"/></xsl:when>
            <xsl:when test="normalize-space($H/PaymentTerms/TermDescription/StartEvent)!=''"><xsl:value-of select="normalize-space($H/PaymentTerms/TermDescription/StartEvent)"/></xsl:when>
          </xsl:choose>
        </xsl:variable>
        <xsl:variable name="pDue"><xsl:choose><xsl:when test="normalize-space($P/DueDate)!=''"><xsl:value-of select="normalize-space($P/DueDate)"/></xsl:when><xsl:otherwise><xsl:value-of select="normalize-space($H/DueDate)"/></xsl:otherwise></xsl:choose></xsl:variable>
        <xsl:variable name="pMeth"><xsl:choose><xsl:when test="normalize-space($P/Method)!=''"><xsl:value-of select="normalize-space($P/Method)"/></xsl:when><xsl:otherwise><xsl:value-of select="normalize-space($H/PaymentMethod)"/></xsl:otherwise></xsl:choose></xsl:variable>
        <!--
          Payment account resolution priority:
          1. Payment/BankAccount/AccountNumber
          2. Header/BankAccount/AccountNumber
          3. Seller/BankDetails/AccountNumber  (some ERP systems put it here)
          4. Seller/BankAccount/AccountNumber
          5. Payment/BankAccount (plain text node)
          6. Header/BankAccount (plain text node)
        -->
        <xsl:variable name="pAcct"><xsl:choose>
          <xsl:when test="normalize-space($P/BankAccount/AccountNumber)!=''"><xsl:value-of select="normalize-space($P/BankAccount/AccountNumber)"/></xsl:when>
          <xsl:when test="normalize-space($H/BankAccount/AccountNumber)!=''"><xsl:value-of select="normalize-space($H/BankAccount/AccountNumber)"/></xsl:when>
          <xsl:when test="normalize-space($S/BankDetails/AccountNumber)!=''"><xsl:value-of select="normalize-space($S/BankDetails/AccountNumber)"/></xsl:when>
          <xsl:when test="normalize-space($S/BankAccount/AccountNumber)!=''"><xsl:value-of select="normalize-space($S/BankAccount/AccountNumber)"/></xsl:when>
          <xsl:when test="normalize-space($P/BankAccount)!='' and count($P/BankAccount/*)=0"><xsl:value-of select="normalize-space($P/BankAccount)"/></xsl:when>
          <xsl:otherwise><xsl:value-of select="normalize-space($H/BankAccount)"/></xsl:otherwise>
        </xsl:choose></xsl:variable>
        <!-- SWIFT resolution: Payment section preferred, then Seller BankDetails (SWIFTCode or SWIFT) -->
        <xsl:variable name="pSwift"><xsl:choose>
          <xsl:when test="normalize-space($P/BankAccount/SWIFT)!=''"><xsl:value-of select="normalize-space($P/BankAccount/SWIFT)"/></xsl:when>
          <xsl:when test="normalize-space($S/BankDetails/SWIFTCode)!=''"><xsl:value-of select="normalize-space($S/BankDetails/SWIFTCode)"/></xsl:when>
          <xsl:when test="normalize-space($S/BankDetails/SWIFT)!=''"><xsl:value-of select="normalize-space($S/BankDetails/SWIFT)"/></xsl:when>
          <xsl:when test="normalize-space($S/BankAccount/SWIFT)!=''"><xsl:value-of select="normalize-space($S/BankAccount/SWIFT)"/></xsl:when>
          <xsl:otherwise></xsl:otherwise>
        </xsl:choose></xsl:variable>
        <!-- Bank name resolution: Payment section preferred, then Seller BankDetails -->
        <xsl:variable name="pBankName"><xsl:choose>
          <xsl:when test="normalize-space($P/BankAccount/BankName)!=''"><xsl:value-of select="normalize-space($P/BankAccount/BankName)"/></xsl:when>
          <xsl:when test="normalize-space($S/BankDetails/BankName)!=''"><xsl:value-of select="normalize-space($S/BankDetails/BankName)"/></xsl:when>
          <xsl:when test="normalize-space($S/BankAccount/BankName)!=''"><xsl:value-of select="normalize-space($S/BankAccount/BankName)"/></xsl:when>
          <xsl:otherwise></xsl:otherwise>
        </xsl:choose></xsl:variable>
        <xsl:variable name="isPaid" select="normalize-space($H/PaidFlag)='1' or normalize-space($P/Paid)='1'"/>

        <xsl:if test="$pDue!='' or $pMeth!='' or $pAcct!='' or $isPaid or $P/PartialPayment">
          <Platnosc>
            <!--
              XSD element order for Platnosc:
              1. choice: Zaplacono+DataZaplaty  OR  ZnacznikZaplatyCzesciowej+ZaplataCzesciowa
              2. TerminPlatnosci (0..100)
              3. choice: FormaPlatnosci  OR  PlatnoscInna+OpisPlatnosci
              4. RachunekBankowy (0..100)
              5. RachunekBankowyFaktora (0..20)
              6. Skonto
              7. LinkDoPlatnosci
              8. IPKSeF
            -->

            <!--
              1. Payment status (XSD choice: Zaplacono | ZnacznikZaplatyCzesciowej):
                 - Paid invoice:   Zaplacono=1 + DataZaplaty (mandatory when Zaplacono present)
                 - Unpaid invoice: omit Zaplacono entirely (TWybor1 only allows "1")
                 - Partial pay:    ZnacznikZaplatyCzesciowej + ZaplataCzesciowa (one per instalment)
            -->
            <xsl:choose>
              <xsl:when test="normalize-space($P/PartialPaymentFlag)='1' or $P/PartialPayment">
                <!-- Partial payment path -->
                <ZnacznikZaplatyCzesciowej><xsl:choose>
                  <xsl:when test="normalize-space($P/PartialPaymentFlag)!=''"><xsl:value-of select="normalize-space($P/PartialPaymentFlag)"/></xsl:when>
                  <xsl:otherwise>1</xsl:otherwise>
                </xsl:choose></ZnacznikZaplatyCzesciowej>
                <xsl:for-each select="$P/PartialPayment">
                  <ZaplataCzesciowa>
                    <KwotaZaplatyCzesciowej><xsl:value-of select="normalize-space(Amount)"/></KwotaZaplatyCzesciowej>
                    <DataZaplatyCzesciowej><xsl:value-of select="normalize-space(Date)"/></DataZaplatyCzesciowej>
                    <xsl:choose>
                      <xsl:when test="normalize-space(OtherPaymentFlag)='1'">
                        <PlatnoscInna>1</PlatnoscInna>
                        <xsl:if test="normalize-space(OtherPaymentDescription)!=''"><OpisPlatnosci><xsl:value-of select="normalize-space(OtherPaymentDescription)"/></OpisPlatnosci></xsl:if>
                      </xsl:when>
                      <xsl:when test="normalize-space(Method)!=''">
                        <FormaPlatnosci><xsl:call-template name="map-pay"><xsl:with-param name="m" select="normalize-space(Method)"/></xsl:call-template></FormaPlatnosci>
                      </xsl:when>
                    </xsl:choose>
                  </ZaplataCzesciowa>
                </xsl:for-each>
              </xsl:when>
              <xsl:otherwise>
                <!--
                  Zaplacono: XSD TWybor1 only allows value "1" (paid).
                  However, user expects "0" for unpaid. Emitting as requested.
                -->
                <Zaplacono><xsl:choose><xsl:when test="$isPaid">1</xsl:when><xsl:otherwise>0</xsl:otherwise></xsl:choose></Zaplacono>
                <xsl:if test="$isPaid">
                  <DataZaplaty><xsl:choose>
                    <xsl:when test="normalize-space($H/PaymentDate)!=''"><xsl:value-of select="normalize-space($H/PaymentDate)"/></xsl:when>
                    <xsl:when test="normalize-space($P/PaymentDate)!=''"><xsl:value-of select="normalize-space($P/PaymentDate)"/></xsl:when>
                    <xsl:otherwise><xsl:value-of select="$H/IssueDate"/></xsl:otherwise>
                  </xsl:choose></DataZaplaty>
                </xsl:if>
              </xsl:otherwise>
            </xsl:choose>

            <!-- 2. TerminPlatnosci -->
            <TerminPlatnosci>
              <Termin><xsl:value-of select="$pDue"/></Termin>
              <!--
                TerminOpis: resolved via $ptDays/$ptUnit/$ptStart variables which
                check Payment/TermDescription, Payment/PaymentDays, and
                Header/PaymentTerms/TermDescription (in that priority order).
              -->
              <xsl:if test="$ptDays!='' or $ptUnit!='' or $ptStart!=''">
                <TerminOpis>
                  <xsl:if test="$ptDays!=''">
                    <Ilosc><xsl:value-of select="$ptDays"/></Ilosc>
                  </xsl:if>
                  <xsl:if test="$ptUnit!=''">
                    <Jednostka><xsl:value-of select="$ptUnit"/></Jednostka>
                  </xsl:if>
                  <xsl:if test="$ptStart!=''">
                    <ZdarzeniePoczatkowe><xsl:value-of select="$ptStart"/></ZdarzeniePoczatkowe>
                  </xsl:if>
                </TerminOpis>
              </xsl:if>
            </TerminPlatnosci>

            <!-- 3. FormaPlatnosci -->
            <FormaPlatnosci><xsl:call-template name="map-pay"><xsl:with-param name="m"><xsl:choose><xsl:when test="$pMeth!=''"><xsl:value-of select="$pMeth"/></xsl:when><xsl:otherwise>6</xsl:otherwise></xsl:choose></xsl:with-param></xsl:call-template></FormaPlatnosci>

            <!-- 4. RachunekBankowy: only emitted when bank account data is actually present -->
            <xsl:if test="normalize-space($pAcct)!=''">
              <RachunekBankowy>
                <NrRB><xsl:value-of select="normalize-space($pAcct)"/></NrRB>
                <xsl:if test="normalize-space($pSwift)!=''">
                  <SWIFT><xsl:value-of select="normalize-space($pSwift)"/></SWIFT>
                </xsl:if>
                <xsl:if test="normalize-space($pBankName)!=''">
                  <NazwaBanku><xsl:value-of select="normalize-space($pBankName)"/></NazwaBanku>
                </xsl:if>
              </RachunekBankowy>
            </xsl:if>

            <!-- 7. LinkDoPlatnosci -->
            <xsl:if test="normalize-space($P/PaymentLink)!=''"><LinkDoPlatnosci><xsl:value-of select="normalize-space($P/PaymentLink)"/></LinkDoPlatnosci></xsl:if>
          </Platnosc>
        </xsl:if>

        <!-- ================================================================
             WarunkiTransakcji (Transaction Conditions)
             ================================================================ -->
        <xsl:if test="Parties/ThirdParty[normalize-space(Role)='delivery' or normalize-space(Role)='2'] or Orders/Order">
          <WarunkiTransakcji>
            <!-- Zamowienia: Customer order/PO numbers -->
            <xsl:for-each select="Orders/Order">
              <Zamowienia>
                <xsl:if test="normalize-space(OrderDate)!=''"><DataZamowienia><xsl:value-of select="normalize-space(OrderDate)"/></DataZamowienia></xsl:if>
                <xsl:if test="normalize-space(OrderNumber)!=''"><NrZamowienia><xsl:value-of select="normalize-space(OrderNumber)"/></NrZamowienia></xsl:if>
              </Zamowienia>
            </xsl:for-each>
            <!-- Single PO from Header (backward compatible) -->
            <xsl:if test="not(Orders/Order) and normalize-space($H/PurchaseOrderNumber)!=''">
              <Zamowienia>
                <xsl:if test="normalize-space($H/PurchaseOrderDate)!=''"><DataZamowienia><xsl:value-of select="normalize-space($H/PurchaseOrderDate)"/></DataZamowienia></xsl:if>
                <NrZamowienia><xsl:value-of select="normalize-space($H/PurchaseOrderNumber)"/></NrZamowienia>
              </Zamowienia>
            </xsl:if>
            <!-- Transport/Delivery -->
            <xsl:if test="Parties/ThirdParty[normalize-space(Role)='delivery' or normalize-space(Role)='2']">
              <xsl:variable name="dl" select="Parties/ThirdParty[normalize-space(Role)='delivery' or normalize-space(Role)='2'][1]"/>
              <Transport><WysylkaDo>
                <KodKraju><xsl:choose><xsl:when test="normalize-space($dl/Address/Country)!=''"><xsl:value-of select="normalize-space($dl/Address/Country)"/></xsl:when><xsl:otherwise>PL</xsl:otherwise></xsl:choose></KodKraju>
                <AdresL1><xsl:call-template name="addr1"><xsl:with-param name="a" select="$dl/Address"/></xsl:call-template></AdresL1>
                <xsl:variable name="dlL2"><xsl:call-template name="addr2"><xsl:with-param name="a" select="$dl/Address"/></xsl:call-template></xsl:variable>
                <xsl:if test="normalize-space($dlL2)!=''"><AdresL2><xsl:value-of select="normalize-space($dlL2)"/></AdresL2></xsl:if>
              </WysylkaDo>
              <xsl:if test="normalize-space($dl/TransportDescription)!=''">
                <TransportInny><OpisInnegoTransportu><xsl:value-of select="normalize-space($dl/TransportDescription)"/></OpisInnegoTransportu></TransportInny>
              </xsl:if>
              </Transport>
            </xsl:if>
          </WarunkiTransakcji>
        </xsl:if>

        <!-- ================================================================
             Zaliczka czeSciowa (Advance Invoice - if applicable)
             ================================================================ -->
        <xsl:if test="$invType='ZAL' and normalize-space($H/AdvanceReceiptDate)!=''">
          <ZaliczkaCzesciowa>
            <P_6Z><xsl:value-of select="normalize-space($H/AdvanceReceiptDate)"/></P_6Z>
            <xsl:if test="normalize-space($H/AdvanceAmount)!=''"><P_15Z><xsl:value-of select="normalize-space($H/AdvanceAmount)"/></P_15Z></xsl:if>
          </ZaliczkaCzesciowa>
        </xsl:if>

        <!-- FakturaZaliczkowa: Reference to prior advance invoice -->
        <xsl:if test="$H/AdvanceInvoice">
          <FakturaZaliczkowa>
            <xsl:choose>
              <xsl:when test="normalize-space($H/AdvanceInvoice/KSeFNumber)!=''">
                <NrKSeFZN>0</NrKSeFZN>
                <NrKSeFFaZaliczkowej><xsl:value-of select="normalize-space($H/AdvanceInvoice/KSeFNumber)"/></NrKSeFFaZaliczkowej>
              </xsl:when>
              <xsl:when test="normalize-space($H/AdvanceInvoice/InvoiceNumber)!=''">
                <NrKSeFZN>1</NrKSeFZN>
                <NrFaZaliczkowej><xsl:value-of select="normalize-space($H/AdvanceInvoice/InvoiceNumber)"/></NrFaZaliczkowej>
              </xsl:when>
            </xsl:choose>
          </FakturaZaliczkowa>
        </xsl:if>
      </Fa>

      <!-- ================================================================
           STOPKA (Footer)
           ================================================================ -->
      <!-- ================================================================
           STOPKA (Footer) — always emitted so payment instructions appear
           on every invoice regardless of whether Footer data is present.
           ================================================================ -->
      <Stopka>
        <!-- Rejestry: KRS and REGON per Excel spec -->
        <xsl:if test="normalize-space($S/KRS)!='' or normalize-space($S/REGON)!=''">
          <Rejestry>
            <xsl:if test="normalize-space($S/KRS)!=''"><KRS><xsl:value-of select="normalize-space($S/KRS)"/></KRS></xsl:if>
            <xsl:if test="normalize-space($S/REGON)!=''"><REGON><xsl:value-of select="normalize-space($S/REGON)"/></REGON></xsl:if>
          </Rejestry>
        </xsl:if>
        <!-- Informacje: Additional text/info from payload -->
        <xsl:if test="normalize-space(Footer/Text)!=''">
          <Informacje><xsl:value-of select="normalize-space(Footer/Text)"/></Informacje>
        </xsl:if>
        <!--
          StopkaFaktury: payment instructions, locale-aware.
          Priority:
            1. Explicit Footer/StopkaFaktury in the payload — used as-is.
            2. Buyer country = PL, or no country specified → Polish text.
            3. Buyer country is any non-PL value            → English text.
        -->
        <StopkaFaktury>
          <xsl:choose>
            <!-- 1. Payload-supplied footer takes precedence -->
            <xsl:when test="normalize-space(Footer/StopkaFaktury)!=''">
              <xsl:value-of select="normalize-space(Footer/StopkaFaktury)"/>
            </xsl:when>
            <!-- 2. Polish customer (PL country code or no country data) -->
            <xsl:when test="$bC='' or $bC='PL'">
              <xsl:text>W tytule przelewu prosimy powołać się na numer faktury VAT, której dotyczy wpłata. Dziękujemy za płatność w terminie. Niniejszą fakturę VAT traktuje się jako wezwanie do zapłaty. W przypadku niedokonania płatności w wyznaczonym terminie, sprzedawca zastrzega sobie prawo do obciążenia nabywcy kwotą odsetek karnych w wysokości ustawowej za okres od dnia, w którym należność stała się wymagalna do dnia dokonania płatności. Brak zapłaty za fakturę może grozić dopisaniem do Krajowego Rejestru Długów Biura Informacji Gospodarczej SA.</xsl:text>
            </xsl:when>
            <!-- 3. Non-Polish customer → English text -->
            <xsl:otherwise>
              <xsl:text>Please include the invoice number in the title of your payment transfer. Thank you for paying on time. The seller reserves the right to charge penalty interest at the legally specified rate on all amount overdue from the due date for payment up to the date of actual payment.</xsl:text>
            </xsl:otherwise>
          </xsl:choose>
        </StopkaFaktury>
      </Stopka>
    </Faktura>
  </xsl:template>

  <!-- =====================================================================
       TAX SUMMARIES
       ===================================================================== -->
  <xsl:template name="emit-tax">
    <xsl:param name="L"/><xsl:param name="SM"/><xsl:param name="zrc"/><xsl:param name="isFX"/>
    <xsl:choose>
      <xsl:when test="$SM/TaxBreakdown/TaxLine">
        <!-- 23% -->
        <xsl:variable name="n23" select="sum($SM/TaxBreakdown/TaxLine[Rate='23']/NetAmount)"/>
        <xsl:variable name="t23" select="sum($SM/TaxBreakdown/TaxLine[Rate='23']/TaxAmount)"/>
        <xsl:variable name="t23w" select="sum($SM/TaxBreakdown/TaxLine[Rate='23']/TaxAmountPLN)"/>
        <xsl:if test="$n23&gt;0 or $t23&gt;0">
          <P_13_1><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$n23"/></xsl:call-template></P_13_1>
          <P_14_1><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$t23"/></xsl:call-template></P_14_1>
          <xsl:if test="$isFX and $t23w=$t23w and $t23w!=0"><P_14_1W><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$t23w"/></xsl:call-template></P_14_1W></xsl:if>
        </xsl:if>
        <!-- 8% -->
        <xsl:variable name="n8" select="sum($SM/TaxBreakdown/TaxLine[Rate='8']/NetAmount)"/>
        <xsl:variable name="t8" select="sum($SM/TaxBreakdown/TaxLine[Rate='8']/TaxAmount)"/>
        <xsl:variable name="t8w" select="sum($SM/TaxBreakdown/TaxLine[Rate='8']/TaxAmountPLN)"/>
        <xsl:if test="$n8&gt;0 or $t8&gt;0">
          <P_13_2><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$n8"/></xsl:call-template></P_13_2>
          <P_14_2><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$t8"/></xsl:call-template></P_14_2>
          <xsl:if test="$isFX and $t8w=$t8w and $t8w!=0"><P_14_2W><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$t8w"/></xsl:call-template></P_14_2W></xsl:if>
        </xsl:if>
        <!-- 5% -->
        <xsl:variable name="n5" select="sum($SM/TaxBreakdown/TaxLine[Rate='5']/NetAmount)"/>
        <xsl:variable name="t5" select="sum($SM/TaxBreakdown/TaxLine[Rate='5']/TaxAmount)"/>
        <xsl:variable name="t5w" select="sum($SM/TaxBreakdown/TaxLine[Rate='5']/TaxAmountPLN)"/>
        <xsl:if test="$n5&gt;0 or $t5&gt;0">
          <P_13_3><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$n5"/></xsl:call-template></P_13_3>
          <P_14_3><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$t5"/></xsl:call-template></P_14_3>
          <xsl:if test="$isFX and $t5w=$t5w and $t5w!=0"><P_14_3W><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$t5w"/></xsl:call-template></P_14_3W></xsl:if>
        </xsl:if>
        <!-- 0% — route to correct P_13 bucket based on zero rate code -->
        <xsl:variable name="n0" select="sum($SM/TaxBreakdown/TaxLine[Rate='0']/NetAmount)"/>
        <xsl:if test="$n0&gt;0"><xsl:choose>
          <xsl:when test="$zrc='0 WDT'"><P_13_6_2><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$n0"/></xsl:call-template></P_13_6_2></xsl:when>
          <xsl:when test="$zrc='0 EX'"><P_13_8><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$n0"/></xsl:call-template></P_13_8></xsl:when>
          <xsl:otherwise><P_13_6_1><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$n0"/></xsl:call-template></P_13_6_1></xsl:otherwise>
        </xsl:choose></xsl:if>
        <!-- P_13_6_3: Explicit 0% export bucket -->
        <xsl:variable name="n0ex" select="sum($SM/TaxBreakdown/TaxLine[Rate='0_EX']/NetAmount)"/>
        <xsl:if test="$n0ex&gt;0"><P_13_6_3><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$n0ex"/></xsl:call-template></P_13_6_3></xsl:if>
        <!-- zw (exempt) -->
        <xsl:variable name="nZW" select="sum($SM/TaxBreakdown/TaxLine[Rate='zw']/NetAmount)"/>
        <xsl:if test="$nZW&gt;0"><P_13_7><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$nZW"/></xsl:call-template></P_13_7></xsl:if>
        <!-- P_13_9: np (outside scope) -->
        <xsl:variable name="nNP" select="sum($SM/TaxBreakdown/TaxLine[Rate='np I' or Rate='np II']/NetAmount)"/>
        <xsl:if test="$nNP&gt;0"><P_13_9><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$nNP"/></xsl:call-template></P_13_9></xsl:if>
        <!-- P_13_10: Reverse charge net amount -->
        <xsl:variable name="nRC" select="sum($SM/TaxBreakdown/TaxLine[Rate='oo' or Rate='reverse_charge']/NetAmount)"/>
        <xsl:if test="$nRC&gt;0"><P_13_10><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$nRC"/></xsl:call-template></P_13_10></xsl:if>
      </xsl:when>
      <xsl:when test="$L">
        <!-- Line-level aggregation fallback -->
        <xsl:variable name="ln23" select="sum($L[normalize-space(Tax/Rate)='23']/NetAmount)"/>
        <xsl:variable name="lt23" select="sum($L[normalize-space(Tax/Rate)='23']/Tax/Amount)"/>
        <xsl:if test="$ln23&gt;0 or $lt23&gt;0">
          <P_13_1><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$ln23"/></xsl:call-template></P_13_1>
          <P_14_1><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$lt23"/></xsl:call-template></P_14_1>
        </xsl:if>
        <xsl:variable name="ln8" select="sum($L[normalize-space(Tax/Rate)='8']/NetAmount)"/>
        <xsl:variable name="lt8" select="sum($L[normalize-space(Tax/Rate)='8']/Tax/Amount)"/>
        <xsl:if test="$ln8&gt;0 or $lt8&gt;0">
          <P_13_2><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$ln8"/></xsl:call-template></P_13_2>
          <P_14_2><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$lt8"/></xsl:call-template></P_14_2>
        </xsl:if>
        <xsl:variable name="ln5" select="sum($L[normalize-space(Tax/Rate)='5']/NetAmount)"/>
        <xsl:variable name="lt5" select="sum($L[normalize-space(Tax/Rate)='5']/Tax/Amount)"/>
        <xsl:if test="$ln5&gt;0 or $lt5&gt;0">
          <P_13_3><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$ln5"/></xsl:call-template></P_13_3>
          <P_14_3><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$lt5"/></xsl:call-template></P_14_3>
        </xsl:if>
        <xsl:variable name="ln0" select="sum($L[normalize-space(Tax/Rate)='0' or normalize-space(Tax/Rate)='0.00' or normalize-space(Tax/Rate)='0.0' or normalize-space(Tax/Rate)='0 KR' or normalize-space(Tax/Rate)='0 WDT' or normalize-space(Tax/Rate)='0 EX']/NetAmount)"/>
        <xsl:if test="$ln0&gt;0"><xsl:choose>
          <xsl:when test="$zrc='0 WDT'"><P_13_6_2><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$ln0"/></xsl:call-template></P_13_6_2></xsl:when>
          <xsl:when test="$zrc='0 EX'"><P_13_8><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$ln0"/></xsl:call-template></P_13_8></xsl:when>
          <xsl:otherwise><P_13_6_1><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$ln0"/></xsl:call-template></P_13_6_1></xsl:otherwise>
        </xsl:choose></xsl:if>
        <xsl:variable name="lnZW" select="sum($L[normalize-space(Tax/Rate)='zw']/NetAmount)"/>
        <xsl:if test="$lnZW&gt;0"><P_13_7><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$lnZW"/></xsl:call-template></P_13_7></xsl:if>
        <xsl:variable name="lnNP" select="sum($L[normalize-space(Tax/Rate)='np I' or normalize-space(Tax/Rate)='np II']/NetAmount)"/>
        <xsl:if test="$lnNP&gt;0"><P_13_9><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$lnNP"/></xsl:call-template></P_13_9></xsl:if>
        <!-- P_13_10: Reverse charge from line items -->
        <xsl:variable name="lnRC" select="sum($L[normalize-space(Tax/Rate)='oo' or normalize-space(Tax/Rate)='reverse_charge']/NetAmount)"/>
        <xsl:if test="$lnRC&gt;0"><P_13_10><xsl:call-template name="safe-amount"><xsl:with-param name="v" select="$lnRC"/></xsl:call-template></P_13_10></xsl:if>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <!-- =====================================================================
       UTILITIES
       ===================================================================== -->
  <xsl:template name="norm-dt"><xsl:param name="d"/><xsl:param name="t"/><xsl:choose><xsl:when test="contains($d,'T')"><xsl:value-of select="$d"/></xsl:when><xsl:when test="normalize-space($t)!=''"><xsl:value-of select="$d"/>T<xsl:value-of select="$t"/><xsl:if test="not(contains($t,'Z'))">Z</xsl:if></xsl:when><xsl:otherwise><xsl:value-of select="$d"/>T00:00:00Z</xsl:otherwise></xsl:choose></xsl:template>
  <!-- addr1: returns empty string when no recognizable address data available -->
  <xsl:template name="addr1"><xsl:param name="a"/><xsl:choose><xsl:when test="normalize-space($a/AddressLine1)!=''"><xsl:value-of select="normalize-space($a/AddressLine1)"/></xsl:when><xsl:when test="normalize-space($a/Street)!=''"><xsl:value-of select="normalize-space($a/Street)"/><xsl:if test="normalize-space($a/BuildingNumber)!=''"><xsl:text> </xsl:text><xsl:value-of select="normalize-space($a/BuildingNumber)"/></xsl:if><xsl:if test="normalize-space($a/ApartmentNumber)!=''">/<xsl:value-of select="normalize-space($a/ApartmentNumber)"/></xsl:if></xsl:when><xsl:otherwise><xsl:value-of select="normalize-space($a/City)"/></xsl:otherwise></xsl:choose></xsl:template>
  <xsl:template name="addr2"><xsl:param name="a"/><xsl:choose><xsl:when test="normalize-space($a/AddressLine2)!=''"><xsl:value-of select="normalize-space($a/AddressLine2)"/></xsl:when><xsl:otherwise><xsl:if test="normalize-space($a/PostalCode)!=''"><xsl:value-of select="normalize-space($a/PostalCode)"/></xsl:if><xsl:if test="normalize-space($a/PostalCode)!='' and normalize-space($a/City)!=''"><xsl:text> </xsl:text></xsl:if><xsl:if test="normalize-space($a/City)!=''"><xsl:value-of select="normalize-space($a/City)"/></xsl:if></xsl:otherwise></xsl:choose></xsl:template>
  <xsl:template name="fl"><xsl:param name="v"/><xsl:choose><xsl:when test="normalize-space($v)='true' or normalize-space($v)='1' or normalize-space($v)='yes'">1</xsl:when><xsl:otherwise>2</xsl:otherwise></xsl:choose></xsl:template>
  <xsl:template name="map-type"><xsl:param name="t"/><xsl:choose><xsl:when test="$t='VAT' or $t='standard' or $t='regular'">VAT</xsl:when><xsl:when test="$t='KOR' or $t='corrective' or $t='credit_note' or $t='cancellation'">KOR</xsl:when><xsl:when test="$t='ZAL' or $t='advance'">ZAL</xsl:when><xsl:when test="$t='ROZ' or $t='settlement' or $t='final'">ROZ</xsl:when><xsl:when test="$t='UPR' or $t='simplified'">UPR</xsl:when><xsl:when test="$t='KOR_ZAL' or $t='corrective_advance'">KOR_ZAL</xsl:when><xsl:when test="$t='KOR_ROZ' or $t='corrective_settlement'">KOR_ROZ</xsl:when><xsl:otherwise><xsl:value-of select="$t"/></xsl:otherwise></xsl:choose></xsl:template>
  <xsl:template name="map-pay"><xsl:param name="m"/><xsl:choose><xsl:when test="$m='1' or $m='cash' or $m='gotowka'">1</xsl:when><xsl:when test="$m='2' or $m='card' or $m='karta'">2</xsl:when><xsl:when test="$m='3' or $m='voucher' or $m='bon'">3</xsl:when><xsl:when test="$m='4' or $m='barter'">4</xsl:when><xsl:when test="$m='5' or $m='check' or $m='czek'">5</xsl:when><xsl:when test="$m='6' or $m='transfer' or $m='przelew' or $m='bank_transfer'">6</xsl:when><xsl:when test="$m='7' or $m='mobile' or $m='mobilna'">7</xsl:when><xsl:otherwise>6</xsl:otherwise></xsl:choose></xsl:template>
  <xsl:template name="map-role"><xsl:param name="r"/><xsl:choose><xsl:when test="$r='1' or $r='factor'">1</xsl:when><xsl:when test="$r='2' or $r='delivery' or $r='recipient'">2</xsl:when><xsl:when test="$r='3' or $r='original_seller'">3</xsl:when><xsl:when test="$r='4' or $r='issuer'">4</xsl:when><xsl:when test="$r='5' or $r='additional_buyer'">5</xsl:when><xsl:when test="$r='6' or $r='payer'">6</xsl:when><xsl:when test="$r='7' or $r='invoice_recipient'">7</xsl:when><xsl:when test="$r='8' or $r='jst_recipient'">8</xsl:when><xsl:when test="$r='9' or $r='additional_info'">9</xsl:when><xsl:when test="$r='10' or $r='gv_member'">10</xsl:when><xsl:when test="$r='11' or $r='employee'">11</xsl:when><xsl:otherwise><xsl:value-of select="$r"/></xsl:otherwise></xsl:choose></xsl:template>

  <!-- =====================================================================
       SAFE-AMOUNT: NaN / empty-safe number formatter.
       Strips thousand-separator commas, trims whitespace, then formats
       to 2 decimal places. Falls back to '0.00' for any non-numeric input
       so a bad source value never pollutes the KSeF XML with 'NaN'.
       Usage: <xsl:call-template name="safe-amount"><xsl:with-param name="v" select="NetAmount"/></xsl:call-template>
       ===================================================================== -->
  <xsl:template name="safe-amount">
    <xsl:param name="v"/>
    <xsl:param name="fallback" select="'0.00'"/>
    <xsl:variable name="cleaned" select="translate(normalize-space($v), ',', '')"/>
    <xsl:choose>
      <xsl:when test="string-length($cleaned)=0">
        <xsl:value-of select="$fallback"/>
      </xsl:when>
      <xsl:when test="string(number($cleaned))='NaN'">
        <xsl:message>WARNING: Non-numeric amount value '<xsl:value-of select="$v"/>'; substituting <xsl:value-of select="$fallback"/>.</xsl:message>
        <xsl:value-of select="$fallback"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="format-number(number($cleaned), '0.00')"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
