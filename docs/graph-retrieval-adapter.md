# Graph Retrieval Adapter

This document describes the n8n workflow that provides a retrieval adapter for querying the Neo4j graph database and returning structured context suitable for LLM prompting.

## Overview

The Graph Retrieval Adapter is designed to:
1. Accept query parameters specifying what to retrieve
2. Execute appropriate Cypher queries against Neo4j
3. Format results as human-readable context for LLM prompts
4. Return structured data including document IDs for hybrid retrieval

## API Endpoint

```
POST http://n8n:5678/webhook/graph-retrieve
```

## Request Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `query` | string | Yes* | - | Search query or entity name |
| `entity` | string | Yes* | - | Specific entity ID or name |
| `query_type` | string | No | `entity_context` | Type of query (see Query Types) |
| `max_depth` | integer | No | 2 | Maximum hops for path queries (1-4) |
| `limit` | integer | No | 20 | Maximum results (1-50) |

*Either `query` or `entity` is required.

## Query Types

### `entity_context` (default)

Get full context for an entity including relationships and documents.

**Request:**
```json
{
  "entity": "API Gateway",
  "query_type": "entity_context"
}
```

**Response context:**
```
## API Gateway (Service)
Handles all external traffic

Related to:
- DEPENDS_ON → Auth Service (Service)
- DEPENDS_ON → Rate Limiter (Service)

Referenced by:
- Platform Team (Team) OWNS → this

Mentioned in documents:
- Platform Architecture Overview
- API Documentation
```

### `find_path`

Find shortest path between two entities.

**Request:**
```json
{
  "query": "John Smith, Payment Service",
  "query_type": "find_path",
  "max_depth": 3
}
```

**Response context:**
```
Path 1:
  John Smith (Person) --[BELONGS_TO]--> Platform Team (Team) --[OWNS]--> Payment Service (Service)
```

### `related_entities`

Get all entities within N hops of a given entity.

**Request:**
```json
{
  "entity": "Platform Team",
  "query_type": "related_entities",
  "max_depth": 2
}
```

**Response context:**
```
Related entities:
- John Smith (Person) [1 hop(s)]: Team Lead
- API Gateway (Service) [1 hop(s)]: External traffic handler
- Auth Service (Service) [2 hop(s)]: Authentication service
```

### `team_services`

Get services owned by a team and their dependencies.

**Request:**
```json
{
  "entity": "Platform Team",
  "query_type": "team_services"
}
```

**Response context:**
```
## Team: Platform Team

Owned services:
- API Gateway: Handles external traffic
- Auth Service: Authentication and authorization

Service dependencies:
- API Gateway depends on Auth Service
- API Gateway depends on Rate Limiter
```

### `document_entities`

Get all entities and concepts mentioned in a document.

**Request:**
```json
{
  "entity": "doc-architecture-001",
  "query_type": "document_entities"
}
```

**Response context:**
```
## Document: Platform Architecture Overview

Entities mentioned:
- API Gateway (Service)
- Auth Service (Service)
- Platform Team (Team)

Concepts:
- Microservices Architecture [architecture]
- Authentication [security]
```

### `concept_documents`

Get documents about a specific concept.

**Request:**
```json
{
  "query": "Microservices",
  "query_type": "concept_documents"
}
```

**Response context:**
```
## Concept: Microservices Architecture (architecture)

Related documents:
- Platform Architecture Overview (relevance: 0.9)
- Service Design Guidelines (relevance: 0.7)
```

## Response Format

```json
{
  "success": true,
  "query_type": "entity_context",
  "result_count": 3,
  "results": [
    {
      "entity_id": "svc-api-gateway",
      "entity_name": "API Gateway",
      "entity_type": "Service",
      "outgoing": [...],
      "incoming": [...],
      "documents": [...]
    }
  ],
  "context": "## API Gateway (Service)\n...",
  "document_ids": ["doc-001", "doc-002"]
}
```

| Field | Description |
|-------|-------------|
| `success` | Whether query executed successfully |
| `query_type` | The query type that was executed |
| `result_count` | Number of results returned |
| `results` | Raw query results as structured data |
| `context` | LLM-friendly formatted text context |
| `document_ids` | List of related document IDs (for hybrid retrieval) |

## Usage Examples

### curl

