<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    xmlns:cmd0="http://www.clarin.eu/cmd/" xmlns:cmd1="http://www.clarin.eu/cmd/1" xmlns:vlo="http://www.clarin.eu/vlo/"
    xmlns:dc="http://purl.org/dc/terms/"
    xmlns:fabio="http://purl.org/spar/fabio/"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    exclude-result-prefixes="xs math"
    version="3.0">
    
    <xsl:param name="base" select="if (exists(/*/@xml:base)) then (/*/@xml:base) else (base-uri())"/>
    
    <!-- allow to rewrite the urls -->
    <xsl:param name="base_strip" select="'/Users/menzowi/Documents/GitHub/CMD2RDF-OST/OST/'"/>
    <xsl:param name="base_add" select="''"/>
    
    <xsl:variable name="about" select="replace(if ($base_strip=$base) then $base else for $strip in tokenize($base_strip,',') return if (starts-with($base,concat('file:',$strip))) then replace($base, concat('file:',$strip), $base_add) else (),'([./])(xml|cmdi)$','$1rdf')"/>
    
    <xsl:template match="/cmd0:CMD|/cmd1:CMD">
        <xsl:message expand-text="yes">DBG: base[{$base}]</xsl:message>
        <xsl:copy>
            <OST>
                <fabio:Dataset rdf:about="{$about}"/>
                <fabio:Work rdf:about="{$about}">
                    <xsl:if test="normalize-space(vlo:hasFacetDescription)!=''">
                        <dc:abstract>
                            <xsl:value-of select="normalize-space(vlo:hasFacetDescription)"/>
                        </dc:abstract>
                    </xsl:if>
                    <xsl:if test="normalize-space(vlo:hasFacetName )!=''">
                        <dc:title>
                            <xsl:value-of select="normalize-space(vlo:hasFacetName )"/>
                        </dc:title>
                    </xsl:if>
                </fabio:Work>
            </OST>
        </xsl:copy>
    </xsl:template>
    
</xsl:stylesheet>