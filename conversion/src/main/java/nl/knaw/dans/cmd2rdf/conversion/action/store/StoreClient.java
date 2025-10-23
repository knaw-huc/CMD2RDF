package nl.knaw.dans.cmd2rdf.conversion.action.store;

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

import javax.ws.rs.client.Client;
import javax.ws.rs.client.ClientBuilder;
import javax.ws.rs.client.Entity;
import javax.ws.rs.client.WebTarget;
import javax.ws.rs.core.Response;
import javax.ws.rs.core.UriBuilder;
import javax.xml.transform.TransformerConfigurationException;
import javax.xml.transform.TransformerException;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.TransformerFactoryConfigurationError;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import java.io.ByteArrayOutputStream;
import java.math.BigInteger;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * A linked data store REST client that makes use of a REST API to upload content to the store,
 * or delete content from the store.
 */
public class StoreClient implements IAction {

    private static final Logger ERROR_LOG = LoggerFactory.getLogger("errorlog");
    private static final Logger LOG = LoggerFactory.getLogger(StoreClient.class);
    private static int n;
    private final List<String> replacedPrefixBaseURI = new ArrayList<String>();
    private String userName;
    private String password;
    private Client client;
    private String serverURL;
    private ActionStatus actionStatus;
    private String namedGIRIQueryParam;
    private boolean namedGIRIEncloseWithBrackets = false;
    private String prefixBaseURI;

    private enum ClientParams {
        REPLACED_PREFIX_BASE_URI("replacedPrefixBaseURI"),
        PREFIX_BASE_URI("prefixBaseURI"),
        NAMED_GRAPH_IRI_QUERY_PARAM("namedGraphIRIQueryParam"),
        SERVER_URL("serverURL"),
        USER_NAME("username"),
        PASSWORD("password"),
        ACTION("action"),
        DEBUG_STORE_HTTP_REQUEST_RESPONSE("debugStoreHttpRequestResponse"),
        NAMED_GRAPH_IRI_ENCLOSE_WITH_BRACKETS("namedGraphIRIEncloseWithBrackets");

        private final String val;

        ClientParams(String val) {
            this.val = val;
        }
    }

    @Override
    public void startUp(Map<String, String> vars) throws ActionException {
        String replacedPrefixBaseURIVar = vars.get(ClientParams.REPLACED_PREFIX_BASE_URI.val);
        String action = vars.get(ClientParams.ACTION.val);
        userName = vars.get(ClientParams.USER_NAME.val);
        password = vars.get(ClientParams.PASSWORD.val);
        serverURL = vars.get(ClientParams.SERVER_URL.val);
        namedGIRIQueryParam = vars.get(ClientParams.NAMED_GRAPH_IRI_QUERY_PARAM.val);
        namedGIRIEncloseWithBrackets = Boolean.parseBoolean(vars.get(ClientParams.NAMED_GRAPH_IRI_ENCLOSE_WITH_BRACKETS.val));
        prefixBaseURI = vars.get(ClientParams.PREFIX_BASE_URI.val);
        String prefixBaseURI = vars.get(ClientParams.PREFIX_BASE_URI.val);

        if (replacedPrefixBaseURIVar == null || replacedPrefixBaseURIVar.isEmpty()) {
            throw new ActionException("replacedPrefixBaseURI is null or empty");
        }
        if (prefixBaseURI == null || prefixBaseURI.isEmpty()) {
            throw new ActionException("prefixBaseURI is null or empty");
        }
        if (serverURL == null || serverURL.isEmpty()) {
            throw new ActionException("serverURL is null or empty");
        }
        if (action == null || action.isEmpty()) {
            throw new ActionException("action is null or empty");
        }

        String[] replacedPrefixBaseURIVars = replacedPrefixBaseURIVar.split(",");
        for (String s : replacedPrefixBaseURIVars) {
            if (!s.trim().isEmpty())
                replacedPrefixBaseURI.add(s);
        }

        actionStatus = Misc.convertToActionStatus(action);

        client = ClientBuilder.newClient();
        if (credentialsProvided()) {
            LOG.info("Using provided credentials for user '{}' for HTTP Basic authentication", userName);
            HttpAuthenticationFeature authFeature = HttpAuthenticationFeature.basic(userName, password);
            client.register(authFeature);
        }
        client.register(new BodyLoggingFilter());

        LOG.debug("StoreClient variables: ");
        LOG.debug("replacedPrefixBaseURI: {}", replacedPrefixBaseURI);
        LOG.debug("prefixBaseURI: {}", prefixBaseURI);
        LOG.debug("serverURL: {}", serverURL);
        if (credentialsProvided()) {
            LOG.debug("userName: {}", userName);
            LOG.debug("password: {}", password);
        }
        LOG.debug("action: {}", action);
        LOG.debug("namedGIRIParam: {}", namedGIRIQueryParam != null ? namedGIRIQueryParam : "N/A");
        LOG.debug("Start StoreRESTClient....");
    }

