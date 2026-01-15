#!/bin/bash
# Ingest sample documents into RAG demo
# Usage: ./scripts/ingest-samples.sh [base_url]

BASE_URL="${1:-https://n8n.strali.solutions}"
INGEST_ENDPOINT="$BASE_URL/webhook/ingest"
SAMPLE_DIR="$(dirname "$0")/../sample-docs"

echo "RAG Sample Document Ingestion"
echo "=============================="
echo "Endpoint: $INGEST_ENDPOINT"
echo ""

# Check if sample docs directory exists
if [ ! -d "$SAMPLE_DIR" ]; then
    echo "Error: Sample docs directory not found: $SAMPLE_DIR"
    exit 1
fi

# Count files
FILE_COUNT=$(ls -1 "$SAMPLE_DIR"/*.txt 2>/dev/null | wc -l)
if [ "$FILE_COUNT" -eq 0 ]; then
    echo "Error: No .txt files found in $SAMPLE_DIR"
    exit 1
fi

echo "Found $FILE_COUNT documents to ingest"
echo ""

SUCCESS=0
FAILED=0

for file in "$SAMPLE_DIR"/*.txt; do
    filename=$(basename "$file")

    # Extract title and source from file (first two lines)
    title=$(grep "^Title:" "$file" | sed 's/^Title: //')
    source=$(grep "^Source:" "$file" | sed 's/^Source: //')

    # Get content (everything after the Source line)
    content=$(sed '1,/^Source:/d' "$file" | sed '/^$/d' | tr '\n' ' ' | sed 's/"/\\"/g')

    echo -n "Ingesting: $title... "

    # Make the API call
    response=$(curl -s -X POST "$INGEST_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d "{
            \"title\": \"$title\",
            \"source\": \"$source\",
            \"content\": \"$content\"
        }" 2>&1)

    # Check response
    if echo "$response" | grep -q '"status":"success"'; then
        chunks=$(echo "$response" | grep -o '"chunks_processed":[0-9]*' | grep -o '[0-9]*')
        echo "OK ($chunks chunks)"
        ((SUCCESS++))
    else
        echo "FAILED"
        echo "  Response: $response"
        ((FAILED++))
    fi
done

echo ""
echo "=============================="
echo "Ingestion complete!"
echo "  Success: $SUCCESS"
echo "  Failed:  $FAILED"
echo ""
echo "Test the search at:"
echo "  https://ai4u.strali.solutions/search"
