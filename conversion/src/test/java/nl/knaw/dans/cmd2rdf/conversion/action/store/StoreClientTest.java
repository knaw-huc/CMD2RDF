package nl.knaw.dans.cmd2rdf.conversion.action.store;

import nl.knaw.dans.cmd2rdf.conversion.action.ActionException;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.w3c.dom.Document;
import org.w3c.dom.Element;

import javax.ws.rs.client.Client;
import javax.ws.rs.client.Entity;
import javax.ws.rs.client.Invocation;
import javax.ws.rs.client.WebTarget;
import javax.ws.rs.core.Response;
import javax.xml.parsers.DocumentBuilderFactory;
import java.net.URI;
import java.util.HashMap;
import java.util.Map;

import static org.junit.Assert.*;
import static org.mockito.Matchers.any;
import static org.mockito.Mockito.when;

@RunWith(org.mockito.runners.MockitoJUnitRunner.class)
public class StoreClientTest {

    @InjectMocks
    private StoreClient client;

    @Mock
    private Client mockClient;

    @Mock
    private WebTarget mockWebTarget;

    @Mock
    private Invocation.Builder mockBuilder;

    @Mock
    private Response mockResponse;

    private Map<String, String> validVars;

    @Before
    public void setup() throws Exception {
        client = new StoreClient();
        validVars = new HashMap<>();
        validVars.put("replacedPrefixBaseURI", "/path/to/files/");
        validVars.put("prefixBaseURI", "http://localhost:8080/cmd2rdf/graph/");
        validVars.put("username", "testUser");
        validVars.put("password", "testPass");
        validVars.put("serverURL", "http://localhost:8080/store");
        validVars.put("action", "POST");
        validVars.put("namedGraphIRIQueryParam", "graph");

        client.startUp(validVars);
        java.lang.reflect.Field clientField = StoreClient.class.getDeclaredField("client");
        clientField.setAccessible(true);
        clientField.set(client, mockClient);
    }

    @Test
    public void testStartUpWithValidVars() throws Exception {
        client.startUp(validVars);
        // No exception means success
    }

    @Test(expected = ActionException.class)
    public void testStartUpWithMissingPrefixBaseURI() throws Exception {
        validVars.remove("prefixBaseURI");
        client.startUp(validVars);
    }

    @Test(expected = ActionException.class)
    public void testStartUpWithMissingServerURL() throws Exception {
        validVars.remove("serverURL");
        client.startUp(validVars);
    }

    @Test
    public void testShutDownDoesNotThrow() throws Exception {
        client.shutDown();
    }

    @Test
    public void testExecuteWithValidXmlNodeAndCreatedResponse() throws Exception {
        // Create a dummy XML Node
        Document doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().newDocument();
        Element dummyElement = doc.createElement("root");
        dummyElement.setTextContent("test");
        doc.appendChild(dummyElement);

        // Setup mocks
        when(mockClient.target(any(URI.class))).thenReturn(mockWebTarget);
        when(mockWebTarget.request()).thenReturn(mockBuilder);
        when(mockBuilder.post(any(Entity.class))).thenReturn(mockResponse);
        when(mockResponse.getStatus()).thenReturn(Response.Status.CREATED.getStatusCode());

        Object result = client.execute("/path/to/files/test.xml", doc);
        assertTrue((Boolean) result);
    }

    @Test
    public void testExecuteWithValidXmlNodeAndOkResponse() throws Exception {
        // Create a dummy XML Node
        Document doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().newDocument();
        Element dummyElement = doc.createElement("root");
        dummyElement.setTextContent("test");
        doc.appendChild(dummyElement);

        // Setup mocks
        when(mockClient.target(any(URI.class))).thenReturn(mockWebTarget);
        when(mockWebTarget.request()).thenReturn(mockBuilder);
        when(mockBuilder.post(any(Entity.class))).thenReturn(mockResponse);
        when(mockResponse.getStatus()).thenReturn(Response.Status.OK.getStatusCode());

        Object result = client.execute("/path/to/files/test.xml", doc);
        assertTrue((Boolean) result);
    }

    @Test
    public void testExecuteWithValidXmlNodeAndNoContentResponse() throws Exception {
        // Create a dummy XML Node
        Document doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().newDocument();
        Element dummyElement = doc.createElement("root");
        dummyElement.setTextContent("test");
        doc.appendChild(dummyElement);

        // Setup mocks
        when(mockClient.target(any(URI.class))).thenReturn(mockWebTarget);
        when(mockWebTarget.request()).thenReturn(mockBuilder);
        when(mockBuilder.post(any(Entity.class))).thenReturn(mockResponse);
        when(mockResponse.getStatus()).thenReturn(Response.Status.NO_CONTENT.getStatusCode());

        Object result = client.execute("/path/to/files/test.xml", doc);
        assertTrue((Boolean) result);
    }

    @Test
    public void testExecuteWithHttpError() throws Exception {
        Document doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().newDocument();
        Element dummyElement = doc.createElement("root");
        doc.appendChild(dummyElement);

        when(mockClient.target(any(URI.class))).thenReturn(mockWebTarget);
        when(mockWebTarget.request()).thenReturn(mockBuilder);
        when(mockBuilder.post(any(Entity.class))).thenReturn(mockResponse);
        when(mockResponse.getStatus()).thenReturn(500);

        Object result = client.execute("/path/to/files/test.xml", doc);
        assertFalse((Boolean) result);
    }

}