<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    
    <!-- 
        XSLT Transformation Template: Canonical XML to FA(3) Format
        
        This is a PLACEHOLDER template. You need to customize this based on:
        1. Your canonical XML schema
        2. The FA(3) standard format specification
        3. Your specific mapping requirements
        
        Example transformation structure provided below.
    -->
    
    <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
    
    <!-- Root template -->
    <xsl:template match="/">
        <FA3Document>
            <xsl:apply-templates select="CanonicalData"/>
        </FA3Document>
    </xsl:template>
    
    <!-- Main data transformation -->
    <xsl:template match="CanonicalData">
        <Header>
            <MessageID><xsl:value-of select="@id"/></MessageID>
            <Timestamp><xsl:value-of select="@timestamp"/></Timestamp>
            <Version>3.0</Version>
        </Header>
        
        <Body>
            <!-- 
                TODO: Map your canonical XML fields to FA(3) format
                
                Example mapping:
                <Field1><xsl:value-of select="SourceField1"/></Field1>
                <Field2><xsl:value-of select="SourceField2"/></Field2>
            -->
            
            <xsl:apply-templates select="*"/>
        </Body>
    </xsl:template>
    
    <!-- Default template for unmapped elements -->
    <xsl:template match="*">
        <xsl:element name="{local-name()}">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:element>
    </xsl:template>
    
    <!-- Copy attributes -->
    <xsl:template match="@*">
        <xsl:attribute name="{local-name()}">
            <xsl:value-of select="."/>
        </xsl:attribute>
    </xsl:template>
    
</xsl:stylesheet>
