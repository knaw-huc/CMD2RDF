CMD2RDF
=======

CMD2RDF is a CLARIN-NL project that converts CMDI (Component MetaData Infrastructure) records
harvested from the CLARIN infrastructure into RDF and uploads them to a graph database (GraphDB).

## Overview

The application runs as a batch job that:
1. Scans a directory of CMDI XML files and computes MD5 checksums to detect new/updated/deleted records
2. Transforms each record through an XSLT pipeline (VLO facets, OST metadata, RDF conversion)
3. Uploads the resulting RDF to a graph store (currently GraphDB) via HTTP PUT into named graphs
4. Converts CLARIN metadata profiles and components to RDF classes

## Building

Requires Java 1.8+ and Maven.

```bash
mvn clean package
```

This produces `batch/target/Cmd2rdf.jar` — a fat JAR with all dependencies included.

## Configuration

The main configuration file is an XML document passed as a runtime argument. Two example configs are
included:

| File | Purpose |
|------|---------|
| `batch/src/main/resources/cmd2rdf.xml` | Production (GraphDB in Docker at `graphdb:7200`) |

### Key properties

| Property | Description | Example |
|----------|-------------|---------|
| `homedir` | Base directory for all relative paths | `/app` |
| `workspace` | Working directory for DB, cache, output | `{homedir}/work` |
| `gitrepo` | Path to this repository | `/app/cmd2rdf` |
| `xmlSourceDir` | Input directory of harvested CMDI files | `/app/data/clarin/results/cmdi` |
| `xsltSourceDir` | Directory containing XSL stylesheets | `{gitrepo}/conversion/src/main/resources/xsl` |
| `urlDB` | Path to HSQLDB checksum database | `{workspace}/db/DB_CMD_CHECKSUM` |
| `profilesCacheDir` | Cached CLARIN profiles/components | `{workspace}/profiles-cache` |
| `prefixBaseURI` | Base URI for generated RDF resources | `http://localhost:8080/cmd2rdf/graph` |
| `serverHost` | GraphDB base URL | `http://localhost:7200` |
| `serverURL` | GraphDB SPARQL statements endpoint | `{serverHost}/repositories/ost-clarin-skg/statements` |
| `username` | GraphDB username | `dba` |
| `password` | GraphDB password | `dba` |

Properties support `{varname}` substitution, so `{serverHost}` in one property resolves to the value
of the `serverHost` property.

## GraphDB Setup

CMD2RDF targets a [GraphDB](https://graphdb.ontotext.com/) repository. Before running:

1. Start GraphDB (e.g. via Docker):
   ```bash
   docker run -p 7200:7200 ontotext/graphdb
   ```

2. Create a repository named `ost-clarin-skg` via the GraphDB Workbench
   (http://localhost:7200) or REST API.

3. Update `serverHost`, `username`, and `password` in your config file to match.

### How RDF is uploaded

Records are uploaded using HTTP `PUT` to the SPARQL statements endpoint with a `context` query
parameter specifying the named graph IRI (enclosed in angle brackets). PUT is used to ensure
idempotent graph replacement — re-running the batch will overwrite existing graphs rather than
appending duplicate triples.

**Endpoint pattern:**
```
PUT http://localhost:7200/repositories/ost-clarin-skg/statements
  ?context=<http://localhost:8080/cmd2rdf/graph/path/to/record.rdf>
Content-Type: application/rdf+xml
```

Named graph IRIs are derived from each record's file path by stripping `xmlSourceDir` and
prepending `prefixBaseURI`.

## Running

```bash
java -jar batch/target/Cmd2rdf.jar /path/to/cmd2rdf.xml
```

Use the local config for development:
```bash
java -jar batch/target/Cmd2rdf.jar batch/src/main/resources/cmd2rdf-local.xml
```

## Processing Pipeline

Each CMDI record passes through the following stages:

### 1. Prepare
- Scans `xmlSourceDir` recursively and computes MD5 checksums
- Compares against the HSQLDB checksum database to identify `NEW`, `UPDATE`, and `DELETE` records

### 2. Record transformation (parallelized by file size)

Records are divided into three size tiers and processed in parallel thread pools:

| Tier | Size range | Threads |
|------|-----------|---------|
| Small | 0 – 10 KB | 32 |
| Medium | 10 KB – 100 KB | 16 |
| Large | > 100 KB | 1 (serial) |

Each record passes through these XSLT transforms in sequence:

| Stylesheet | Purpose |
|-----------|---------|
| `addVLOFacets.xsl` | Enriches with VLO (Virtual Language Observatory) facet metadata |
| `addOST.xsl` | Adds OST metadata and organization/language URIs |
| `CMDRecord2RDF.xsl` | Core transform: CMDI XML → RDF/XML |
| `addOrganisationEntity.xsl` | Links organization RDF entities from VLO harvest |
| `addLanguageEntity.xsl` | Adds language metadata entities |
| `saveVLO.xsl` | Exports VLO facets to a separate file |

After transformation, the RDF is uploaded to GraphDB and the checksum DB is marked `DONE`.

### 3. Profiles & Components
Cached CLARIN metadata profiles (eg., `clarin.eu_cr1_p_*.xml`) and components (eg., `clarin.eu_cr1_c_*.xml`)
are transformed via `Component2RDF.xsl` and uploaded to GraphDB under a dedicated named graph
namespace.

### 4. Cleanup
The checksum database is finalized (deleted records are removed).

## Logs

Log output is configured in `batch/src/main/resources/logback.xml`:

| Log file | Contents |
|----------|---------|
| `/app/logs/cmd2rdf/cmd2rdf.log` | Full application log (rolling, 5-day retention) |
| `/app/logs/cmd2rdf/errors.log` | Error-level messages only |
| `/app/logs/cmd2rdf/errorfiles.log` | Paths of files that failed processing |

## Project Structure

```
CMD2RDF/
├── batch/          # Batch runner: Launcher, JobProcessor, config parsing
├── config/         # XML configuration model and parsing
├── conversion/     # Core logic: XSLT transforms, StoreClient, checksum DB, utilities
│   └── src/main/resources/xsl/   # All XSLT stylesheets
└── batch/src/main/resources/
    ├── cmd2rdf.xml            # Production config
    ├── cmd2rdf-local.xml      # Local development config
    └── logback.xml            # Logging configuration
```
