package nl.knaw.dans.cmd2rdf.conversion.action.transform;

import javax.xml.transform.TransformerFactory;

import net.sf.saxon.Configuration;
import net.sf.saxon.TransformerFactoryImpl;
import net.sf.saxon.lib.ExtensionFunctionDefinition;
import net.sf.saxon.lib.ExtensionFunctionCall;
import net.sf.saxon.om.StructuredQName;
import net.sf.saxon.value.SequenceType;
import net.sf.saxon.expr.XPathContext;
import net.sf.saxon.om.Sequence;
import net.sf.saxon.trans.XPathException;
import net.sf.saxon.s9api.Processor;
import net.sf.saxon.s9api.SaxonApiException;
import net.sf.saxon.s9api.XPathCompiler;
import net.sf.saxon.s9api.XPathExecutable;
import net.sf.saxon.s9api.XPathSelector;
import net.sf.saxon.s9api.XdmNode;
import net.sf.saxon.om.NodeInfo;
import net.sf.saxon.value.StringValue;
import net.sf.saxon.s9api.XdmNodeKind;
import net.sf.saxon.s9api.XdmSequenceIterator;

public final class ExtensionFunctions {
    /**
     * Registers with Saxon-HE 12.8 all the extension functions
     * <p>This method must be invoked once per TransformerFactory.
     *
     * @param factory the TransformerFactory pointing to
     * Saxon-HE 12.8 extension function registry
     * (that is, a <tt>net.sf.saxon.Configuration</tt>).
     * This object must be an instance of
     * <tt>net.sf.saxon.TransformerFactoryImpl</tt>.
     */
    public static void registerAll(TransformerFactory factory) throws Exception {
        if (!(factory instanceof TransformerFactoryImpl)) {
            throw new IllegalArgumentException("TransformerFactory must be an instance of net.sf.saxon.TransformerFactoryImpl");
        }

        Processor processor = new Processor(false); // false for Saxon-HE
        Configuration config = processor.getUnderlyingConfiguration();
        config.registerExtensionFunction(new EvaluateDefinition());

        ((TransformerFactoryImpl) factory).setConfiguration(config);
    }

    // -----------------------------------------------------------------------
    // sx:evaluate
    // -----------------------------------------------------------------------

    public static final class EvaluateDefinition
            extends ExtensionFunctionDefinition {
        @Override
        public StructuredQName getFunctionQName() {
            return new StructuredQName("sx",
                    "java:nl.knaw.dans.saxon",
                    "evaluate");
        }

        @Override
        public int getMinimumNumberOfArguments() {
            return 2;
        }

        @Override
        public int getMaximumNumberOfArguments() {
            return 3;
        }

        @Override
        public SequenceType[] getArgumentTypes() {
            return new SequenceType[] {
                    SequenceType.SINGLE_NODE,
                    SequenceType.SINGLE_STRING,
                    SequenceType.OPTIONAL_NODE
            };
        }

        @Override
        public SequenceType getResultType(SequenceType[] suppliedArgTypes) {
            return SequenceType.ANY_SEQUENCE;
        }

        @Override
        public boolean dependsOnFocus() {
            return true;
        }

        @Override
        public ExtensionFunctionCall makeCallExpression() {
            return new ExtensionFunctionCall() {
                @Override
                public Sequence call(XPathContext context, Sequence[] arguments) throws XPathException {
                    Sequence seq = null;
                    try {
                        NodeInfo node = (NodeInfo) arguments[0].head();
                        StringValue path = (StringValue) arguments[1].head();
                        NodeInfo nsNode = arguments.length == 3 ? (NodeInfo) arguments[2].head() : node;

                        Processor processor = new Processor(context.getConfiguration());
                        XPathCompiler xpc = processor.newXPathCompiler();

                        // Declare namespaces from the context node
                        XdmNode xdmNsNode = new XdmNode(nsNode);
                        if (xdmNsNode.getNodeKind() == XdmNodeKind.ELEMENT) {
                            XdmSequenceIterator<?> nsIter = xdmNsNode.axisIterator(net.sf.saxon.s9api.Axis.NAMESPACE);
                            while (nsIter.hasNext()) {
                                XdmNode ns = (XdmNode) nsIter.next();
                                String prefix = ns.getNodeName() != null ? ns.getNodeName().getLocalName() : "";
                                String uri = ns.getStringValue();
                                xpc.declareNamespace(prefix, uri);
                            }
                        }

                        XPathExecutable xpe = xpc.compile(path.getStringValue());
                        XPathSelector xps = xpe.load();
                        xps.setContextItem(new XdmNode(node));
                        seq = xps.evaluate().getUnderlyingValue();
                    } catch (SaxonApiException e) {
                        System.err.println("ERR: " + e.getMessage());
                        e.printStackTrace(System.err);
                        throw new XPathException("Error evaluating XPath: " + e.getMessage(), e);
                    }

                    return seq;
                }
            };
        }
    }
}