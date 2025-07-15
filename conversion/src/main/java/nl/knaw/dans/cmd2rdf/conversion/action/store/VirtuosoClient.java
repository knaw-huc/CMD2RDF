package nl.knaw.dans.cmd2rdf.conversion.action.store;

import java.io.ByteArrayOutputStream;
import java.math.BigInteger;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import javax.ws.rs.client.Client;
import javax.ws.rs.client.ClientBuilder;
import javax.ws.rs.client.Entity;
import javax.ws.rs.client.WebTarget;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;
import javax.ws.rs.core.UriBuilder;
import javax.xml.transform.TransformerConfigurationException;
import javax.xml.transform.TransformerException;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.TransformerFactoryConfigurationError;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;

import nl.knaw.dans.cmd2rdf.conversion.action.ActionException;
import nl.knaw.dans.cmd2rdf.conversion.action.ActionStatus;
import nl.knaw.dans.cmd2rdf.conversion.action.IAction;
import nl.knaw.dans.cmd2rdf.conversion.util.Misc;

import org.apache.commons.io.FileUtils;
import org.glassfish.jersey.client.authentication.HttpAuthenticationFeature;
import org.javasimon.SimonManager;
import org.javasimon.Split;
import org.joda.time.Period;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.w3c.dom.Node;

/**
 * @author Eko Indarto
 *
 */
public class VirtuosoClient implements IAction {
	private static final MediaType MEDIA_TYPE_APPLICATION_RDF_XML =
										new MediaType("application", "rdf+xml");
	private static final Logger errLog = LoggerFactory.getLogger("errorlog");
	private static final String NAMED_GRAPH_IRI = "graph-uri";
	private static final Logger log = LoggerFactory.getLogger(VirtuosoClient.class);
	private Client client;
	private final List<String> replacedPrefixBaseURI = new ArrayList<String>();
	private String prefixBaseURI;
	private String serverURL;
    private ActionStatus act;
	private static int n;
	

	public VirtuosoClient(){
	}

	public void startUp(Map<String, String> vars)
			throws ActionException {
		String replacedPrefixBaseURIVar = vars.get("replacedPrefixBaseURI");
		prefixBaseURI = vars.get("prefixBaseURI");
		serverURL = vars.get("serverURL");
        String username = vars.get("username");
        String password = vars.get("password");
		String action = vars.get("action");
		
		if (replacedPrefixBaseURIVar == null || replacedPrefixBaseURIVar.isEmpty())
			throw new ActionException("replacedPrefixBaseURI is null or empty");
		if (prefixBaseURI == null || prefixBaseURI.isEmpty())
			throw new ActionException("prefixBaseURI is null or empty");
		if (serverURL == null || serverURL.isEmpty())
			throw new ActionException("serverURL is null or empty");
		if (username == null || username.isEmpty())
			throw new ActionException("username is null or empty");
		if (password == null || password.isEmpty())
			throw new ActionException("password is null or empty");
		if (action == null || action.isEmpty())
			throw new ActionException("action is null or empty");
		
		String replacedPrefixBaseURIVars[] = replacedPrefixBaseURIVar.split(",");
		for (String s:replacedPrefixBaseURIVars) {
			if (!s.trim().isEmpty())
				replacedPrefixBaseURI.add(s);
		}
		
		act = Misc.convertToActionStatus(action);
	
		log.debug("VirtuosoClient variables: ");
        log.debug("replacedPrefixBaseURI: {}", replacedPrefixBaseURI);
        log.debug("prefixBaseURI: {}", prefixBaseURI);
        log.debug("serverURL: {}", serverURL);
        log.debug("username: {}", username);
        log.debug("password: {}", password);
        log.debug("action: {}", action);
		log.debug("Start VirtuosoClient....");
		
//		ClientConfig clientConfig = new ClientConfig();
//		clientConfig.connectorProvider(new ApacheConnectorProvider());
//		client = ClientBuilder.newClient(clientConfig);
//		client = ClientBuilder.newClient();
//		HttpAuthenticationFeature authFeature = HttpAuthenticationFeature.digest(username, password);
//		client.register(authFeature);
		
		client = ClientBuilder.newClient();
		HttpAuthenticationFeature authFeature = HttpAuthenticationFeature.digest(username, password);
		client.register(authFeature);
	}

	public Object execute(String path, Object object) throws ActionException {
		Split split = SimonManager.getStopwatch("stopwatch.virtuosoUpload").start();
		boolean status = false;
		switch(act){
			case POST: status = uploadRdfToVirtuoso(path, object);
				break; 
			case DELETE: status = deleteRdfFromVirtuoso(path);
				break;
			default:
		}
		split.stop();
		return status;
	}

