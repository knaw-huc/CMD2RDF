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

    <xsl:include href="CMD2RDF.xsl"/>

    <xsl:param name="base" select="if (exists(/*/@xml:base)) then (/*/@xml:base) else (base-uri())"/>

    <!-- allow to rewrite the urls -->
    <xsl:param name="base_strip" select="'/Users/listj/Clarin.Data/TI_Total/'"/>
    <xsl:param name="base_add" select="''"/>

    <!-- Entity identifiers must be absolute, including when the document base is a filename URN. -->
    <xsl:param name="skgBaseURI" select="'otf:'"/>

    <xsl:variable name="path-about" select="replace(if ($base_strip=$base) then $base else for $strip in tokenize($base_strip,',') return if (starts-with($base,concat('file:',$strip))) then replace($base, concat('file:',$strip), $base_add) else (),'([./])(xml|cmdi)$','$1rdf')"/>
    <xsl:variable name="about" select="replace($path-about, '^(urn:)/+', '$1', 'i')"/>

    <!-- the identifier the record carries itself, which is also what the VLO keys its records on -->
    <xsl:variable name="selfLink" select="normalize-space((/cmd0:CMD/cmd0:Header/cmd0:MdSelfLink|/cmd1:CMD/cmd1:Header/cmd1:MdSelfLink)[1])"/>

    <!-- the record path relative to the harvest directory, unique within the corpus -->
    <xsl:variable name="record-path" select="replace(if (starts-with($about,$base_add)) then substring-after($about,$base_add) else $about,'^/|\.rdf$','')"/>

    <!-- SKG-IF local identifier of this record, encoded the way the VLO encodes record identifiers.
         A record without an MdSelfLink has no identifier of its own, so mint one from its path and
         mark it as created on-the-fly. -->
    <xsl:variable name="skg-id" select="
        if ($selfLink!='')
        then concat($skgBaseURI, cmd0:encodeId($selfLink))
        else concat($skgBaseURI, 'otf___', cmd0:encodeId($record-path))"/>

    <!-- Slugify function: replaces any run of non-letter/non-digit characters with _ and strips leading/trailing underscores.
         Normalizes to NFC first, so that a name spelled with a precomposed character and one spelled with a combining mark
         do not end up as two different identifiers. -->
    <xsl:function name="ost:slugify" as="xs:string">
        <xsl:param name="text" as="xs:string"/>
        <xsl:sequence select="lower-case(replace(replace(normalize-unicode(normalize-space($text),'NFC'), '[^\p{L}\p{N}]+', '_'), '^_|_$', ''))"/>
    </xsl:function>

    <!-- SKG-IF local identifier for an entity derived from a facet value: the metadata holds no
         identifier for it, so mint one from the name and mark it as created on-the-fly. The type is
         part of the identifier so a person and an organisation of the same name stay distinct. -->
    <xsl:function name="ost:entity-id" as="xs:string">
        <xsl:param name="type" as="xs:string"/>
        <xsl:param name="name" as="xs:string"/>
        <xsl:sequence select="concat($skgBaseURI, 'otf___', $type, '___', ost:slugify($name))"/>
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
                <fabio:Dataset rdf:about="{$skg-id}"/>
                <fabio:Work rdf:about="{$skg-id}">
                    <!-- PID (Handle, DOI, etc.) -->
                    <xsl:variable name="pid" select="$selfLink"/>
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
                        <fabio:Expression rdf:about="{concat($skg-id, '#expression')}">
                            <frbr:embodiment rdf:resource="{concat($skg-id, '#manifestation')}"/>
                        </fabio:Expression>
                    </frbr:realization>

                    <!-- Link to organisations (relevant_organisations in SKG-IF) -->
                    <xsl:for-each select="$orgs">
                        <dc:relation rdf:resource="{ost:entity-id('org', .)}"/>
                    </xsl:for-each>

                    <!-- Link to creators (contributions / persons in SKG-IF) -->
                    <xsl:for-each select="$creators">
                        <dc:creator rdf:resource="{ost:entity-id('person', .)}"/>
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

                <fabio:Manifestation rdf:about="{concat($skg-id, '#manifestation')}">

                    <!-- Hosting data source (SKG-IF hosting_data_source) -->
                    <xsl:if test="normalize-space($provider) != ''">
                        <dcat:accessService rdf:resource="{ost:entity-id('ds', $provider)}"/>
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
                    <foaf:Organization rdf:about="{ost:entity-id('org', .)}">
                        <foaf:name><xsl:value-of select="."/></foaf:name>
                        <rdf:type rdf:resource="http://purl.org/cerif/frapo/ResearchInstitute"/>
                    </foaf:Organization>
                </xsl:for-each>

                <!-- Person entities from creator facet (type: person) -->
                <!-- VLO supplies names as "Family, Given"; split on the first comma. -->
                <!-- When no comma is present we cannot reliably split, so emit foaf:name only. -->
                <xsl:for-each select="$creators">
                    <foaf:Person rdf:about="{ost:entity-id('person', .)}">
                        <foaf:name><xsl:value-of select="."/></foaf:name>
                        <xsl:if test="contains(., ',')">
                            <foaf:familyName><xsl:value-of select="normalize-space(substring-before(., ','))"/></foaf:familyName>
                            <foaf:givenName><xsl:value-of select="normalize-space(substring-after(., ','))"/></foaf:givenName>
                        </xsl:if>
                    </foaf:Person>
                </xsl:for-each>

                <!-- Provider as data source (SKG-IF data source = dcat:DataService), classified as a repository -->
                <xsl:if test="normalize-space($provider) != ''">
                    <dcat:DataService rdf:about="{ost:entity-id('ds', $provider)}">
                        <foaf:name><xsl:value-of select="$provider"/></foaf:name>
                        <rdf:type rdf:resource="http://purl.org/cerif/frapo/Repository"/>
                    </dcat:DataService>
                </xsl:if>

                <!-- SKG-IF Service entity: emitted in addition to the dataset Work/Manifestation for -->
                <!-- records on the WebLicht profile (clarin.eu:cr1:p_1320657629644). Mapped onto the -->
                <!-- SKG-IF service extension ontology (https://w3id.org/skg-if/extension/srv/ontology/). -->
                <!-- srv:Service is a subclass of schema:SoftwareApplication. -->
                <xsl:if test="$isWebLicht">
                    <srv:Service rdf:about="{concat($skg-id, '#service')}">

                        <!-- name (foaf:name) -->
                        <xsl:for-each select="$titles">
                            <foaf:name><xsl:value-of select="."/></foaf:name>
                        </xsl:for-each>

                        <!-- description (dcterms:description) -->
                        <xsl:for-each select="$descriptions">
                            <dc:description><xsl:value-of select="."/></dc:description>
                        </xsl:for-each>

                        <!-- identifiers (datacite:hasIdentifier) -->
                        <xsl:variable name="pid" select="$selfLink"/>
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
                            <srv:hasHostingOrganisation rdf:resource="{ost:entity-id('ds', $provider)}"/>
                        </xsl:if>

                        <!-- relevant organisations (dcterms:relation) -->
                        <xsl:for-each select="$orgs">
                            <dc:relation rdf:resource="{ost:entity-id('org', .)}"/>
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