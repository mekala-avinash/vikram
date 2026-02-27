<?xml version="1.0" encoding="UTF-8"?>
<!--
    KSeF FA(3) XSLT Transformation Map
    ====================================
    Transforms Canonical XML (internal format) to KSeF FA(3) standard format.

    Input:  Canonical XML generated from Invoice systems based on SmartKSeF mapping format.
    Output: KSeF FA(3) compliant XML for submission to Polish KSeF system

    IMPORTANT: This mapping structure matches the FA(3) schema specification.
    XPath source locations perfectly mirror the SmartKSeF JSON path fields 
    (e.g., seller.identity.taxId.nip) translated to XML structure 
    (e.g., /Invoice/Seller/Identity/TaxId/Nip).

    KSeF FA(3) Schema Reference:
    FA(3)_schemat.xsd (namespace: http://crd.gov.pl/wzor/2025/06/25/13775/)
-->
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:fa="http://crd.gov.pl/wzor/2025/06/25/13775/"
    exclude-result-prefixes="fa">

    <xsl:output method="xml" version="1.0" encoding="UTF-8" indent="no" omit-xml-declaration="yes"/>

    <xsl:template match="/">
        <Faktura xmlns="http://crd.gov.pl/wzor/2025/06/25/13775/">
            <!-- NAGLOWEK -->
            <Naglowek>
                <KodFormularza kodSystemowy="FA(3)" wersjaSchemy="1-0E">3</KodFormularza>
                <DataWytworzeniaFa>
                    <!-- Date and time of invoice creation -->
                    <xsl:value-of select="/Invoice/Invoice/IssueDate"/>T<xsl:value-of select="/Invoice/Invoice/IssueTime"/>Z
                </DataWytworzeniaFa>
                <!-- Facultative: Name of the taxpayer's system -->
                <SystemInfo>ITAAG002eLIMS-BPT_EUPL007</SystemInfo>
            </Naglowek>

            <!-- SELLER (Podmiot1) -->
            <Podmiot1>
                <xsl:if test="/Invoice/Seller/EORI">
                    <NrEORI><xsl:value-of select="/Invoice/Seller/EORI"/></NrEORI>
                </xsl:if>
                <DaneIdentyfikacyjne>
                    <NIP><xsl:value-of select="/Invoice/Seller/Identity/TaxId/Nip"/></NIP>
                    <Nazwa><xsl:value-of select="/Invoice/Seller/Identity/Name"/></Nazwa>
                </DaneIdentyfikacyjne>
                <Adres>
                    <KodKraju><xsl:value-of select="/Invoice/Seller/Address/CountryCode"/></KodKraju>
                    <AdresL1><xsl:value-of select="/Invoice/Seller/Address/Line1"/></AdresL1>
                    <xsl:if test="/Invoice/Seller/Address/Line2">
                        <AdresL2><xsl:value-of select="/Invoice/Seller/Address/Line2"/></AdresL2>
                    </xsl:if>
                    <xsl:if test="/Invoice/Seller/Address/Gln">
                        <GLN><xsl:value-of select="/Invoice/Seller/Address/Gln"/></GLN>
                    </xsl:if>
                </Adres>
                
                <xsl:if test="/Invoice/Seller/CorrespondenceAddress">
                    <AdresKoresp>
                        <KodKraju><xsl:value-of select="/Invoice/Seller/CorrespondenceAddress/CountryCode"/></KodKraju>
                        <AdresL1><xsl:value-of select="/Invoice/Seller/CorrespondenceAddress/Line1"/></AdresL1>
                        <xsl:if test="/Invoice/Seller/CorrespondenceAddress/Line2">
                            <AdresL2><xsl:value-of select="/Invoice/Seller/CorrespondenceAddress/Line2"/></AdresL2>
                        </xsl:if>
                        <xsl:if test="/Invoice/Seller/CorrespondenceAddress/Gln">
                            <GLN><xsl:value-of select="/Invoice/Seller/CorrespondenceAddress/Gln"/></GLN>
                        </xsl:if>
                    </AdresKoresp>
                </xsl:if>
                
                <xsl:if test="/Invoice/Seller/Contact">
                    <DaneKontaktowe>
                        <xsl:if test="/Invoice/Seller/Contact/Email">
                            <Email><xsl:value-of select="/Invoice/Seller/Contact/Email"/></Email>
                        </xsl:if>
                        <xsl:if test="/Invoice/Seller/Contact/Phone">
                            <Telefon><xsl:value-of select="/Invoice/Seller/Contact/Phone"/></Telefon>
                        </xsl:if>
                    </DaneKontaktowe>
                </xsl:if>
            </Podmiot1>

            <!-- BUYER (Podmiot2) -->
            <Podmiot2>
                <xsl:if test="/Invoice/Buyer/EORI">
                    <NrEORI><xsl:value-of select="/Invoice/Buyer/EORI"/></NrEORI>
                </xsl:if>
                <DaneIdentyfikacyjne>
                    <xsl:if test="/Invoice/Buyer/Identity/TaxId/Nip">
                        <NIP><xsl:value-of select="/Invoice/Buyer/Identity/TaxId/Nip"/></NIP>
                    </xsl:if>
                    <xsl:if test="/Invoice/Buyer/Identity/TaxId/VatUE/Code">
                        <KodUE><xsl:value-of select="/Invoice/Buyer/Identity/TaxId/VatUE/Code"/></KodUE>
                        <NrVatUE><xsl:value-of select="/Invoice/Buyer/Identity/TaxId/VatUE/Number"/></NrVatUE>
                    </xsl:if>
                    <xsl:if test="/Invoice/Buyer/Identity/TaxId/OtherId/CountryCode">
                        <KodKraju><xsl:value-of select="/Invoice/Buyer/Identity/TaxId/OtherId/CountryCode"/></KodKraju>
                        <NrID><xsl:value-of select="/Invoice/Buyer/Identity/TaxId/OtherId/Number"/></NrID>
                    </xsl:if>
                    <xsl:if test="/Invoice/Buyer/Identity/TaxId/NoId == 'true'">
                        <BrakID>1</BrakID>
                    </xsl:if>
                    <xsl:if test="/Invoice/Buyer/Identity/Name">
                        <Nazwa><xsl:value-of select="/Invoice/Buyer/Identity/Name"/></Nazwa>
                    </xsl:if>
                </DaneIdentyfikacyjne>
                
                <xsl:if test="/Invoice/Buyer/Address">
                    <Adres>
                        <KodKraju><xsl:value-of select="/Invoice/Buyer/Address/CountryCode"/></KodKraju>
                        <AdresL1><xsl:value-of select="/Invoice/Buyer/Address/Line1"/></AdresL1>
                        <xsl:if test="/Invoice/Buyer/Address/Line2">
                            <AdresL2><xsl:value-of select="/Invoice/Buyer/Address/Line2"/></AdresL2>
                        </xsl:if>
                    </Adres>
                </xsl:if>
                
                <xsl:if test="/Invoice/Buyer/CorrespondenceAddress">
                    <AdresKoresp>
                        <KodKraju><xsl:value-of select="/Invoice/Buyer/CorrespondenceAddress/CountryCode"/></KodKraju>
                        <AdresL1><xsl:value-of select="/Invoice/Buyer/CorrespondenceAddress/Line1"/></AdresL1>
                        <xsl:if test="/Invoice/Buyer/CorrespondenceAddress/Line2">
                            <AdresL2><xsl:value-of select="/Invoice/Buyer/CorrespondenceAddress/Line2"/></AdresL2>
                        </xsl:if>
                    </AdresKoresp>
                </xsl:if>
                
                <xsl:if test="/Invoice/Buyer/Contact">
                    <DaneKontaktowe>
                        <xsl:if test="/Invoice/Buyer/Contact/Email">
                            <Email><xsl:value-of select="/Invoice/Buyer/Contact/Email"/></Email>
                        </xsl:if>
                        <xsl:if test="/Invoice/Buyer/Contact/Phone">
                            <Telefon><xsl:value-of select="/Invoice/Buyer/Contact/Phone"/></Telefon>
                        </xsl:if>
                    </DaneKontaktowe>
                </xsl:if>

                <xsl:if test="/Invoice/Buyer/CustomerId">
                    <NrKlienta><xsl:value-of select="/Invoice/Buyer/CustomerId"/></NrKlienta>
                </xsl:if>
            </Podmiot2>

            <!-- INVOICE CORE (Fa) -->
            <Fa>
                <!-- Invoice issue code -->
                <xsl:if test="/Invoice/Invoice/CurrencyCode">
                    <KodWaluty><xsl:value-of select="/Invoice/Invoice/CurrencyCode"/></KodWaluty>
                </xsl:if>
                <P_1><xsl:value-of select="/Invoice/Invoice/IssueDate"/></P_1>
                <P_2><xsl:value-of select="/Invoice/Invoice/InvoiceNumber"/></P_2>
                
                <xsl:if test="/Invoice/Settlements/PaymentTerms">
                    <Platnosc>
                        <TerminPlatnosci><xsl:value-of select="/Invoice/Settlements/PaymentTerms/PaymentDate"/></TerminPlatnosci>
                        <FormaPlatnosci><xsl:value-of select="/Invoice/Settlements/PaymentTerms/PaymentMethod"/></FormaPlatnosci>
                        <RachunekBankowy>
                            <NrRB><xsl:value-of select="/Invoice/Settlements/BankAccounts/Iban"/></NrRB>
                        </RachunekBankowy>
                    </Platnosc>
                </xsl:if>

                <xsl:if test="/Invoice/TermsOfDeliveryAndOrder/OrderNumber != ''">
                    <WarunkiTransakcji>
                        <Zowies>
                            <NrZow><xsl:value-of select="/Invoice/TermsOfDeliveryAndOrder/OrderNumber"/></NrZow>
                        </Zowies>
                    </WarunkiTransakcji>
                </xsl:if>

                <!-- LINES -->
                <xsl:for-each select="/Invoice/FaRow/FaRow">
                    <FaWiersz>
                        <NrWierszaFa><xsl:value-of select="Number"/></NrWierszaFa>
                        <P_7><xsl:value-of select="Name"/></P_7>
                        <xsl:if test="MeasureUnit">
                            <P_8A><xsl:value-of select="MeasureUnit"/></P_8A>
                        </xsl:if>
                        <xsl:if test="Quantity">
                            <P_8B><xsl:value-of select="Quantity"/></P_8B>
                        </xsl:if>
                        <xsl:if test="NetUnitPrice">
                            <P_9A><xsl:value-of select="NetUnitPrice"/></P_9A>
                        </xsl:if>
                        <xsl:if test="DiscountAmount">
                            <P_10><xsl:value-of select="DiscountAmount"/></P_10>
                        </xsl:if>
                        <P_11><xsl:value-of select="NetAmount"/></P_11>
                        <P_12><xsl:value-of select="VatRate"/></P_12>
                    </FaWiersz>
                </xsl:for-each>

                <!-- SUMMARY (Rozliczenie) -->
                <xsl:if test="/Invoice/Fa/Taxes">
                    <Rozliczenie>
                        <StawkiPodatku>
                            <xsl:for-each select="/Invoice/Fa/Taxes/TaxRate">
                                <StawkaPodatku>
                                    <KodStawki><xsl:value-of select="Rate"/></KodStawki>
                                    <PodstawaOpodatkowania><xsl:value-of select="Base"/></PodstawaOpodatkowania>
                                    <KwotaPodatku><xsl:value-of select="Amount"/></KwotaPodatku>
                                </StawkaPodatku>
                            </xsl:for-each>
                        </StawkiPodatku>
                        <KwotaPodatkuNaleznego><xsl:value-of select="/Invoice/Fa/Taxes/TotalVatAmount"/></KwotaPodatkuNaleznego>
                        <KwotaDoZaplaty><xsl:value-of select="/Invoice/Fa/Taxes/GrossAmount"/></KwotaDoZaplaty>
                    </Rozliczenie>
                </xsl:if>
            </Fa>
        </Faktura>
    </xsl:template>
</xsl:stylesheet>
