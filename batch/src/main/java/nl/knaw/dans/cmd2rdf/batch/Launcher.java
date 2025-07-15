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

import org.easybatch.core.job.JobExecutor;
import org.easybatch.core.job.JobReport;
import org.easybatch.core.job.Job;
import org.easybatch.core.job.JobBuilder;
import org.easybatch.xml.XmlRecordMapper;
import org.easybatch.xml.XmlRecordReader;
import org.javasimon.SimonManager;
import org.javasimon.Split;
import org.javasimon.Stopwatch;
import org.joda.time.Period;
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
    	
    	
        // Build an easy batch job
        Job job = new JobBuilder()
                .reader(new XmlRecordReader("CMD2RDF",
								Files.newInputStream(new File(args[0]).toPath())))
                .mapper(new XmlRecordMapper<Jobs>(Jobs.class))
                .processor(new JobProcessor())
                .build();

        
        // Run easy batch job
        JobReport jobReport = JobExecutor.execute(job);
        split.stop();
       
        // Print the job execution report
        log.info("Start time: {}", jobReport.getFormattedStartTime());
        log.info("End time: {}", jobReport.getFormattedEndTime());
		String duration = jobReport.getFormattedDuration();
		try {
			Period p = new Period(Long.parseLong(duration.replace("ms", "").trim()));
			log.info("Duration: {} hours, {} minutes, {} seconds, {} ms.", p.getHours(), p.getMinutes(),
							p.getSeconds(), p.getMillis());
		} catch (NumberFormatException e) {
			// We're going to log what we got back as duration, it's better than nothing
			log.info("Duration: {}", duration);
		}
        Period p2 = new Period(stopwatchTotal.getLastUsage()-stopwatchTotal.getFirstUsage());
        log.debug("Total: {} hours, {} minutes, {} seconds, {} ms.",
						p2.getHours(), p2.getMinutes(), p2.getSeconds(), p2.getMillis());
        log.debug("stopwatchTotal: {}", stopwatchTotal);
        log.debug("stopwatchDb: {}", stopwatchDb);
        log.debug("stopwatchOai: {}", stopwatchOai);
        log.debug("stopwatchTrans1: {}", stopwatchTrans1);
        log.debug("stopwatchTrans2: {}", stopwatchTrans2);
        log.debug("stopwatchFS: {}", stopwatchFS);
        log.debug("stopwatchBI: {}", stopwatchBI);
    }

}
