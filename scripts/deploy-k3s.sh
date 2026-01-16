#!/bin/bash
# Deploy RAG Reference Architecture to k3s
# Run this on rag-node-01

set -e

echo "=========================================="
echo "RAG Reference Architecture - k3s Deployment"
echo "=========================================="

# Check if running on correct machine
if [[ ! -f /etc/rancher/k3s/k3s.yaml ]]; then
    echo "ERROR: k3s not found. Install k3s first:"
    echo "  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC=\"--disable traefik --disable servicelb\" sh -"
    exit 1
fi

# Set kubeconfig
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
K8S_DIR="$REPO_DIR/k8s"

echo ""
echo "[1/6] Creating secrets..."
if [[ ! -f "$K8S_DIR/overlays/production/secrets.yaml" ]]; then
    echo "ERROR: secrets.yaml not found!"
    echo "Copy secrets.yaml.example to secrets.yaml and fill in values"
    exit 1
fi

echo ""
echo "[2/6] Creating static files ConfigMap..."
kubectl create configmap openwebui-static-files \
    --from-file=search.html="$REPO_DIR/static/search.html" \
    --from-file=showcase.html="$REPO_DIR/static/showcase.html" \
    --from-file=loader.js="$REPO_DIR/static/loader.js" \
    -n rag-demo --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "[3/6] Applying Kustomize manifests..."
kubectl apply -k "$K8S_DIR/overlays/production"

echo ""
echo "[4/6] Waiting for pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n rag-demo --timeout=300s || true

echo ""
echo "[5/6] Checking pod status..."
kubectl get pods -n rag-demo

echo ""
echo "[6/6] Pulling Ollama models..."
kubectl exec -n rag-demo deployment/ollama -- ollama pull nomic-embed-text || true
kubectl exec -n rag-demo deployment/ollama -- ollama pull phi3:mini || true

echo ""
echo "=========================================="
echo "Deployment complete!"
echo ""
echo "Services:"
echo "  OpenWebUI: kubectl port-forward -n rag-demo svc/openwebui 8080:8080"
echo "  n8n:       kubectl port-forward -n rag-demo svc/n8n 5678:5678"
echo "  ES:        kubectl port-forward -n rag-demo svc/elasticsearch 9200:9200"
echo "=========================================="
