# Hybrid RAG Pipeline

This document describes the hybrid RAG pipeline that combines Elasticsearch vector retrieval with Neo4j graph reasoning for enhanced question answering.

## Overview

The hybrid pipeline enhances traditional vector-based RAG by adding graph context:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           User Question                                  │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
                     ┌────────────────────────┐
                     │   Embed Query (Ollama) │
                     └────────────┬───────────┘
                                  │
                                  ▼
                     ┌────────────────────────┐
                     │ Vector Search (ES)     │
                     │ → Relevant documents   │
                     └────────────┬───────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │                           │
            hybrid_mode=true           hybrid_mode=false
                    │                           │
                    ▼                           │
       ┌────────────────────────┐              │
       │ Extract Entities (LLM) │              │
       └────────────┬───────────┘              │
                    │                           │
                    ▼                           │
       ┌────────────────────────┐              │
       │ Query Graph (Neo4j)    │              │
       │ → Entity relationships │              │
       └────────────┬───────────┘              │
                    │                           │
                    └─────────────┬─────────────┘
                                  │
                                  ▼
                     ┌────────────────────────┐
                     │ Merge Context          │
                     │ (Graph + Documents)    │
                     └────────────┬───────────┘
                                  │
                                  ▼
                     ┌────────────────────────┐
                     │ Generate Answer (LLM)  │
                     └────────────┬───────────┘
                                  │
                                  ▼
                     ┌────────────────────────┐
                     │       Response         │
                     └────────────────────────┘
```

## API Endpoint

```
POST http://n8n:5678/webhook/rag
```

## Request Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `query` | string | *required* | The user's question |
| `hybrid_mode` | boolean | `true` | Enable graph context enrichment |
| `vector_limit` | integer | 5 | Max documents from vector search (1-10) |
| `graph_depth` | integer | 2 | Max hops for graph traversal (1-3) |
| `model` | string | `mistral:7b` | Ollama model for answer generation |

## Response Format

```json
{
  "query": "Who owns the API Gateway?",
  "answer": "The Platform Team owns the API Gateway service...",
  "mode": "hybrid",
  "sources": {
    "vector_documents": 5,
    "graph_context_used": true,
    "entities_extracted": ["API Gateway", "Platform Team"]
  }
}
```

## Usage Examples

### Hybrid Mode (Default)

```bash
curl -X POST http://n8n:5678/webhook/rag \
  -H "Content-Type: application/json" \
  -d '{
    "query": "What services does the Platform Team own and what do they depend on?"
  }'
```

Response:
```json
{
  "query": "What services does the Platform Team own and what do they depend on?",
  "answer": "The Platform Team owns the API Gateway and Auth Service. The API Gateway depends on the Auth Service for authentication, and also relies on the Rate Limiter service for traffic control.",
  "mode": "hybrid",
  "sources": {
    "vector_documents": 5,
    "graph_context_used": true,
    "entities_extracted": ["Platform Team", "API Gateway"]
  }
}
```

### Vector-Only Mode

```bash
curl -X POST http://n8n:5678/webhook/rag \
  -H "Content-Type: application/json" \
  -d '{
    "query": "What are the best practices for API design?",
    "hybrid_mode": false
  }'
```

Response:
```json
{
  "query": "What are the best practices for API design?",
  "answer": "Based on the documentation, key API design best practices include...",
  "mode": "vector_only",
  "sources": {
    "vector_documents": 5,
    "graph_context_used": false,
    "entities_extracted": []
  }
}
```

## When to Use Each Mode

| Query Type | Recommended Mode | Why |
|------------|------------------|-----|
| Factual questions about entities | Hybrid | Graph provides relationship context |
| "Who owns/manages X?" | Hybrid | Ownership is a graph relationship |
| "What depends on X?" | Hybrid | Dependencies are graph edges |
| "How is X related to Y?" | Hybrid | Path queries benefit from graph |
| Semantic search ("best practices") | Vector-only | No entity relationships needed |
| Summarization tasks | Vector-only | Content focus, not relationships |
| General knowledge questions | Vector-only | Documents are primary source |

## Pipeline Stages

### 1. Query Embedding

The user's question is converted to a vector embedding using Ollama's `nomic-embed-text` model.

### 2. Vector Search

Elasticsearch performs cosine similarity search to find the most relevant document chunks.

### 3. Entity Extraction (Hybrid Only)

If hybrid mode is enabled, the LLM extracts key entities from the query:

```
Query: "What services does the Platform Team own?"
Entities: ["Platform Team", "services"]
```

### 4. Graph Query (Hybrid Only)

Neo4j is queried for context about the extracted entities:
- Entity descriptions
- Outgoing relationships (e.g., OWNS, DEPENDS_ON)
- Incoming relationships (e.g., referenced by other entities)

### 5. Context Merging

The pipeline combines:
- **Graph context**: Entity relationships and descriptions
- **Vector context**: Relevant document chunks

Example merged context:
```
## Knowledge Graph Context

