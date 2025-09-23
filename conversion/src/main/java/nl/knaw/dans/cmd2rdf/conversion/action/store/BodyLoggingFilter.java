package nl.knaw.dans.cmd2rdf.conversion.action.store;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.ws.rs.client.*;
import javax.ws.rs.core.MultivaluedMap;
import javax.ws.rs.ext.Provider;
import java.io.*;
import java.nio.charset.StandardCharsets;

@Provider
public class BodyLoggingFilter implements ClientRequestFilter, ClientResponseFilter {

    private final static Logger log = LoggerFactory.getLogger(BodyLoggingFilter.class);

    @Override
    public void filter(ClientRequestContext requestContext) throws IOException {
        log.debug(">>> REQUEST >>>");
        log.debug("{} {}", requestContext.getMethod(), requestContext.getUri());
        logHeaders(requestContext.getHeaders());

        if (requestContext.hasEntity()) {
            final ByteArrayOutputStream buffer = new ByteArrayOutputStream();
            OutputStream origStream = requestContext.getEntityStream();

            requestContext.setEntityStream(new FilterOutputStream(origStream) {
                @Override
                public void write(int b) throws IOException {
                    buffer.write(b);
                    super.write(b);
                }

                @Override
                public void write(byte[] b, int off, int len) throws IOException {
                    buffer.write(b, off, len);
                    super.write(b, off, len);
                }

                @Override
                public void close() throws IOException {
                    super.close();
                    log.debug("Request Body: {}", new String(buffer.toByteArray(), StandardCharsets.UTF_8));
                }
            });
        }

        log.debug(">>> END REQUEST >>>");
    }

    @Override
    public void filter(ClientRequestContext requestContext, ClientResponseContext responseContext) throws IOException {
        log.debug("<<< RESPONSE <<<");
        log.debug("Status: {}", responseContext.getStatus());
        logHeaders(responseContext.getHeaders());

        if (responseContext.hasEntity()) {
            InputStream originalStream = responseContext.getEntityStream();
            byte[] bytes = readAllBytes(originalStream);
            log.debug("Response Body: {}", new String(bytes, StandardCharsets.UTF_8));
            responseContext.setEntityStream(new ByteArrayInputStream(bytes));
        }

        log.debug("<<< END RESPONSE <<<");
    }

    private void logHeaders(MultivaluedMap<String, ?> headers) {
        for (String key : headers.keySet()) {
            log.debug("{}: {}", key, headers.get(key));
        }
    }

    private byte[] readAllBytes(InputStream is) throws IOException {
        ByteArrayOutputStream buffer = new ByteArrayOutputStream();
        byte[] chunk = new byte[4096];
        int n;
        while ((n = is.read(chunk)) != -1) {
            buffer.write(chunk, 0, n);
        }
        return buffer.toByteArray();
    }

}
