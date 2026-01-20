# Graph RAG Architecture

This document describes the optional graph database integration for the RAG reference architecture.

## Overview

The RAG system supports two complementary retrieval strategies:

| Strategy | Store | Purpose | Status |
|----------|-------|---------|--------|
| **Vector RAG** | Elasticsearch | Semantic similarity search | Default |
| **Graph RAG** | Neo4j | Entity relationships & reasoning | Optional |

Graph RAG is **additive** - it does not replace vector RAG. Both can be used independently or combined for hybrid retrieval.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              User Query                                  │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           OpenWebUI / API                                │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         n8n (Orchestrator)                               │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                      Query Router                                │    │
│  │  • Semantic queries     → Vector RAG                            │    │
│  │  • Relationship queries → Graph RAG                             │    │
│  │  • Complex queries      → Hybrid (both)                         │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└──────────────┬─────────────────────────────────────┬────────────────────┘
               │                                     │
               ▼                                     ▼
┌──────────────────────────────┐      ┌──────────────────────────────┐
│       Vector RAG Path        │      │       Graph RAG Path         │
│  ┌────────────────────────┐  │      │  ┌────────────────────────┐  │
│  │    Elasticsearch       │  │      │  │       Neo4j            │  │
│  │    (vector store)      │  │      │  │    (graph store)       │  │
│  │                        │  │      │  │                        │  │
│  │  • Document embeddings │  │      │  │  • Entity nodes        │  │
│  │  • Similarity search   │  │      │  │  • Relationship edges  │  │
│  │  • BM25 + kNN          │  │      │  │  • Cypher queries      │  │
│  └────────────────────────┘  │      │  └────────────────────────┘  │
└──────────────┬───────────────┘      └──────────────┬───────────────┘
               │                                     │
               └──────────────┬──────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Context Assembly                                 │
│         Combine retrieved documents + graph context                      │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                              Ollama                                      │
│                         (LLM Inference)                                  │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                             Response                                     │
└─────────────────────────────────────────────────────────────────────────┘
```

## When to Use Each Strategy

### Vector RAG (Elasticsearch)

Best for queries that require semantic understanding:

```
✅ "Find documents about machine learning"
✅ "What are the best practices for API design?"
✅ "Summarize our security policies"
✅ "Find similar content to this paragraph"
```

**How it works:**
1. Query is converted to embedding vector
2. Elasticsearch finds similar document chunks via kNN
3. Top-k results returned as context

### Graph RAG (Neo4j)

Best for queries that require relationship traversal:

```
✅ "Who reports to the CTO?"
✅ "What projects depend on service X?"
✅ "How is component A connected to component B?"
✅ "List all services that team Y owns"
✅ "What is the dependency chain for this feature?"
```

**How it works:**
1. Entities extracted from query
2. Cypher query traverses graph relationships
3. Connected entities and paths returned as context

### Hybrid RAG

Combines both strategies for complex queries:

```
✅ "What documentation exists for services owned by team X?"
    → Graph: Find services owned by team X
    → Vector: Search documentation for those services

✅ "Find security issues related to our payment dependencies"
    → Graph: Traverse payment service dependency tree
    → Vector: Search for security content in related docs
```

## Data Model

### Vector Store (Elasticsearch)

```json
{
  "index": "documents",
  "mappings": {
    "properties": {
      "content": { "type": "text" },
      "embedding": { "type": "dense_vector", "dims": 768 },
      "metadata": {
        "source": "string",
        "created_at": "date",
        "entity_refs": ["entity_id_1", "entity_id_2"]
      }
    }
  }
}
```

### Graph Store (Neo4j)

```cypher
// Node types
(:Document {id, title, source, created_at})
(:Entity {id, name, type})  // type: Person, Service, Team, Project, etc.
(:Concept {id, name})

// Relationship types
(:Document)-[:MENTIONS]->(:Entity)
(:Document)-[:ABOUT]->(:Concept)
(:Entity)-[:BELONGS_TO]->(:Team)
(:Entity)-[:REPORTS_TO]->(:Entity)
(:Entity)-[:OWNS]->(:Entity)
(:Entity)-[:DEPENDS_ON]->(:Entity)
(:Entity)-[:RELATED_TO]->(:Entity)
```

### Entity Linking

Documents in Elasticsearch reference entities in Neo4j:

```
┌─────────────────────┐         ┌─────────────────────┐
│   Elasticsearch     │         │       Neo4j         │
│                     │         │                     │
│  Document {         │         │  (Entity:Service)   │
│    content: "...",  │────────▶│    {name: "api-gw"} │
│    entity_refs: [   │         │         │           │
│      "srv:api-gw"   │         │         ▼           │
│    ]                │         │  (Entity:Team)      │
│  }                  │         │    {name: "platform"}│
└─────────────────────┘         └─────────────────────┘
```

## Ingestion Pipeline

### Vector Ingestion (existing)

```
Source → Chunking → Embedding → Elasticsearch
```

### Graph Ingestion (new)

```
Source → Entity Extraction → Relationship Extraction → Neo4j
           (NER + LLM)           (LLM)
