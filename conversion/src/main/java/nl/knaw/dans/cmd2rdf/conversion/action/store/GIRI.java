package nl.knaw.dans.cmd2rdf.conversion.action.store;

import java.util.List;

public class GIRI {

    public static String build(String path, List<String> replacedPrefixBaseURI, String prefixBaseURI) throws GIRIException {
        String gIRI = null;
        for (String s:replacedPrefixBaseURI) {
            if (path.startsWith(s)) {
                gIRI = path.replace(s, prefixBaseURI)
                        .replace(".xml", ".rdf")
                        .replaceAll(" ", "_")
                        .replaceFirst("(?i)^(urn:)/+", "$1");
                break;
            }
        }
        if (gIRI == null) {
            throw new GIRIException("GIRI error: " + path + " is not found as prefix in " + replacedPrefixBaseURI);
        }

        return gIRI;
    }

}
