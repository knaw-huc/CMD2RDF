<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    xmlns:cmd0="http://www.clarin.eu/cmd/"
    xmlns:cmd1="http://www.clarin.eu/cmd/1"
    xmlns:vlo="http://www.clarin.eu/vlo/"
    xmlns:dc="http://purl.org/dc/terms/"
    xmlns:fabio="http://purl.org/spar/fabio/"
    xmlns:datacite="http://purl.org/spar/datacite/"
    xmlns:silvio="http://www.essepuntato.it/2010/06/literalreification/"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:foaf="http://xmlns.com/foaf/0.1/"
    xmlns:frapo="http://purl.org/cerif/frapo/"
    xmlns:ost="https://ostrails.eu/"
    exclude-result-prefixes="xs math ost"
    version="3.0">
    
    <xsl:output method="xml" indent="yes" />
    
    <xsl:param name="base" select="if (exists(/*/@xml:base)) then (/*/@xml:base) else (base-uri())"/>

    <!-- allow to rewrite the urls -->
    <xsl:param name="base_strip" select="'/Users/listj/Clarin.Data/TI_Total/'"/>
    <xsl:param name="base_add" select="''"/>

    <!-- SKG-IF base URI for organisation entities -->
    <xsl:param name="skg-base" select="'https://w3id.org/skg-if/sandbox/my-skg-acronym/'"/>
    
    <xsl:variable name="about" select="replace(if ($base_strip=$base) then $base else for $strip in tokenize($base_strip,',') return if (starts-with($base,concat('file:',$strip))) then replace($base, concat('file:',$strip), $base_add) else (),'([./])(xml|cmdi)$','$1rdf')"/>

    <!-- Slugify function: convert name to lowercase identifier with underscores -->
    <xsl:function name="ost:slugify" as="xs:string">
        <xsl:param name="text" as="xs:string"/>
        <xsl:sequence select="lower-case(replace(normalize-space($text), '\s+', '_'))"/>
    </xsl:function>

    <xsl:template match="/cmd0:CMD|/cmd1:CMD">
        <xsl:message expand-text="yes">DBG: base[{$base}]</xsl:message>

        <!-- Extract organisation facet values (available from addVLOFacets.xsl) -->
        <xsl:variable name="orgs" select="distinct-values(vlo:hasFacetOrganisation[normalize-space(.)!=''])"/>

        <!-- Extract provider : try MdCollectionDisplayName first, fall back to repository from path -->
        <xsl:variable name="provider">
            <xsl:choose>
                <xsl:when test="normalize-space(/cmd0:CMD/cmd0:Header/cmd0:MdCollectionDisplayName | /cmd1:CMD/cmd1:Header/cmd1:MdCollectionDisplayName) != ''">
                    <xsl:value-of select="normalize-space(/cmd0:CMD/cmd0:Header/cmd0:MdCollectionDisplayName | /cmd1:CMD/cmd1:Header/cmd1:MdCollectionDisplayName)"/>
                </xsl:when>
                <xsl:otherwise>
                    <!-- Fall back to repository name from file path -->
                    <xsl:value-of select="replace($about,'^.*/([^/]*)/[^/]*$','$1')"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <xsl:copy>
            <xsl:apply-templates select="@*"/>
            <OST>
                <fabio:Dataset rdf:about="{$about}"/>
                <fabio:Work rdf:about="{$about}">
                    <xsl:variable name="pid" select="normalize-space(/cmd0:CMD/cmd0:Header/cmd0:MdSelfLink|/cmd1:CMD/cmd1:Header/cmd1:MdSelfLink)"/>
                    <xsl:if test="$pid!=''">
                        <datacite:hasIdentifier>
                            <datacite:Identifier>
                                <xsl:choose>
                                    <xsl:when test="starts-with($pid,'https://hdl.handle.net/')">
                                        <datacite:usesIdentifierScheme rdf:resource="http://purl.org/spar/datacite/handle"/>
                                    </xsl:when>
                                    <!--TODO: check all PID scheme types -->
                                </xsl:choose>
                                <silvio:hasLiteralValue>
                                    <xsl:value-of select="$pid"/>
                                </silvio:hasLiteralValue>
                            </datacite:Identifier>
                        </datacite:hasIdentifier>
                    </xsl:if>
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
                    <!-- Link to organisations (relevant_organisations in SKG-IF) -->
                    <xsl:for-each select="$orgs">
                        <dc:relation rdf:resource="{concat($skg-base, ost:slugify(.))}"/>
                    </xsl:for-each>
                    <xsl:if test="normalize-space($provider) != ''">
                        <dc:relation rdf:resource="{concat($skg-base, ost:slugify($provider))}"/>
                    </xsl:if>
                </fabio:Work>

                <!-- Organisation entities from facet (type: research) -->
                <xsl:for-each select="$orgs">
                    <foaf:Organization rdf:about="{concat($skg-base, ost:slugify(.))}">
                        <foaf:name><xsl:value-of select="."/></foaf:name>
                        <rdf:type rdf:resource="http://purl.org/cerif/frapo/ResearchInstitute"/>
                    </foaf:Organization>
                </xsl:for-each>

                <!-- Provider organisation (type: archive) -->
                <xsl:if test="normalize-space($provider) != ''">
                    <foaf:Organization rdf:about="{concat($skg-base, ost:slugify($provider))}">
                        <foaf:name><xsl:value-of select="$provider"/></foaf:name>
                        <rdf:type rdf:resource="http://purl.org/cerif/frapo/Repository"/>
                    </foaf:Organization>
                </xsl:if>
            </OST>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
    
    
</xsl:stylesheet>
