<?xml version="1.0" encoding="UTF-8"?>
<!--
    KSeF FA(3) XSLT Transformation Map
    ====================================
    Transforms Canonical XML (internal format) to KSeF FA(3) standard format.

    Input:  Canonical XML generated from Invoice systems based on CanonicalInvoice format.
    Output: KSeF FA(3) compliant XML for submission to Polish KSeF system
-->
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:fa="http://ksef.mf.gov.pl/schema/FA/3-0E"
    exclude-result-prefixes="fa">

    <xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>

    <xsl:template match="/">
        <Faktura xmlns="http://ksef.mf.gov.pl/schema/FA/3-0E">
            <!-- NAGLOWEK -->
            <Naglowek>
                <KodFormularza kodSystemowy="FA(3)" wersjaSchemy="1-0E">3</KodFormularza>
                <DataWytworzeniaFa>
                    <!-- Formatting: appending T00:00:00Z if missing -->
                    <xsl:value-of select="/CanonicalInvoice/Header/IssueDate"/>T00:00:00Z
                </DataWytworzeniaFa>
                <xsl:choose>
                    <xsl:when test="normalize-space(/CanonicalInvoice/Header/SystemInfo) != ''">
                        <SystemInfo><xsl:value-of select="/CanonicalInvoice/Header/SystemInfo"/></SystemInfo>
                    </xsl:when>
                    <xsl:otherwise>
                        <SystemInfo>Standard_Integration_System</SystemInfo>
                    </xsl:otherwise>
                </xsl:choose>
            </Naglowek>

            <!-- SELLER (Podmiot1) -->
            <Podmiot1>
                <DaneIdentyfikacyjne>
                    <NIP><xsl:value-of select="normalize-space(/CanonicalInvoice/Parties/Seller/TaxId)"/></NIP>
                    <Nazwa><xsl:value-of select="/CanonicalInvoice/Parties/Seller/Name"/></Nazwa>
                </DaneIdentyfikacyjne>
                <Adres>
                    <xsl:choose>
                        <xsl:when test="normalize-space(/CanonicalInvoice/Parties/Seller/Address/Country) != ''">
                            <KodKraju><xsl:value-of select="normalize-space(/CanonicalInvoice/Parties/Seller/Address/Country)"/></KodKraju>
                        </xsl:when>
                        <xsl:otherwise><KodKraju>PL</KodKraju></xsl:otherwise>
                    </xsl:choose>
                    <AdresL1><xsl:value-of select="normalize-space(/CanonicalInvoice/Parties/Seller/Address/Street)"/></AdresL1>
                    <xsl:if test="normalize-space(/CanonicalInvoice/Parties/Seller/Address/City) != ''">
                        <AdresL2><xsl:value-of select="normalize-space(/CanonicalInvoice/Parties/Seller/Address/City)"/></AdresL2>
                    </xsl:if>
                </Adres>
                <xsl:if test="normalize-space(/CanonicalInvoice/Parties/Seller/Contact/Email) != '' or normalize-space(/CanonicalInvoice/Parties/Seller/Contact/Phone) != ''">
                    <DaneKontaktowe>
                        <xsl:if test="normalize-space(/CanonicalInvoice/Parties/Seller/Contact/Email) != ''">
                            <Email><xsl:value-of select="normalize-space(/CanonicalInvoice/Parties/Seller/Contact/Email)"/></Email>
                        </xsl:if>
                        <xsl:if test="normalize-space(/CanonicalInvoice/Parties/Seller/Contact/Phone) != ''">
                            <Telefon><xsl:value-of select="normalize-space(/CanonicalInvoice/Parties/Seller/Contact/Phone)"/></Telefon>
                        </xsl:if>
                    </DaneKontaktowe>
                </xsl:if>
            </Podmiot1>

            <!-- BUYER (Podmiot2) -->
            <Podmiot2>
                <DaneIdentyfikacyjne>
                    <NIP><xsl:value-of select="normalize-space(/CanonicalInvoice/Parties/Buyer/TaxId)"/></NIP>
                    <Nazwa><xsl:value-of select="/CanonicalInvoice/Parties/Buyer/Name"/></Nazwa>
                </DaneIdentyfikacyjne>
                <Adres>
                    <xsl:choose>
                        <xsl:when test="normalize-space(/CanonicalInvoice/Parties/Buyer/Address/Country) != ''">
                            <KodKraju><xsl:value-of select="normalize-space(/CanonicalInvoice/Parties/Buyer/Address/Country)"/></KodKraju>
                        </xsl:when>
                        <xsl:otherwise><KodKraju>PL</KodKraju></xsl:otherwise>
                    </xsl:choose>
                    <AdresL1><xsl:value-of select="normalize-space(/CanonicalInvoice/Parties/Buyer/Address/Street)"/></AdresL1>
                    <xsl:if test="normalize-space(/CanonicalInvoice/Parties/Buyer/Address/City) != ''">
                        <AdresL2><xsl:value-of select="normalize-space(/CanonicalInvoice/Parties/Buyer/Address/City)"/></AdresL2>
                    </xsl:if>
                </Adres>
                <xsl:if test="normalize-space(/CanonicalInvoice/Parties/Buyer/Contact/Email) != '' or normalize-space(/CanonicalInvoice/Parties/Buyer/Contact/Phone) != ''">
                    <DaneKontaktowe>
                        <xsl:if test="normalize-space(/CanonicalInvoice/Parties/Buyer/Contact/Email) != ''">
                            <Email><xsl:value-of select="normalize-space(/CanonicalInvoice/Parties/Buyer/Contact/Email)"/></Email>
                        </xsl:if>
                        <xsl:if test="normalize-space(/CanonicalInvoice/Parties/Buyer/Contact/Phone) != ''">
                            <Telefon><xsl:value-of select="normalize-space(/CanonicalInvoice/Parties/Buyer/Contact/Phone)"/></Telefon>
                        </xsl:if>
                    </DaneKontaktowe>
                </xsl:if>
            </Podmiot2>

            <!-- INVOICE CORE (Fa) -->
            <Fa>
                <!-- Invoice issue code -->
                <P_1><xsl:value-of select="/CanonicalInvoice/Header/IssueDate"/></P_1>
                <P_2><xsl:value-of select="/CanonicalInvoice/Header/InvoiceNumber"/></P_2>
                
                <xsl:if test="normalize-space(/CanonicalInvoice/Header/Currency) != ''">
                    <Waluta>
                        <KodWaluty><xsl:value-of select="normalize-space(/CanonicalInvoice/Header/Currency)"/></KodWaluty>
                    </Waluta>
                </xsl:if>
                
                <xsl:if test="normalize-space(/CanonicalInvoice/Header/DueDate) != ''">
                    <Platnosc>
                        <TerminPlatnosci><xsl:value-of select="normalize-space(/CanonicalInvoice/Header/DueDate)"/></TerminPlatnosci>
                        <xsl:choose>
                            <xsl:when test="normalize-space(/CanonicalInvoice/Header/PaymentMethod) != ''">
                                <FormaPlatnosci><xsl:value-of select="normalize-space(/CanonicalInvoice/Header/PaymentMethod)"/></FormaPlatnosci>
                            </xsl:when>
                            <xsl:otherwise>
                                <FormaPlatnosci>1</FormaPlatnosci>
                            </xsl:otherwise>
                        </xsl:choose>
                        
                        <xsl:if test="normalize-space(/CanonicalInvoice/Header/BankAccount) != ''">
                            <RachunekBankowy>
                                <NrRB><xsl:value-of select="normalize-space(/CanonicalInvoice/Header/BankAccount)"/></NrRB>
                            </RachunekBankowy>
                        </xsl:if>
                    </Platnosc>
                </xsl:if>

                <!-- LINES -->
                <xsl:for-each select="/CanonicalInvoice/Lines/LineItem">
                    <FaWiersz>
                        <NrWierszaFa><xsl:value-of select="@Number"/></NrWierszaFa>
                        <P_7><xsl:value-of select="Product/Name"/></P_7>
                        <xsl:if test="normalize-space(Quantity/@Unit) != ''">
                            <P_8A><xsl:value-of select="normalize-space(Quantity/@Unit)"/></P_8A>
                        </xsl:if>
                        <xsl:if test="normalize-space(Product/SKU) != ''">
                            <Indeks><xsl:value-of select="normalize-space(Product/SKU)"/></Indeks>
                        </xsl:if>
                        <xsl:if test="normalize-space(Quantity) != ''">
                            <P_8B><xsl:value-of select="normalize-space(Quantity)"/></P_8B>
                        </xsl:if>
                        <xsl:if test="normalize-space(UnitPrice) != ''">
                            <P_9A><xsl:value-of select="normalize-space(UnitPrice)"/></P_9A>
                        </xsl:if>
                        <xsl:if test="normalize-space(DiscountAmount) != ''">
                            <P_10><xsl:value-of select="normalize-space(DiscountAmount)"/></P_10>
                        </xsl:if>
                        <P_11><xsl:value-of select="NetAmount"/></P_11>
                        <xsl:if test="normalize-space(Tax/Rate) != ''">
                            <P_12><xsl:value-of select="normalize-space(Tax/Rate)"/></P_12>
                        </xsl:if>
                    </FaWiersz>
                </xsl:for-each>

                <!-- SUMMARY (Rozliczenie) -->
                <xsl:if test="/CanonicalInvoice/Summary">
                    <Rozliczenie>
                        <xsl:choose>
                            <xsl:when test="/CanonicalInvoice/Summary/Taxes/Tax">
                                <StawkiPodatku>
                                    <xsl:for-each select="/CanonicalInvoice/Summary/Taxes/Tax">
                                        <StawkaPodatku>
                                            <KodStawki><xsl:value-of select="Rate"/></KodStawki>
                                            <PodstawaOpodatkowania><xsl:value-of select="NetAmount"/></PodstawaOpodatkowania>
                                            <KwotaPodatku><xsl:value-of select="TaxAmount"/></KwotaPodatku>
                                        </StawkaPodatku>
                                    </xsl:for-each>
                                </StawkiPodatku>
                            </xsl:when>
                            <xsl:otherwise>
                                <StawkiPodatku>
                                    <StawkaPodatku>
                                        <KodStawki>23</KodStawki> <!-- Fallback for incomplete Canonical model -->
                                        <PodstawaOpodatkowania><xsl:value-of select="/CanonicalInvoice/Summary/TotalNetAmount"/></PodstawaOpodatkowania>
                                        <KwotaPodatku><xsl:value-of select="/CanonicalInvoice/Summary/TotalTaxAmount"/></KwotaPodatku>
                                    </StawkaPodatku>
                                </StawkiPodatku>
                            </xsl:otherwise>
                        </xsl:choose>
                        <KwotaPodatkuNaleznego><xsl:value-of select="/CanonicalInvoice/Summary/TotalTaxAmount"/></KwotaPodatkuNaleznego>
                        <KwotaDoZaplaty><xsl:value-of select="/CanonicalInvoice/Summary/TotalGrossAmount"/></KwotaDoZaplaty>
                    </Rozliczenie>
                </xsl:if>
            </Fa>
        </Faktura>
    </xsl:template>
</xsl:stylesheet>
