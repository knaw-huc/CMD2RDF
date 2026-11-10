package nl.knaw.dans.cmd2rdf.conversion.action.store;

public enum StoreClientParams {

    REPLACED_PREFIX_BASE_URI("replacedPrefixBaseURI"),
    PREFIX_BASE_URI("prefixBaseURI"),
    NAMED_GRAPH_IRI_QUERY_PARAM("namedGraphIRIQueryParam"),
    SERVER_URL("serverURL"),
    USER_NAME("username"),
    PASSWORD("password"),
    ACTION("action"),
    DEBUG_STORE_HTTP_REQUEST_RESPONSE("debugStoreHttpRequestResponse"),
    NAMED_GRAPH_IRI_ENCLOSE_WITH_BRACKETS("namedGraphIRIEncloseWithBrackets"),
    ACCESS_TOKEN("accessToken");

    private final String val;

    StoreClientParams(String val) {
        this.val = val;
    }

    public String getKey() {
        return val;
    }

}