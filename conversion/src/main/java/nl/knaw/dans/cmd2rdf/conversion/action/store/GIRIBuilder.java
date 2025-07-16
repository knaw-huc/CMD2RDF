package nl.knaw.dans.cmd2rdf.conversion.action.store;

import java.util.List;

public class GIRIBuilder {

    private final List<String> replacedPrefixBaseURI;
    private final String prefixBaseURI;

    public GIRIBuilder(List<String> replacedPrefixBaseURI, String prefixBaseURI) {
        this.replacedPrefixBaseURI = replacedPrefixBaseURI;
        this.prefixBaseURI = prefixBaseURI;
    }


    public String getGIRI(String path) throws IllegalArgumentException {
        if (path == null) {
            throw new IllegalArgumentException("gIRI ERROR: provided path is non-existent");
        }
        String gIRI = null;
        for (String s : replacedPrefixBaseURI) {
            if (path.startsWith(s)) {
                gIRI = path.replace(s, this.prefixBaseURI).replace(".xml", ".rdf")
                                .replaceAll(" ", "_");
                break;
            }
        }

        if (gIRI == null) {
            throw new IllegalArgumentException("gIRI ERROR: " + path + " is not found as prefix in " + replacedPrefixBaseURI);
        }

        return gIRI;
    }

}
