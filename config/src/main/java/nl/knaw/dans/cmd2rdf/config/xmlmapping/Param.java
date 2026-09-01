package nl.knaw.dans.cmd2rdf.config.xmlmapping;

/**
 * @author Eko Indarto
 *
 */

import jakarta.xml.bind.annotation.XmlAccessType;
import jakarta.xml.bind.annotation.XmlAccessorType;
import jakarta.xml.bind.annotation.XmlAttribute;
import jakarta.xml.bind.annotation.XmlRootElement;
import jakarta.xml.bind.annotation.XmlValue;

@XmlRootElement (name="param")
@XmlAccessorType(XmlAccessType.FIELD)
public class Param {
	@XmlAttribute
	String name;
	
	@XmlValue
	String value;

}