```bash
# Get entity context
curl -X POST http://n8n:5678/webhook/graph-retrieve \
  -H "Content-Type: application/json" \
  -d '{"entity": "Platform Team", "query_type": "entity_context"}'

# Find path between entities
curl -X POST http://n8n:5678/webhook/graph-retrieve \
  -H "Content-Type: application/json" \
  -d '{"query": "John Smith, API Gateway", "query_type": "find_path"}'

# Fuzzy search
curl -X POST http://n8n:5678/webhook/graph-retrieve \
  -H "Content-Type: application/json" \
  -d '{"query": "gateway"}'
```

### From n8n (Hybrid RAG)

Use in a RAG workflow to combine graph context with vector search:

```javascript
// 1. Call graph retrieval
const graphResponse = await $http.post(
  'http://localhost:5678/webhook/graph-retrieve',
  { entity: userQuery, query_type: 'entity_context' }
);

// 2. Get document IDs from graph
const docIds = graphResponse.document_ids;

// 3. Use docIds to filter Elasticsearch vector search
const esQuery = {
  query: {
    bool: {
      must: { knn: { embedding: queryEmbedding } },
      filter: { terms: { _id: docIds } }
    }
  }
};

// 4. Combine contexts for LLM
const fullContext = `
Graph Context:
${graphResponse.context}

Document Context:
${esResults.map(r => r.content).join('\n')}
`;
```

## Integration with RAG Pipeline

### Hybrid Retrieval Flow

```
┌─────────────┐
│ User Query  │
└──────┬──────┘
       │
       ▼
┌──────────────────────────────────────────┐
│            Query Classifier              │
│  (Determine if graph context is useful)  │
└─────────┬────────────────────┬───────────┘
          │                    │
          ▼                    ▼
┌─────────────────┐   ┌─────────────────┐
│ Graph Retrieval │   │ Vector Search   │
│   (Neo4j)       │   │ (Elasticsearch) │
└────────┬────────┘   └────────┬────────┘
         │                     │
         └──────────┬──────────┘
                    │
                    ▼
         ┌─────────────────┐
         │ Context Merger  │
         │ (Combine both)  │
         └────────┬────────┘
                  │
                  ▼
         ┌─────────────────┐
         │     Ollama      │
         │   (Generate)    │
         └─────────────────┘
```

### When to Use Graph Retrieval

| Query Pattern | Use Graph? | Query Type |
|--------------|------------|------------|
| "What is X?" | Maybe | `entity_context` |
| "Who owns X?" | Yes | `entity_context` or `team_services` |
| "How is X related to Y?" | Yes | `find_path` |
| "What depends on X?" | Yes | `related_entities` |
| "Find documents about X" | Vector first | - |
| "List all services" | Yes | `related_entities` with Service filter |

## Setup Instructions

### 1. Import Workflow

1. Open n8n UI
2. Import `n8n/graph-retrieval-workflow.json`

### 2. Configure Credentials

1. Create HTTP Basic Auth credential for Neo4j:
   - Name: `Neo4j Credentials`
   - User: `neo4j`
   - Password: (from internal docs)

2. Link to "Query Neo4j" node

### 3. Activate

Toggle workflow to Active.

## Error Handling

### No Results

```json
{
  "success": true,
  "result_count": 0,
  "results": [],
  "context": "No results found."
}
```

### Query Error

```json
{
  "success": false,
  "error": "Neo4j error message"
}
```

### Validation Error

```json
{
  "success": false,
  "error": "Either query or entity is required"
}
```

## Performance Considerations

- **Query timeout**: 30 seconds (configurable in workflow)
- **Max depth**: Limited to 4 hops to prevent expensive traversals
- **Result limit**: Capped at 50 results
- **Regex patterns**: Case-insensitive fuzzy matching

## Extending Query Types

To add a new query type:

1. Edit "Build Cypher Query" node
2. Add new case in switch statement:
   ```javascript
   case 'my_new_type':
     cypher = `MATCH ...`;
     params = { ... };
     break;
   ```

3. Edit "Format LLM Context" node
4. Add formatting for new type:
   ```javascript
   case 'my_new_type':
     contextText += // format results
     break;
   ```

## Troubleshooting

### Empty results for known entity

- Check entity name matches exactly or use fuzzy search
- Verify entity exists: `MATCH (e:Entity) WHERE e.name =~ '(?i).*keyword.*' RETURN e`

### Slow queries

- Reduce `max_depth` for path queries
- Add indexes for frequently queried properties
- Use specific `query_type` instead of default

### Connection errors

- Verify Neo4j is running: `kubectl get pods -n rag-demo -l app=neo4j`
- Check credentials in n8n
- Test connection: `curl http://neo4j:7474/`
