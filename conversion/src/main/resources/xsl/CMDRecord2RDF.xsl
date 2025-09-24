<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE rdf:RDF [
    <!ENTITY rdf 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'>
    <!ENTITY rdfs 'http://www.w3.org/TR/WD-rdf-schema#'>
    <!ENTITY xsd 'http://www.w3.org/2001/XMLSchema#'>
    <!ENTITY cmdm 'http://www.clarin.eu/cmd/general.rdf#'>
    <!ENTITY oa 'http://www.w3.org/ns/oa#'>
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0" xmlns:dcr="http://www.isocat.org/ns/dcr.rdf#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:cmd0="http://www.clarin.eu/cmd/" xmlns:cmd1="http://www.clarin.eu/cmd/1" xmlns:cmdm="http://www.clarin.eu/cmd/general.rdf#" xmlns:ore="http://www.openarchives.org/ore/terms/" xmlns:oa="http://www.w3.org/ns/oa#" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:vlo="http://www.clarin.eu/vlo/"  xmlns:cmdi="http://www.clarin.eu/cmdi/">

    <xsl:output method="xml" encoding="UTF-8"/>

	<xsl:param name="base" select="if (exists(/*/@xml:base)) then (/*/@xml:base) else (base-uri())"/>
	
    <!-- allow to rewrite the urls -->
    <xsl:param name="base_strip" select="'/Users/menzowi/Documents/Projects/OSTrails/SKG/test/'"/>
    <xsl:param name="base_add" select="''"/>

    <xsl:variable name="about" select="replace(if ($base_strip=$base) then $base else for $strip in tokenize($base_strip,',') return if (starts-with($base,concat('file:',$strip))) then replace($base, concat('file:',$strip), $base_add) else (),'([./])(xml|cmdi)$','$1rdf')"/>

    <xsl:include href="CMD2RDF.xsl"/>

    <xsl:template match="text()"/>

    <!-- let's create some RDF -->
    <xsl:template match="/(cmd0:CMD|cmd1:CMD)">
        <xsl:message expand-text="yes">DBG: base[{$base}] base-strip[{$base_strip}] about[{$about}]</xsl:message>
        <rdf:RDF>
            <xsl:attribute name="xml:base" select="$about"/>
        	<rdf:Description rdf:about="{$about}">
        		<cmdi:inRepository rdf:resource="{replace($about,'(^.*/)[^/]*','$1')}"/>
        		<rdfs:label>
        			<xsl:variable name="record" select="replace($about,'^.*/(.*)\.(.*)$','$1')"/>
        			<xsl:variable name="repository" select="replace($about,'^.*/([^/]*)/[^/]*$','$1')"/>
        		    <xsl:choose>
        		        <xsl:when test="exists(vlo:hasFacetName)">
        		            <xsl:value-of select="(vlo:hasFacetName)[1]"/>
        		        </xsl:when>
        		        <xsl:otherwise>
        		            <xsl:value-of select="replace(replace($record,'^oai_',''),'_',' ')"/>
        		        </xsl:otherwise>
        		    </xsl:choose>
        		    <xsl:text> (</xsl:text>
        			<xsl:value-of select="replace($repository,'_',' ')"/>
        			<xsl:text>)</xsl:text>
        		</rdfs:label>
        	</rdf:Description>
            <!-- The CMDI is seen as OA Annotation of a (set of) resource(s) -->
            <oa:Annotation rdf:about="{$about}">
                <xsl:apply-templates select="(cmd0:Resources|cmd1:Resources)" mode="resources"/>
                <oa:hasBody>
                    <xsl:apply-templates select="(cmd0:Components|cmd1:Components)">
                        <xsl:with-param name="context" tunnel="yes" select="''"/>
                    </xsl:apply-templates>
                </oa:hasBody>
                <oa:motivatedBy rdf:resource="&oa;describing"/>
                <xsl:apply-templates select="(cmd0:Resources|cmd1:Resources)" mode="other"/>
            </oa:Annotation>
            <!-- The CMDI is an ORE ResourceMap to other metadata descriptions -->
            <xsl:if test="exists((cmd0:Resources|cmd1:Resources)/(cmd0:ResourceProxyList|cmd1:ResourceProxyList)/(cmd0:ResourceProxy|cmd1:ResourceProxy)[(cmd0:ResourceType|cmd1:ResourceType)='Metadata'])">
                <ore:ResourceMap rdf:about="{$about}">
                    <ore:describes>
                        <ore:Aggregation>
                            <xsl:apply-templates select="(cmd0:Resources|cmd1:Resources)" mode="metadata"/>
                        </ore:Aggregation>
                    </ore:describes>
                </ore:ResourceMap>
            </xsl:if>
            <xsl:apply-templates select="(cmd0:Header|cmd1:Header)"/>
        	<rdf:Description rdf:about="{$about}">
        		<xsl:apply-templates select="vlo:*"/>
        	    <xsl:copy-of select="OST/*"/>
        	</rdf:Description>
        </rdf:RDF>
    </xsl:template>

    <xsl:template match="cmd0:MdCreator|cmd1:MdCreator">
        <rdf:Description rdf:about="{concat('#',generate-id((/cmd0:CMD/cmd0:Components/*,/cmd1:CMD/cmd1:Components/*)[1]))}">
            <dc:creator>
                <xsl:value-of select="."/>
            </dc:creator>
        </rdf:Description>
    </xsl:template>

    <xsl:template match="cmd0:MdCreationDate|cmd1:MdCreationDate">
        <rdf:Description rdf:about="{concat('#',generate-id((/cmd0:CMD/cmd0:Components/*,/cmd1:CMD/cmd1:Components/*)[1]))}">
            <dc:created>
                <xsl:value-of select="."/>
            </dc:created>
        </rdf:Description>
    </xsl:template>

    <xsl:template match="cmd0:MdSelfLink|cmd1:MdSelfLink">
        <rdf:Description rdf:about="{concat('#',generate-id((/cmd0:CMD/cmd0:Components/*,/cmd1:CMD/cmd1:Components/*)[1]))}">
            <dc:identifier>
                <xsl:value-of select="."/>
            </dc:identifier>
        </rdf:Description>
    </xsl:template>

    <xsl:template match="cmd0:MdProfile|cmd1:MdProfile">
        <!-- TODO? -->
    </xsl:template>

    <xsl:template match="cmd0:MdCollectionDisplayName|cmd1:MdCollectionDisplayName">
        <!-- TODO -->
    </xsl:template>

    <xsl:template match="text()" mode="resources"/>
    <xsl:template match="(cmd0:ResourceProxy|cmd1:ResourceProxy)[(cmd0:ResourceType|cmd1:ResourceType)!='Resource']" mode="resources"/>
    <xsl:template match="(cmd0:ResourceProxy|cmd1:ResourceProxy)[(cmd0:ResourceType|cmd1:ResourceType)='Resource']" mode="resources">
        <oa:hasTarget>
            <cmdm:Resource rdf:about="{cmd0:ResourceRef|cmd1:ResourceRef}">
                <xsl:if test="normalize-space((cmd0:ResourceType|cmd1:ResourceType)/@mimetype)!=''">
                    <cmdm:hasMimeType>
                        <xsl:value-of select="(cmd0:ResourceType|cmd1:ResourceType)/@mimetype"/>
                    </cmdm:hasMimeType>
                </xsl:if>
            </cmdm:Resource>
        </oa:hasTarget>
    </xsl:template>

    <xsl:template match="text()" mode="metadata"/>
    <xsl:template match="(cmd0:ResourceProxy|cmd1:ResourceProxy)[(cmd0:ResourceType|cmd1:ResourceType)!='Metadata']" mode="metadata"/>
    <xsl:template match="(cmd0:ResourceProxy|cmd1:ResourceProxy)[(cmd0:ResourceType|cmd1:ResourceType)='Metadata']" mode="metadata">
        <ore:aggregates rdf:resource="{cmd0:ResourceRef|cmd1:ResourceRef}"/>
        <!--
        <cmdm:hasMimeType rdf:about="{ResourceRef}">
            <xsl:value-of select="ResourceType/@mimetype"/>
        </cmdm:hasMimeType>
        -->
    </xsl:template>

    <xsl:template match="text()" mode="other"/>
    <xsl:template match="(cmd0:ResourceProxy|cmd1:ResourceProxy)[(cmd0:ResourceType|cmd1:ResourceType)=('Resource','Metadata')]" mode="other"/>
    <xsl:template match="(cmd0:ResourceProxy|cmd1:ResourceProxy)[not((cmd0:ResourceType|cmd1:ResourceType)=('Resource','Metadata'))]" mode="other">
        <xsl:element name="cmdm:has{cmd0:ResourceType|cmd1:ResourceType}">
            <xsl:attribute name="rdf:resource" select="cmd0:ResourceRef|cmd1:ResourceRef"/>
        </xsl:element>
        <!--
        <cmdm:hasMimeType rdf:about="{ResourceRef}">
            <xsl:value-of select="ResourceType/@mimetype"/>
        </cmdm:hasMimeType>
        -->
    </xsl:template>

    <!-- the CMD body -->
    <xsl:template match="/cmd0:CMD/cmd0:Components|/cmd1:CMD/cmd1:Components">
        <!-- get the profile id -->
        <xsl:variable name="id">
            <xsl:choose>
                <xsl:when test="exists(/(cmd0:CMD|cmd1:CMD)/@xsi:schemaLocation)">
                    <xsl:sequence select="cmd0:id(/(cmd0:CMD|cmd1:CMD)/@xsi:schemaLocation)"/>
                </xsl:when>
                <xsl:when test="exists((/cmd0:CMD/cmd0:Header/cmd0:MdProfile,/cmd1:CMD/cmd1:Header/cmd1:MdProfile))">
                    <!-- and ignore if there are multiple MdProfile and just take the first!! 
                         although probably this more a case for the schema validation!  -->
                    <xsl:sequence select="cmd0:id((/cmd0:CMD/cmd0:Header/cmd0:MdProfile,/cmd1:CMD/cmd1:Header/cmd1:MdProfile)[1])"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:message terminate="yes">
                        <xsl:text>ERR: the CMDI record doesn't refer to its profile!</xsl:text>
                    </xsl:message>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:if test="not(starts-with($id,'clarin.eu:'))">
            <xsl:text>ERR: the CMDI record doesn't refer to a profile in the CR!</xsl:text>
        </xsl:if>
        <!-- load the profile -->
        <xsl:variable name="profile" select="cmd0:profile($id)"/>
        <!-- the base URL (the namespace in RDF/XML) of the RDF resources will change during traversal to the URL of the active profile/component -->
        <xsl:variable name="ns" select="concat(cmd0:ppath($id,'rdf'),'#')"/>
        <!-- we traverse the profile/component scheme and find the matching instances -->
        <xsl:apply-templates select="$profile/ComponentSpec/Component">
            <xsl:with-param name="context" tunnel="yes" select="''"/>
            <xsl:with-param name="ns" tunnel="yes" select="$ns"/>
            <xsl:with-param name="instance" tunnel="yes" select="."/>
        </xsl:apply-templates>
    </xsl:template>

    <!-- a CMD component -->
    <xsl:template match="Component">
        <xsl:param name="context" tunnel="yes"/>
        <xsl:param name="ns" tunnel="yes"/>
        <xsl:param name="instance" tunnel="yes"/>
        <!-- if the component has its own id its something that can be shared by multiple profiles/components and has its own base RDF (namespace) -->
        <xsl:variable name="local-ns">
            <xsl:choose>
                <xsl:when test="exists(@ComponentId)">
                    <xsl:sequence select="concat(cmd0:cpath(@ComponentId,'rdf'),'#')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="$ns"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <!-- if the component has its own id its something that can be shared by multiple profiles/components a new context is started -->
        <xsl:variable name="local-context">
            <xsl:choose>
                <xsl:when test="exists(@ComponentId)">
                    <xsl:sequence select="''"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="$context"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="profile" select="."/>
        <xsl:variable name="name" select="@name"/>
        <!-- extend the context with this component -->
        <xsl:variable name="id" select="cmd0:path($local-context,$name)"/>
        <!-- find the matching instances -->
        <xsl:for-each select="$instance/*[local-name()=$name]">
            <!-- create a class -->
            <xsl:variable name="class">
                <xsl:element name="{$id}" namespace="{$local-ns}">
                    <xsl:attribute name="rdf:about" select="concat('#',generate-id(.))"/>
                    <xsl:for-each select="tokenize(@ref,'\s+')">
                        <xsl:variable name="res" select="."/>
                        <cmdm:describesResource rdf:resource="{($instance/ancestor::cmd0:CMD/cmd0:Resources/cmd0:ResourceProxyList/cmd0:ResourceProxy[@id=$res]/cmd0:ResourceRef,$instance/ancestor::cmd1:CMD/cmd1:Resources/cmd1:ResourceProxyList/cmd1:ResourceProxy[@id=$res]/cmd1:ResourceRef)[1]}"/>
                    </xsl:for-each>
                    <!-- switch back from the instance to the profile -->
                    <xsl:apply-templates select="$profile/*">
                        <xsl:with-param name="context" tunnel="yes" select="$id"/>
                        <xsl:with-param name="ns" tunnel="yes" select="$local-ns"/>
                        <xsl:with-param name="instance" tunnel="yes" select="."/>
                    </xsl:apply-templates>
                </xsl:element>
            </xsl:variable>
            <!-- is this the root or not -->
            <xsl:choose>
                <xsl:when test="exists((parent::cmd0:Components|parent::cmd1:Components))">
                    <xsl:copy-of select="$class"/>
                </xsl:when>
                <xsl:otherwise>
                    <!-- use the generic RELcat related relationship for the nesting of components -->
                    <cmdm:contains>
                        <xsl:copy-of select="$class"/>
                    </cmdm:contains>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:template>

    <!-- a CMD element -->
    <xsl:template match="Element">
        <xsl:param name="context" tunnel="yes"/>
        <xsl:param name="ns" tunnel="yes"/>
        <xsl:param name="instance" tunnel="yes"/>
        <xsl:variable name="profile" select="."/>
        <xsl:variable name="name" select="@name"/>
        <!-- extend the context with this element -->
        <xsl:variable name="id" select="cmd0:path($context,$name)"/>
        <xsl:variable name="has" select="cmd0:path($context,concat('has',@name))"/>
        <!-- find the matching instances -->
        <xsl:for-each select="$instance/*[local-name()=$name]">
            <!-- use the generic RELcat related relationship for the nesting of the element in its component -->
            <cmdm:contains>
                <!-- a CMD element is a RDF class -->
                <xsl:element name="{$id}" namespace="{$ns}">
                    <xsl:attribute name="rdf:about" select="concat('#',generate-id(.))"/>
                    <!-- the value is assigned to a propery of the CMD element RDF class -->
                    <xsl:element name="{$has}ElementValue" namespace="{$ns}">
                        <!-- map the CMD XSD datatype to a datatype supported by RDF -->
                        <xsl:attribute name="rdf:datatype" select="concat('&xsd;',cmd0:datatype($profile/@ValueScheme))"/>
                        <!-- copy @xml:lang -->
                        <xsl:copy-of select="@xml:lang"/>
                        <!-- copy the literal -->
                        <xsl:value-of select="."/>
                    </xsl:element>
                    <!-- if there is enum we also have an entity property -->
                    <xsl:if test="exists($profile/ValueScheme/Vocabulary/enumeration)">
                        <xsl:element name="{$id}ElementEntity" namespace="{$ns}">
                            <xsl:attribute name="rdf:resource" select="concat($ns,$id,'ValueScheme',$STEP,replace(.,'\s',''))"/>
                        </xsl:element>
                    </xsl:if>
                    <!-- switch back from the instance to the profile to handle the attributes -->
                    <xsl:apply-templates select="$profile/AttributeList/Attribute">
                        <xsl:with-param name="context" tunnel="yes" select="$id"/>
                        <xsl:with-param name="ns" tunnel="yes" select="$ns"/>
                        <xsl:with-param name="instance" tunnel="yes" select="."/>
                    </xsl:apply-templates>
                </xsl:element>
            </cmdm:contains>
        </xsl:for-each>
    </xsl:template>

    <!-- a CMD attribute -->
    <xsl:template match="Attribute">
        <xsl:param name="context" tunnel="yes"/>
        <xsl:param name="ns" tunnel="yes"/>
        <xsl:param name="instance" tunnel="yes"/>
        <xsl:variable name="profile" select="."/>
        <xsl:variable name="name" select="Name"/>
        <!-- extend the context with this attribute -->
        <xsl:variable name="id" select="concat(cmd0:path($context,$name),'Attribute')"/>
        <xsl:variable name="has" select="concat(cmd0:path($context,concat('has',$name)),'Attribute')"/>
        <!-- find the matching instances -->
        <xsl:for-each select="$instance/@*[local-name()=$name]">
            <cmdm:containsAttribute>
                <xsl:element name="{$id}" namespace="{$ns}">
                    <xsl:attribute name="rdf:about" select="concat('#',generate-id(.))"/>
                    <xsl:element name="{$has}Value" namespace="{$ns}">
                        <!-- map the CMD XSD datatype to a datatype supported by RDF -->
                        <xsl:attribute name="rdf:datatype" select="concat('&xsd;',cmd0:datatype($profile/Type))"/>
                        <!-- copy the literal -->
                        <xsl:value-of select="."/>
                    </xsl:element>
                    <xsl:if test="exists($profile/ValueScheme/Vocabulary/enumeration)">
                        <xsl:element name="{$has}Entity" namespace="{$ns}">
                            <xsl:attribute name="rdf:resource" select="concat($ns,$id,'ValueScheme',$STEP,replace(.,'\s',''))"/>
                        </xsl:element>
                    </xsl:if>
                </xsl:element>
            </cmdm:containsAttribute>
        </xsl:for-each>
    </xsl:template>
	
	<!-- a VLO facet -->
	<xsl:template match="vlo:*">
		<xsl:element name="vlo:{local-name()}ElementValue">
			<xsl:attribute name="rdf:datatype" select="'&xsd;string'"/>
			<xsl:value-of select="."/>
		</xsl:element>
	</xsl:template>

</xsl:stylesheet>
