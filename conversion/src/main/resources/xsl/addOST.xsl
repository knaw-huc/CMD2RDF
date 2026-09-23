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

    <!-- Absolute base for local SKG-IF entity identifiers. -->
    <xsl:param name="skgBaseURI" select="'otf:'"/>

    <xsl:variable name="path-about" select="replace(if ($base_strip=$base) then $base else for $strip in tokenize($base_strip,',') return if (starts-with($base,concat('file:',$strip))) then replace($base, concat('file:',$strip), $base_add) else (),'([./])(xml|cmdi)$','$1rdf')"/>
    <xsl:variable name="about" select="replace($path-about, '^(urn:)/+', '$1', 'i')"/>

    <!-- the identifier the record carries itself, which is also what the VLO keys its records on -->
    <xsl:variable name="selfLink" select="normalize-space((/cmd0:CMD/cmd0:Header/cmd0:MdSelfLink|/cmd1:CMD/cmd1:Header/cmd1:MdSelfLink)[1])"/>

    <!-- the record path relative to the harvest directory, unique within the corpus -->
    <xsl:variable name="record-path" select="replace(if (starts-with($about,$base_add)) then substring-after($about,$base_add) else $about,'^/|\.rdf$','')"/>

    <!-- Short fallback key: use only the final filename, without a CMDI/RDF extension. The normal
         pipeline obtains a VLO id from addVLOFacets.xsl; this value is only used when addOST.xsl is
         run directly on a record that has neither hasFacetId nor MdSelfLink. -->
    <xsl:variable name="record-name" as="xs:string" select="
        replace(
            tokenize(replace($record-path, '\\', '/'), '/')[last()],
            '\.(xml|cmdi|rdf)$',
            '',
            'i'
        )"/>

    <!-- addVLOFacets.xsl writes the VLO record key explicitly. The fallback keeps this stylesheet
         usable on its own, but the normal pipeline should always take the first branch. -->
    <xsl:variable name="vlo-id" as="xs:string" select="
        if (normalize-space(string((/*/vlo:hasFacetId)[1])) != '')
        then normalize-space(string((/*/vlo:hasFacetId)[1]))
        else if ($selfLink != '')
        then encode-for-uri(cmd0:encodeId($selfLink))
        else encode-for-uri(cmd0:encodeId($record-name))"/>

    <!-- The VLO id identifies the source record. Prefix it with the SKG entity kind so the
         generated product and service IRIs do not conflate those entities with the record. -->
    <xsl:variable name="product-id" as="xs:string"
                  select="concat($skgBaseURI, 'product___', $vlo-id)"/>
    <xsl:variable name="service-id" as="xs:string"
                  select="concat($skgBaseURI, 'service___', $vlo-id)"/>

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
        <xsl:variable name="collections" select="distinct-values(vlo:hasFacetCollection[normalize-space(.)!='']/normalize-space(.))"/>
        <xsl:variable name="resourceClasses" as="xs:string*"
                      select="distinct-values(vlo:hasFacetResourceClass[normalize-space(.)!='']/normalize-space(.))"/>
        <xsl:variable name="resourceClassText" as="xs:string"
                      select="lower-case(string-join($resourceClasses, ' '))"/>

        <!-- Classify only on explicit resource-class signals. The order is intentional: records can
             contain several broad CMDI/DCMI classes, so specific software and dataset signals take
             precedence over publication signals. A generic value such as Text is not enough to call
             a product literature. No reliable match means plain fabio:Work (SKG-IF 'other'). -->
        <xsl:variable name="isSoftware" as="xs:boolean" select="matches(
            $resourceClassText,
            '(^|[^a-z])(research software|software|source code|computer program|executable|script|workflow|tool)([^a-z]|$)'
        )"/>
        <xsl:variable name="isDataset" as="xs:boolean" select="matches(
            $resourceClassText,
            '(^|[^a-z])(dataset|data set|corpus|lexical resource|lexicon|database|data collection)([^a-z]|$)'
        )"/>
        <xsl:variable name="isLiterature" as="xs:boolean" select="matches(
            $resourceClassText,
            '(^|[^a-z])(research literature|literature|journal article|article|book|book chapter|chapter|thesis|dissertation|report|conference paper|conference proceedings|proceedings|working paper|preprint|publication)([^a-z]|$)'
        )"/>

        <!-- Explicit product URLs from profile metadata. Unlike MdSelfLink, these identifier fields
             describe the resource/product. Do not infer a product identifier from arbitrary links. -->
        <xsl:variable name="productIdentifierUrls" as="xs:string*"
                      select="distinct-values((/cmd0:CMD/cmd0:Components | /cmd1:CMD/cmd1:Components)
                                //*[matches(lower-case(local-name()), '(identifier|pid)$')]
                                    [not(ancestor::*[
                                        matches(
                                            lower-case(local-name()),
                                            '^(service|person|creator|author|contact|organisation|organization)$'
                                        )
                                    ])]
                                [matches(normalize-space(.), '^https?://')]
        )"/>

        <!-- A collection is not necessarily a service portal. Only values that explicitly look like
             a portal/catalogue are promoted to an SKG-IF srv:Portal. -->
        <xsl:variable name="portalCollections" select="$collections[
            matches(lower-case(.), '(portal|catalog|catalogue|marketplace|orchestrator|registry|virtual language observatory|weblight)')
        ]"/>

        <!-- The Service shape requires exactly one foaf:name. Prefer the first VLO title and use a
             deterministic identifier-derived fallback for malformed records without a title. -->
        <xsl:variable name="serviceName" select="
            if (exists($titles)) then normalize-space($titles[1])
            else if ($selfLink != '') then $selfLink
            else $vlo-id"/>

        <!-- Keep each CMDI ResourceRef together with its ResourceType. Treating every ResourceRef as
             a service endpoint loses the distinction between resources, landing pages and services. -->
        <xsl:variable name="resourceProxies" select="(
            /cmd0:CMD/cmd0:Resources/cmd0:ResourceProxyList/cmd0:ResourceProxy,
            /cmd1:CMD/cmd1:Resources/cmd1:ResourceProxyList/cmd1:ResourceProxy
        )"/>

        <!-- Standard SearchService proxies and historical/custom service-like proxy types used by
             WebLicht. A proxy typed merely as Resource or LandingPage is deliberately excluded. -->
        <xsl:variable name="serviceProxyRefs" as="xs:string*" select="distinct-values(
            $resourceProxies[
                *:ResourceRef[normalize-space(.) != '']
                and matches(
                    lower-case(normalize-space(string(*:ResourceType))),
                    '^(search\s*service|web[ -]?service|wsdl\s*service|api\s*service|service)$'
                )
            ]/*:ResourceRef[normalize-space(.) != '']/normalize-space(.)
        )"/>

        <xsl:variable name="landingPageUrls" as="xs:string*" select="distinct-values(
            $resourceProxies[
                lower-case(normalize-space(string(*:ResourceType))) = 'landingpage'
            ]/*:ResourceRef[normalize-space(.) != '']/normalize-space(.)
        )"/>

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

        <!-- Creator organisation(s) of a WebLicht service. The profile elements are in the cmd0 namespace -->
        <!-- in CMDI 1.1 and in a profile-specific namespace in CMDI 1.2, hence the wildcards. -->
        <xsl:variable name="hostingOrgs" select="distinct-values((/cmd0:CMD/cmd0:Components|/cmd1:CMD/cmd1:Components)/*:WebLichtWebService/*:Service/*:Creation/*:Creators/*:Creator/*:Contact/*:Organisation[normalize-space(.)!='']/normalize-space(.))"/>

        <!-- A WebLicht Service/PID identifies the service itself. Unlike MdSelfLink, it is therefore
             suitable for datacite:hasIdentifier. Profiles may use different namespaces, so match by
             local name while still requiring PID and URL to be direct children of Service. -->
        <xsl:variable name="serviceElements" select="
            (/cmd0:CMD/cmd0:Components|/cmd1:CMD/cmd1:Components)//*[local-name() = 'Service']
        "/>
        <xsl:variable name="servicePids" as="xs:string*" select="distinct-values(
            $serviceElements/*[local-name() = 'PID'][normalize-space(.) != '']/normalize-space(.)
        )"/>
        <xsl:variable name="serviceComponentUrls" as="xs:string*" select="distinct-values(
            $serviceElements/*[local-name() = 'URL'][normalize-space(.) != '']/normalize-space(.)
        )"/>

        <!-- Service/URL can denote either an executable endpoint or an API description such as WSDL,
             OpenAPI or Swagger. Preserve that distinction in DCAT. -->
        <xsl:variable name="endpointDescriptionUrls" as="xs:string*" select="$serviceComponentUrls[
            matches(lower-case(.), '(\?wsdl($|[&amp;#])|\.wsdl($|[?#])|(^|[/_.-])(openapi|swagger)([/_.?#-]|$))')
        ]"/>
        <xsl:variable name="endpointUrls" as="xs:string*" select="distinct-values((
            $serviceProxyRefs,
            $serviceComponentUrls[not(. = $endpointDescriptionUrls)]
        ))"/>

        <xsl:copy>
            <!-- This copy preserves the attributes on the root cmd0:CMD / cmd1:CMD element — most importantly @xml:base, also used further downstream to compute the about -->
            <xsl:copy-of select="@*"/>
            <OST>
                <!-- A WebLicht profile describes a service, not a dataset. -->
                <xsl:if test="not($isWebLicht)">
                    <fabio:Work rdf:about="{$product-id}">
                        <xsl:choose>
                            <xsl:when test="$isSoftware">
                                <rdf:type rdf:resource="http://purl.org/spar/fabio/Software"/>
                            </xsl:when>
                            <xsl:when test="$isDataset">
                                <rdf:type rdf:resource="http://purl.org/spar/fabio/Dataset"/>
                            </xsl:when>
                            <xsl:when test="$isLiterature">
                                <rdf:type rdf:resource="http://purl.org/spar/fabio/ScholarlyWork"/>
                            </xsl:when>
                            <!-- Otherwise the element itself types the entity only as fabio:Work,
                                 which maps to the SKG-IF product type 'other'. -->
                            <xsl:otherwise/>
                        </xsl:choose>

                        <!-- MdSelfLink identifies the CMDI metadata record and is deliberately not
                             emitted here. Only explicit URI-typed product identifiers are mapped. -->
                        <xsl:for-each select="$productIdentifierUrls">
                            <datacite:hasIdentifier>
                                <datacite:Identifier>
                                    <datacite:usesIdentifierScheme rdf:resource="http://purl.org/spar/datacite/url"/>
                                    <silvio:hasLiteralValue><xsl:value-of select="."/></silvio:hasLiteralValue>
                                </datacite:Identifier>
                            </datacite:hasIdentifier>
                        </xsl:for-each>

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
                            <fabio:Expression rdf:about="{concat($product-id, '#expression')}">
                                <frbr:embodiment rdf:resource="{concat($product-id, '#manifestation')}"/>
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
                </xsl:if>

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

                <xsl:if test="not($isWebLicht)">
                    <fabio:Manifestation rdf:about="{concat($product-id, '#manifestation')}">

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
                </xsl:if>

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
                    <srv:Service rdf:about="{$service-id}">

                        <!-- name (foaf:name): exactly one value is required by the Service shape -->
                        <foaf:name><xsl:value-of select="$serviceName"/></foaf:name>

                        <!-- description (dcterms:description): SRV-O expects rdfs:langString.
                             Preserve a source language tag and use BCP 47 'und' when it is unknown. -->
                        <xsl:for-each select="$descriptions">
                            <dc:description>
                                <xsl:attribute name="xml:lang" select="if (@xml:lang) then string(@xml:lang) else 'und'"/>
                                <xsl:value-of select="."/>
                            </dc:description>
                        </xsl:for-each>

                        <!-- Service identifiers come from the profile's Service/PID element. MdSelfLink
                             is intentionally not emitted here because it identifies the CMDI record. -->
                        <xsl:for-each select="$servicePids">
                            <xsl:variable name="pid" select="."/>
                            <datacite:hasIdentifier>
                                <datacite:Identifier>
                                    <xsl:choose>
                                        <xsl:when test="matches(lower-case($pid), '^(https?://hdl\.handle\.net/|hdl:)')">
                                            <datacite:usesIdentifierScheme rdf:resource="http://purl.org/spar/datacite/handle"/>
                                        </xsl:when>
                                        <xsl:when test="matches(lower-case($pid), '^(https?://(dx\.)?doi\.org/|doi:|10\.[0-9]{4,9}/)')">
                                            <datacite:usesIdentifierScheme rdf:resource="http://purl.org/spar/datacite/doi"/>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <datacite:usesIdentifierScheme rdf:resource="http://purl.org/spar/datacite/local-resource-identifier-scheme"/>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                    <silvio:hasLiteralValue><xsl:value-of select="$pid"/></silvio:hasLiteralValue>
                                </datacite:Identifier>
                            </datacite:hasIdentifier>
                        </xsl:for-each>

                        <!-- hosting organisation (srv:hasHostingOrganisation): no VLO facet names it, so take the -->
                        <!-- creator organisation from the record itself; for WebLicht services the creating centre -->
                        <!-- also hosts the service -->
                        <xsl:for-each select="$hostingOrgs">
                            <srv:hasHostingOrganisation rdf:resource="{ost:entity-id('org', .)}"/>
                        </xsl:for-each>

                        <!-- research infrastructure (srv:isPartOfResearchInfrastructure): always CLARIN -->
                        <srv:isPartOfResearchInfrastructure rdf:resource="{ost:entity-id('org', 'CLARIN ERIC')}"/>

                        <!-- venues (srv:hasVenue): the VLO and collection values explicitly recognisable
                             as portals/catalogues, e.g. "WebLicht Webservice Orchestrator" -->
                        <srv:hasVenue rdf:resource="{ost:entity-id('venue', 'Virtual Language Observatory')}"/>
                        <xsl:for-each select="$portalCollections">
                            <srv:hasVenue rdf:resource="{ost:entity-id('venue', .)}"/>
                        </xsl:for-each>

                        <!-- relevant organisations (dcterms:relation). Until the srv ontology declares its -->
                        <!-- organisation properties subproperties of dcterms:relation, it asks producers to -->
                        <!-- repeat those organisations here, hence the hosting organisations and CLARIN. -->
                        <xsl:for-each select="distinct-values(($orgs, $hostingOrgs))">
                            <dc:relation rdf:resource="{ost:entity-id('org', .)}"/>
                        </xsl:for-each>
                        <dc:relation rdf:resource="{ost:entity-id('org', 'CLARIN ERIC')}"/>

                        <!-- Landing pages are user-facing pages about the service, not API endpoints. -->
                        <xsl:for-each select="$landingPageUrls">
                            <foaf:page rdf:resource="{.}"/>
                        </xsl:for-each>

                        <!-- API profile: dcterms:conformsTo must point to at most one srv:APIProfile,
                             rather than containing a media-type literal. Executable endpoints and API
                             descriptions are mapped separately; unrelated ResourceRefs are ignored. -->
                        <xsl:if test="exists($endpointUrls) or exists($endpointDescriptionUrls)">
                            <dc:conformsTo>
                                <srv:APIProfile rdf:about="{concat($service-id, '#api-profile')}">
                                    <xsl:for-each select="$endpointUrls">
                                        <dcat:endpointURL rdf:resource="{.}"/>
                                    </xsl:for-each>
                                    <xsl:for-each select="$endpointDescriptionUrls">
                                        <dcat:endpointDescription rdf:resource="{.}"/>
                                    </xsl:for-each>
                                </srv:APIProfile>
                            </dc:conformsTo>
                        </xsl:if>

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

                    <!-- Hosting organisations (SKG-IF organization, type srv_hosting_organisation) -->
                    <xsl:for-each select="$hostingOrgs">
                        <foaf:Organization rdf:about="{ost:entity-id('org', .)}">
                            <foaf:name><xsl:value-of select="."/></foaf:name>
                            <rdf:type rdf:resource="https://w3id.org/skg-if/extension/srv/ontology/HostingOrganisation"/>
                        </foaf:Organization>
                    </xsl:for-each>

                    <!-- CLARIN as research infrastructure (SKG-IF organisation, type srv_research_infrastructure) -->
                    <foaf:Organization rdf:about="{ost:entity-id('org', 'CLARIN ERIC')}">
                        <foaf:name>CLARIN ERIC</foaf:name>
                        <rdf:type rdf:resource="https://w3id.org/skg-if/extension/srv/ontology/ResearchInfrastructure"/>
                        <foaf:homepage rdf:resource="https://www.clarin.eu/"/>
                    </foaf:Organization>

                    <!-- Venues (skg:Venue = fabio:ExpressionCollection, type srv_portal) -->
                    <fabio:ExpressionCollection rdf:about="{ost:entity-id('venue', 'Virtual Language Observatory')}">
                        <foaf:name>Virtual Language Observatory</foaf:name>
                        <rdf:type rdf:resource="https://w3id.org/skg-if/extension/srv/ontology/Portal"/>
                        <foaf:homepage rdf:resource="https://vlo.clarin.eu/"/>
                    </fabio:ExpressionCollection>
                    <xsl:for-each select="$portalCollections">
                        <fabio:ExpressionCollection rdf:about="{ost:entity-id('venue', .)}">
                            <foaf:name><xsl:value-of select="."/></foaf:name>
                            <rdf:type rdf:resource="https://w3id.org/skg-if/extension/srv/ontology/Portal"/>
                        </fabio:ExpressionCollection>
                    </xsl:for-each>
                </xsl:if>
            </OST>
        </xsl:copy>
    </xsl:template>

</xsl:stylesheet>
