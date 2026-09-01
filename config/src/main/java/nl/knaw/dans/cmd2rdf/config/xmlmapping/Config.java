package nl.knaw.dans.cmd2rdf.config.xmlmapping;

/**
 * @author Eko Indarto
 *
 */

import java.util.List;

import jakarta.xml.bind.annotation.XmlAccessType;
import jakarta.xml.bind.annotation.XmlAccessorType;
import jakarta.xml.bind.annotation.XmlAttribute;
import jakarta.xml.bind.annotation.XmlElement;
import jakarta.xml.bind.annotation.XmlElementWrapper;

@XmlAccessorType(XmlAccessType.FIELD)
public class Config {
	
	
	@XmlAttribute
	String version;
	
	@XmlElementWrapper(name = "properties")
	@XmlElement(name="property")
	private
	List<Property> property;

	public List<Property> getProperty() {
		return property;
	}

	public void setProperty(List<Property> property) {
		this.property = property;
	}
}
