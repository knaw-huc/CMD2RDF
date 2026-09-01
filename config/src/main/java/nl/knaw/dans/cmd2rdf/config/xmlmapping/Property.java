package nl.knaw.dans.cmd2rdf.config.xmlmapping;

/**
 * @author Eko Indarto
 *
 */

import jakarta.xml.bind.annotation.XmlAccessType;
import jakarta.xml.bind.annotation.XmlAccessorType;
import jakarta.xml.bind.annotation.XmlAttribute;
import jakarta.xml.bind.annotation.XmlValue;

@XmlAccessorType(XmlAccessType.FIELD)
public class Property {
	@XmlAttribute
	public String name;
	
	@XmlValue
	public String value;

	public String getValue() {
		return value;
	}

	public void setValue(String value) {
		this.value = value;
	}
}
