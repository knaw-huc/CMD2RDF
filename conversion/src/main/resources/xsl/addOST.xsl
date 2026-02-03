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
    xmlns:literal="http://www.essepuntato.it/2010/06/literalreification/"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:foaf="http://xmlns.com/foaf/0.1/"
    xmlns:frbr="http://purl.org/vocab/frbr/core#"
    xmlns:prism="http://prismstandard.org/namespaces/basic/2.0/"
    xmlns:pso="http://purl.org/spar/pso/"
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

        <!-- Extract VLO facet values -->
        <xsl:variable name="orgs" select="distinct-values(vlo:hasFacetOrganisation[normalize-space(.)!=''])"/>
        <xsl:variable name="formats" select="distinct-values(vlo:hasFacetFormat[normalize-space(.)!=''])"/>
        <xsl:variable name="licenses" select="distinct-values(vlo:hasFacetLicense[normalize-space(.)!=''])"/>
        <xsl:variable name="availability" select="distinct-values(vlo:hasFacetAvailability[normalize-space(.)!=''])"/>
        <xsl:variable name="resourceClasses" select="distinct-values(vlo:hasFacetResourceClass[normalize-space(.)!=''])"/>
        <xsl:variable name="mediaTypes" select="distinct-values(vlo:hasFacetMediaType[normalize-space(.)!=''])"/>
        <xsl:variable name="versions" select="distinct-values(vlo:hasFacetVersion[normalize-space(.)!=''])"/>
        <xsl:variable name="distributionMedium" select="distinct-values(vlo:hasFacetDistributionMedium[normalize-space(.)!=''])"/>

        <!-- Extract provider: try MdCollectionDisplayName first, fall back to repository from path -->
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

        <!-- Extract ResourceProxy elements for manifestations -->
        <xsl:variable name="resources" select=".//cmd0:ResourceProxy|.//cmd1:ResourceProxy"/>

        <xsl:copy>
            <xsl:apply-templates select="@*"/>
            <OST>
                <fabio:Dataset rdf:about="{$about}"/>
                <fabio:Work rdf:about="{$about}">
                    <!-- PID (Handle, DOI, etc.) -->
                    <xsl:variable name="pid" select="normalize-space(/cmd0:CMD/cmd0:Header/cmd0:MdSelfLink|/cmd1:CMD/cmd1:Header/cmd1:MdSelfLink)"/>
                    <xsl:if test="$pid!=''">
                        <datacite:hasIdentifier>
                            <datacite:Identifier>
                                <xsl:choose>
                                    <xsl:when test="starts-with($pid,'https://hdl.handle.net/')">
                                        <datacite:usesIdentifierScheme rdf:resource="http://purl.org/spar/datacite/handle"/>
                                    </xsl:when>
                                    <xsl:when test="starts-with($pid,'http://hdl.handle.net/')">
                                        <datacite:usesIdentifierScheme rdf:resource="http://purl.org/spar/datacite/handle"/>
                                    </xsl:when>
                                    <xsl:when test="starts-with($pid,'https://doi.org/') or starts-with($pid,'http://dx.doi.org/')">
                                        <datacite:usesIdentifierScheme rdf:resource="http://purl.org/spar/datacite/doi"/>
                                    </xsl:when>
                                </xsl:choose>
                                <literal:hasLiteralValue>
                                    <xsl:value-of select="$pid"/>
                                </literal:hasLiteralValue>
                            </datacite:Identifier>
                        </datacite:hasIdentifier>
                    </xsl:if>

                    <!-- Description from VLO facet -->
                    <xsl:if test="normalize-space(vlo:hasFacetDescription)!=''">
                        <dc:abstract>
                            <xsl:value-of select="normalize-space(vlo:hasFacetDescription)"/>
                        </dc:abstract>
                    </xsl:if>

                    <!-- Title from VLO facet -->
                    <xsl:if test="normalize-space(vlo:hasFacetName)!=''">
                        <dc:title>
                            <xsl:value-of select="normalize-space(vlo:hasFacetName)"/>
                        </dc:title>
                    </xsl:if>

                    <!-- Link to manifestations via FRBR chain: Work → Expression → Manifestation (embodiment?) -->
                    <xsl:for-each select="$resources">
                        <frbr:realization>
                            <fabio:Expression rdf:about="{concat($about, '#expression-', position())}">
                                <frbr:embodiment rdf:resource="{concat($about, '#manifestation-', position())}"/>
                            </fabio:Expression>
                        </frbr:realization>
                    </xsl:for-each>

                    <!-- Link to organisations (relevant_organisations in SKG-IF) -->
                    <xsl:for-each select="$orgs">
                        <dc:relation rdf:resource="{concat($skg-base, ost:slugify(.))}"/>
                    </xsl:for-each>
                </fabio:Work>

                <!-- Create manifestation entities -->
                <xsl:for-each select="$resources">
                    <xsl:variable name="position" select="position()"/>
                    <xsl:variable name="manifestation-id" select="concat($about, '#manifestation-', $position)"/>
                    <xsl:variable name="resourceRef" select="normalize-space(cmd0:ResourceRef|cmd1:ResourceRef)"/>
                    <xsl:variable name="resourceType" select="normalize-space(cmd0:ResourceType/text()|cmd1:ResourceType/text())"/>
                    <xsl:variable name="mimeType" select="normalize-space(cmd0:ResourceType/@mimetype|cmd1:ResourceType/@mimetype)"/>

                    <fabio:Manifestation rdf:about="{$manifestation-id}">
                        <!-- Type classification based on resourceType, see https://office.clarin.eu/v/CE-2016-0880-CMDI_12_specification.pdf, 2.3.1 -->
                        <xsl:choose>
                            <xsl:when test="lower-case($resourceType) = 'resource'">
                                <rdf:type rdf:resource="http://purl.org/spar/fabio/DigitalManifestation"/>
                            </xsl:when>
                            <xsl:when test="lower-case($resourceType) = 'metadata'">
                                <rdf:type rdf:resource="http://purl.org/spar/fabio/MetadataDocument"/>
                            </xsl:when>
                            <xsl:when test="lower-case($resourceType) = 'searchpage'">
                                <rdf:type rdf:resource="http://purl.org/spar/fabio/WebPage"/>
                            </xsl:when>
                            <xsl:when test="lower-case($resourceType) = 'searchservice'">
                                <rdf:type rdf:resource="http://purl.org/spar/fabio/WebService"/>
                            </xsl:when>
                            <xsl:when test="lower-case($resourceType) = 'landingpage'">
                                <rdf:type rdf:resource="http://purl.org/spar/fabio/WebPage"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <rdf:type rdf:resource="http://purl.org/spar/fabio/DigitalManifestation"/>
                            </xsl:otherwise>
                        </xsl:choose>

                        <!-- Identifier with scheme (URL) -->
                        <xsl:if test="$resourceRef != ''">
                            <datacite:hasIdentifier>
                                <datacite:Identifier>
                                    <datacite:usesIdentifierScheme rdf:resource="http://purl.org/spar/datacite/url"/>
                                    <literal:hasLiteralValue>
                                        <xsl:value-of select="$resourceRef"/>
                                    </literal:hasLiteralValue>
                                </datacite:Identifier>
                            </datacite:hasIdentifier>
                        </xsl:if>

                        <!-- Format/media type from mimetype attribute -->
                        <xsl:if test="$mimeType != ''">
                            <dc:format>
                                <xsl:value-of select="$mimeType"/>
                            </dc:format>
                        </xsl:if>

                        <!-- License from VLO facets -->
                        <xsl:for-each select="$licenses">
                            <xsl:choose>
                                <!-- If it looks like a URL, use rdf:resource -->
                                <xsl:when test="starts-with(., 'http://') or starts-with(., 'https://')">
                                    <dc:license rdf:resource="{.}"/>
                                </xsl:when>
                                <!-- Otherwise use literal value -->
                                <xsl:otherwise>
                                    <dc:license>
                                        <xsl:value-of select="."/>
                                    </dc:license>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:for-each>

                        <!-- Access Rights using PSO vocabulary -->
                        <xsl:for-each select="$availability">
                            <xsl:choose>
                                <xsl:when test="lower-case(.) = 'pub' or lower-case(.) = 'open' or lower-case(.) = 'public'">
                                    <pso:holdsStatusInTime>
                                        <pso:StatusInTime>
                                            <pso:withStatus rdf:resource="http://purl.org/spar/pso/open-access"/>
                                        </pso:StatusInTime>
                                    </pso:holdsStatusInTime>
                                </xsl:when>
                                <xsl:when test="lower-case(.) = 'aca' or lower-case(.) = 'academic' or lower-case(.) = 'restricted'">
                                    <pso:holdsStatusInTime>
                                        <pso:StatusInTime>
                                            <pso:withStatus rdf:resource="http://purl.org/spar/pso/restricted-access"/>
                                            <rdfs:comment>Academic/Restricted access</rdfs:comment>
                                        </pso:StatusInTime>
                                    </pso:holdsStatusInTime>
                                </xsl:when>
                                <xsl:when test="lower-case(.) = 'res' or lower-case(.) = 'closed'">
                                    <pso:holdsStatusInTime>
                                        <pso:StatusInTime>
                                            <pso:withStatus rdf:resource="http://purl.org/spar/pso/closed-access"/>
                                        </pso:StatusInTime>
                                    </pso:holdsStatusInTime>
                                </xsl:when>
                                <xsl:otherwise>
                                    <!-- Fallback: keep as literal comment -->
                                    <pso:holdsStatusInTime>
                                        <pso:StatusInTime>
                                            <rdfs:comment><xsl:value-of select="."/></rdfs:comment>
                                        </pso:StatusInTime>
                                    </pso:holdsStatusInTime>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:for-each>

                        <!-- Version, mapped to PRISM versionIdentifier -->
                        <xsl:for-each select="$versions">
                            <prism:versionIdentifier>
                                <xsl:value-of select="."/>
                            </prism:versionIdentifier>
                        </xsl:for-each>

                        <!-- Resource type label for reference -->
                        <xsl:if test="$resourceType != ''">
                            <rdfs:label>
                                <xsl:value-of select="$resourceType"/>
                            </rdfs:label>
                        </xsl:if>
                    </fabio:Manifestation>
                </xsl:for-each>

                <!-- Organisation entities from facet (type: research) -->
                <xsl:for-each select="$orgs">
                    <foaf:Organization rdf:about="{concat($skg-base, ost:slugify(.))}">
                        <foaf:name><xsl:value-of select="."/></foaf:name>
                        <rdf:type rdf:resource="http://purl.org/cerif/frapo/ResearchInstitute"/>
                    </foaf:Organization>
                </xsl:for-each>

                <!-- Provider organisation (type: archive/repository) -->
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