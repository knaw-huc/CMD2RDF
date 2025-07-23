package nl.knaw.dans.cmd2rdf.conversion.action.store;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.util.Collection;
import java.util.Map;

import nl.knaw.dans.cmd2rdf.conversion.action.ActionException;
import nl.knaw.dans.cmd2rdf.conversion.action.IAction;

import org.apache.commons.io.FileUtils;
import org.javasimon.SimonManager;
import org.javasimon.Split;
import org.joda.time.Period;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * @author Eko Indarto
 *
 */
public class VirtuosoBulkImporter implements IAction {

	private static final Logger ERROR_LOG = LoggerFactory.getLogger("errorlog");
	private static final Logger log = LoggerFactory.getLogger(VirtuosoBulkImporter.class);
    private boolean skip;
	private String[] virtuosoBulkImport;

	private enum ClientParams {
		BULK_IMPORT_SHELL_PATH("bulkImportShellPath"),
		HOST("host"),
		PORT("port"),
		USERNAME("username"),
		PASSWORD("password"),
		RDF_DIR("rdfDir");

		private final String val;

		ClientParams(String val) {
			this.val = val;
		}
	}

	public VirtuosoBulkImporter(){
	}

	public void startUp(Map<String, String> vars) throws ActionException {
		String bulkImportShellPath = vars.get(ClientParams.BULK_IMPORT_SHELL_PATH.val);
		String host = vars.get(ClientParams.HOST.val);
		String port = vars.get(ClientParams.PORT.val);
		String username = vars.get(ClientParams.USERNAME.val);
		String password = vars.get(ClientParams.PASSWORD.val);
		String rdfDir = vars.get(ClientParams.RDF_DIR.val);
        String bulkImportShellFile;

        if (bulkImportShellPath == null || bulkImportShellPath.isEmpty()) {
			throw new ActionException(this.name() + ": bulkImportShellPath is null or empty");
		} else {
			bulkImportShellFile = bulkImportShellPath.trim();
			//Check whether the virtuoso_bulk_import.sh is executable or not.
			File file = new File(bulkImportShellFile);
			if (!file.exists() || !file.isFile())
				throw new ActionException(this.name() + "'" + bulkImportShellFile + "' doesn't exist or not a file.");
			if (!file.canExecute())
				throw new ActionException(this.name() + "'" + bulkImportShellFile + "' is not executable file. Try: chmod a+x to the file.");
		}
		if (host == null || host.isEmpty())
			throw new ActionException(this.name() + ": host is null or empty");
		if (port == null || port.isEmpty())
			throw new ActionException(this.name() + ": port is null or empty");
		if (username == null || username.isEmpty())
			throw new ActionException(this.name() + ": username is null or empty");
		if (rdfDir == null || rdfDir.isEmpty())
			throw new ActionException(this.name() + ": rdfDir is null or empty");
		
		File file = new File(rdfDir);
		if (!file.exists() || !file.isDirectory()) {
			skip=true;
            ERROR_LOG.error("Directory '{}' does not exist.", rdfDir);
		} 
		
		//"/data/cmdi2rdf/virtuoso/bin/isql 1111  dba dba exec="ld_dir_all('/data/cmdi2rdf/BIG-files/rdf-output/','*.rdf','http://eko.indarto/tst.rdf');"
		
		if(!skip)
			virtuosoBulkImport = new String[]{bulkImportShellFile, host + ":" + port, username, password, rdfDir};
	}

	public Object execute(String path, Object object) throws ActionException {
		if (!skip) {
			Split split = SimonManager.getStopwatch("stopwatch.bulkimport").start();
			boolean status = executeBulkImport();
			split.stop();
			if (!status) {
				ERROR_LOG.error("FATAL ERROR, THE BULK IMPORT IS FAILED ---> SYSTEM TERMINATED.");
				System.exit(1);
			}
			return status;
		} 
		return skip;
	}


	private boolean executeBulkImport() throws ActionException {
		boolean ok=false;
		log.info("######## START EXECUTING BULK IMPORT ###############");
		for (String s:virtuosoBulkImport)
            log.info("BULK COMMAND: {}", s);
		
		long start = System.currentTimeMillis();
		Collection<File> cf = FileUtils.listFiles(new File(virtuosoBulkImport[virtuosoBulkImport.length-1]),
									new String[]{"rdf", "graph"}, true);
    	log.info("============= Trying to import '{}' files.", cf.size());
		ok = executeIsql(virtuosoBulkImport);
		
		if (!ok)
			ERROR_LOG.error("ERROR>>>>> BULK IMPORT EXECUTION IS FAILED");
		
		long duration = System.currentTimeMillis() - start;
		Period p = new Period(duration);
		log.info("######## END BULK IMPORT ###############");
        log.info("DURATION: {} hours, {} minutes, {} secs, {} msec.", p.getHours(), p.getMinutes(), p.getSeconds(), p.getMillis());
		return ok;
	}

	private boolean executeIsql(String[] args) throws ActionException {
		boolean ok = false;
		StringBuilder output = new StringBuilder();
		Process process;
		try {
			process = Runtime.getRuntime().exec(args);
			while (process.waitFor() != 0) {
				log.info("process...");
			}

			BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
			String line = "";
			while ((line = reader.readLine())!= null) {
				output.append(line).append("\n");
			}
			String outputStr = output.toString();
			log.info(outputStr);
			ok = outputStr.contains("Done.") && outputStr.contains("msec.");

		} catch (Exception e) {
            ERROR_LOG.error("ERROR: {}", e.getMessage(), e);
			throw new ActionException("ERROR: " + e.getMessage());
		}
		return ok;
	}

	public void shutDown() throws ActionException {
	}

	@Override
	public String name() {
		return this.getClass().getName();
	}

}
