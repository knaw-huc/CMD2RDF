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
import jakarta.xml.bind.annotation.XmlRootElement;


@XmlRootElement (name="class")
@XmlAccessorType(XmlAccessType.FIELD)
public class Clazz {
	@XmlAttribute
	private
	String name;
	
	
	@XmlElementWrapper(name = "properties")
	@XmlElement(name="property")
	private
	List<Property> property;


	public String getName() {
		return name;
	}


	public void setName(String name) {
		this.name = name;
	}


	public List<Property> getProperty() {
		return property;
	}


	public void setProperty(List<Property> property) {
		this.property = property;
	}
	
	
	
}