	private boolean deleteRdfFromVirtuoso(String path) {
		UriBuilder uriBuilder;
		try {
			String gIRI = getGIRI(path);
			uriBuilder = UriBuilder.fromUri(new URI(serverURL));
			uriBuilder.queryParam(NAMED_GRAPH_IRI, gIRI);
			WebTarget target = client.target(uriBuilder.build());
			Response response = target.request().delete();
			int status = response.getStatus();
			log.info("Upload {} to virtuoso server.\nResponse status: {}",
							path.replace(".xml", ".rdf"), status);
			if ((status == Response.Status.CREATED.getStatusCode()) || (status == Response.Status.OK.getStatusCode())){
				n++;
				log.info("[{}] is DELETED.", n);
				return true;
			} else {
				errLog.error(">>>>>>>>>> ERROR: {}\t{}", status, path);
			}
		} catch (URISyntaxException e) {
			errLog.error("ERROR: URISyntaxException, caused by {}", e.getMessage(), e);
		} catch (ActionException e) {
			errLog.error("ERROR: ActionException, caused by {}", e.getMessage(), e);
		}

		return false;
	}

	private String getGIRI(String path) throws ActionException {
		String gIRI = null;
		for (String s:replacedPrefixBaseURI) {
			if (path.startsWith(s)) {
				gIRI = path.replace(s, this.prefixBaseURI)
						   .replace(".xml", ".rdf")
						   .replaceAll(" ", "_");
				break;
			}
		}
		if (gIRI==null) {
			throw new ActionException("gIRI ERROR: " + path + " is not found as prefix in " + replacedPrefixBaseURI);
		}

		return gIRI;
	}

	private boolean uploadRdfToVirtuoso(String path, Object object)
			throws ActionException {
		if (object instanceof Node) {
			String fileName = path.replace(".xml", ".rdf");
			log.info("Upload '{}'.", fileName);
			Node node = (Node)object;
			DOMSource source = new DOMSource(node);
			ByteArrayOutputStream bos = new ByteArrayOutputStream();
			StreamResult result = new StreamResult(bos);
			try {
				log.info("START transformation from DOMSource to RDF");
				long startTrans = System.currentTimeMillis();
				TransformerFactory.newInstance().newTransformer().transform(source,result);
				Period p = new Period(System.currentTimeMillis() - startTrans);
				log.info("END transformation from DOMSource to RDF. Duration: {} minutes, {} secs, {} ms.",
							p.getMinutes(), p.getSeconds(), p.getMillis());

				byte[] bytes = bos.toByteArray();
				log.info("{} has BYTES SIZE : {}", fileName,
								FileUtils.byteCountToDisplaySize(BigInteger.valueOf(bytes.length)));

				long startUpload = System.currentTimeMillis();

				String gIRI = getGIRI(path);
				UriBuilder uriBuilder = UriBuilder.fromUri(new URI(serverURL));
				uriBuilder.queryParam(NAMED_GRAPH_IRI, gIRI);
				WebTarget target = client.target(uriBuilder.build());

				Response response = target.request().post(Entity.entity(bytes, MEDIA_TYPE_APPLICATION_RDF_XML));
				int status = response.getStatus();
				log.info("'{}' is uploaded to virtuoso server.\nResponse status: {}",
								path.replace(".xml", ".rdf"), status);
				if ((status == Response.Status.CREATED.getStatusCode()) || (status == Response.Status.OK.getStatusCode())){
					n++;
					log.info("[{}] is CREATED. Duration: {} milliseconds.", n, System.currentTimeMillis() - startUpload);
					return true;
				} else {
					log.error(">>>>>>>>>> ERROR: {}", status);
				}

			} catch (TransformerConfigurationException e) {
				errLog.error("ERROR: TransformerConfigurationException, caused by {}", e.getMessage(), e);
			} catch (TransformerException e) {
				errLog.error("ERROR: TransformerException, caused by {}", e.getMessage());
			} catch (TransformerFactoryConfigurationError e) {
				errLog.error("ERROR: TransformerFactoryConfigurationError, caused by {}", e.getMessage(), e);
			} catch (URISyntaxException e) {
				errLog.error("ERROR: URISyntaxException, caused by {}", e.getMessage(), e);
			}
		} else
			throw new ActionException("Unknown input ("+path+", "+object+")");

		return false;
	}

	public void shutDown() throws ActionException {
		if (client != null) {
			client.close();
		}
	}
	
	@Override
	public String name() {
		return this.getClass().getName();
	}

}
