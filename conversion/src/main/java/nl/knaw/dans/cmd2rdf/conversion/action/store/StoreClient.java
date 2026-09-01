package nl.knaw.dans.cmd2rdf.conversion.action.store;

import nl.knaw.dans.cmd2rdf.conversion.action.ActionException;
import nl.knaw.dans.cmd2rdf.conversion.action.ActionStatus;
import nl.knaw.dans.cmd2rdf.conversion.action.IAction;
import nl.knaw.dans.cmd2rdf.conversion.util.Misc;
import org.apache.commons.io.FileUtils;
import org.javasimon.SimonManager;
import org.javasimon.Split;
import org.joda.time.Period;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.w3c.dom.Node;

import javax.xml.transform.TransformerConfigurationException;
import javax.xml.transform.TransformerException;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.TransformerFactoryConfigurationError;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.math.BigInteger;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Map;

/**
 * A linked data store REST client that makes use of a REST API to upload content to the store,
 * or delete content from the store.
 */
public class StoreClient implements IAction {

    private static final Logger ERROR_LOG = LoggerFactory.getLogger("errorlog");
    private static final Logger LOG = LoggerFactory.getLogger(StoreClient.class);
    private static final Logger ERROR_FILES_LOG = LoggerFactory.getLogger("errorfileslog");

    private static final String APPLICATION_RDF_XML = "application/rdf+xml";

    private static int n;
    private final List<String> replacedPrefixBaseURI = new ArrayList<String>();
    private String userName;
    private String password;
    private HttpClient client;
    private String authorization;
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

        client = HttpClient.newHttpClient();
        if (credentialsProvided()) {
            LOG.info("Using provided credentials for user '{}' for HTTP Basic authentication", userName);
            authorization = "Basic " + Base64.getEncoder().encodeToString(
                    (userName + ":" + password).getBytes(StandardCharsets.UTF_8));
        }

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
                String giri = getGIRI(path);
                URI uri = buildStoreURI(namedGIRIEncloseWithBrackets ? "<" + giri + ">" : giri);

                // Do request
                HttpRequest request = newRequestBuilder(uri)
                        .header("Content-Type", APPLICATION_RDF_XML)
                        .PUT(HttpRequest.BodyPublishers.ofByteArray(bytes))
                        .build();
                HttpResponse<String> response = send(request, bytes);

                int status = response.statusCode();
                LOG.info("'{}' is uploaded to store.\nResponse status: {}",
                        path.replace(".xml", ".rdf"), status);
                if (isSuccessful(status)) {
                    n++;
                    LOG.info("[{}] is CREATED. Duration: {} milliseconds.", n, System.currentTimeMillis() - startUpload);
                    return true;
                } else {
                    LOG.error(">>>>>>>>>> ERROR: {}", status);
                    ERROR_FILES_LOG.info(path.replace(".rdf", ".xml"));
                }
            } catch (TransformerConfigurationException e) {
                ERROR_LOG.error("ERROR: TransformerConfigurationException, caused by {}", e.getMessage(), e);
            } catch (TransformerException e) {
                ERROR_LOG.error("ERROR: TransformerException, caused by {}", e.getMessage());
            } catch (TransformerFactoryConfigurationError e) {
                ERROR_LOG.error("ERROR: TransformerFactoryConfigurationError, caused by {}", e.getMessage(), e);
            } catch (URISyntaxException e) {
                ERROR_LOG.error("ERROR: URISyntaxException, caused by {}", e.getMessage(), e);
            } catch (IOException e) {
                ERROR_LOG.error("ERROR: IOException, caused by {}", e.getMessage(), e);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                ERROR_LOG.error("ERROR: InterruptedException, caused by {}", e.getMessage(), e);
            } catch (IllegalArgumentException e) {
                ERROR_LOG.error("ERROR: IllegalArgumentException, caused by {}", e.getMessage(), e);
            }
            throw new ActionException("Unknown input (" + path + ", " + object + ")");
        }

        return false;
    }

    private boolean deleteRdfFromStore(String path) {
        try {
            URI uri = buildStoreURI(getGIRI(path));
            HttpRequest request = newRequestBuilder(uri).DELETE().build();
            HttpResponse<String> response = send(request, null);
            int status = response.statusCode();
            LOG.info("Delete {} from store.\nResponse status: {}",
                    path.replace(".xml", ".rdf"), status);
            if (isSuccessful(status)) {
                n++;
                LOG.info("[{}] is DELETED.", n);
                return true;
            } else {
                ERROR_LOG.error(">>>>>>>>>> ERROR: {}\t{}", status, path);
            }
        } catch (URISyntaxException e) {
            ERROR_LOG.error("ERROR: URISyntaxException, caused by {}", e.getMessage(), e);
        } catch (IOException e) {
            ERROR_LOG.error("ERROR: IOException, caused by {}", e.getMessage(), e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            ERROR_LOG.error("ERROR: InterruptedException, caused by {}", e.getMessage(), e);
        } catch (ActionException e) {
            ERROR_LOG.error("ERROR: ActionException, caused by {}", e.getMessage(), e);
        }

        return false;
    }

    /**
     * Appends the named / context IRI as query parameter to the configured server URL.
     */
    private URI buildStoreURI(String giri) throws URISyntaxException {
        URI base = new URI(serverURL);
        String query = namedGIRIQueryParam + "=" + giri;
        if (base.getQuery() != null) {
            query = base.getQuery() + "&" + query;
        }
        return new URI(base.getScheme(), base.getAuthority(), base.getPath(), query, base.getFragment());
    }

    private HttpRequest.Builder newRequestBuilder(URI uri) {
        HttpRequest.Builder builder = HttpRequest.newBuilder(uri);
        if (authorization != null) {
            builder.header("Authorization", authorization);
        }
        return builder;
    }

    private HttpResponse<String> send(HttpRequest request, byte[] body) throws IOException, InterruptedException {
        if (LOG.isDebugEnabled()) {
            LOG.debug(">>> REQUEST >>> {} {}", request.method(), request.uri());
            if (body != null) {
                LOG.debug("Request Body: {}", new String(body, StandardCharsets.UTF_8));
            }
        }
        HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
        if (LOG.isDebugEnabled()) {
            LOG.debug("<<< RESPONSE <<< Status: {}", response.statusCode());
            LOG.debug("Response Body: {}", response.body());
        }
        return response;
    }

    private boolean isSuccessful(int status) {
        return status == 200 || status == 201 || status == 204;
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
