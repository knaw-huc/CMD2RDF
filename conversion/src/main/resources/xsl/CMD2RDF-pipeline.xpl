<?xml version="1.0" encoding="UTF-8"?>
<p:pipeline xmlns:p="http://www.w3.org/ns/xproc" version="1.0" name="CMD2RDF-pipeline">
    
    <p:option name="debug"          select="'true'"/>
    <p:option name="debugOutputDir" select="'/Users/listj/debug'"/>
    
    <p:option name="base_strip" select="'/Users/menzowi/Documents/Projects/OSTrails/SKG/test/'"/>
    <p:option name="base_add"   select="''"/>
    
    <p:option name="skg-base"
        select="'https://w3id.org/skg-if/sandbox/my-skg-acronym/'"/>
    
    <p:option name="beta-vlo-facets-url"
        select="'https://beta-vlo.clarin.eu/api/facets?q=id:'"/>
    <p:option name="beta-vlo-record-url"
        select="'https://beta-vlo.clarin.eu/api/records/'"/>
    <p:option name="vloFacetMapping"
        select="'https://raw.githubusercontent.com/clarin-eric/VLO-mapping/master/mapping/facetConcepts.xml'"/>
    
    <p:option name="VLO-orgs" select="''"/>
    <p:option name="vloOutputDir" select="'.'"/>
    
    
    <!-- Step 1 - addVLOFacets -->
    <p:xslt name="addVLOFacets">
        <p:input port="stylesheet">
            <p:document href="addVLOFacets.xsl"/>
        </p:input>
        <p:with-param name="beta-vlo-facets-url" select="$beta-vlo-facets-url"/>
        <p:with-param name="beta-vlo-record-url" select="$beta-vlo-record-url"/>
        <p:with-param name="vloFacetMapping"     select="$vloFacetMapping"/>
    </p:xslt>
    
    <p:choose name="debug-1">
        <p:when test="$debug = 'true'">
            <p:store indent="true">
                <p:input port="source">
                    <p:pipe step="addVLOFacets" port="result"/>
                </p:input>
                <p:with-option name="href" select="concat($debugOutputDir, '/01-addVLOFacets.xml')"/>
            </p:store>
        </p:when>
        <p:otherwise><p:sink><p:input port="source"><p:empty/></p:input></p:sink></p:otherwise>
    </p:choose>
    
    
    <!-- Step 2 - addOST -->
    <p:xslt name="addOST">
        <p:input port="source">
            <p:pipe step="addVLOFacets" port="result"/>
        </p:input>
        <p:input port="stylesheet">
            <p:document href="addOST.xsl"/>
        </p:input>
        <p:with-param name="base_strip" select="$base_strip"/>
        <p:with-param name="base_add"   select="$base_add"/>
        <p:with-param name="skg-base"   select="$skg-base"/>
    </p:xslt>
    
    <p:choose name="debug-2">
        <p:when test="$debug = 'true'">
            <p:store indent="true">
                <p:input port="source">
                    <p:pipe step="addOST" port="result"/>
                </p:input>
                <p:with-option name="href" select="concat($debugOutputDir, '/02-addOST.xml')"/>
            </p:store>
        </p:when>
        <p:otherwise><p:sink><p:input port="source"><p:empty/></p:input></p:sink></p:otherwise>
    </p:choose>
    
    
    <!-- Step 3 - CMDRecord2RDF -->
    <p:xslt name="CMDRecord2RDF">
        <p:input port="source">
            <p:pipe step="addOST" port="result"/>
        </p:input>
        <p:input port="stylesheet">
            <p:document href="CMDRecord2RDF.xsl"/>
        </p:input>
        <p:with-param name="base_strip" select="$base_strip"/>
        <p:with-param name="base_add"   select="$base_add"/>
    </p:xslt>
    
    <p:choose name="debug-3">
        <p:when test="$debug = 'true'">
            <p:store indent="true">
                <p:input port="source">
                    <p:pipe step="CMDRecord2RDF" port="result"/>
                </p:input>
                <p:with-option name="href" select="concat($debugOutputDir, '/03-CMDRecord2RDF.xml')"/>
            </p:store>
        </p:when>
        <p:otherwise><p:sink><p:input port="source"><p:empty/></p:input></p:sink></p:otherwise>
    </p:choose>
    
    
    <!-- Step 4 – addOrganisationEntity -->
    <p:xslt name="addOrganisationEntity">
        <p:input port="source">
            <p:pipe step="CMDRecord2RDF" port="result"/>
        </p:input>
        <p:input port="stylesheet">
            <p:document href="addOrganisationEntity.xsl"/>
        </p:input>
        <p:with-param name="VLO-orgs" select="$VLO-orgs"/>
    </p:xslt>
    
    <p:choose name="debug-4">
        <p:when test="$debug = 'true'">
            <p:store indent="true">
                <p:input port="source">
                    <p:pipe step="addOrganisationEntity" port="result"/>
                </p:input>
                <p:with-option name="href" select="concat($debugOutputDir, '/04-addOrganisationEntity.xml')"/>
            </p:store>
        </p:when>
        <p:otherwise><p:sink><p:input port="source"><p:empty/></p:input></p:sink></p:otherwise>
    </p:choose>
    
    
    <!-- Step 5 – addLanguageEntity -->
    <p:xslt name="addLanguageEntity">
        <p:input port="source">
            <p:pipe step="addOrganisationEntity" port="result"/>
        </p:input>
        <p:input port="stylesheet">
            <p:document href="addLanguageEntity.xsl"/>
        </p:input>
        <p:input port="parameters">
            <p:empty/>
        </p:input>
    </p:xslt>
    
    <p:choose name="debug-5">
        <p:when test="$debug = 'true'">
            <p:store indent="true">
                <p:input port="source">
                    <p:pipe step="addLanguageEntity" port="result"/>
                </p:input>
                <p:with-option name="href" select="concat($debugOutputDir, '/05-addLanguageEntity.xml')"/>
            </p:store>
        </p:when>
        <p:otherwise><p:sink><p:input port="source"><p:empty/></p:input></p:sink></p:otherwise>
    </p:choose>
    
    
    <!-- Step 6 – saveVLO -->
    <p:xslt name="saveVLO">
        <p:input port="source">
            <p:pipe step="addLanguageEntity" port="result"/>
        </p:input>
        <p:input port="stylesheet">
            <p:document href="saveVLO.xsl"/>
        </p:input>
        <p:with-param name="vloOutputDir" select="$vloOutputDir"/>
    </p:xslt>
    
    <p:choose name="debug-6">
        <p:when test="$debug = 'true'">
            <p:store indent="true">
                <p:input port="source">
                    <p:pipe step="saveVLO" port="result"/>
                </p:input>
                <p:with-option name="href" select="concat($debugOutputDir, '/06-saveVLO.xml')"/>
            </p:store>
        </p:when>
        <p:otherwise><p:sink><p:input port="source"><p:empty/></p:input></p:sink></p:otherwise>
    </p:choose>
    
    
    <!-- bind pipeline output to saveVLO's result, independent of debug -->
    <p:identity name="final">
        <p:input port="source">
            <p:pipe step="saveVLO" port="result"/>
        </p:input>
    </p:identity>
    
</p:pipeline>