package nl.knaw.dans.cmd2rdf.conversion.action.store;

import nl.knaw.dans.cmd2rdf.conversion.action.ActionException;
import nl.knaw.dans.cmd2rdf.conversion.action.ActionStatus;
import nl.knaw.dans.cmd2rdf.conversion.action.IAction;
import nl.knaw.dans.cmd2rdf.conversion.util.Misc;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import javax.ws.rs.client.Client;
import javax.ws.rs.client.ClientBuilder;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public abstract class StoreClient implements IAction {

    private final static Logger LOGGER = LoggerFactory.getLogger(StoreClient.class);

    private final List<String> replacedPrefixBaseURI = new ArrayList<String>();
    private String userName;
    private String password;
    private Client client;
    private String serverURL;
    private ActionStatus actionStatus;
    private String namedGIRIQueryParam;
    private boolean namedGIRIEncloseWithBrackets = false;
    private String prefixBaseURI;
    private String action;

    public String getAccessToken() {
        return accessToken;
    }

    private String accessToken;

    public List<String> getReplacedPrefixBaseURI() {
        return replacedPrefixBaseURI;
    }

    public String getUserName() {
        return userName;
    }

    public String getPassword() {
        return password;
    }

    public Client getClient() {
        return client;
    }

    public String getServerURL() {
        return serverURL;
    }

    public ActionStatus getActionStatus() {
        return actionStatus;
    }

    public String getNamedGIRIQueryParam() {
        return namedGIRIQueryParam;
    }

    public boolean doNamedGIRIEncloseWithBrackets() {
        return namedGIRIEncloseWithBrackets;
    }

    public String getPrefixBaseURI() {
        return prefixBaseURI;
    }

    public String getAction() {
        return action;
    }

    @Override
    public void startUp(Map<String, String> vars) throws ActionException {
        String replacedPrefixBaseURIVar = vars.get(StoreClientParams.REPLACED_PREFIX_BASE_URI.getKey());
        action = vars.get(StoreClientParams.ACTION.getKey());
        userName = vars.get(StoreClientParams.USER_NAME.getKey());
        password = vars.get(StoreClientParams.PASSWORD.getKey());
        serverURL = vars.get(StoreClientParams.SERVER_URL.getKey());
        namedGIRIQueryParam = vars.get(StoreClientParams.NAMED_GRAPH_IRI_QUERY_PARAM.getKey());
        namedGIRIEncloseWithBrackets =
                Boolean.parseBoolean(vars.get(StoreClientParams.NAMED_GRAPH_IRI_ENCLOSE_WITH_BRACKETS.getKey()));
        prefixBaseURI = vars.get(StoreClientParams.PREFIX_BASE_URI.getKey());
        accessToken = vars.get(StoreClientParams.ACCESS_TOKEN.getKey());
        namedGIRIEncloseWithBrackets =
                Boolean.parseBoolean(vars.get(StoreClientParams.NAMED_GRAPH_IRI_ENCLOSE_WITH_BRACKETS.getKey()));

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

        client = ClientBuilder.newClient();
        client.register(new BodyLoggingFilter());

        LOGGER.debug("StoreClient variables: ");
        LOGGER.debug("replacedPrefixBaseURI: {}", replacedPrefixBaseURI);
        LOGGER.debug("prefixBaseURI: {}", prefixBaseURI);
        LOGGER.debug("serverURL: {}", serverURL);
        LOGGER.debug("userName: {}", userName);
        LOGGER.debug("action: {}", action);
        LOGGER.debug("namedGIRIParam: {}", namedGIRIQueryParam != null ? namedGIRIQueryParam : "N/A");
    }

    @Override
    public void shutDown() throws ActionException {
        if (client != null) {
            client.close();
        }
    }

}
