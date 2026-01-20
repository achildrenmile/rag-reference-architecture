# Graph Schema for RAG Knowledge Modeling

This document defines the Neo4j graph schema used to model knowledge relationships on top of existing documents stored in Elasticsearch.

## Design Principles

1. **Additive, not replacement** - Graph enriches vector search, doesn't replace it
2. **Document-centric** - Documents remain the source of truth in Elasticsearch
3. **Incremental enrichment** - New entities/relations can be added without re-ingestion
4. **Query-driven** - Schema optimized for common retrieval patterns

## Node Types

### Document

Represents a document indexed in Elasticsearch. Links graph entities back to source content.

```cypher
(:Document {
  id: String,           // Elasticsearch document ID
  title: String,        // Document title
  source: String,       // Source system/path
  doc_type: String,     // e.g., "markdown", "pdf", "confluence"
  created_at: DateTime,
  updated_at: DateTime,
  es_index: String      // Elasticsearch index name
})
```

### Section

A logical section within a document (maps to chunks in vector store).

```cypher
(:Section {
  id: String,           // Unique section ID
  doc_id: String,       // Parent document ID
  heading: String,      // Section heading/title
  chunk_index: Integer, // Position in document
  es_chunk_id: String   // Elasticsearch chunk ID (for linking)
})
```

### Entity

A named entity extracted from documents (people, services, systems, etc.).

```cypher
(:Entity {
  id: String,           // Unique entity ID
  name: String,         // Canonical name
  type: String,         // Entity type (see Entity Types below)
  aliases: [String],    // Alternative names
  description: String,  // Brief description
  external_id: String   // ID in external system (optional)
})
```

**Entity Types:**
| Type | Description | Examples |
|------|-------------|----------|
| `Person` | Individual people | "John Smith", "CTO" |
| `Team` | Groups/teams | "Platform Team", "Security" |
| `Service` | Software services | "api-gateway", "auth-service" |
| `System` | External systems | "Salesforce", "AWS" |
| `Technology` | Tech/frameworks | "Kubernetes", "Python" |
| `Product` | Products | "Enterprise Suite", "Mobile App" |
| `Location` | Places | "HQ", "EU Region" |
| `Organization` | Companies/orgs | "Acme Corp", "Partner Inc" |

### Concept

Abstract concepts, topics, or themes that appear across documents.

```cypher
(:Concept {
  id: String,           // Unique concept ID
  name: String,         // Concept name
  category: String,     // e.g., "security", "architecture", "process"
  description: String,
  keywords: [String]    // Related search terms
})
```

### Requirement

Optional: Formal requirements or specifications.

```cypher
(:Requirement {
  id: String,           // Requirement ID (e.g., "REQ-001")
  title: String,
  status: String,       // "draft", "approved", "deprecated"
  priority: String,     // "must", "should", "could"
  source_doc_id: String
})
```

## Relationship Types

### CONTAINS

Document contains sections.

```cypher
(:Document)-[:CONTAINS {order: Integer}]->(:Section)
```

### MENTIONS

Document or section mentions an entity.

```cypher
(:Document)-[:MENTIONS {
  count: Integer,       // Number of mentions
  context: String,      // Snippet of mention context
  confidence: Float     // Extraction confidence (0-1)
}]->(:Entity)

(:Section)-[:MENTIONS]->(:Entity)
```

### ABOUT

Document or section is about a concept.

```cypher
(:Document)-[:ABOUT {
  relevance: Float      // How central is this concept (0-1)
}]->(:Concept)

(:Section)-[:ABOUT]->(:Concept)
```

### REFERENCES

Document references another document.

```cypher
(:Document)-[:REFERENCES {
  ref_type: String      // "cites", "links_to", "imports"
}]->(:Document)
```

### RELATED_TO

Generic relationship between entities or concepts.

```cypher
(:Entity)-[:RELATED_TO {
  relation: String,     // Describes the relationship
  weight: Float         // Strength of relationship (0-1)
}]->(:Entity)

(:Concept)-[:RELATED_TO]->(:Concept)
```

### DEPENDS_ON

Dependency relationship (services, systems, requirements).

```cypher
(:Entity)-[:DEPENDS_ON {
  dep_type: String,     // "runtime", "build", "data"
  critical: Boolean
}]->(:Entity)

(:Requirement)-[:DEPENDS_ON]->(:Requirement)
```

### DERIVED_FROM

Entity or requirement derived from a document.

```cypher
(:Entity)-[:DERIVED_FROM {
  extracted_at: DateTime,
  method: String        // "manual", "llm", "ner"
}]->(:Document)

(:Requirement)-[:DERIVED_FROM]->(:Document)
```

### BELONGS_TO

Organizational membership.

```cypher
(:Entity {type: "Person"})-[:BELONGS_TO {
  role: String,         // "member", "lead", "owner"
  since: DateTime
}]->(:Entity {type: "Team"})

(:Entity {type: "Service"})-[:BELONGS_TO]->(:Entity {type: "Team"})
```

