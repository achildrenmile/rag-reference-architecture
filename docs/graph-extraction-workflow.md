# Graph Entity Extraction Workflow

This document describes the n8n workflow for extracting entities and relationships from documents and storing them in the Neo4j graph database.

## Overview

The Graph Entity Extraction workflow uses Ollama LLM to identify entities (people, teams, services, etc.) and their relationships from document content, then stores them in Neo4j following the defined graph schema.

## Workflow Diagram

```
┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐
│   Webhook   │───►│  Validate   │───►│ Extract Entities    │
│   /extract  │    │   Input     │    │     (Ollama)        │
└─────────────┘    └─────────────┘    └──────────┬──────────┘
                                                  │
                                                  ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐
│  Response   │◄───│   Insert    │◄───│   Parse & Build     │
│   JSON      │    │   Neo4j     │    │   Cypher Query      │
└─────────────┘    └─────────────┘    └─────────────────────┘
```

## Setup Instructions

### 1. Import the Workflow

1. Open n8n UI (accessible via Tailscale)
2. Go to **Workflows** → **Import from File**
3. Upload `n8n/graph-extraction-workflow.json`

### 2. Configure Neo4j Credentials

1. Go to **Credentials** in n8n
2. Create new **HTTP Basic Auth** credential:
   - Name: `Neo4j Credentials`
   - User: `neo4j`
   - Password: (from internal docs)
3. Link credential to both Neo4j nodes in the workflow

### 3. Activate the Workflow

1. Toggle the workflow to **Active**
2. Note the webhook URL: `http://n8n:5678/webhook/extract-graph`

## API Usage

### Endpoint

```
POST http://n8n:5678/webhook/extract-graph
```

### Request Body

```json
{
  "content": "Document text to extract entities from...",
  "doc_id": "optional-document-id",
  "title": "Document Title",
  "source": "confluence"
}
```

### Parameters

| Field | Required | Description |
|-------|----------|-------------|
| `content` | Yes | Document text (max 15,000 chars) |
| `doc_id` | No | Unique document ID (auto-generated if not provided) |
| `title` | No | Document title (default: "Untitled") |
| `source` | No | Source system (default: "unknown") |

### Response

```json
{
  "status": "success",
  "doc_id": "doc_123",
  "entities_extracted": 5,
  "relationships_extracted": 3
}
```

## Example Usage

### curl

```bash
curl -X POST http://n8n:5678/webhook/extract-graph \
  -H "Content-Type: application/json" \
  -d '{
    "content": "The Platform Team owns the API Gateway service which handles all external traffic. The API Gateway depends on the Auth Service for authentication. John Smith leads the Platform Team.",
    "doc_id": "doc-platform-overview",
    "title": "Platform Architecture Overview",
    "source": "confluence"
  }'
```

### From n8n (chained workflow)

```javascript
// In a Code node, after ingesting to Elasticsearch
const docData = $input.first().json;

// Trigger graph extraction
return [{
  json: {
    content: docData.content,
    doc_id: docData.chunk_id,
    title: docData.title,
    source: docData.source
  }
}];
// Connect to HTTP Request node calling /webhook/extract-graph
```

## Entity Types Extracted

The workflow extracts the following entity types:

| Type | Examples |
|------|----------|
| `Person` | "John Smith", "CTO" |
| `Team` | "Platform Team", "Security Team" |
| `Service` | "API Gateway", "Auth Service" |
| `System` | "Salesforce", "AWS" |
| `Technology` | "Kubernetes", "Python" |
| `Product` | "Enterprise Suite" |
| `Organization` | "Acme Corp" |

## Relationship Types Extracted

| Type | Description |
|------|-------------|
| `OWNS` | Team/Person owns a Service/Product |
| `BELONGS_TO` | Person belongs to Team |
| `DEPENDS_ON` | Service depends on another Service |
| `RELATED_TO` | General relationship |

## Concepts Extracted

Abstract concepts are categorized:

| Category | Examples |
|----------|----------|
| `architecture` | Microservices, Event-Driven |
| `security` | Authentication, Encryption |
| `process` | CI/CD, Agile |
| `technology` | Containerization, Cloud Native |

## Integration with RAG Ingestion

To enable graph extraction during document ingestion:

### Option A: Chain Workflows

Modify the RAG Ingestion workflow to call graph extraction:

```
[Existing Ingestion] → [Store in ES] → [HTTP Request to /extract-graph]
```

### Option B: Scheduled Batch Processing

Create a scheduled workflow that:
1. Queries Elasticsearch for recent documents
2. Calls graph extraction for each
3. Marks documents as processed

### Option C: Manual/On-Demand

Call the extraction endpoint manually for specific documents.

## Verifying Extraction

After extraction, verify in Neo4j:

```cypher
// Check document was created
MATCH (d:Document {id: "doc-platform-overview"})
RETURN d;

// Check entities linked to document
MATCH (d:Document {id: "doc-platform-overview"})-[:MENTIONS]->(e:Entity)
RETURN e.name, e.type;

// Check all entities
MATCH (e:Entity) RETURN e.name, e.type LIMIT 20;

// Check relationships
MATCH (e1:Entity)-[r]->(e2:Entity)
RETURN e1.name, type(r), e2.name LIMIT 20;
```

## Troubleshooting

### No entities extracted

1. Check Ollama is running: `kubectl get pods -n rag-demo -l app=ollama`
2. Verify model is loaded: Document content may need to be longer
3. Check Ollama logs: `kubectl logs -n rag-demo deployment/ollama`

### Neo4j connection failed

1. Verify credentials in n8n
2. Check Neo4j is running: `kubectl get pods -n rag-demo -l app=neo4j`
3. Test connection: `curl http://neo4j:7474/`

### Extraction timeout

The workflow has a 120s timeout for Ollama. For very large documents:
- Reduce content size (workflow truncates at 15k chars)
- Use a faster model

### Malformed JSON from Ollama

The workflow attempts to extract JSON from the response even if there's surrounding text. If extraction fails:
- Check Ollama response in workflow execution logs
- Adjust the prompt in "Extract Entities" node
- Try different temperature settings

## Performance Considerations

- **Extraction time**: ~5-15 seconds per document (depends on model and length)
- **Rate limiting**: No built-in rate limiting; add delay nodes if processing many documents
- **Batch size**: Process documents individually; batch processing not implemented

## Customization

### Change LLM Model

Edit the "Extract Entities (Ollama)" node:
- Change `model` parameter to use a different Ollama model
- Adjust `num_predict` for longer/shorter responses

### Modify Extraction Prompt

Edit the prompt in "Extract Entities (Ollama)" node to:
- Add custom entity types
- Change relationship types
- Adjust output format

### Add Entity Types

1. Update the prompt schema
2. Modify "Parse Extraction" code to handle new types
3. Update the graph schema documentation