### Platform Team (Team)
Infrastructure and platform services team

Relationships:
- OWNS → API Gateway (Service)
- OWNS → Auth Service (Service)

Referenced by:
- John Smith (Person) via BELONGS_TO

## Retrieved Documents

[Document 1: Platform Architecture]
The Platform Team is responsible for core infrastructure...

[Document 2: API Gateway Documentation]
The API Gateway handles all external traffic...
```

### 6. Answer Generation

The merged context is sent to the LLM with the user's question to generate a comprehensive answer.

## Configuration

### Enable/Disable Hybrid Mode

Per-request:
```json
{"query": "...", "hybrid_mode": false}
```

To change the default, modify the "Validate Input" node in the workflow:
```javascript
hybrid_mode: body.hybrid_mode !== false  // Default: true
// Change to:
hybrid_mode: body.hybrid_mode === true   // Default: false
```

### Adjust Vector/Graph Balance

- Increase `vector_limit` for more document context
- Increase `graph_depth` for deeper relationship exploration
- Modify the context template in "Merge Context" node

## Setup Instructions

### 1. Import Workflow

```bash
# Import into n8n
n8n import:workflow --input=n8n/hybrid-rag-workflow.json
```

Or via n8n UI: Workflows → Import from File

### 2. Configure Credentials

Create HTTP Basic Auth credential for Neo4j:
- Name: `Neo4j Credentials`
- User: `neo4j`
- Password: (from internal docs)

Link to "Query Graph (Neo4j)" node.

### 3. Activate Workflow

Toggle to Active in n8n UI.

## Performance

| Stage | Typical Time |
|-------|--------------|
| Embedding | 100-200ms |
| Vector search | 50-100ms |
| Entity extraction | 2-5s |
| Graph query | 50-200ms |
| Answer generation | 5-15s |
| **Total (hybrid)** | **8-20s** |
| **Total (vector-only)** | **6-15s** |

## Troubleshooting

### Hybrid mode not enriching answers

1. Check if entities are being extracted:
   - Look at workflow execution logs
   - Verify "entities_extracted" in response

2. Check Neo4j has data:
   ```cypher
   MATCH (e:Entity) RETURN count(e)
   ```

3. Verify entity names match graph:
   - Entity extraction is fuzzy matched
   - Check for typos in entity names

### Slow response times

1. Reduce `vector_limit` and `graph_depth`
2. Use a faster/smaller model
3. Check Ollama is using GPU (if available)

### Empty graph context

1. Verify graph extraction workflow has populated Neo4j
2. Check entity names in query match graph entities
3. Run manual Cypher query to verify data:
   ```cypher
   MATCH (e:Entity) WHERE e.name =~ '(?i).*platform.*' RETURN e
   ```

## Comparison: Vector-Only vs Hybrid

### Vector-Only Strengths
- Faster response time
- Works without graph data
- Better for semantic similarity queries

### Hybrid Strengths
- Relationship-aware answers
- Entity context enrichment
- Multi-hop reasoning
- Structured knowledge integration

### Example Comparison

**Query:** "What does the API Gateway depend on?"

**Vector-Only Answer:**
> "The API Gateway is mentioned in several documents about our platform architecture. It handles external traffic and provides routing capabilities."

**Hybrid Answer:**
> "According to the knowledge graph, the API Gateway depends on the Auth Service for authentication and authorization. It also has a dependency on the Rate Limiter service for traffic control. The Platform Team owns the API Gateway."

The hybrid answer includes explicit relationship information from the graph.
