<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:ost="https://ostrails.eu/"
    exclude-result-prefixes="xs ost">

    <xsl:output method="xml" encoding="UTF-8" indent="yes"/>

    <xsl:template match="/ost:SKG">
        <!-- Serialize local source records using only their filename. -->
        <xsl:variable name="source-record" as="xs:string"
            select="if (starts-with(lower-case(string(@source-record)), 'file:'))
                    then replace(string(@source-record), '^.*/', '')
                    else string(@source-record)"/>
        <rdf:RDF>
            <xsl:if test="normalize-space($source-record) ne ''">
                <xsl:attribute name="xml:base" select="$source-record"/>
            </xsl:if>

            <!-- Each generated entity is a top-level RDF node. -->
            <xsl:copy-of select="*" copy-namespaces="no"/>
        </rdf:RDF>
    </xsl:template>

</xsl:stylesheet>
