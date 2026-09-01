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
public class Profile{
	
	@XmlAttribute(required = false)
	private
	String desc;
	
	@XmlAttribute(required = true)
	private
	String filter;
	
	@XmlAttribute(required = true)
	private
	String xmlSource;
	
	@XmlElementWrapper(name = "actions")
	@XmlElement(name="action")
	private
	List<Action> actions;

	public String getDesc() {
		return desc;
	}

	public void setDesc(String desc) {
		this.desc = desc;
	}

	public String getFilter() {
		return filter;
	}

	public void setFilter(String filter) {
		this.filter = filter;
	}

	public List<Action> getActions() {
		return actions;
	}

	public void setActions(List<Action> actions) {
		this.actions = actions;
	}

	public String getXmlSource() {
		return xmlSource;
	}

	public void setXmlSource(String xmlSource) {
		this.xmlSource = xmlSource;
	}
	
}