### OWNS

Ownership relationship.

```cypher
(:Entity {type: "Team"})-[:OWNS]->(:Entity {type: "Service"})
(:Entity {type: "Person"})-[:OWNS]->(:Entity {type: "Product"})
```

## Schema Diagram

```
                                    ┌─────────────┐
                                    │  Concept    │
                                    │             │
                                    └──────▲──────┘
                                           │ ABOUT
                                           │
┌─────────────┐   CONTAINS    ┌─────────────┐    MENTIONS    ┌─────────────┐
│  Document   │──────────────►│   Section   │───────────────►│   Entity    │
│             │               │             │                │             │
└──────┬──────┘               └─────────────┘                └──────┬──────┘
       │                                                            │
       │ MENTIONS                                                   │
       │ ABOUT                                                      │
       │ REFERENCES                                                 │
       ▼                                                            ▼
┌─────────────┐                                              ┌─────────────┐
│  Document   │◄─────────── DERIVED_FROM ────────────────────│   Entity    │
│  (other)    │                                              │  (other)    │
└─────────────┘                                              └─────────────┘
                                                                    │
                              DEPENDS_ON ◄──────────────────────────┤
                              RELATED_TO ◄──────────────────────────┤
                              BELONGS_TO ◄──────────────────────────┤
                              OWNS ◄────────────────────────────────┘
```

## Indexes and Constraints

```cypher
// Unique constraints
CREATE CONSTRAINT doc_id IF NOT EXISTS FOR (d:Document) REQUIRE d.id IS UNIQUE;
CREATE CONSTRAINT section_id IF NOT EXISTS FOR (s:Section) REQUIRE s.id IS UNIQUE;
CREATE CONSTRAINT entity_id IF NOT EXISTS FOR (e:Entity) REQUIRE e.id IS UNIQUE;
CREATE CONSTRAINT concept_id IF NOT EXISTS FOR (c:Concept) REQUIRE c.id IS UNIQUE;
CREATE CONSTRAINT req_id IF NOT EXISTS FOR (r:Requirement) REQUIRE r.id IS UNIQUE;

// Indexes for common lookups
CREATE INDEX entity_name IF NOT EXISTS FOR (e:Entity) ON (e.name);
CREATE INDEX entity_type IF NOT EXISTS FOR (e:Entity) ON (e.type);
CREATE INDEX concept_name IF NOT EXISTS FOR (c:Concept) ON (c.name);
CREATE INDEX doc_source IF NOT EXISTS FOR (d:Document) ON (d.source);
```

## Example Cypher Queries

### Find all entities mentioned in a document

```cypher
MATCH (d:Document {id: $doc_id})-[:MENTIONS]->(e:Entity)
RETURN e.name, e.type, e.description
ORDER BY e.type, e.name
```

### Find documents about a concept

```cypher
MATCH (d:Document)-[r:ABOUT]->(c:Concept {name: $concept_name})
RETURN d.id, d.title, r.relevance
ORDER BY r.relevance DESC
LIMIT 10
```

### Find services owned by a team

```cypher
MATCH (t:Entity {type: "Team", name: $team_name})-[:OWNS]->(s:Entity {type: "Service"})
RETURN s.name, s.description
```

### Find dependency chain for a service

```cypher
MATCH path = (s:Entity {type: "Service", name: $service_name})-[:DEPENDS_ON*1..5]->(dep:Entity)
RETURN path
```

### Find related entities (2 hops)

```cypher
MATCH (e:Entity {name: $entity_name})-[:RELATED_TO|DEPENDS_ON|BELONGS_TO*1..2]-(related:Entity)
WHERE related <> e
RETURN DISTINCT related.name, related.type,
       length(shortestPath((e)-[*]-(related))) as distance
ORDER BY distance, related.type
```

### Find documents that reference each other (citation network)

```cypher
MATCH (d1:Document)-[:REFERENCES]->(d2:Document)
RETURN d1.title as source, d2.title as target
```

### Hybrid query: Get document IDs for vector search based on graph traversal

```cypher
// Find all documents related to services owned by Platform team
MATCH (t:Entity {type: "Team", name: "Platform"})-[:OWNS]->(s:Entity {type: "Service"})
MATCH (d:Document)-[:MENTIONS]->(s)
RETURN DISTINCT d.id as es_doc_id, d.es_index
// Use these IDs to filter Elasticsearch vector search
```

### Find common concepts between two documents

```cypher
MATCH (d1:Document {id: $doc1_id})-[:ABOUT]->(c:Concept)<-[:ABOUT]-(d2:Document {id: $doc2_id})
RETURN c.name, c.category
```

### Get entity context for LLM prompt

