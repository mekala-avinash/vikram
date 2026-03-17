<?xml version="1.0" encoding="UTF-8"?>
<!--
  ===========================================================================
  CanonicalInvoice to KSeF FA(3) XSLT   v6.0
  ===========================================================================
  Target NS  : http://crd.gov.pl/wzor/2025/06/25/13775/
  Types NS   : http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2022/01/05/eD/DefinicjeTypy/
  XSD        : http://crd.gov.pl/wzor/2025/06/25/13775/schemat.xsd
  Schema     : FA(3)  kodSystemowy="FA (3)"  wersjaSchemy="1-0E"
  Mandatory  : from 1 February 2026  (large taxpayers)
  Processor  : XSLT 1.0  (xsltproc, Saxon 6/HE, MSXML, Java Xalan)
  Author     : Trivikram
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

  <xsl:param name="debug"        select="'false'"/>
  <xsl:param name="system-info"  select="''"/>
  <xsl:param name="fallback-nip" select="'7763593843'"/>

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

    <xsl:if test="not($H/IssueDate) or normalize-space($H/IssueDate)=''"><xsl:message terminate="yes">FATAL: Header/IssueDate required.</xsl:message></xsl:if>
    <xsl:if test="not($H/InvoiceNumber) or normalize-space($H/InvoiceNumber)=''"><xsl:message terminate="yes">FATAL: Header/InvoiceNumber required.</xsl:message></xsl:if>
    <xsl:if test="not($S/TaxId) or normalize-space($S/TaxId)=''"><xsl:message terminate="yes">FATAL: Seller/TaxId required.</xsl:message></xsl:if>
    <xsl:if test="$debug='true'"><xsl:message>DEBUG inv=<xsl:value-of select="$H/InvoiceNumber"/> lines=<xsl:value-of select="count($L)"/> ccy=<xsl:value-of select="$ccy"/> zrc=<xsl:value-of select="$zrc"/></xsl:message></xsl:if>

    <Faktura>

      <!-- NAGLOWEK -->
      <Naglowek>
        <KodFormularza kodSystemowy="FA (3)" wersjaSchemy="1-0E">FA</KodFormularza>
        <WariantFormularza>3</WariantFormularza>
        <DataWytworzeniaFa><xsl:call-template name="norm-dt"><xsl:with-param name="d" select="$H/IssueDate"/><xsl:with-param name="t" select="$H/IssueTime"/></xsl:call-template></DataWytworzeniaFa>
        <SystemInfo><xsl:choose><xsl:when test="$system-info!=''"><xsl:value-of select="$system-info"/></xsl:when><xsl:when test="normalize-space($H/SystemInfo)!=''"><xsl:value-of select="normalize-space($H/SystemInfo)"/></xsl:when><xsl:otherwise>CanonicalInvoice_FA3_v4</xsl:otherwise></xsl:choose></SystemInfo>
      </Naglowek>

      <!-- PODMIOT1 -->
      <Podmiot1>
        <xsl:if test="normalize-space($S/VATPrefix)!=''"><PrefiksPodatnika><xsl:value-of select="normalize-space($S/VATPrefix)"/></PrefiksPodatnika></xsl:if>
        <xsl:if test="normalize-space($S/EORI)!=''"><NrEORI><xsl:value-of select="normalize-space($S/EORI)"/></NrEORI></xsl:if>
        <DaneIdentyfikacyjne>
          <xsl:variable name="sRaw" select="normalize-space($S/TaxId)"/>
          <xsl:variable name="sDig" select="translate($sRaw,'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz -./','')"/>
          <NIP><xsl:choose><xsl:when test="string-length($sDig)=10 and translate($sDig,'0123456789','')='' and substring($sDig,1,1)!='0'"><xsl:value-of select="$sDig"/></xsl:when><xsl:otherwise><xsl:message>WARNING: Seller NIP '<xsl:value-of select="$sRaw"/>' invalid, using fallback.</xsl:message><xsl:value-of select="$fallback-nip"/></xsl:otherwise></xsl:choose></NIP>
          <Nazwa><xsl:choose><xsl:when test="normalize-space($S/Name)!=''"><xsl:value-of select="normalize-space($S/Name)"/></xsl:when><xsl:otherwise>UNKNOWN_SELLER</xsl:otherwise></xsl:choose></Nazwa>
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

      <!-- PODMIOT2 -->
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

      <!-- PODMIOT3 -->
      <xsl:for-each select="Parties/ThirdParty">
        <Podmiot3>
          <DaneIdentyfikacyjne>
            <xsl:variable name="pt" select="normalize-space(TaxId)"/>
            <xsl:choose>
              <xsl:when test="string-length($pt)=10 and translate($pt,'0123456789','')=''"><NIP><xsl:value-of select="$pt"/></NIP></xsl:when>
              <xsl:when test="$pt!=''"><NrID><xsl:value-of select="$pt"/></NrID></xsl:when>
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
          <Rola><xsl:call-template name="map-role"><xsl:with-param name="r" select="normalize-space(Role)"/></xsl:call-template></Rola>
        </Podmiot3>
      </xsl:for-each>

      <!-- FA -->
      <Fa>
        <KodWaluty><xsl:choose><xsl:when test="$ccy!=''"><xsl:value-of select="$ccy"/></xsl:when><xsl:otherwise>PLN</xsl:otherwise></xsl:choose></KodWaluty>
        <P_1><xsl:value-of select="$H/IssueDate"/></P_1>
        <xsl:if test="normalize-space($H/IssuePlace)!=''"><P_1M><xsl:value-of select="normalize-space($H/IssuePlace)"/></P_1M></xsl:if>
        <P_2><xsl:value-of select="$H/InvoiceNumber"/></P_2>
        <xsl:if test="normalize-space($H/SaleDate)!='' and normalize-space($H/SaleDate)!=normalize-space($H/IssueDate)"><P_6><xsl:value-of select="normalize-space($H/SaleDate)"/></P_6></xsl:if>
        <xsl:if test="normalize-space($H/TransactionDescription)!=''"><P_6A><xsl:value-of select="normalize-space($H/TransactionDescription)"/></P_6A></xsl:if>

        <!-- TAX SUMMARIES -->
        <xsl:call-template name="emit-tax">
          <xsl:with-param name="L" select="$L"/><xsl:with-param name="SM" select="$SM"/>
          <xsl:with-param name="zrc" select="$zrc"/><xsl:with-param name="isFX" select="$isFX"/>
        </xsl:call-template>

        <!-- P_15 -->
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

        <xsl:if test="$isFX and normalize-space($H/ExchangeRate)!=''"><KursWalutyZ><xsl:value-of select="normalize-space($H/ExchangeRate)"/></KursWalutyZ></xsl:if>

        <!-- ADNOTACJE (FA(3) structure with wrapper elements) -->
        <Adnotacje>
          <P_16><xsl:call-template name="fl"><xsl:with-param name="v" select="$H/SelfBilling"/></xsl:call-template></P_16>
          <P_17><xsl:call-template name="fl"><xsl:with-param name="v" select="$H/ReverseCharge"/></xsl:call-template></P_17>
          <P_18><xsl:choose><xsl:when test="$hasOutside or normalize-space($H/IntraCommunitySupply)='true' or normalize-space($H/IntraCommunitySupply)='1'">1</xsl:when><xsl:otherwise>2</xsl:otherwise></xsl:choose></P_18>
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
        <RodzajFaktury><xsl:choose>
          <xsl:when test="normalize-space($H/InvoiceType)!=''"><xsl:call-template name="map-type"><xsl:with-param name="t" select="normalize-space($H/InvoiceType)"/></xsl:call-template></xsl:when>
          <xsl:otherwise>VAT</xsl:otherwise>
        </xsl:choose></RodzajFaktury>

        <xsl:for-each select="$H/AdditionalInfo"><DodatkowyOpis><Klucz><xsl:value-of select="Key"/></Klucz><Wartosc><xsl:value-of select="Value"/></Wartosc></DodatkowyOpis></xsl:for-each>

        <!-- FaWiersz (line items) -->
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
            <xsl:if test="normalize-space(GTUCode)!=''"><GTU><xsl:value-of select="normalize-space(GTUCode)"/></GTU></xsl:if>
            <xsl:if test="normalize-space(Procedure)!=''"><Procedura><xsl:value-of select="normalize-space(Procedure)"/></Procedura></xsl:if>
          </FaWiersz>
        </xsl:for-each>

        <!-- PLATNOSC -->
        <xsl:variable name="pDue"><xsl:choose><xsl:when test="normalize-space($P/DueDate)!=''"><xsl:value-of select="normalize-space($P/DueDate)"/></xsl:when><xsl:otherwise><xsl:value-of select="normalize-space($H/DueDate)"/></xsl:otherwise></xsl:choose></xsl:variable>
        <xsl:variable name="pMeth"><xsl:choose><xsl:when test="normalize-space($P/Method)!=''"><xsl:value-of select="normalize-space($P/Method)"/></xsl:when><xsl:otherwise><xsl:value-of select="normalize-space($H/PaymentMethod)"/></xsl:otherwise></xsl:choose></xsl:variable>
        <xsl:variable name="pAcct"><xsl:choose><xsl:when test="normalize-space($P/BankAccount/AccountNumber)!=''"><xsl:value-of select="normalize-space($P/BankAccount/AccountNumber)"/></xsl:when><xsl:otherwise><xsl:value-of select="normalize-space($H/BankAccount)"/></xsl:otherwise></xsl:choose></xsl:variable>
        <xsl:variable name="isPaid" select="normalize-space($H/PaidFlag)='1'"/>

        <xsl:if test="$pDue!='' or $pMeth!='' or $pAcct!='' or $isPaid">
          <Platnosc>
            <xsl:if test="$isPaid"><Zaplacono>1</Zaplacono><DataZaplaty><xsl:choose><xsl:when test="normalize-space($H/PaymentDate)!=''"><xsl:value-of select="normalize-space($H/PaymentDate)"/></xsl:when><xsl:otherwise><xsl:value-of select="$H/IssueDate"/></xsl:otherwise></xsl:choose></DataZaplaty></xsl:if>
            <xsl:if test="$pDue!=''"><TerminPlatnosci><Termin><xsl:value-of select="$pDue"/></Termin></TerminPlatnosci></xsl:if>
            <FormaPlatnosci><xsl:call-template name="map-pay"><xsl:with-param name="m"><xsl:choose><xsl:when test="$pMeth!=''"><xsl:value-of select="$pMeth"/></xsl:when><xsl:otherwise>6</xsl:otherwise></xsl:choose></xsl:with-param></xsl:call-template></FormaPlatnosci>
            <xsl:if test="$pAcct!=''">
              <RachunekBankowy>
                <NrRB><xsl:value-of select="$pAcct"/></NrRB>
                <xsl:if test="normalize-space($P/BankAccount/SWIFT)!=''"><SWIFT><xsl:value-of select="normalize-space($P/BankAccount/SWIFT)"/></SWIFT></xsl:if>
                <xsl:if test="normalize-space($P/BankAccount/BankName)!=''"><NazwaBanku><xsl:value-of select="normalize-space($P/BankAccount/BankName)"/></NazwaBanku></xsl:if>
                <xsl:if test="normalize-space($P/BankAccount/Description)!=''"><OpisRachunku><xsl:value-of select="normalize-space($P/BankAccount/Description)"/></OpisRachunku></xsl:if>
              </RachunekBankowy>
            </xsl:if>
            <xsl:if test="normalize-space($P/Description)!=''"><OpisZaplaty><xsl:value-of select="normalize-space($P/Description)"/></OpisZaplaty></xsl:if>
            <xsl:if test="normalize-space($P/PaymentLink)!=''"><LinkDoPlatnosci><xsl:value-of select="normalize-space($P/PaymentLink)"/></LinkDoPlatnosci></xsl:if>
          </Platnosc>
        </xsl:if>

        <!-- WarunkiTransakcji -->
        <xsl:if test="Parties/ThirdParty[normalize-space(Role)='delivery' or normalize-space(Role)='2']">
          <xsl:variable name="dl" select="Parties/ThirdParty[normalize-space(Role)='delivery' or normalize-space(Role)='2'][1]"/>
          <WarunkiTransakcji><Transport><WysylkaDo>
            <KodKraju><xsl:choose><xsl:when test="normalize-space($dl/Address/Country)!=''"><xsl:value-of select="normalize-space($dl/Address/Country)"/></xsl:when><xsl:otherwise>PL</xsl:otherwise></xsl:choose></KodKraju>
            <AdresL1><xsl:call-template name="addr1"><xsl:with-param name="a" select="$dl/Address"/></xsl:call-template></AdresL1>
            <xsl:variable name="dlL2"><xsl:call-template name="addr2"><xsl:with-param name="a" select="$dl/Address"/></xsl:call-template></xsl:variable>
            <xsl:if test="normalize-space($dlL2)!=''"><AdresL2><xsl:value-of select="normalize-space($dlL2)"/></AdresL2></xsl:if>
          </WysylkaDo><TransportInny><OpisInnegoTransportu>wg ustalenia/umowy</OpisInnegoTransportu></TransportInny></Transport></WarunkiTransakcji>
        </xsl:if>
      </Fa>

      <!-- STOPKA -->
      <xsl:if test="Footer or $S/KRS or $S/REGON">
        <Stopka><StopkaFaktury>
          <xsl:if test="normalize-space($S/KRS)!=''">KRS: <xsl:value-of select="normalize-space($S/KRS)"/></xsl:if>
          <xsl:if test="normalize-space($S/KRS)!='' and normalize-space($S/REGON)!=''"> | </xsl:if>
          <xsl:if test="normalize-space($S/REGON)!=''">REGON: <xsl:value-of select="normalize-space($S/REGON)"/></xsl:if>
          <xsl:if test="(normalize-space($S/KRS)!='' or normalize-space($S/REGON)!='') and normalize-space(Footer/Text)!=''"> | </xsl:if>
          <xsl:if test="normalize-space(Footer/Text)!=''"><xsl:value-of select="normalize-space(Footer/Text)"/></xsl:if>
        </StopkaFaktury></Stopka>
      </xsl:if>
    </Faktura>
  </xsl:template>

  <!-- =====================================================================
       TAX SUMMARIES
       ===================================================================== -->
  <xsl:template name="emit-tax">
    <xsl:param name="L"/><xsl:param name="SM"/><xsl:param name="zrc"/><xsl:param name="isFX"/>
    <xsl:choose>
      <xsl:when test="$SM/TaxBreakdown/TaxLine">
        <xsl:variable name="n23" select="sum($SM/TaxBreakdown/TaxLine[Rate='23']/NetAmount)"/><xsl:variable name="t23" select="sum($SM/TaxBreakdown/TaxLine[Rate='23']/TaxAmount)"/><xsl:variable name="t23w" select="sum($SM/TaxBreakdown/TaxLine[Rate='23']/TaxAmountPLN)"/>
        <xsl:if test="$n23&gt;0 or $t23&gt;0"><P_13_1><xsl:value-of select="format-number($n23,'0.00')"/></P_13_1><P_14_1><xsl:value-of select="format-number($t23,'0.00')"/></P_14_1><xsl:if test="$isFX and $t23w=$t23w and $t23w!=0"><P_14_1W><xsl:value-of select="format-number($t23w,'0.00')"/></P_14_1W></xsl:if></xsl:if>
        <xsl:variable name="n8" select="sum($SM/TaxBreakdown/TaxLine[Rate='8']/NetAmount)"/><xsl:variable name="t8" select="sum($SM/TaxBreakdown/TaxLine[Rate='8']/TaxAmount)"/><xsl:variable name="t8w" select="sum($SM/TaxBreakdown/TaxLine[Rate='8']/TaxAmountPLN)"/>
        <xsl:if test="$n8&gt;0 or $t8&gt;0"><P_13_2><xsl:value-of select="format-number($n8,'0.00')"/></P_13_2><P_14_2><xsl:value-of select="format-number($t8,'0.00')"/></P_14_2><xsl:if test="$isFX and $t8w=$t8w and $t8w!=0"><P_14_2W><xsl:value-of select="format-number($t8w,'0.00')"/></P_14_2W></xsl:if></xsl:if>
        <xsl:variable name="n5" select="sum($SM/TaxBreakdown/TaxLine[Rate='5']/NetAmount)"/><xsl:variable name="t5" select="sum($SM/TaxBreakdown/TaxLine[Rate='5']/TaxAmount)"/><xsl:variable name="t5w" select="sum($SM/TaxBreakdown/TaxLine[Rate='5']/TaxAmountPLN)"/>
        <xsl:if test="$n5&gt;0 or $t5&gt;0"><P_13_3><xsl:value-of select="format-number($n5,'0.00')"/></P_13_3><P_14_3><xsl:value-of select="format-number($t5,'0.00')"/></P_14_3><xsl:if test="$isFX and $t5w=$t5w and $t5w!=0"><P_14_3W><xsl:value-of select="format-number($t5w,'0.00')"/></P_14_3W></xsl:if></xsl:if>
        <xsl:variable name="n0" select="sum($SM/TaxBreakdown/TaxLine[Rate='0']/NetAmount)"/>
        <xsl:if test="$n0&gt;0"><xsl:choose><xsl:when test="$zrc='0 WDT'"><P_13_6_2><xsl:value-of select="format-number($n0,'0.00')"/></P_13_6_2></xsl:when><xsl:when test="$zrc='0 EX'"><P_13_8><xsl:value-of select="format-number($n0,'0.00')"/></P_13_8></xsl:when><xsl:otherwise><P_13_6_1><xsl:value-of select="format-number($n0,'0.00')"/></P_13_6_1></xsl:otherwise></xsl:choose></xsl:if>
        <xsl:variable name="nZW" select="sum($SM/TaxBreakdown/TaxLine[Rate='zw']/NetAmount)"/>
        <xsl:if test="$nZW&gt;0"><P_13_7><xsl:value-of select="format-number($nZW,'0.00')"/></P_13_7></xsl:if>
      </xsl:when>
      <xsl:when test="$L">
        <xsl:variable name="ln23" select="sum($L[normalize-space(Tax/Rate)='23']/NetAmount)"/><xsl:variable name="lt23" select="sum($L[normalize-space(Tax/Rate)='23']/Tax/Amount)"/>
        <xsl:if test="$ln23&gt;0 or $lt23&gt;0"><P_13_1><xsl:value-of select="format-number($ln23,'0.00')"/></P_13_1><P_14_1><xsl:value-of select="format-number($lt23,'0.00')"/></P_14_1></xsl:if>
        <xsl:variable name="ln8" select="sum($L[normalize-space(Tax/Rate)='8']/NetAmount)"/><xsl:variable name="lt8" select="sum($L[normalize-space(Tax/Rate)='8']/Tax/Amount)"/>
        <xsl:if test="$ln8&gt;0 or $lt8&gt;0"><P_13_2><xsl:value-of select="format-number($ln8,'0.00')"/></P_13_2><P_14_2><xsl:value-of select="format-number($lt8,'0.00')"/></P_14_2></xsl:if>
        <xsl:variable name="ln5" select="sum($L[normalize-space(Tax/Rate)='5']/NetAmount)"/><xsl:variable name="lt5" select="sum($L[normalize-space(Tax/Rate)='5']/Tax/Amount)"/>
        <xsl:if test="$ln5&gt;0 or $lt5&gt;0"><P_13_3><xsl:value-of select="format-number($ln5,'0.00')"/></P_13_3><P_14_3><xsl:value-of select="format-number($lt5,'0.00')"/></P_14_3></xsl:if>
        <xsl:variable name="ln0" select="sum($L[normalize-space(Tax/Rate)='0' or normalize-space(Tax/Rate)='0.00' or normalize-space(Tax/Rate)='0.0' or normalize-space(Tax/Rate)='0 KR' or normalize-space(Tax/Rate)='0 WDT' or normalize-space(Tax/Rate)='0 EX']/NetAmount)"/>
        <xsl:if test="$ln0&gt;0"><xsl:choose><xsl:when test="$zrc='0 WDT'"><P_13_6_2><xsl:value-of select="format-number($ln0,'0.00')"/></P_13_6_2></xsl:when><xsl:when test="$zrc='0 EX'"><P_13_8><xsl:value-of select="format-number($ln0,'0.00')"/></P_13_8></xsl:when><xsl:otherwise><P_13_6_1><xsl:value-of select="format-number($ln0,'0.00')"/></P_13_6_1></xsl:otherwise></xsl:choose></xsl:if>
        <xsl:variable name="lnZW" select="sum($L[normalize-space(Tax/Rate)='zw']/NetAmount)"/>
        <xsl:if test="$lnZW&gt;0"><P_13_7><xsl:value-of select="format-number($lnZW,'0.00')"/></P_13_7></xsl:if>
        <xsl:variable name="lnNP" select="sum($L[normalize-space(Tax/Rate)='np I' or normalize-space(Tax/Rate)='np II']/NetAmount)"/>
        <xsl:if test="$lnNP&gt;0"><P_13_9><xsl:value-of select="format-number($lnNP,'0.00')"/></P_13_9></xsl:if>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <!-- =====================================================================
       UTILITIES
       ===================================================================== -->
  <xsl:template name="norm-dt"><xsl:param name="d"/><xsl:param name="t"/><xsl:choose><xsl:when test="contains($d,'T')"><xsl:value-of select="$d"/></xsl:when><xsl:when test="normalize-space($t)!=''"><xsl:value-of select="$d"/>T<xsl:value-of select="$t"/><xsl:if test="not(contains($t,'Z'))">Z</xsl:if></xsl:when><xsl:otherwise><xsl:value-of select="$d"/>T00:00:00Z</xsl:otherwise></xsl:choose></xsl:template>
  <xsl:template name="addr1"><xsl:param name="a"/><xsl:choose><xsl:when test="normalize-space($a/AddressLine1)!=''"><xsl:value-of select="normalize-space($a/AddressLine1)"/></xsl:when><xsl:when test="normalize-space($a/Street)!=''"><xsl:value-of select="normalize-space($a/Street)"/><xsl:if test="normalize-space($a/BuildingNumber)!=''"><xsl:text> </xsl:text><xsl:value-of select="normalize-space($a/BuildingNumber)"/></xsl:if><xsl:if test="normalize-space($a/ApartmentNumber)!=''">/<xsl:value-of select="normalize-space($a/ApartmentNumber)"/></xsl:if></xsl:when><xsl:otherwise>UNKNOWN ADDRESS</xsl:otherwise></xsl:choose></xsl:template>
  <xsl:template name="addr2"><xsl:param name="a"/><xsl:choose><xsl:when test="normalize-space($a/AddressLine2)!=''"><xsl:value-of select="normalize-space($a/AddressLine2)"/></xsl:when><xsl:otherwise><xsl:if test="normalize-space($a/PostalCode)!=''"><xsl:value-of select="normalize-space($a/PostalCode)"/></xsl:if><xsl:if test="normalize-space($a/PostalCode)!='' and normalize-space($a/City)!=''"><xsl:text> </xsl:text></xsl:if><xsl:if test="normalize-space($a/City)!=''"><xsl:value-of select="normalize-space($a/City)"/></xsl:if></xsl:otherwise></xsl:choose></xsl:template>
  <xsl:template name="fl"><xsl:param name="v"/><xsl:choose><xsl:when test="normalize-space($v)='true' or normalize-space($v)='1' or normalize-space($v)='yes'">1</xsl:when><xsl:otherwise>2</xsl:otherwise></xsl:choose></xsl:template>
  <xsl:template name="map-type"><xsl:param name="t"/><xsl:choose><xsl:when test="$t='VAT' or $t='standard' or $t='regular'">VAT</xsl:when><xsl:when test="$t='KOR' or $t='corrective' or $t='credit_note'">KOR</xsl:when><xsl:when test="$t='ZAL' or $t='advance'">ZAL</xsl:when><xsl:when test="$t='ROZ' or $t='settlement' or $t='final'">ROZ</xsl:when><xsl:when test="$t='UPR' or $t='simplified'">UPR</xsl:when><xsl:when test="$t='KOR_ZAL' or $t='corrective_advance'">KOR_ZAL</xsl:when><xsl:when test="$t='KOR_ROZ' or $t='corrective_settlement'">KOR_ROZ</xsl:when><xsl:otherwise><xsl:value-of select="$t"/></xsl:otherwise></xsl:choose></xsl:template>
  <xsl:template name="map-pay"><xsl:param name="m"/><xsl:choose><xsl:when test="$m='1' or $m='cash' or $m='gotowka'">1</xsl:when><xsl:when test="$m='2' or $m='card' or $m='karta'">2</xsl:when><xsl:when test="$m='3' or $m='voucher' or $m='bon'">3</xsl:when><xsl:when test="$m='4' or $m='barter'">4</xsl:when><xsl:when test="$m='5' or $m='check' or $m='czek'">5</xsl:when><xsl:when test="$m='6' or $m='transfer' or $m='przelew' or $m='bank_transfer'">6</xsl:when><xsl:when test="$m='7' or $m='mobile' or $m='mobilna'">7</xsl:when><xsl:otherwise>6</xsl:otherwise></xsl:choose></xsl:template>
  <xsl:template name="map-role"><xsl:param name="r"/><xsl:choose><xsl:when test="$r='1' or $r='factor'">1</xsl:when><xsl:when test="$r='2' or $r='delivery' or $r='recipient'">2</xsl:when><xsl:when test="$r='3' or $r='original_seller'">3</xsl:when><xsl:when test="$r='4' or $r='issuer'">4</xsl:when><xsl:when test="$r='5' or $r='additional_buyer'">5</xsl:when><xsl:when test="$r='6' or $r='payer'">6</xsl:when><xsl:when test="$r='7' or $r='invoice_recipient'">7</xsl:when><xsl:when test="$r='8' or $r='jst_recipient'">8</xsl:when><xsl:when test="$r='9' or $r='additional_info'">9</xsl:when><xsl:when test="$r='10' or $r='gv_member'">10</xsl:when><xsl:when test="$r='11' or $r='employee'">11</xsl:when><xsl:otherwise><xsl:value-of select="$r"/></xsl:otherwise></xsl:choose></xsl:template>

</xsl:stylesheet>
