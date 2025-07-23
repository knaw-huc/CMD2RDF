package nl.knaw.dans.cmd2rdf.conversion.action.store;

import nl.knaw.dans.cmd2rdf.conversion.action.ActionException;
import nl.knaw.dans.cmd2rdf.conversion.action.IAction;
import org.apache.commons.io.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.io.IOException;
import java.util.Map;

public class CleanDirectory implements IAction {

    private static final Logger LOG = LoggerFactory.getLogger(CleanDirectory.class);
    private static final Logger ERROR_LOG = LoggerFactory.getLogger("errorlog");

    private String directoryToClean;

    @Override
    public void startUp(Map<String, String> vars) throws ActionException {
        directoryToClean = vars.get("directoryToRemove");
        if (directoryToClean == null || directoryToClean.isEmpty()) {
            throw new ActionException("directoryToRemove is null or empty");
        }
    }

    @Override
    public Object execute(String path, Object object) throws ActionException {
        LOG.info("Cleaning directory: {}", directoryToClean);
        if (object != null && (Boolean) object) {
            File file = new File(directoryToClean);
            if (!file.exists() || !file.isDirectory()) {
                ERROR_LOG.error("ERROR: >>>>> {} doesn't exist.", directoryToClean);
            }

            try {
                FileUtils.cleanDirectory(file);
            } catch (IOException e) {
                ERROR_LOG.error("FATAL ERROR: Clearing '{}' failed: {}", directoryToClean, e.getMessage());
            }
        } else {
            ERROR_LOG.error("========= VIRTUOSO ERROR");
        }
        return false;
    }

    @Override
    public void shutDown() throws ActionException {
        // NOTHING
    }

    @Override
    public String name() {
        return this.getClass().getName();
    }

}
