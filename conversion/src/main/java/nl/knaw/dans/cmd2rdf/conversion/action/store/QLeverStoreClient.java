package nl.knaw.dans.cmd2rdf.conversion.action.store;

import nl.knaw.dans.cmd2rdf.conversion.action.ActionException;
import org.apache.http.HttpStatus;
import org.apache.jena.riot.Lang;
import org.apache.jena.riot.RDFParser;
import org.apache.jena.riot.RiotException;
import org.apache.jena.riot.system.StreamRDF;
import org.apache.jena.riot.system.StreamRDFWriter;
import org.javasimon.SimonManager;
import org.javasimon.Split;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.w3c.dom.Node;

import javax.ws.rs.client.Entity;
import javax.ws.rs.client.Invocation;
import javax.ws.rs.core.HttpHeaders;
import javax.ws.rs.core.Response;
import javax.ws.rs.core.UriBuilder;
import javax.xml.transform.TransformerException;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.util.Map;

/**
 * Sends graphs to a QLever endpoint using the SPARQL 1.1 Graph Store HTTP Protocol.
 * <p>
 * QLever does not accept RDF/XML, so each record is converted to N-Triples first.
 * Action POST replaces the record's named graph (HTTP PUT), action DELETE drops it (HTTP DELETE).
 * Updates require the QLever access token, which is sent as a Bearer token.
 */
public class QLeverStoreClient extends StoreClient {

    private static final Logger ERROR_LOG = LoggerFactory.getLogger("errorlog");
    private static final Logger LOG = LoggerFactory.getLogger(QLeverStoreClient.class);
    private static final Logger ERROR_FILES_LOG = LoggerFactory.getLogger("errorfiles");

    @Override
    public void startUp(Map<String, String> vars) throws ActionException {
        super.startUp(vars);
        if (getAccessToken() == null) {
            throw new ActionException("accessToken is null or empty");
        }

        LOG.debug("QLeverStoreClient variables: replacedPrefixBaseURI: {}, prefixBaseURI: {}, qleverURL: {}, action: {}",
                getReplacedPrefixBaseURI(), getPrefixBaseURI(), getServerURL(), getAction());
    }

    @Override
    public Object execute(String path, Object object) throws ActionException {
        Split split = SimonManager.getStopwatch("stopwatch.qleverUpload").start();
        try {
            switch (getActionStatus()) {
                case POST:
                    return putGraph(path, object);
                case DELETE:
                    return deleteGraph(path);
                default:
                    return false;
            }
        } finally {
            split.stop();
        }
    }

    @Override
    public String name() {
        return this.getClass().getName();
    }

    private boolean putGraph(String path, Object object) throws ActionException {
        if (!(object instanceof Node)) {
            return false;
        }
        String giri = GIRI.build(path, getReplacedPrefixBaseURI(), getPrefixBaseURI());
        try {
            byte[] nTriples = toNTriples((Node) object, giri);
            long start = System.currentTimeMillis();
            Response response = request(giri).put(
                    Entity.entity(nTriples, StoreMediaTypes.APPLICATION_N_TRIPLES.getMediaType()));
            int status = response.getStatus();
            response.close();
            if (status == HttpStatus.SC_OK
                    || status == HttpStatus.SC_CREATED
                    || status == HttpStatus.SC_NO_CONTENT) {
                LOG.info("PUT graph <{}>: status {}, {} ms.", giri, status, System.currentTimeMillis() - start);
                return true;
            }
            LOG.error(">>>>>>>>>> ERROR: PUT graph <{}>: status {}", giri, status);
            ERROR_FILES_LOG.info(path);
        } catch (TransformerException | RiotException e) {
            ERROR_LOG.error("ERROR: converting {} to N-Triples, caused by {}", path, e.getMessage(), e);
        } catch (RuntimeException e) {
            ERROR_LOG.error("ERROR: uploading {} to QLever, caused by {}", path, e.getMessage(), e);
        }
        throw new ActionException("Failed to upload " + path + " to QLever");
    }

    private boolean deleteGraph(String path) {
        try {
            String giri = GIRI.build(path, getReplacedPrefixBaseURI(), getPrefixBaseURI());
            Response response = request(giri).delete();
            int status = response.getStatus();
            response.close();
            if (status == HttpStatus.SC_OK
                    || status == HttpStatus.SC_NO_CONTENT
                    || status == HttpStatus.SC_NOT_FOUND) {
                LOG.info("DELETE graph <{}>: status {}", giri, status);
                return true;
            }
            ERROR_LOG.error(">>>>>>>>>> ERROR: DELETE graph <{}>: status {}\t{}", giri, status, path);
        } catch (GIRIException e) {
            ERROR_LOG.error("ERROR: deleting {} from QLever, caused by {}", path, e.getMessage(), e);
        }
        return false;
    }

    private Invocation.Builder request(String giri) {
        return getClient().target(UriBuilder.fromUri(getServerURL()).queryParam("graph", giri))
                          .request()
                          .header(HttpHeaders.AUTHORIZATION, "Bearer " + getAccessToken());
    }

    private String toBaseIRI(String iri) {
        String nss = iri.replaceAll("[^A-Za-z0-9._~-]", "_");
        return "urn:x-ost-clarin-skg:" + nss;
    }

    private byte[] toNTriples(Node node, String baseIRI) throws TransformerException {
        ByteArrayOutputStream rdfXml = new ByteArrayOutputStream();
        TransformerFactory.newInstance().newTransformer().transform(new DOMSource(node), new StreamResult(rdfXml));
        ByteArrayOutputStream nTriples = new ByteArrayOutputStream();
        StreamRDF writer = StreamRDFWriter.getWriterStream(nTriples, Lang.NTRIPLES);
        RDFParser.create().source(new ByteArrayInputStream(rdfXml.toByteArray()))
                          .lang(Lang.RDFXML)
                          .base(toBaseIRI(baseIRI))
                          .parse(writer);
        return nTriples.toByteArray();
    }

}
