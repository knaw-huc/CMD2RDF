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
public class Component{
	
	@XmlAttribute(required = false)
	String desc;
	
	@XmlAttribute(required = true)
	String filter;
	
	@XmlAttribute(required = true)
	String xmlSource;
	
	@XmlElementWrapper(name = "actions")
	@XmlElement(name="action")
	List<Action> actions;
	
}

