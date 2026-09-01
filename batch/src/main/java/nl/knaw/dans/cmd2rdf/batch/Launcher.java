package nl.knaw.dans.cmd2rdf.batch;

/**
 * @author Eko Indarto
 *
 */

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.file.Files;

import nl.knaw.dans.cmd2rdf.config.xmlmapping.Jobs;

import jakarta.xml.bind.JAXBContext;
import jakarta.xml.bind.Unmarshaller;
import org.javasimon.SimonManager;
import org.javasimon.Split;
import org.javasimon.Stopwatch;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.bridge.SLF4JBridgeHandler;

public class Launcher {
	private static final Logger log = LoggerFactory.getLogger(Launcher.class);
	private static volatile Stopwatch stopwatchTotal = SimonManager.getStopwatch("stopwatch.total");
	private static volatile Stopwatch stopwatchDb = SimonManager.getStopwatch("stopwatch.db");
	private static volatile Stopwatch stopwatchOai = SimonManager.getStopwatch("stopwatch.oai");
	private static volatile Stopwatch stopwatchTrans1 = SimonManager.getStopwatch("stopwatch.trans1");
	private static volatile Stopwatch stopwatchTrans2 = SimonManager.getStopwatch("stopwatch.trans2");
	private static volatile Stopwatch stopwatchFS = SimonManager.getStopwatch("stopwatch.virtuosoUpload");
	private static volatile Stopwatch stopwatchBI = SimonManager.getStopwatch("stopwatch.bulkimport");
	
    public static void main(String[] args) throws Exception {
    	
    	Split split = stopwatchTotal.start();
    	if (args == null || args.length !=1 
    			|| !(new File (args[0]).isFile())
    			|| !(new File (args[0])).getName().endsWith(".xml")) {
    		System.out.println("An XML configuration file is required.");
    		System.exit(1);
    	}
    	
    	ClassLoader classLoader = Thread.currentThread (). getContextClassLoader ();
    	InputStream inputStream = classLoader.getResourceAsStream ("logging.properties");
//    	java.util.logging.Logger  log = java.util.logging.LogManager.getLogManager().getLogger(java.util.logging.Logger.GLOBAL_LOGGER_NAME);
//    	for (Handler h : log.getHandlers()) {
//    	    h.setLevel(Level.INFO);
//    	}
    	SLF4JBridgeHandler.removeHandlersForRootLogger();
    	java.util.logging.LogManager.getLogManager().readConfiguration(inputStream);
    	//SLF4JBridgeHandler.removeHandlersForRootLogger();
    	SLF4JBridgeHandler.install();
    	
    	
        Unmarshaller unmarshaller = JAXBContext.newInstance(Jobs.class).createUnmarshaller();
        Jobs jobs = (Jobs) unmarshaller.unmarshal(new File(args[0]));
        long startTime = System.currentTimeMillis();
        new JobProcessor().processJobs(jobs);
        long endTime = System.currentTimeMillis();
        split.stop();

        log.info("Start time: {}", new java.util.Date(startTime));
        log.info("End time: {}", new java.util.Date(endTime));
        java.time.Duration d = java.time.Duration.ofMillis(endTime - startTime);
        log.info("Duration: {} hours, {} minutes, {} seconds, {} ms.", d.toHours(), d.toMinutesPart(), d.toSecondsPart(), d.toMillisPart());
        java.time.Duration p2 = java.time.Duration.ofMillis(stopwatchTotal.getLastUsage()-stopwatchTotal.getFirstUsage());
        log.debug("Total: {} hours, {} minutes, {} seconds, {} ms.",
						p2.toHours(), p2.toMinutesPart(), p2.toSecondsPart(), p2.toMillisPart());
        log.debug("stopwatchTotal: {}", stopwatchTotal);
        log.debug("stopwatchDb: {}", stopwatchDb);
        log.debug("stopwatchOai: {}", stopwatchOai);
        log.debug("stopwatchTrans1: {}", stopwatchTrans1);
        log.debug("stopwatchTrans2: {}", stopwatchTrans2);
        log.debug("stopwatchFS: {}", stopwatchFS);
        log.debug("stopwatchBI: {}", stopwatchBI);
    }

}