    @Override
    public Object execute(String path, Object object) throws ActionException {
        Split split = SimonManager.getStopwatch("stopwatch.storeUpload").start();
        boolean status = false;
        switch(actionStatus) {
            case POST: status = uploadRdfToStore(path, object);
                break;
            case DELETE: status = deleteRdfFromStore(path);
                break;
            default:
        }
        split.stop();
        return status;
    }

    @Override
    public void shutDown() throws ActionException {
        if (client != null) {
            client.close();
        }
    }

    @Override
    public String name() {
        return this.getClass().getName();
    }

    private boolean uploadRdfToStore(String path, Object object) throws ActionException {
        if (object instanceof Node) {
            String fileName = path.replace(".xml", ".rdf");

            LOG.info("Upload '{}'.", fileName);
            Node node = (Node)object;
            DOMSource source = new DOMSource(node);
            ByteArrayOutputStream bos = new ByteArrayOutputStream();
            StreamResult result = new StreamResult(bos);

            try {
                LOG.info("START transformation from DOMSource to RDF");
                long startTrans = System.currentTimeMillis();
                TransformerFactory.newInstance().newTransformer().transform(source,result);
                Period p = new Period(System.currentTimeMillis() - startTrans);
                LOG.info("END transformation from DOMSource to RDF. Duration: {} minutes, {} secs, {} ms.",
                        p.getMinutes(), p.getSeconds(), p.getMillis());

                byte[] bytes = bos.toByteArray();
                LOG.info("{} has BYTES SIZE : {}", fileName,
                        FileUtils.byteCountToDisplaySize(BigInteger.valueOf(bytes.length)));

                long startUpload = System.currentTimeMillis();

                // Build named / context IRI
                UriBuilder uriBuilder = UriBuilder.fromUri(new URI(serverURL));
                String giri = getGIRI(path);
                uriBuilder.queryParam(namedGIRIQueryParam, namedGIRIEncloseWithBrackets ? "<" + giri + ">" : giri);
                WebTarget target = client.target(uriBuilder.build());

                // Do request
                Response response = target.request().post(
                        Entity.entity(bytes, StoreMediaTypes.APPLICATION_RDF_XML.getMediaType()));

                int status = response.getStatus();
                LOG.info("'{}' is uploaded to store.\nResponse status: {}",
                        path.replace(".xml", ".rdf"), status);
                if ((status == Response.Status.CREATED.getStatusCode())
                        || (status == Response.Status.OK.getStatusCode())
                        || (status == Response.Status.NO_CONTENT.getStatusCode())) {
                    n++;
                    LOG.info("[{}] is CREATED. Duration: {} milliseconds.", n,
                            System.currentTimeMillis() - startUpload);
                    return true;
                } else {
                    LOG.error(">>>>>>>>>> ERROR: {}", status);
                }
            } catch (TransformerConfigurationException e) {
                ERROR_LOG.error("ERROR: TransformerConfigurationException, caused by {}", e.getMessage(), e);
            } catch (TransformerException e) {
                ERROR_LOG.error("ERROR: TransformerException, caused by {}", e.getMessage());
            } catch (TransformerFactoryConfigurationError e) {
                ERROR_LOG.error("ERROR: TransformerFactoryConfigurationError, caused by {}", e.getMessage(), e);
            } catch (URISyntaxException e) {
                ERROR_LOG.error("ERROR: URISyntaxException, caused by {}", e.getMessage(), e);
            } catch (IllegalArgumentException e) {
                ERROR_LOG.error("ERROR: IllegalArgumentException, caused by {}", e.getMessage(), e);
            }
            throw new ActionException("Unknown input (" + path + ", " + object + ")");
        }

        return false;
    }

    private boolean deleteRdfFromStore(String path) {
        UriBuilder uriBuilder;
        try {
            uriBuilder = UriBuilder.fromUri(new URI(serverURL));
            uriBuilder.queryParam(namedGIRIQueryParam, getGIRI(path));
            WebTarget target = client.target(uriBuilder.build());
            Response response = target.request().delete();
            int status = response.getStatus();
            LOG.info("Delete {} from store.\nResponse status: {}",
                    path.replace(".xml", ".rdf"), status);
            if ((status == Response.Status.CREATED.getStatusCode())
                    || (status == Response.Status.OK.getStatusCode())
                    || (status == Response.Status.NO_CONTENT.getStatusCode())) {
                n++;
                LOG.info("[{}] is DELETED.", n);
                return true;
            } else {
                ERROR_LOG.error(">>>>>>>>>> ERROR: {}\t{}", status, path);
            }
        } catch (URISyntaxException e) {
            ERROR_LOG.error("ERROR: URISyntaxException, caused by {}", e.getMessage(), e);
        } catch (ActionException e) {
            ERROR_LOG.error("ERROR: ActionException, caused by {}", e.getMessage(), e);
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

    private boolean credentialsProvided() {
        return userName != null && !userName.isEmpty() && password != null && !password.isEmpty();
    }

}