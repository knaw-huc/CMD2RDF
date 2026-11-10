package nl.knaw.dans.cmd2rdf.conversion.action.store;

import nl.knaw.dans.cmd2rdf.conversion.action.ActionException;
import org.apache.commons.io.FileUtils;
import org.glassfish.jersey.client.authentication.HttpAuthenticationFeature;
import org.javasimon.SimonManager;
import org.javasimon.Split;
import org.joda.time.Period;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.w3c.dom.Node;
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
import java.util.Map;

/**
 * A linked data store REST client that makes use of a REST API to upload content to the store,
 * or delete content from the store.
 */
public class GraphDBStoreClient extends StoreClient {

    private static final Logger ERROR_LOG = LoggerFactory.getLogger("errorlog");
    private static final Logger LOG = LoggerFactory.getLogger(GraphDBStoreClient.class);
    private static final Logger ERROR_FILES_LOG = LoggerFactory.getLogger("errorfiles");
    private static int n;

    @Override
    public void startUp(Map<String, String> vars) throws ActionException {
        super.startUp(vars);

        if (credentialsProvided()) {
            LOG.info("Using provided credentials for user '{}' for HTTP Basic authentication", getUserName());
            HttpAuthenticationFeature authFeature = HttpAuthenticationFeature.basic(getUserName(), getPassword());
            getClient().register(authFeature);
        }

        LOG.debug("StoreClient variables: ");
        LOG.debug("replacedPrefixBaseURI: {}", getReplacedPrefixBaseURI());
        LOG.debug("prefixBaseURI: {}", getPrefixBaseURI());
        LOG.debug("serverURL: {}", getServerURL());
        LOG.debug("userName: {}", getUserName());
        LOG.debug("action: {}", getAction());
        LOG.debug("namedGIRIParam: {}", getNamedGIRIQueryParam() != null ? getNamedGIRIQueryParam() : "N/A");
    }

    @Override
    public Object execute(String path, Object object) throws ActionException {
        Split split = SimonManager.getStopwatch("stopwatch.storeUpload").start();
        boolean status = false;
        switch(getActionStatus()) {
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
                UriBuilder uriBuilder = UriBuilder.fromUri(new URI(getServerURL()));
                String giri = GIRI.build(path, getReplacedPrefixBaseURI(), getPrefixBaseURI());
                uriBuilder.queryParam(getNamedGIRIQueryParam(), doNamedGIRIEncloseWithBrackets() ? "<" + giri + ">" : giri);
                WebTarget target = getClient().target(uriBuilder.build());

                // Do request
                Response response = target.request().put(
                        Entity.entity(bytes, StoreMediaTypes.APPLICATION_RDF_XML.getMediaType()));

                int status = response.getStatus();
                LOG.info("'{}' is uploaded to store.\nResponse status: {}",
                        path.replace(".xml", ".rdf"), status);
                if ((status == Response.Status.CREATED.getStatusCode())
                        || (status == Response.Status.OK.getStatusCode())
                        || (status == Response.Status.NO_CONTENT.getStatusCode())) {
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
            uriBuilder = UriBuilder.fromUri(new URI(getServerURL()));
            uriBuilder.queryParam(getNamedGIRIQueryParam(), GIRI.build(path, getReplacedPrefixBaseURI(), getPrefixBaseURI()));
            WebTarget target = getClient().target(uriBuilder.build());
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
        } catch (GIRIException e) {
            ERROR_LOG.error("ERROR: GIRIException, caused by {}", e.getMessage(), e);
        }

        return false;
    }

    private boolean credentialsProvided() {
        return getUserName() != null && !getUserName().isEmpty() && getPassword() != null && !getPassword().isEmpty();
    }

}