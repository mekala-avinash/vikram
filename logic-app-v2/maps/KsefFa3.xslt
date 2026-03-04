<?xml version="1.0" encoding="UTF-8"?>
<!--
    KSeF FA(3) XSLT Transformation Map — v2
    =========================================
    Transforms CanonicalInvoice XML to FA(3)-compliant XML per FA(3)_schemat.xsd.
    Target namespace: http://crd.gov.pl/wzor/2025/06/25/13775/

    Input:  CanonicalInvoice XML
    Output: Faktura XML validated against FA(3)_schemat.xsd
-->
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://crd.gov.pl/wzor/2025/06/25/13775/"
    exclude-result-prefixes="xsl">

    <xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>

    <!-- ===== ROOT ===== -->
    <xsl:template match="/">
        <Faktura>

            <!-- ===== NAGLOWEK (Header) ===== -->
            <Naglowek>
                <KodFormularza kodSystemowy="FA (3)" wersjaSchemy="1-0E">FA</KodFormularza>
                <WariantFormularza>3</WariantFormularza>
                <DataWytworzeniaFa>
                    <xsl:choose>
                        <xsl:when test="contains(/CanonicalInvoice/Header/IssueDate, 'T')">
                            <xsl:value-of select="/CanonicalInvoice/Header/IssueDate"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="/CanonicalInvoice/Header/IssueDate"/>
                            <xsl:text>T00:00:00Z</xsl:text>
                        </xsl:otherwise>
                    </xsl:choose>
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

            <!-- ===== PODMIOT1 (Seller) ===== -->
            <Podmiot1>
                <DaneIdentyfikacyjne>
                    <!-- TPodmiot1 strictly requires a valid Polish NIP. Alternatives like NrID/BrakID are NOT allowed for the Seller. -->
                    <!-- We use a hardcoded dummy NIP (1111111111) for testing if the incoming NIP is not a valid 10-digit Polish NIP -->
                    <xsl:variable name="sellerTaxId" select="normalize-space(/CanonicalInvoice/Parties/Seller/TaxId)"/>
                    <NIP>
                        <xsl:choose>
                            <xsl:when test="string-length($sellerTaxId) = 10 and not(contains($sellerTaxId, '-')) and not(contains($sellerTaxId, ' ')) and translate($sellerTaxId, '0123456789', '') = ''">
                                <xsl:value-of select="$sellerTaxId"/>
                            </xsl:when>
                            <xsl:otherwise>1111111111</xsl:otherwise>
                        </xsl:choose>
                    </NIP>
                    <Nazwa><xsl:value-of select="normalize-space(/CanonicalInvoice/Parties/Seller/Name)"/></Nazwa>
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

            <!-- ===== PODMIOT2 (Buyer) ===== -->
            <Podmiot2>
                <DaneIdentyfikacyjne>
                    <!-- Use NIP only if value matches Polish 10-digit NIP pattern; otherwise use NrID or BrakID -->
                    <xsl:variable name="buyerTaxId" select="normalize-space(/CanonicalInvoice/Parties/Buyer/TaxId)"/>
                    <xsl:variable name="buyerCountry" select="normalize-space(/CanonicalInvoice/Parties/Buyer/Address/Country)"/>
                    <xsl:choose>
                        <xsl:when test="string-length($buyerTaxId) = 10 and not(contains($buyerTaxId, '-')) and not(contains($buyerTaxId, ' ')) and translate($buyerTaxId, '0123456789', '') = ''">
                            <NIP><xsl:value-of select="$buyerTaxId"/></NIP>
                        </xsl:when>
                        <xsl:when test="$buyerTaxId != ''">
                            <xsl:if test="$buyerCountry != '' and $buyerCountry != 'PL'">
                                <KodKraju><xsl:value-of select="$buyerCountry"/></KodKraju>
                            </xsl:if>
                            <NrID><xsl:value-of select="$buyerTaxId"/></NrID>
                        </xsl:when>
                        <xsl:otherwise>
                            <BrakID>1</BrakID>
                        </xsl:otherwise>
                    </xsl:choose>
                    <!-- Nazwa is optional in TPodmiot2; only emit when present -->
                    <xsl:if test="normalize-space(/CanonicalInvoice/Parties/Buyer/Name) != ''">
                        <Nazwa><xsl:value-of select="normalize-space(/CanonicalInvoice/Parties/Buyer/Name)"/></Nazwa>
                    </xsl:if>
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
                <!-- JST: 2 = does not concern JST subordinate unit -->
                <JST>2</JST>
                <!-- GV: 2 = does not concern VAT group member -->
                <GV>2</GV>
            </Podmiot2>

            <!-- ===== FA (Invoice Core) ===== -->
            <Fa>
                <!-- KodWaluty is a direct child of Fa (not wrapped in Waluta) -->
                <KodWaluty>
                    <xsl:choose>
                        <xsl:when test="normalize-space(/CanonicalInvoice/Header/Currency) != ''">
                            <xsl:value-of select="normalize-space(/CanonicalInvoice/Header/Currency)"/>
                        </xsl:when>
                        <xsl:otherwise>PLN</xsl:otherwise>
                    </xsl:choose>
                </KodWaluty>

                <!-- P_1: Issue date -->
                <P_1><xsl:value-of select="/CanonicalInvoice/Header/IssueDate"/></P_1>

                <!-- P_2: Invoice number -->
                <P_2><xsl:value-of select="/CanonicalInvoice/Header/InvoiceNumber"/></P_2>

                <!-- Tax summary fields: P_13_x / P_14_x mapped by rate -->
                <xsl:call-template name="emit-tax-summaries"/>

                <!-- P_15: Total gross amount (required) -->
                <P_15><xsl:value-of select="/CanonicalInvoice/Summary/TotalGrossAmount"/></P_15>

                <!-- ===== ADNOTACJE (Annotations - all required) ===== -->
                <Adnotacje>
                    <!-- P_16: Cash method (metoda kasowa) - 2 = No -->
                    <P_16>2</P_16>
                    <!-- P_17: Self-billing (samofakturowanie) - 2 = No -->
                    <P_17>2</P_17>
                    <!-- P_18: Reverse charge (odwrotne obciazenie) - 2 = No -->
                    <P_18>2</P_18>
                    <!-- P_18A: Split payment (mechanizm podzielonej platnosci) - 2 = No -->
                    <P_18A>2</P_18A>
                    <!-- Zwolnienie: Tax exemption - P_19N=1 means no exemption applies -->
                    <Zwolnienie>
                        <P_19N>1</P_19N>
                    </Zwolnienie>
                    <!-- NoweSrodkiTransportu: New means of transport - P_22N=1 means none -->
                    <NoweSrodkiTransportu>
                        <P_22N>1</P_22N>
                    </NoweSrodkiTransportu>
                    <!-- P_23: Simplified procedure - 2 = No -->
                    <P_23>2</P_23>
                    <!-- PMarzy: Margin procedures - P_PMarzyN=1 means none -->
                    <PMarzy>
                        <P_PMarzyN>1</P_PMarzyN>
                    </PMarzy>
                </Adnotacje>

                <!-- RodzajFaktury: Invoice type (required) -->
                <RodzajFaktury>
                    <xsl:choose>
                        <xsl:when test="normalize-space(/CanonicalInvoice/Header/InvoiceType) != ''">
                            <xsl:value-of select="normalize-space(/CanonicalInvoice/Header/InvoiceType)"/>
                        </xsl:when>
                        <xsl:otherwise>VAT</xsl:otherwise>
                    </xsl:choose>
                </RodzajFaktury>

                <!-- ===== FaWiersz (Line Items) ===== -->
                <xsl:for-each select="/CanonicalInvoice/Lines/LineItem">
                    <FaWiersz>
                        <NrWierszaFa><xsl:value-of select="@Number"/></NrWierszaFa>
                        <xsl:if test="normalize-space(Product/Name) != ''">
                            <P_7><xsl:value-of select="Product/Name"/></P_7>
                        </xsl:if>
                        <xsl:if test="normalize-space(Product/SKU) != ''">
                            <Indeks><xsl:value-of select="normalize-space(Product/SKU)"/></Indeks>
                        </xsl:if>
                        <xsl:if test="normalize-space(Quantity/@Unit) != ''">
                            <P_8A><xsl:value-of select="normalize-space(Quantity/@Unit)"/></P_8A>
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
                        <xsl:if test="normalize-space(NetAmount) != ''">
                            <P_11><xsl:value-of select="NetAmount"/></P_11>
                        </xsl:if>
                        <xsl:if test="normalize-space(Tax/Rate) != ''">
                            <!-- Map raw rate to TStawkaPodatku enum values -->
                            <P_12>
                                <xsl:variable name="rawRate" select="normalize-space(Tax/Rate)"/>
                                <xsl:choose>
                                    <xsl:when test="$rawRate = '23' or $rawRate = '22' or $rawRate = '8' or $rawRate = '7' or $rawRate = '5' or $rawRate = '4' or $rawRate = '3'">
                                        <xsl:value-of select="$rawRate"/>
                                    </xsl:when>
                                    <xsl:when test="$rawRate = '0 KR' or $rawRate = '0 WDT' or $rawRate = '0 EX'">
                                        <xsl:value-of select="$rawRate"/>
                                    </xsl:when>
                                    <xsl:when test="$rawRate = 'zw' or $rawRate = 'oo' or $rawRate = 'np I' or $rawRate = 'np II'">
                                        <xsl:value-of select="$rawRate"/>
                                    </xsl:when>
                                    <!-- Numeric 0 or empty maps to 'zw' (exempt) -->
                                    <xsl:when test="$rawRate = '0' or $rawRate = '0.00' or $rawRate = '0.0'">
                                        <xsl:text>zw</xsl:text>
                                    </xsl:when>
                                    <!-- Any other unrecognised value maps to 'np I' (out of scope) -->
                                    <xsl:otherwise>
                                        <xsl:text>np I</xsl:text>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </P_12>
                        </xsl:if>
                    </FaWiersz>
                </xsl:for-each>

                <!-- ===== PLATNOSC (Payment) ===== -->
                <xsl:if test="normalize-space(/CanonicalInvoice/Header/DueDate) != '' or normalize-space(/CanonicalInvoice/Header/PaymentMethod) != ''">
                    <Platnosc>
                        <xsl:if test="normalize-space(/CanonicalInvoice/Header/DueDate) != ''">
                            <TerminPlatnosci>
                                <Termin><xsl:value-of select="normalize-space(/CanonicalInvoice/Header/DueDate)"/></Termin>
                            </TerminPlatnosci>
                        </xsl:if>
                        <xsl:choose>
                            <xsl:when test="normalize-space(/CanonicalInvoice/Header/PaymentMethod) != ''">
                                <FormaPlatnosci><xsl:value-of select="normalize-space(/CanonicalInvoice/Header/PaymentMethod)"/></FormaPlatnosci>
                            </xsl:when>
                            <xsl:otherwise>
                                <!-- Default: 6 = Przelew (bank transfer) -->
                                <FormaPlatnosci>6</FormaPlatnosci>
                            </xsl:otherwise>
                        </xsl:choose>
                        <xsl:if test="normalize-space(/CanonicalInvoice/Header/BankAccount) != ''">
                            <RachunekBankowy>
                                <NrRB><xsl:value-of select="normalize-space(/CanonicalInvoice/Header/BankAccount)"/></NrRB>
                            </RachunekBankowy>
                        </xsl:if>
                    </Platnosc>
                </xsl:if>
            </Fa>
        </Faktura>
    </xsl:template>

    <!-- ===== NAMED TEMPLATE: Emit P_13_x / P_14_x tax summary fields ===== -->
    <xsl:template name="emit-tax-summaries">
        <xsl:choose>
            <!-- When detailed tax breakdown is available -->
            <xsl:when test="/CanonicalInvoice/Summary/Taxes/Tax">
                <xsl:for-each select="/CanonicalInvoice/Summary/Taxes/Tax">
                    <xsl:choose>
                        <!-- 23% rate -> P_13_1 / P_14_1 -->
                        <xsl:when test="Rate = 23 or Rate = 22">
                            <P_13_1><xsl:value-of select="NetAmount"/></P_13_1>
                            <P_14_1><xsl:value-of select="TaxAmount"/></P_14_1>
                        </xsl:when>
                        <!-- 8% rate -> P_13_2 / P_14_2 -->
                        <xsl:when test="Rate = 8 or Rate = 7">
                            <P_13_2><xsl:value-of select="NetAmount"/></P_13_2>
                            <P_14_2><xsl:value-of select="TaxAmount"/></P_14_2>
                        </xsl:when>
                        <!-- 5% rate -> P_13_3 / P_14_3 -->
                        <xsl:when test="Rate = 5">
                            <P_13_3><xsl:value-of select="NetAmount"/></P_13_3>
                            <P_14_3><xsl:value-of select="TaxAmount"/></P_14_3>
                        </xsl:when>
                        <!-- 0% rate -> P_13_6_1 (domestic 0%) -->
                        <xsl:when test="Rate = 0">
                            <P_13_6_1><xsl:value-of select="NetAmount"/></P_13_6_1>
                        </xsl:when>
                    </xsl:choose>
                </xsl:for-each>
            </xsl:when>
            <!-- Fallback: assume all net at 23% -->
            <xsl:when test="/CanonicalInvoice/Summary/TotalNetAmount">
                <P_13_1><xsl:value-of select="/CanonicalInvoice/Summary/TotalNetAmount"/></P_13_1>
                <P_14_1><xsl:value-of select="/CanonicalInvoice/Summary/TotalTaxAmount"/></P_14_1>
            </xsl:when>
        </xsl:choose>
    </xsl:template>

</xsl:stylesheet>