```

### Combined Pipeline

```
┌──────────┐
│  Source  │
│ Document │
└────┬─────┘
     │
     ▼
┌──────────────────────────────────────────────────┐
│              n8n Ingestion Workflow               │
│                                                   │
│  ┌─────────────┐    ┌─────────────────────────┐  │
│  │   Chunking  │    │   Entity Extraction     │  │
│  │             │    │   (Ollama NER prompt)   │  │
│  └──────┬──────┘    └───────────┬─────────────┘  │
│         │                       │                 │
│         ▼                       ▼                 │
│  ┌─────────────┐    ┌─────────────────────────┐  │
│  │  Embedding  │    │ Relationship Extraction │  │
│  │  (Ollama)   │    │   (Ollama LLM prompt)   │  │
│  └──────┬──────┘    └───────────┬─────────────┘  │
│         │                       │                 │
│         ▼                       ▼                 │
│  ┌─────────────┐    ┌─────────────────────────┐  │
│  │Elasticsearch│    │        Neo4j            │  │
│  │   Index     │    │   Create/Merge Nodes    │  │
│  └─────────────┘    └─────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

## Component Details

### Neo4j

**Why Neo4j:**
- Native graph database with optimized traversal
- Cypher query language is intuitive
- Strong community and tooling
- Official Kubernetes Helm chart
- Community Edition is free (GPLv3)

**Alternatives considered:**
- ArangoDB: Multi-model but steeper learning curve
- Amazon Neptune: Cloud-only, expensive
- JanusGraph: Complex setup, better for massive scale

**Resource requirements:**
- Memory: 1-2GB minimum
- Storage: Depends on graph size
- CPU: 1-2 cores

### Query Router (n8n)

The query router in n8n determines which retrieval path to use:

```javascript
// Simplified routing logic
function routeQuery(query) {
  const relationshipKeywords = [
    'who', 'reports to', 'owns', 'depends on',
    'connected', 'related', 'manages', 'team'
  ];

  const isRelationshipQuery = relationshipKeywords.some(
    kw => query.toLowerCase().includes(kw)
  );

  if (isRelationshipQuery) {
    return 'graph';  // or 'hybrid' for complex queries
  }
  return 'vector';
}
```

More sophisticated routing can use LLM classification.

## Kubernetes Deployment

Neo4j is deployed as an optional component alongside the existing stack:

```
k8s/
├── base/
│   ├── elasticsearch/     # Existing
│   ├── ollama/            # Existing
│   ├── openwebui/         # Existing
│   ├── n8n/               # Existing
│   └── neo4j/             # NEW (optional)
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── pvc.yaml
│       └── kustomization.yaml
└── overlays/
    └── production/
        └── kustomization.yaml  # Include neo4j if enabled
```

### Enabling Graph RAG

To enable Neo4j in production:

```yaml
# k8s/overlays/production/kustomization.yaml
resources:
  - ../../base/elasticsearch
  - ../../base/ollama
  - ../../base/openwebui
  - ../../base/n8n
  - ../../base/neo4j        # Uncomment to enable
```

## Implementation Phases

### Phase 1: Infrastructure
- [ ] Add Neo4j Kubernetes manifests
- [ ] Configure persistent storage
- [ ] Add to Argo CD (disabled by default)

### Phase 2: Ingestion
- [ ] Create n8n workflow for entity extraction
- [ ] Create n8n workflow for graph population
- [ ] Link documents to entities

### Phase 3: Retrieval
- [ ] Add graph query endpoint to n8n
- [ ] Implement query router
- [ ] Test graph-only queries

### Phase 4: Hybrid
- [ ] Combine vector + graph results
- [ ] Context assembly for LLM
- [ ] Evaluate retrieval quality

## Example Queries

### Pure Vector (existing)
```
User: "What are our coding standards?"
→ Elasticsearch similarity search
→ Returns: Top 5 document chunks about coding standards
```

### Pure Graph (new)
```
User: "Who owns the payment service?"
→ Cypher: MATCH (t:Team)-[:OWNS]->(s:Service {name: 'payment'}) RETURN t
→ Returns: Team "Platform" owns payment service
```

### Hybrid (new)
```
User: "Find documentation for services owned by the platform team"
→ Graph: MATCH (t:Team {name: 'platform'})-[:OWNS]->(s:Service) RETURN s
→ Returns: [api-gateway, payment, auth]
→ Vector: Search docs where entity_refs IN [api-gateway, payment, auth]
→ Returns: Relevant documentation for those services
```

## Limitations

- **Graph construction requires effort**: Entities and relationships must be extracted or manually defined
- **Not suitable for all queries**: Pure semantic search doesn't benefit from graph
- **Additional resource usage**: Neo4j requires memory and storage
- **Maintenance overhead**: Two data stores to keep in sync

## References

- [Neo4j Documentation](https://neo4j.com/docs/)
- [Neo4j Kubernetes Helm Chart](https://neo4j.com/docs/operations-manual/current/kubernetes/)
- [Graph RAG Paper](https://arxiv.org/abs/2404.16130)
- [LangChain Graph RAG](https://python.langchain.com/docs/use_cases/graph/)
