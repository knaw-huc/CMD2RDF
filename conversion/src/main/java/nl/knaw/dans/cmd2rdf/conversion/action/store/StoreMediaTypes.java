package nl.knaw.dans.cmd2rdf.conversion.action.store;

import javax.ws.rs.core.MediaType;

/**
 * (RDF) store media types
 */
public enum StoreMediaTypes {

    APPLICATION_RDF_XML("application", "rdf+xml");

    private final MediaType mediaType;

    StoreMediaTypes(String type, String subtype) {
        this.mediaType = new MediaType(type, subtype);
    }

    public MediaType getMediaType() {
        return mediaType;
    }

}
