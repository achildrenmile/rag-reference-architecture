# Performance and Regression Testing

This document describes performance testing for the RAG system, including baseline metrics and how to run regression tests.

## Test Script

Run the automated test suite:

```bash
./scripts/test-rag-performance.sh
```

Options:
- `NAMESPACE=rag-demo` - Kubernetes namespace (default: rag-demo)
- `ITERATIONS=5` - Number of latency test iterations (default: 5)

## Baseline Performance Metrics

### Database Query Latency

| Component | Operation | Latency (avg) | Notes |
|-----------|-----------|---------------|-------|
| Elasticsearch | Count query | ~16ms | Index: rag-demo |
| Elasticsearch | Search (5 docs) | ~18ms | Match all query |
| Neo4j | Node count | ~5ms | Simple aggregation |
| Neo4j | Relationship query | ~22ms | 10 result limit |

### Resource Consumption (Baseline)

| Component | CPU | Memory | Notes |
|-----------|-----|--------|-------|
| Elasticsearch | 5m | ~4.7GB | Primary memory consumer |
| Neo4j | 8m | ~825MB | Heap limited to 1GB |
| n8n | 3m | ~310MB | Workflow orchestration |
| OpenWebUI | 3m | ~618MB | Frontend + API |
| Ollama | 1m | ~110MB | Idle state (no model loaded) |
| nginx | 1m | ~13MB | Reverse proxy |
| cloudflared | 4m | ~18MB | Tunnel to Cloudflare |
| mcpo | 2m | ~348MB | MCP orchestrator |
| **Total** | ~27m | ~7GB | Single node cluster |

Node utilization: ~32% memory, <1% CPU

## What the Tests Verify

### 1. Pod Health Check
Verifies all pods in the namespace are in Running state.

### 2. Elasticsearch Functionality
- Connectivity to Elasticsearch
- Document count in rag-demo index
- Query response time

### 3. Elasticsearch Search Latency
- Runs multiple search queries
- Calculates average latency
- Baseline: <50ms for simple queries

### 4. Neo4j Connectivity
- HTTP API connectivity
- Authentication validation
- Node count query

### 5. Neo4j Query Latency
- Relationship traversal queries
- Average latency calculation
- Baseline: <50ms for simple traversals

### 6. n8n Webhook Availability
- Tests hybrid RAG webhook endpoint
- Reports if workflow needs activation
- When active: compares hybrid vs vector-only latency

### 7. Resource Consumption
- Pod-level CPU and memory usage
- Node-level resource utilization
- Helps identify resource pressure

## Performance Targets

| Metric | Target | Critical |
|--------|--------|----------|
| Elasticsearch query | <100ms | >500ms |
| Neo4j query | <100ms | >500ms |
| Vector-only RAG | <15s | >30s |
| Hybrid RAG | <20s | >45s |
| Node memory | <80% | >90% |
| Node CPU | <70% | >85% |

## Disabling Graph Database

The graph database (Neo4j) can be safely disabled without affecting vector RAG:

### Option 1: Scale to Zero
```bash
kubectl scale deployment neo4j -n rag-demo --replicas=0
```

### Option 2: Delete Deployment
```bash
kubectl delete deployment neo4j -n rag-demo
kubectl delete service neo4j -n rag-demo
kubectl delete pvc neo4j-data -n rag-demo  # Warning: deletes data
```

### Option 3: Disable in n8n Workflow
Set `hybrid_mode: false` as default in the workflow's "Validate Input" node.

## Monitoring

### Real-time Monitoring
```bash
# Watch pod resources
watch kubectl top pods -n rag-demo

# Watch node resources
watch kubectl top nodes

# Pod logs
kubectl logs -f deploy/elasticsearch -n rag-demo
kubectl logs -f deploy/neo4j -n rag-demo
```

### Prometheus Metrics (if configured)
- `elasticsearch_*` - ES metrics
- `neo4j_*` - Neo4j metrics
- `container_*` - Kubernetes container metrics

## Troubleshooting

### High Elasticsearch Memory
Elasticsearch is configured with a 4GB heap. If memory pressure occurs:
1. Reduce `ES_JAVA_OPTS` in deployment
2. Delete old indices
3. Reduce replica count

### Slow Neo4j Queries
1. Check indexes exist: `CALL db.indexes()`
2. Analyze query: `EXPLAIN MATCH ...`
3. Reduce graph traversal depth in workflows

### n8n Workflow Timeout
1. Reduce `vector_limit` parameter
2. Reduce `graph_depth` parameter
3. Use a smaller/faster Ollama model
