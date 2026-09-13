<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:vlo="http://www.clarin.eu/vlo/"
                exclude-result-prefixes="xs vlo" version="3.0">

    <!-- Shared encoding for VLO API lookups and SKG entity identifiers. -->
	<xsl:function name="vlo:encodeId" as="xs:string">
		<xsl:param name="id" as="xs:string"/>
		<!-- codepoints: : 58  / 47  ? 63  # 35  [ 91  ] 93  @ 64  ! 33  $ 36  & 38  ' 39  ( 40  ) 41  * 42  + 43  , 44  ; 59  = 61  % 37 -->
		<xsl:variable name="url-codepoints" select="(58, 47, 63, 35, 91, 93, 64, 33, 36, 38, 39, 40, 41, 42, 43, 44, 59, 61, 37)"/>
		<xsl:sequence select="
			string-join((for $cp in string-to-codepoints($id) return
							if ($cp = $url-codepoints) then concat('_', $cp, '_') else codepoints-to-string($cp)), '') "/>
	</xsl:function>

</xsl:stylesheet>
