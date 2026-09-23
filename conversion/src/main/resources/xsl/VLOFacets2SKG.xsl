<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:cmd0="http://www.clarin.eu/cmd/"
                xmlns:cmd1="http://www.clarin.eu/cmd/1"
                xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:fabio="http://purl.org/spar/fabio/"
                xmlns:srv="https://w3id.org/skg-if/extension/srv/ontology/"
                xmlns:ost="https://ostrails.eu/"
                exclude-result-prefixes="#all">

    <!--
        Reuse the facet-to-entity mapping while giving this pipeline stage an
        explicit output contract. The imported stylesheet creates a temporary
        CMD wrapper containing OST; this stylesheet exposes only the generated
        SKG resources to the next stage.
    -->
    <xsl:import href="addOST.xsl"/>

    <xsl:output method="xml" encoding="UTF-8" indent="yes"/>

    <!--
        Override the legacy rewrite variables with a safe fallback. With no
        configured strip prefix, retain the source base URI unchanged.
    -->
    <xsl:variable name="path-about" as="xs:string"
                  select="
            let $rewritten := (
                for $strip in tokenize($base_strip, '\s*,\s*')[. ne '']
                return
                    if (starts-with($base, concat('file:', $strip)))
                    then replace($base, concat('^file:', $strip), $base_add)
                    else ()
            )[1]
            return replace(($rewritten, string($base))[1],
                           '([./])(xml|cmdi)$', '$1rdf')"/>

    <xsl:variable name="about" as="xs:string"
                  select="replace($path-about, '^(urn:)/+', '$1', 'i')"/>

    <xsl:template match="/cmd0:CMD | /cmd1:CMD">
        <xsl:variable name="generated" as="document-node()">
            <xsl:document>
                <xsl:next-match/>
            </xsl:document>
        </xsl:variable>

        <!-- addOST.xsl now gives products and services separate identifiers. Read the
             primary resource from the generated RDF instead of referring to the removed
             legacy $skg-id variable. A CMDI record produces either a Work or a Service. -->
        <xsl:variable name="primary-resource" as="xs:string?"
                      select="string((
                $generated/*/OST/fabio:Work/@rdf:about,
                $generated/*/OST/srv:Service/@rdf:about
            )[1])"/>

        <ost:SKG source-record="{$about}">
            <xsl:if test="$primary-resource != ''">
                <xsl:attribute name="primary-resource" select="$primary-resource"/>
            </xsl:if>
            <xsl:copy-of select="$generated/*/OST/*" copy-namespaces="no"/>
        </ost:SKG>
    </xsl:template>

</xsl:stylesheet>
