package nl.knaw.dans.cmd2rdf.conversion;

import java.io.StringReader;
import javax.xml.transform.Transformer;
import javax.xml.transform.dom.DOMResult;
import javax.xml.transform.stream.StreamSource;
import junit.framework.TestCase;
import net.sf.saxon.TransformerFactoryImpl;
import org.w3c.dom.Document;
import org.w3c.dom.Element;

public class OSTIdentifierTest extends TestCase {
    private static final String SELF_LINK = "oai:compendium.lr.sign-lang.uni-hamburg.de:treeoflife";
    private static final String VLO_ID = "oai_58_compendium.lr.sign-lang.uni-hamburg.de_58_treeoflife";

    public void testMissingFacetUsesSelfLinkInBothCMDIVersions() throws Exception {
        check("http://www.clarin.eu/cmd/", "", VLO_ID);
        check("http://www.clarin.eu/cmd/1", "", VLO_ID);
    }

    public void testBlankFacetUsesSelfLink() throws Exception {
        check("http://www.clarin.eu/cmd/1", "<vlo:hasFacetId> </vlo:hasFacetId>", VLO_ID);
    }

    public void testExistingFacetTakesPrecedence() throws Exception {
        check("http://www.clarin.eu/cmd/1", "<vlo:hasFacetId>existing-id</vlo:hasFacetId>", "existing-id");
    }

    private void check(String namespace, String facets, String expected) throws Exception {
        Transformer transformer = new TransformerFactoryImpl().newTransformer(new StreamSource(
                getClass().getResource("/xsl/addOST.xsl").toExternalForm()));
        transformer.setParameter("base", "http://localhost:8080/cmd2rdf/graph/treeoflife.xml");
        transformer.setParameter("base_strip", "http://localhost:8080/cmd2rdf/graph/treeoflife.xml");
        String input = "<CMD xmlns='" + namespace + "' xmlns:vlo='http://www.clarin.eu/vlo/'>"
                + "<Header><MdSelfLink>  " + SELF_LINK + "  </MdSelfLink></Header>" + facets + "<Components/></CMD>";
        DOMResult result = new DOMResult();
        transformer.transform(new StreamSource(new StringReader(input)), result);
        Document document = (Document) result.getNode();
        for (String type : new String[] {"Dataset", "Work"}) {
            Element entity = (Element) document.getElementsByTagNameNS("http://purl.org/spar/fabio/", type).item(0);
            assertNotNull(entity);
            assertEquals(expected, entity.getAttributeNS("http://www.w3.org/1999/02/22-rdf-syntax-ns#", "about"));
        }
        assertEquals(SELF_LINK, document.getElementsByTagNameNS(
                "http://www.essepuntato.it/2010/06/literalreification/", "hasLiteralValue").item(0).getTextContent());
    }
}
