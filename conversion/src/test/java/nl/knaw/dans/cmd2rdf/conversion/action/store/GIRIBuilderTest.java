package nl.knaw.dans.cmd2rdf.conversion.action.store;

import org.junit.Before;
import org.junit.Test;

import java.util.ArrayList;
import java.util.Arrays;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.fail;

public class GIRIBuilderTest {

    private GIRIBuilder giriBuilder;

    @Before
    public void setup() {
        giriBuilder = new GIRIBuilder(Arrays.asList("http://oldprefix/", "http://testprefix/"), "http://newprefix/");
    }

    @Test
    public void testGetGIRIWithValidPrefix() {
        String path = "http://oldprefix/data/document.xml";
        String expected = "http://newprefix/data/document.rdf";
        assertEquals(expected, giriBuilder.getGIRI(path));
    }

    @Test
    public void testGetGIRIWithSecondPrefix() {
        String path = "http://testprefix/data/file.xml";
        String expected = "http://newprefix/data/file.rdf";
        assertEquals(expected, giriBuilder.getGIRI(path));
    }

    @Test
    public void testGetGIRIWithSpaces() {
        String path = "http://oldprefix/data with spaces/document.xml";
        String expected = "http://newprefix/data_with_spaces/document.rdf";
        assertEquals(expected, giriBuilder.getGIRI(path));
    }

    @Test(expected = IllegalArgumentException.class)
    public void testGetGIRIWithNoMatchingPrefix() {
        String path = "http://unknownprefix/data/document.xml";
        try {
            giriBuilder.getGIRI(path);
            fail("Expected IllegalArgumentException");
        } catch (IllegalArgumentException e) {
            assertEquals("gIRI ERROR: http://unknownprefix/data/document.xml is not found as prefix in [http://oldprefix/, http://testprefix/]",
                    e.getMessage());
            throw e;
        }
    }

    @Test(expected = IllegalArgumentException.class)
    public void testGetGIRIWithEmptyPrefixList() {
        GIRIBuilder emptyBuilder = new GIRIBuilder(new ArrayList<String>(), "http://newprefix/");
        String path = "http://oldprefix/data/document.xml";
        try {
            emptyBuilder.getGIRI(path);
            fail("Expected IllegalArgumentException");
        } catch (IllegalArgumentException e) {
            assertEquals("gIRI ERROR: http://oldprefix/data/document.xml is not found as prefix in []",
                    e.getMessage());
            throw e;
        }
    }

    @Test(expected = IllegalArgumentException.class)
    public void testGetGIRIWithNullPath() {
        giriBuilder.getGIRI(null);
    }

}
