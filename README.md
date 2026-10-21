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
| `batch/src/main/resources/cmd2rdf-local.xml` | Local development (GraphDB at `localhost:7200`, repository `test`, `prefixBaseURI` = `urn:`); small records use the [SKG-only pipeline](#skg-only-pipeline) |

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

Upload graph IRIs use the generated RDF root's `xml:base`, which must be an absolute URI.
If `xml:base` is absent, the graph IRI is derived from the file path by stripping
`xmlSourceDir` and prepending `prefixBaseURI`. Deletions still use this file-path mapping;
changing graph names in XSLT therefore also requires aligning deletion handling.

When `prefixBaseURI` is `urn:`, slashes directly after the scheme are dropped, so
`urn:/record.rdf` becomes `urn:record.rdf`. The stylesheets apply the same rule, so graph IRIs
from `xml:base` and from the file-path mapping match.

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

`addVLOFacets.xsl` only queries the VLO API when the record has a non-empty `MdSelfLink`;
records without one get their facets from the local VLO facet mapping only.

#### SKG-only pipeline

An alternative pipeline emits only the SKG-IF entities derived from the VLO facets, without the
full CMDI → RDF conversion:

| Stylesheet | Purpose |
|-----------|---------|
| `addVLOFacets.xsl` | Enriches with VLO facet metadata |
| `VLOFacets2SKG.xsl` | Maps the facets to SKG-IF entities (reuses `addOST.xsl`) and wraps them in an `ost:SKG` intermediate document |
| `SKG2RDF.xsl` | Serializes the `ost:SKG` document as RDF/XML, one top-level resource per entity |

These stylesheets can be run as a single XProc pipeline, `CMD2RDF-facet-only.xpl`, in something like Oxygen.

The pipeline must have a `source` input port and a `result` output port. Configuration properties
whose names match options declared by the pipeline are passed to it as option values. The
pipeline's options are:

| Option | Default | Description |
|--------|---------|-------------|
| `beta-vlo-facets-url`, `beta-vlo-record-url`, `vloFacetMapping` | CLARIN VLO endpoints | Facet lookup (see `addVLOFacets.xsl`) |
| `base_strip`, `base_add` | empty | Rewrites the source path into the record IRI |
| `skgBaseURI` | `otf:` | Base URI for generated SKG-IF entity identifiers |
| `debug`, `debugOutputDir` | `true`, `/Users/listj/debug` | Write the output of each stage to `debugOutputDir` |

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
    ├── cmd2rdf-skgif.xml      # Production SKGIF only config
    └── logback.xml            # Logging configuration
```

## Specifics related to entity generation

### SKGIF Grants and Venues
Publishing venues are generated as `fabio:ExpressionCollection` entities, linked from each `fabio:Expression` using `frbr:partOf` (SKG-IF `biblio.in`).
The mapping accepts these explicit CMDI fields, independent of profile namespace:

| Source fields | Venue type |
|---------------|------------|
| `JournalTitle`, `JournalName`, text-only `Journal`, `Journal/Name`, `Journal/Title` | Journal |
| `ProceedingsTitle`, `Proceedings/Name`, `Proceedings/Title` | Conference proceedings |
| `DatasetCatalogName`, `DatasetCatalogueName`, `DatasetCatalog/Name` or `Title`, `DatasetCatalogue/Name` or `Title` | Repository |

The above are heuristics, based on the CMDI data, not necessarily facets; sadly the facets do not provide enough information.

More heuristics surrounding venues:

- Field matching ignores case.
- Blank and placeholder values and fields inside references, citations, bibliographies or related resources are excluded.
- Generic collection/provider names and conference events do not establish publishing venues.
- Venue identifiers are minted from the venue type and normalized name. Repeated names of the same type are
  deduplicated within a record.
- Multiple venues produce separate expressions sharing the existing manifestation. These mappings produce names and types only; they do not infer
  venue identifiers such as ISSNs or venue access rights from product metadata.

WebLicht services retain their existing VLO and explicitly recognised portal collection venues.

Grants are emitted as `frapo:Grant` entities, linked from the product using `frapo:isFundedBy` (SKG-IF `funding`). Supported funding metadata is:

| Source fields within a funding block | Output |
|-------------------------------------|--------|
| `GrantNumber`, `AwardNumber`; `Number` in an explicit block | `frapo:hasGrantNumber` |
| `GrantTitle`, `AwardTitle`; `Title` or `Name` in an explicit block | `dcterms:title`, retaining explicit language tags |
| `FunderName`, text-only `Funder` or `FundingAgency`, `FundingOrganisation` / `FundingOrganization`, or their `Name` child | `frapo:hasFundingAgency` plus a funder organisation |
| `GrantIdentifier`, `AwardIdentifier`; `Identifier`, `DOI` or `PID` in an explicit block | `datacite:hasIdentifier` for recognised DOI, Handle, URL, URN or W3ID values |

Explicit blocks are `Grant`, `Funding` and `FundingReference`. A `Project` or
other component with a direct `GrantNumber` or `AwardNumber` is also supported;
`Project` permits the generic field names above. Matching ignores case and profile
namespaces. Each block must supply an award number or recognised award identifier;
a `Grant` block may instead supply a title. A project name, generic project ID,
funder name alone, or free-text funding acknowledgement does not create a grant.
References, related resources, blank values and placeholders are excluded. Blocks
with multiple distinct award numbers or funder names are skipped because they need
a profile-specific mapping to establish which award belongs to which funder.

Identifiers are deterministic:

- Explicit award identifiers take precedence
- Otherwise the exact award number is scoped by funder name, or by source record when no funder
  is known. T
- Title-only grants use the source record and title.
- Repeated grants are merged within a record.
- Grant identifiers are excluded from product identifiers. This first
  mapping emits numbers, titles, identifiers and funders; it does not infer amounts,
  dates, beneficiaries or funding for WebLicht services.

For local `file:` records, `SKG2RDF.xsl` sets `xml:base` to the file name only.
