<?xml version="1.0" encoding="UTF-8"?>
<p:pipeline xmlns:p="http://www.w3.org/ns/xproc"
            version="1.0"
            name="CMD2RDF-facet-only">

    <!-- VLO lookup and local mapping configuration. -->
    <p:option name="beta-vlo-facets-url"
              select="'https://beta-vlo.clarin.eu/api/facets?q=id:'"/>
    <p:option name="beta-vlo-record-url"
              select="'https://beta-vlo.clarin.eu/api/records/'"/>
    <p:option name="vloFacetMapping"
              select="'https://raw.githubusercontent.com/clarin-eric/VLO-mapping/master/mapping/facetConcepts.xml'"/>

    <!-- Identifier rewriting and SKG serialization configuration. -->
    <p:option name="base_strip" select="''"/>
    <p:option name="base_add" select="''"/>
    <p:option name="skgBaseURI" select="'otf:'"/>
    <p:option name="emitProvenance" select="'false'"/>
    <p:option name="debug" select="'true'"/>
    <p:option name="debugOutputDir" select="'/Users/listj/debug'"/>

    <!-- Stage 1: enrich the CMD record with VLO facets. -->
    <p:xslt name="addVLOFacets">
        <p:input port="stylesheet">
            <p:document href="addVLOFacets.xsl"/>
        </p:input>
        <p:with-param name="beta-vlo-facets-url" select="$beta-vlo-facets-url"/>
        <p:with-param name="beta-vlo-record-url" select="$beta-vlo-record-url"/>
        <p:with-param name="vloFacetMapping" select="$vloFacetMapping"/>
    </p:xslt>

    <p:choose name="dumpFacets">
        <p:when test="$debug = 'true'">
            <p:store indent="true">
                <p:input port="source">
                    <p:pipe step="addVLOFacets" port="result"/>
                </p:input>
                <p:with-option name="href"
                               select="concat($debugOutputDir, '/01-addVLOFacets.xml')"/>
            </p:store>
        </p:when>
        <p:otherwise>
            <p:sink>
                <p:input port="source"><p:empty/></p:input>
            </p:sink>
        </p:otherwise>
    </p:choose>

    <!-- Stage 2: consume the facets and create the explicit SKG intermediate. -->
    <p:xslt name="createSKG">
        <p:input port="source">
            <p:pipe step="addVLOFacets" port="result"/>
        </p:input>
        <p:input port="stylesheet">
            <p:document href="VLOFacets2SKG.xsl"/>
        </p:input>
        <p:with-param name="base_strip" select="$base_strip"/>
        <p:with-param name="base_add" select="$base_add"/>
        <p:with-param name="skgBaseURI" select="$skgBaseURI"/>
    </p:xslt>

    <p:choose name="dumpSKG">
        <p:when test="$debug = 'true'">
            <p:store indent="true">
                <p:input port="source">
                    <p:pipe step="createSKG" port="result"/>
                </p:input>
                <p:with-option name="href"
                               select="concat($debugOutputDir, '/02-facets-to-SKG.xml')"/>
            </p:store>
        </p:when>
        <p:otherwise>
            <p:sink>
                <p:input port="source"><p:empty/></p:input>
            </p:sink>
        </p:otherwise>
    </p:choose>

    <!-- Stage 3: emit only the generated SKG graph as RDF/XML. -->
    <p:xslt name="serializeSKG">
        <p:input port="source">
            <p:pipe step="createSKG" port="result"/>
        </p:input>
        <p:input port="stylesheet">
            <p:document href="SKG2RDF.xsl"/>
        </p:input>
        <p:with-param name="emitProvenance"
                      select="$emitProvenance = 'true'"/>
    </p:xslt>

    <p:choose name="dumpRDF">
        <p:when test="$debug = 'true'">
            <p:store indent="true">
                <p:input port="source">
                    <p:pipe step="serializeSKG" port="result"/>
                </p:input>
                <p:with-option name="href"
                               select="concat($debugOutputDir, '/03-SKG-to-RDF.xml')"/>
            </p:store>
        </p:when>
        <p:otherwise>
            <p:sink>
                <p:input port="source"><p:empty/></p:input>
            </p:sink>
        </p:otherwise>
    </p:choose>

    <!-- Keep the serialized RDF as the implicit primary pipeline result. -->
    <p:identity name="result">
        <p:input port="source">
            <p:pipe step="serializeSKG" port="result"/>
        </p:input>
    </p:identity>

</p:pipeline>
