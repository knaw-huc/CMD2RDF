/**
 * 
 */
package nl.knaw.dans.cmd2rdf.config;

import java.io.File;
import java.io.FileInputStream;
import java.text.SimpleDateFormat;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import nl.knaw.dans.cmd2rdf.config.exception.ConfigException;
import nl.knaw.dans.cmd2rdf.config.xmlmapping.Jobs;
import nl.knaw.dans.cmd2rdf.config.xmlmapping.Property;

import jakarta.xml.bind.JAXBContext;
import jakarta.xml.bind.Unmarshaller;

/**
 * @author akmi
 *
 */
public class ConfigReader {
	
	private File xmlFile;
	private String rawXmlContent;
	private final Pattern pattern = Pattern.compile("\\{(.*?)\\}");
	private Map<String, String> GLOBAL_VARS = new HashMap<String, String>();

	/**
	 * @param args
	 */
	public static void main(String[] args) {
		// TODO Auto-generated method stub

	}
	
	public ConfigReader(String xmlSrcFilePath) throws ConfigException {
		xmlFile = new File(xmlSrcFilePath);
		if (xmlFile == null || xmlSrcFilePath.isEmpty() || !xmlFile.exists() 
				|| !xmlFile.isFile() || !xmlSrcFilePath.endsWith(".xml"))
			throw new ConfigException("'" + xmlSrcFilePath + "'. The given xml file does not exist or not a xml file.");
	
		init();
	}

	private void init() throws ConfigException{
		try {
			rawXmlContent = new String(java.nio.file.Files.readAllBytes(xmlFile.toPath()), "UTF-8");
			Unmarshaller unmarshaller = JAXBContext.newInstance(Jobs.class).createUnmarshaller();
			Jobs j = (Jobs) unmarshaller.unmarshal(xmlFile);
			fetchConfigProperties(j.getConfig().getProperty());
		} catch (Exception e) {
			throw new ConfigException("Cannot open CMD2RDF FIle. " + e.getMessage());
		}
	}

	private void fetchConfigProperties(List<Property> configPropertyList) {
		for (Property p : configPropertyList) {
			GLOBAL_VARS.put(p.name, p.value);
		}
		//iterate through map, find whether map values contain {val}
		for (Map.Entry<String, String> e : GLOBAL_VARS.entrySet()) {
			String pVal = e.getValue();
			Matcher m = pattern.matcher(pVal);
			if (m.find()) {
				String globalVar = m.group(1);
				if (GLOBAL_VARS.containsKey(globalVar)) {
					pVal = pVal.replace(m.group(0), GLOBAL_VARS.get(globalVar));
					GLOBAL_VARS.put(e.getKey(), pVal);
				}
			}
		}
	}

	public String getTripleStoreServerHost(){
		return GLOBAL_VARS.get("serverHost");
	}

	public String getTripleStoreUsername(){
		return GLOBAL_VARS.get("username");
	}
	
	public String getTripleStorePassword(){
		return GLOBAL_VARS.get("password");
	}
	
	public String getConfigFileLastModifiedDate(){
		SimpleDateFormat sdf = new SimpleDateFormat("EEE, d MMM yyyy HH:mm:ss");
		return sdf.format(xmlFile.lastModified());
	}
	
	public String getRawXmlContent() {
		return rawXmlContent;
	}
	
	public String getPrefixBaseURI() {
		return GLOBAL_VARS.get("prefixBaseURI");
	}
	
	public String getDirDownloadPwd() {
		return GLOBAL_VARS.get("dirDownloadPwd");
	}
	
}
