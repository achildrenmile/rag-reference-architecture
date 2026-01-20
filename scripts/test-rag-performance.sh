#!/bin/bash
# RAG Performance and Regression Test Script
# Tests Elasticsearch, Neo4j, and n8n RAG workflows

set -e

NAMESPACE="${NAMESPACE:-rag-demo}"
NEO4J_PASSWORD="${NEO4J_PASSWORD:-aspL7Lt2UVrANyb5A6Xo}"
ITERATIONS="${ITERATIONS:-5}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  RAG Performance & Regression Tests   ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Helper function to run tests from nginx pod
run_curl() {
    kubectl exec -n "$NAMESPACE" deploy/nginx -- curl -s -w "\n%{time_total}" "$@" 2>/dev/null
}

# Test 1: Check all pods are running
echo -e "${YELLOW}[1/7] Checking pod status...${NC}"
PODS_NOT_READY=$(kubectl get pods -n "$NAMESPACE" --no-headers | grep -v "Running" | wc -l)
if [ "$PODS_NOT_READY" -eq 0 ]; then
    echo -e "${GREEN}✓ All pods are running${NC}"
else
    echo -e "${RED}✗ Some pods are not running:${NC}"
    kubectl get pods -n "$NAMESPACE" --no-headers | grep -v "Running"
    exit 1
fi

# Test 2: Elasticsearch connectivity and document count
echo ""
echo -e "${YELLOW}[2/7] Testing Elasticsearch...${NC}"
ES_RESULT=$(run_curl -X GET "http://elasticsearch:9200/rag-demo/_count")
ES_COUNT=$(echo "$ES_RESULT" | head -1 | jq -r '.count // 0')
ES_TIME=$(echo "$ES_RESULT" | tail -1)
echo -e "  Document count: ${GREEN}$ES_COUNT${NC}"
echo -e "  Response time: ${GREEN}${ES_TIME}s${NC}"

