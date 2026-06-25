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
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:foaf="http://xmlns.com/foaf/0.1/"
    xmlns:frbr="http://purl.org/vocab/frbr/core#"
    xmlns:prism="http://prismstandard.org/namespaces/basic/2.0/"
    xmlns:pso="http://purl.org/spar/pso/"
    xmlns:dcat="http://www.w3.org/ns/dcat#"
    xmlns:schema="https://schema.org/"
    xmlns:srv="https://w3id.org/skg-if/extension/srv/ontology/"
    xmlns:ost="https://ostrails.eu/"
    exclude-result-prefixes="xs math ost"
    version="3.0">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="base" select="if (exists(/*/@xml:base)) then (/*/@xml:base) else (base-uri())"/>

    <!-- allow to rewrite the urls -->
    <xsl:param name="base_strip" select="'/Users/listj/Clarin.Data/TI_Total/'"/>
    <xsl:param name="base_add" select="''"/>

    <!-- SKG-IF base URI for organisation entities -->
    <xsl:param name="skg-base" select="'otf:'"/>

    <xsl:variable name="about" select="replace(if ($base_strip=$base) then $base else for $strip in tokenize($base_strip,',') return if (starts-with($base,concat('file:',$strip))) then replace($base, concat('file:',$strip), $base_add) else (),'([./])(xml|cmdi)$','$1rdf')"/>

    <!-- Slugify function: replaces any run of non-letter/non-digit characters with _ and strips leading/trailing underscores -->
    <xsl:function name="ost:slugify" as="xs:string">
        <xsl:param name="text" as="xs:string"/>
        <xsl:sequence select="lower-case(replace(replace(normalize-space($text), '[^\p{L}\p{N}]+', '_'), '^_|_$', ''))"/>
    </xsl:function>

    <xsl:template match="/cmd0:CMD|/cmd1:CMD">
        <!--<xsl:message expand-text="yes">DBG: base[{$base}]</xsl:message>-->

        <!-- Extract VLO facet values -->
        <xsl:variable name="orgs" select="distinct-values(vlo:hasFacetOrganisation[normalize-space(.)!=''])"/>
        <xsl:variable name="creators" select="distinct-values(vlo:hasFacetCreator[normalize-space(.)!=''])"/>
        <xsl:variable name="formats" select="distinct-values(vlo:hasFacetFormat[normalize-space(.)!=''])"/>
        <xsl:variable name="licenses" select="distinct-values(vlo:hasFacetLicense[normalize-space(.)!=''])"/>
        <xsl:variable name="licenseTypes" select="distinct-values(vlo:hasFacetLicenseType[normalize-space(.)!=''])"/>
        <xsl:variable name="availability" select="distinct-values(vlo:hasFacetAvailability[normalize-space(.)!=''])"/>
        <xsl:variable name="versions" select="distinct-values(vlo:hasFacetVersion[normalize-space(.)!=''])"/>
        <xsl:variable name="descriptions" select="vlo:hasFacetDescription[normalize-space(.)!='']" />
        <xsl:variable name="titles" select="vlo:hasFacetName[normalize-space(.)!='']" />
        
        <!-- Extract provider : try the VLO 'collection' facet first, fall back to repository from path -->
        <xsl:variable name="provider">
            <xsl:choose>
                <xsl:when test="vlo:hasFacetCollection[normalize-space(.)!='']">
                    <xsl:value-of select="normalize-space((vlo:hasFacetCollection[normalize-space(.)!=''])[1])"/>
                </xsl:when>
                <xsl:otherwise>
                    <!-- Fall back to repository name from file path -->
                    <xsl:value-of select="replace($about,'^.*/([^/]*)/[^/]*$','$1')"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <!-- WebLicht profile records describe a tool/web service rather than a dataset -->
        <xsl:variable name="isWebLicht" select="contains(normalize-space(string-join((/cmd0:CMD/cmd0:Header/cmd0:MdProfile,/cmd1:CMD/cmd1:Header/cmd1:MdProfile),' ')), 'clarin.eu:cr1:p_1320657629644')"/>

        <xsl:copy>
            <!-- This copy preserves the attributes on the root cmd0:CMD / cmd1:CMD element — most importantly @xml:base, also used further downstream to compute the about -->
            <xsl:copy-of select="@*"/>
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
                                <silvio:hasLiteralValue>
                                    <xsl:value-of select="$pid"/>
                                </silvio:hasLiteralValue>
                            </datacite:Identifier>
                        </datacite:hasIdentifier>
                    </xsl:if>
                    
                    <!-- Descriptions from VLO facets -->
                    <xsl:for-each select="$descriptions">
                        <dc:abstract><xsl:value-of select="." /></dc:abstract>
                    </xsl:for-each>
                    
                    <!-- Titles from VLO facet -->
                    <xsl:for-each select="$titles">
                        <dc:title><xsl:value-of select="."/></dc:title>
                    </xsl:for-each>
                 
                    <!-- Link to single VLO-facet-based manifestation via FRBR chain -->
                    <frbr:realization>
                        <fabio:Expression rdf:about="{concat($about, '#expression')}">
                            <frbr:embodiment rdf:resource="{concat($about, '#manifestation')}"/>
                        </fabio:Expression>
                    </frbr:realization>

                    <!-- Link to organisations (relevant_organisations in SKG-IF) -->
                    <xsl:for-each select="$orgs">
                        <dc:relation rdf:resource="{concat($skg-base, ost:slugify(.))}"/>
                    </xsl:for-each>

                    <!-- Link to creators (contributions / persons in SKG-IF) -->
                    <xsl:for-each select="$creators">
                        <dc:creator rdf:resource="{concat($skg-base, ost:slugify(.))}"/>
                    </xsl:for-each>
                </fabio:Work>

                <!-- Single manifestation derived from VLO facets (availability, license, licenseType, format) -->
                <!-- The var accessTokens creates a flat deduplicated set of lowercase words from 2 VLO facets variables: availability/licenseTypes -->
                <!-- The result is something like: ("free", "if", "you", "are", "a", "scientist", "...", "aca", "bas:brothers") -->
                <!-- This is then used in the xsl:choose below as a sequence, where $accessTokens = ('aca', 'academic', 'restricted') -->
                <!-- is an XPath existential test — true if any token in $accessTokens equals any of those values. -->
                <!-- That's how "aca" buried inside a long concatenated string gets matched. -->
                <xsl:variable name="accessTokens" select="
                    distinct-values((
                        for $av in ($availability, $licenses, $licenseTypes)
                            return tokenize(lower-case(normalize-space($av)), '\s+')
                    ))"/>

                <fabio:Manifestation rdf:about="{concat($about, '#manifestation')}">

                    <!-- Hosting data source (SKG-IF hosting_data_source) -->
                    <xsl:if test="normalize-space($provider) != ''">
                        <dcat:accessService rdf:resource="{concat($skg-base, ost:slugify($provider))}"/>
                    </xsl:if>

                    <!-- Format(s) from VLO hasFacetFormat -->
                    <xsl:for-each select="$formats">
                        <dc:format><xsl:value-of select="."/></dc:format>
                    </xsl:for-each>

                    <!-- License from VLO hasFacetLicense -->
                    <xsl:for-each select="$licenses">
                        <xsl:choose>
                            <xsl:when test="starts-with(., 'http://') or starts-with(., 'https://')">
                                <dc:license rdf:resource="{.}"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <dc:license><xsl:value-of select="."/></dc:license>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each>

                    <!-- License type from VLO hasFacetLicenseType -->
                    <xsl:for-each select="$licenseTypes">
                        <xsl:choose>
                            <xsl:when test="starts-with(., 'http://') or starts-with(., 'https://')">
                                <dc:license rdf:resource="{.}"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <dc:license><xsl:value-of select="."/></dc:license>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each>

                    <!-- Access rights from VLO availability, license and licenseType. VLO concatenates multiple -->
                    <!-- availability values into one element, so we tokenize and pick the most -->
                    <!-- restrictive keyword (RES > ACA > PUB). -->
                    <xsl:choose>
                        <xsl:when test="$accessTokens = ('res', 'closed')">
                            <pso:holdsStatusInTime>
                                <pso:StatusInTime>
                                    <pso:withStatus rdf:resource="http://purl.org/spar/pso/closed-access"/>
                                </pso:StatusInTime>
                            </pso:holdsStatusInTime>
                        </xsl:when>
                        <xsl:when test="$accessTokens = ('aca', 'academic', 'restricted')">
                            <pso:holdsStatusInTime>
                                <pso:StatusInTime>
                                    <pso:withStatus rdf:resource="http://purl.org/spar/pso/restricted-access"/>
                                    <rdfs:comment>Academic/Restricted access</rdfs:comment>
                                </pso:StatusInTime>
                            </pso:holdsStatusInTime>
                        </xsl:when>
                        <xsl:when test="$accessTokens = ('pub', 'open', 'public')">
                            <pso:holdsStatusInTime>
                                <pso:StatusInTime>
                                    <pso:withStatus rdf:resource="http://purl.org/spar/pso/open-access"/>
                                </pso:StatusInTime>
                            </pso:holdsStatusInTime>
                        </xsl:when>
                        <xsl:when test="exists($availability)">
                            <!-- Fallback: raw availability text as comment -->
                            <pso:holdsStatusInTime>
                                <pso:StatusInTime>
                                    <rdfs:comment><xsl:value-of select="string-join($availability, '; ')"/></rdfs:comment>
                                </pso:StatusInTime>
                            </pso:holdsStatusInTime>
                        </xsl:when>
                    </xsl:choose>

                    <!-- Version from VLO hasFacetVersion -->
                    <xsl:for-each select="$versions">
                        <prism:versionIdentifier><xsl:value-of select="."/></prism:versionIdentifier>
                    </xsl:for-each>
                </fabio:Manifestation>

                <!-- Organisation entities from facet (type: research) -->
                <xsl:for-each select="$orgs">
                    <foaf:Organization rdf:about="{concat($skg-base, ost:slugify(.))}">
                        <foaf:name><xsl:value-of select="."/></foaf:name>
                        <rdf:type rdf:resource="http://purl.org/cerif/frapo/ResearchInstitute"/>
                    </foaf:Organization>
                </xsl:for-each>

                <!-- Person entities from creator facet (type: person) -->
                <!-- VLO supplies names as "Family, Given"; split on the first comma. -->
                <!-- When no comma is present we cannot reliably split, so emit foaf:name only. -->
                <xsl:for-each select="$creators">
                    <foaf:Person rdf:about="{concat($skg-base, ost:slugify(.))}">
                        <foaf:name><xsl:value-of select="."/></foaf:name>
                        <xsl:if test="contains(., ',')">
                            <foaf:familyName><xsl:value-of select="normalize-space(substring-before(., ','))"/></foaf:familyName>
                            <foaf:givenName><xsl:value-of select="normalize-space(substring-after(., ','))"/></foaf:givenName>
                        </xsl:if>
                    </foaf:Person>
                </xsl:for-each>

                <!-- Provider as data source (SKG-IF data source = dcat:DataService), classified as a repository -->
                <xsl:if test="normalize-space($provider) != ''">
                    <dcat:DataService rdf:about="{concat($skg-base, ost:slugify($provider))}">
                        <foaf:name><xsl:value-of select="$provider"/></foaf:name>
                        <rdf:type rdf:resource="http://purl.org/cerif/frapo/Repository"/>
                    </dcat:DataService>
                </xsl:if>

                <!-- SKG-IF Service entity: emitted in addition to the dataset Work/Manifestation for -->
                <!-- records on the WebLicht profile (clarin.eu:cr1:p_1320657629644). Mapped onto the -->
                <!-- SKG-IF service extension ontology (https://w3id.org/skg-if/extension/srv/ontology/). -->
                <!-- srv:Service is a subclass of schema:SoftwareApplication. -->
                <xsl:if test="$isWebLicht">
                    <srv:Service rdf:about="{concat($about, '#service')}">

                        <!-- name (foaf:name) -->
                        <xsl:for-each select="$titles">
                            <foaf:name><xsl:value-of select="."/></foaf:name>
                        </xsl:for-each>

                        <!-- description (dcterms:description) -->
                        <xsl:for-each select="$descriptions">
                            <dc:description><xsl:value-of select="."/></dc:description>
                        </xsl:for-each>

                        <!-- identifiers (datacite:hasIdentifier) -->
                        <xsl:variable name="pid" select="normalize-space(/cmd0:CMD/cmd0:Header/cmd0:MdSelfLink|/cmd1:CMD/cmd1:Header/cmd1:MdSelfLink)"/>
                        <xsl:if test="$pid!=''">
                            <datacite:hasIdentifier>
                                <datacite:Identifier>
                                    <xsl:choose>
                                        <xsl:when test="starts-with($pid,'https://hdl.handle.net/') or starts-with($pid,'http://hdl.handle.net/')">
                                            <datacite:usesIdentifierScheme rdf:resource="http://purl.org/spar/datacite/handle"/>
                                        </xsl:when>
                                        <xsl:when test="starts-with($pid,'https://doi.org/') or starts-with($pid,'http://dx.doi.org/')">
                                            <datacite:usesIdentifierScheme rdf:resource="http://purl.org/spar/datacite/doi"/>
                                        </xsl:when>
                                    </xsl:choose>
                                    <silvio:hasLiteralValue><xsl:value-of select="$pid"/></silvio:hasLiteralValue>
                                </datacite:Identifier>
                            </datacite:hasIdentifier>
                        </xsl:if>

                        <!-- hosting organisation (srv:hasHostingOrganisation): the provider derived above -->
                        <xsl:if test="normalize-space($provider) != ''">
                            <srv:hasHostingOrganisation rdf:resource="{concat($skg-base, ost:slugify($provider))}"/>
                        </xsl:if>

                        <!-- relevant organisations (dcterms:relation) -->
                        <xsl:for-each select="$orgs">
                            <dc:relation rdf:resource="{concat($skg-base, ost:slugify(.))}"/>
                        </xsl:for-each>

                        <!-- API profile (dcterms:conformsTo): e.g. WADL media type. -->
                        <!-- NB: the WADL endpoint URL lives in the VLO _resourceRef field, which addVLOFacets -->
                        <!-- skips, so only the media type is available here. -->
                        <xsl:for-each select="$formats">
                            <dc:conformsTo><xsl:value-of select="."/></dc:conformsTo>
                        </xsl:for-each>

                        <!-- License: not part of the srv extension, retained as plain DCTerms. -->
                        <xsl:for-each select="$licenses">
                            <xsl:choose>
                                <xsl:when test="starts-with(., 'http://') or starts-with(., 'https://')">
                                    <dc:license rdf:resource="{.}"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <dc:license><xsl:value-of select="."/></dc:license>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:for-each>

                        <xsl:for-each select="$licenseTypes">
                            <xsl:choose>
                                <xsl:when test="starts-with(., 'http://') or starts-with(., 'https://')">
                                    <dc:license rdf:resource="{.}"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <dc:license><xsl:value-of select="."/></dc:license>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:for-each>

                        <!-- Free access (schema:isAccessibleForFree): derived from the same access tokens -->
                        <!-- used for the manifestation. Open/public => true, restricted/closed => false. -->
                        <xsl:choose>
                            <xsl:when test="$accessTokens = ('pub', 'open', 'public')">
                                <schema:isAccessibleForFree rdf:datatype="http://www.w3.org/2001/XMLSchema#boolean">true</schema:isAccessibleForFree>
                            </xsl:when>
                            <xsl:when test="$accessTokens = ('res', 'closed', 'aca', 'academic', 'restricted')">
                                <schema:isAccessibleForFree rdf:datatype="http://www.w3.org/2001/XMLSchema#boolean">false</schema:isAccessibleForFree>
                            </xsl:when>
                        </xsl:choose>
                    </srv:Service>
                </xsl:if>
            </OST>
        </xsl:copy>
    </xsl:template>

</xsl:stylesheet>