```cypher
MATCH (e:Entity {name: $entity_name})
OPTIONAL MATCH (e)-[:BELONGS_TO]->(team:Entity {type: "Team"})
OPTIONAL MATCH (e)-[:DEPENDS_ON]->(dep:Entity)
OPTIONAL MATCH (e)<-[:OWNS]-(owner:Entity)
RETURN e.name, e.type, e.description,
       collect(DISTINCT team.name) as teams,
       collect(DISTINCT dep.name) as dependencies,
       collect(DISTINCT owner.name) as owners
```

## Integration with Elasticsearch

The graph schema links to Elasticsearch via document and section IDs:

```
┌─────────────────────────────────────────────────────────────────┐
│                        Query Flow                                │
└─────────────────────────────────────────────────────────────────┘

1. User Query: "What services does the Platform team own?"

2. Graph Query (Neo4j):
   MATCH (t:Entity {name: "Platform", type: "Team"})-[:OWNS]->(s:Entity {type: "Service"})
   MATCH (d:Document)-[:MENTIONS]->(s)
   RETURN s.name, collect(d.id) as doc_ids

3. Vector Search (Elasticsearch):
   Filter by doc_ids from graph
   + Semantic search for "platform team services"

4. Combined Context → LLM → Response
```

## Schema Evolution

The schema is designed for incremental enrichment:

1. **Adding new entity types**: Add new `type` values to Entity nodes
2. **Adding new relationships**: Create new relationship types as needed
3. **Enriching existing nodes**: Add properties without migration
4. **Linking new documents**: Create Document nodes and relationships incrementally

No re-ingestion of existing documents is required for schema changes.

## Initialization Script

Run this to set up the schema in a fresh Neo4j instance:

```cypher
// Create constraints
CREATE CONSTRAINT doc_id IF NOT EXISTS FOR (d:Document) REQUIRE d.id IS UNIQUE;
CREATE CONSTRAINT section_id IF NOT EXISTS FOR (s:Section) REQUIRE s.id IS UNIQUE;
CREATE CONSTRAINT entity_id IF NOT EXISTS FOR (e:Entity) REQUIRE e.id IS UNIQUE;
CREATE CONSTRAINT concept_id IF NOT EXISTS FOR (c:Concept) REQUIRE c.id IS UNIQUE;
CREATE CONSTRAINT req_id IF NOT EXISTS FOR (r:Requirement) REQUIRE r.id IS UNIQUE;

// Create indexes
CREATE INDEX entity_name IF NOT EXISTS FOR (e:Entity) ON (e.name);
CREATE INDEX entity_type IF NOT EXISTS FOR (e:Entity) ON (e.type);
CREATE INDEX concept_name IF NOT EXISTS FOR (c:Concept) ON (c.name);
CREATE INDEX concept_category IF NOT EXISTS FOR (c:Concept) ON (c.category);
CREATE INDEX doc_source IF NOT EXISTS FOR (d:Document) ON (d.source);
CREATE INDEX doc_type IF NOT EXISTS FOR (d:Document) ON (d.doc_type);
```

## Sample Data

Example of populating the graph with sample data:

```cypher
// Create a team
CREATE (t:Entity {
  id: "team-platform",
  name: "Platform Team",
  type: "Team",
  description: "Core infrastructure and platform services"
});

// Create services
CREATE (s1:Entity {
  id: "svc-api-gateway",
  name: "api-gateway",
  type: "Service",
  description: "Main API gateway for external traffic"
});

CREATE (s2:Entity {
  id: "svc-auth",
  name: "auth-service",
  type: "Service",
  description: "Authentication and authorization service"
});

// Create ownership relationships
MATCH (t:Entity {id: "team-platform"})
MATCH (s:Entity) WHERE s.id IN ["svc-api-gateway", "svc-auth"]
CREATE (t)-[:OWNS]->(s);

// Create dependency
MATCH (gw:Entity {id: "svc-api-gateway"})
MATCH (auth:Entity {id: "svc-auth"})
CREATE (gw)-[:DEPENDS_ON {dep_type: "runtime", critical: true}]->(auth);

// Link to a document
CREATE (d:Document {
  id: "doc-architecture-001",
  title: "Platform Architecture Overview",
  source: "confluence",
  doc_type: "markdown",
  es_index: "documents",
  created_at: datetime()
});

MATCH (d:Document {id: "doc-architecture-001"})
MATCH (s:Entity) WHERE s.id IN ["svc-api-gateway", "svc-auth"]
CREATE (d)-[:MENTIONS {count: 5, confidence: 0.95}]->(s);

// Create a concept
CREATE (c:Concept {
  id: "concept-microservices",
  name: "Microservices Architecture",
  category: "architecture",
  keywords: ["microservices", "distributed", "service mesh"]
});

MATCH (d:Document {id: "doc-architecture-001"})
MATCH (c:Concept {id: "concept-microservices"})
CREATE (d)-[:ABOUT {relevance: 0.9}]->(c);
```