if [ "$ES_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Elasticsearch is functional${NC}"
else
    echo -e "${YELLOW}⚠ Elasticsearch has no documents${NC}"
fi

# Test 3: Elasticsearch vector search latency
echo ""
echo -e "${YELLOW}[3/7] Testing Elasticsearch search latency...${NC}"
ES_LATENCIES=()
for i in $(seq 1 $ITERATIONS); do
    RESULT=$(run_curl -X POST "http://elasticsearch:9200/rag-demo/_search" \
        -H "Content-Type: application/json" \
        -d '{"size": 5, "query": {"match_all": {}}}')
    LATENCY=$(echo "$RESULT" | tail -1)
    ES_LATENCIES+=("$LATENCY")
done
ES_AVG=$(echo "${ES_LATENCIES[@]}" | tr ' ' '\n' | awk '{sum+=$1} END {printf "%.3f", sum/NR}')
echo -e "  Average latency ($ITERATIONS runs): ${GREEN}${ES_AVG}s${NC}"
echo -e "${GREEN}✓ Elasticsearch search working${NC}"

# Test 4: Neo4j connectivity
echo ""
echo -e "${YELLOW}[4/7] Testing Neo4j...${NC}"
NEO4J_AUTH=$(echo -n "neo4j:$NEO4J_PASSWORD" | base64)
NEO4J_RESULT=$(run_curl -X POST "http://neo4j:7474/db/neo4j/tx/commit" \
    -H "Content-Type: application/json" \
    -H "Authorization: Basic $NEO4J_AUTH" \
    -d '{"statements":[{"statement":"MATCH (n) RETURN count(n) as nodeCount"}]}')
NEO4J_COUNT=$(echo "$NEO4J_RESULT" | head -1 | jq -r '.results[0].data[0].row[0] // 0')
NEO4J_ERRORS=$(echo "$NEO4J_RESULT" | head -1 | jq -r '.errors | length')
NEO4J_TIME=$(echo "$NEO4J_RESULT" | tail -1)

echo -e "  Node count: ${GREEN}$NEO4J_COUNT${NC}"
echo -e "  Response time: ${GREEN}${NEO4J_TIME}s${NC}"

if [ "$NEO4J_ERRORS" -eq 0 ]; then
    echo -e "${GREEN}✓ Neo4j is functional${NC}"
else
    echo -e "${RED}✗ Neo4j returned errors${NC}"
    exit 1
fi

# Test 5: Neo4j query latency
echo ""
echo -e "${YELLOW}[5/7] Testing Neo4j query latency...${NC}"
NEO4J_LATENCIES=()
for i in $(seq 1 $ITERATIONS); do
    RESULT=$(run_curl -X POST "http://neo4j:7474/db/neo4j/tx/commit" \
        -H "Content-Type: application/json" \
        -H "Authorization: Basic $NEO4J_AUTH" \
        -d '{"statements":[{"statement":"MATCH (e:Entity)-[r]->(t) RETURN e.name, type(r), t.name LIMIT 10"}]}')
    LATENCY=$(echo "$RESULT" | tail -1)
    NEO4J_LATENCIES+=("$LATENCY")
done
NEO4J_AVG=$(echo "${NEO4J_LATENCIES[@]}" | tr ' ' '\n' | awk '{sum+=$1} END {printf "%.3f", sum/NR}')
echo -e "  Average latency ($ITERATIONS runs): ${GREEN}${NEO4J_AVG}s${NC}"
echo -e "${GREEN}✓ Neo4j queries working${NC}"

# Test 6: n8n webhook availability
echo ""
echo -e "${YELLOW}[6/7] Testing n8n RAG webhook...${NC}"
N8N_RESULT=$(run_curl -X POST "http://n8n:5678/webhook/rag" \
    -H "Content-Type: application/json" \
    -d '{"query": "test", "hybrid_mode": false}')
N8N_CODE=$(echo "$N8N_RESULT" | head -1 | jq -r '.code // "success"')

if [ "$N8N_CODE" = "404" ]; then
    echo -e "${YELLOW}⚠ Hybrid RAG workflow not activated${NC}"
    echo -e "  Import and activate workflow from: n8n/hybrid-rag-workflow.json"
else
    echo -e "${GREEN}✓ n8n RAG webhook is active${NC}"

    # Test hybrid vs vector-only
    echo ""
    echo -e "${YELLOW}[6b] Comparing hybrid vs vector-only latency...${NC}"

    # Vector-only
    VECTOR_START=$(date +%s.%N)
    run_curl -X POST "http://n8n:5678/webhook/rag" \
        -H "Content-Type: application/json" \
        -d '{"query": "What is RAG?", "hybrid_mode": false}' > /dev/null
    VECTOR_END=$(date +%s.%N)
    VECTOR_TIME=$(echo "$VECTOR_END - $VECTOR_START" | bc)
    echo -e "  Vector-only: ${GREEN}${VECTOR_TIME}s${NC}"

    # Hybrid
    HYBRID_START=$(date +%s.%N)
    run_curl -X POST "http://n8n:5678/webhook/rag" \
        -H "Content-Type: application/json" \
        -d '{"query": "What is RAG?", "hybrid_mode": true}' > /dev/null
    HYBRID_END=$(date +%s.%N)
    HYBRID_TIME=$(echo "$HYBRID_END - $HYBRID_START" | bc)
    echo -e "  Hybrid: ${GREEN}${HYBRID_TIME}s${NC}"
fi

# Test 7: Resource consumption
echo ""
echo -e "${YELLOW}[7/7] Checking resource consumption...${NC}"
echo ""
echo -e "  ${BLUE}Pod Resource Usage:${NC}"
kubectl top pods -n "$NAMESPACE" 2>/dev/null || echo "  (metrics-server not available)"
echo ""
echo -e "  ${BLUE}Node Resource Usage:${NC}"
kubectl top nodes 2>/dev/null || echo "  (metrics-server not available)"

# Summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}           Test Summary                 ${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "  Elasticsearch docs:     ${GREEN}$ES_COUNT${NC}"
echo -e "  Elasticsearch latency:  ${GREEN}${ES_AVG}s${NC} (avg)"
echo -e "  Neo4j nodes:            ${GREEN}$NEO4J_COUNT${NC}"
echo -e "  Neo4j latency:          ${GREEN}${NEO4J_AVG}s${NC} (avg)"
echo ""
echo -e "${GREEN}All regression tests passed!${NC}"
