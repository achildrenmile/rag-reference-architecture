# OpenShift Migration Plan - RAG Reference Architecture

## Executive Summary

This document outlines the complete migration path from Docker Compose to OpenShift on the existing rag-node-01 hardware, with GitOps-based deployment and Cloudflare Tunnel exposure.

---

## Phase 0: Current State Analysis

### Hardware (rag-node-01 - GEEKOM A8)
| Resource | Available | Required for OpenShift |
|----------|-----------|----------------------|
| CPU | 8 cores / 16 threads (Ryzen 9 8945HS) | 4+ cores ✅ |
| RAM | 32 GB | 16+ GB ✅ |
| Storage | 950 GB NVMe (100GB allocated, **850GB free**) | 120+ GB ✅ |
| OS | Ubuntu 24.04 LTS | Supported ✅ |

### Current Docker Workloads
- Elasticsearch 9 (~8GB RAM, ~20GB data)
- Ollama (~4GB RAM, ~10GB models)
- OpenWebUI (~1GB RAM, ~1GB data)
- n8n (~1GB RAM, ~1GB data)
- MCPO, nginx proxies, cloudflared

### Verdict: **Hardware is sufficient for Single Node OpenShift (SNO) or MicroShift**

---

## Phase 1: Backup to GitHub

### 1.1 What's Already in GitHub
```
rag-reference-architecture/
├── docker-compose.yml          ✅ Infrastructure as Code
├── nginx/default.conf          ✅ Nginx configs
├── n8n-custom/nginx.conf       ✅ n8n proxy config
├── mcpo/config.json            ✅ MCP server config
├── static/                     ✅ Custom HTML pages
├── scripts/                    ✅ Utility scripts
└── n8n/*.json                  ✅ Workflow definitions
```

### 1.2 Data That Needs Backup (NOT in GitHub)

| Data | Location | Backup Method |
|------|----------|---------------|
| Elasticsearch indices | `esdata` volume | `elasticdump` or snapshot API |
| Ollama models | `ollama-data` volume | Re-pull after migration (faster) |
| OpenWebUI users/settings | `openwebui-data` volume | SQLite backup + file copy |
| n8n workflows/credentials | `n8n-data` volume | n8n export API or file copy |

### 1.3 Backup Scripts to Add

```bash
# scripts/backup-data.sh
#!/bin/bash
BACKUP_DIR="/tmp/rag-backup-$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Elasticsearch - export indices
docker exec elasticsearch curl -X PUT "localhost:9200/_snapshot/backup" -H 'Content-Type: application/json' -d '{
  "type": "fs",
  "settings": { "location": "/usr/share/elasticsearch/backup" }
}'

# OpenWebUI - copy SQLite
docker cp openwebui:/app/backend/data/webui.db $BACKUP_DIR/

# n8n - export workflows
docker exec n8n n8n export:workflow --all --output=/home/node/.n8n/backups/
docker cp n8n:/home/node/.n8n/backups $BACKUP_DIR/n8n-workflows

echo "Backup complete: $BACKUP_DIR"
```

---

## Phase 2: OpenShift Architecture Decision

### Option A: MicroShift (Recommended for Demo)

**Pros:**
- Lightweight (~2GB base RAM)
- Single binary, easy install
- RHEL/CentOS compatible
- Supports Kubernetes APIs
- Good for edge/demo scenarios

**Cons:**
- No web console (CLI only)
- Limited operator support
- Community support only

**Resource Usage:** ~4GB RAM, ~20GB disk

### Option B: Single Node OpenShift (SNO)

**Pros:**
- Full OpenShift experience
- Web console included
- Full operator catalog
- Enterprise support available

**Cons:**
- Heavy (~16GB RAM minimum)
- Complex installation
- Requires RHCOS or RHEL

**Resource Usage:** ~16GB RAM, ~120GB disk

### Option C: OKD (Community OpenShift)

**Pros:**
- Free, open source
- Full OpenShift features
- Web console included

**Cons:**
- Community support only
- Can be unstable

### Recommendation: **MicroShift** for demo purposes
- Leaves resources for actual workloads
- Simple to install and maintain
- Can upgrade to full OpenShift later

---

## Phase 3: Pre-Installation Setup

### 3.1 Expand LVM Storage

```bash
# On rag-node-01 (requires sudo)

# Check available space in volume group
sudo vgs

# Extend logical volume by 200GB for OpenShift
sudo lvextend -L +200G /dev/ubuntu-vg/ubuntu-lv

# Resize filesystem
sudo resize2fs /dev/ubuntu-vg/ubuntu-lv

# Verify
df -h /
```

### 3.2 System Requirements

```bash
# Install prerequisites
sudo apt update
sudo apt install -y curl wget git jq

# Disable swap (required for Kubernetes)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Load required kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Sysctl settings
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
vm.max_map_count                    = 262144
EOF

sudo sysctl --system
```

### 3.3 Stop Existing Docker Workloads

```bash
cd ~/rag-reference-architecture
docker compose down

# Backup volumes before proceeding
./scripts/backup-data.sh
```

---

## Phase 4: MicroShift Installation

### 4.1 Install MicroShift on Ubuntu

```bash
# Add Red Hat repository (or use CentOS Stream for easier compatibility)
# For Ubuntu, we'll use the unofficial build or switch to k3s with OpenShift tooling

# Option: Use k3s as base with OpenShift-compatible tooling
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik --disable servicelb" sh -

# Install kubectl
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Verify
kubectl get nodes
```

### 4.2 Alternative: True MicroShift (Requires RHEL/CentOS)

```bash
# If switching to CentOS Stream 9:

# Enable MicroShift repo
sudo dnf copr enable @redhat-et/microshift -y

# Install MicroShift
sudo dnf install -y microshift

# Start MicroShift
sudo systemctl enable --now microshift

# Get kubeconfig
mkdir -p ~/.kube
sudo cat /var/lib/microshift/resources/kubeadmin/kubeconfig > ~/.kube/config
```

---

## Phase 5: GitOps Setup with ArgoCD

### 5.1 Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 5.2 Repository Structure for GitOps

```
rag-reference-architecture/
├── k8s/
│   ├── base/
│   │   ├── namespace.yaml
│   │   ├── elasticsearch/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── pvc.yaml
│   │   │   └── configmap.yaml
│   │   ├── ollama/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── pvc.yaml
│   │   ├── openwebui/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── pvc.yaml
│   │   │   └── configmap.yaml
│   │   ├── n8n/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── pvc.yaml
│   │   │   └── configmap.yaml
│   │   ├── mcpo/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── configmap.yaml
│   │   └── ingress/
│   │       ├── ingress.yaml
│   │       └── configmap-nginx.yaml
│   ├── overlays/
│   │   └── production/
│   │       ├── kustomization.yaml
│   │       ├── secrets.yaml.enc      # Sealed secrets
│   │       └── patches/
│   └── argocd/
│       └── application.yaml
└── docker-compose.yml                 # Keep for local dev
```

### 5.3 ArgoCD Application Definition

```yaml
# k8s/argocd/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rag-reference-architecture
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/achildrenmile/rag-reference-architecture.git
    targetRevision: main
    path: k8s/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: rag-demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

## Phase 6: Kubernetes Manifests

### 6.1 Namespace

```yaml
# k8s/base/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: rag-demo
  labels:
    app.kubernetes.io/part-of: rag-reference-architecture
```

### 6.2 Elasticsearch

```yaml
# k8s/base/elasticsearch/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: elasticsearch
  namespace: rag-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      initContainers:
        - name: sysctl
          image: busybox
          command: ["sysctl", "-w", "vm.max_map_count=262144"]
          securityContext:
            privileged: true
      containers:
        - name: elasticsearch
          image: docker.elastic.co/elasticsearch/elasticsearch:9.0.0
          env:
            - name: discovery.type
              value: single-node
            - name: xpack.security.enabled
              value: "false"
            - name: ES_JAVA_OPTS
              value: "-Xms4g -Xmx4g"
          ports:
            - containerPort: 9200
          resources:
            requests:
              memory: "4Gi"
              cpu: "1"
            limits:
              memory: "8Gi"
              cpu: "4"
          volumeMounts:
            - name: data
              mountPath: /usr/share/elasticsearch/data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: elasticsearch-data
---
# k8s/base/elasticsearch/pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: elasticsearch-data
  namespace: rag-demo
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
---
# k8s/base/elasticsearch/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch
  namespace: rag-demo
spec:
  selector:
    app: elasticsearch
  ports:
    - port: 9200
      targetPort: 9200
```

### 6.3 Ollama

```yaml
# k8s/base/ollama/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama
  namespace: rag-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  template:
    metadata:
      labels:
        app: ollama
    spec:
      containers:
        - name: ollama
          image: ollama/ollama:latest
          ports:
            - containerPort: 11434
          resources:
            requests:
              memory: "4Gi"
              cpu: "2"
            limits:
              memory: "16Gi"
              cpu: "8"
          volumeMounts:
            - name: data
              mountPath: /root/.ollama
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: ollama-data
---
# k8s/base/ollama/pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ollama-data
  namespace: rag-demo
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 30Gi
---
# k8s/base/ollama/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: ollama
  namespace: rag-demo
spec:
  selector:
    app: ollama
  ports:
    - port: 11434
      targetPort: 11434
```

### 6.4 OpenWebUI

```yaml
# k8s/base/openwebui/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openwebui
  namespace: rag-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: openwebui
  template:
    metadata:
      labels:
        app: openwebui
    spec:
      containers:
        - name: openwebui
          image: ghcr.io/open-webui/open-webui:main
          env:
            - name: OLLAMA_BASE_URL
              value: http://ollama:11434
            - name: WEBUI_NAME
              value: AI4U
            - name: WEBUI_SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: openwebui-secrets
                  key: secret-key
            - name: VECTOR_DB
              value: elasticsearch
            - name: ELASTICSEARCH_URL
              value: http://elasticsearch:9200
            - name: ENABLE_RAG_HYBRID_SEARCH
              value: "true"
          ports:
            - containerPort: 8080
          resources:
            requests:
              memory: "512Mi"
              cpu: "250m"
            limits:
              memory: "2Gi"
              cpu: "2"
          volumeMounts:
            - name: data
              mountPath: /app/backend/data
            - name: static-files
              mountPath: /app/backend/open_webui/static/search.html
              subPath: search.html
            - name: static-files
              mountPath: /app/backend/open_webui/static/showcase.html
              subPath: showcase.html
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: openwebui-data
        - name: static-files
          configMap:
            name: openwebui-static-files
---
# k8s/base/openwebui/pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: openwebui-data
  namespace: rag-demo
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
# k8s/base/openwebui/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: openwebui
  namespace: rag-demo
spec:
  selector:
    app: openwebui
  ports:
    - port: 8080
      targetPort: 8080
```

---

## Phase 7: Cloudflare Tunnel Integration

### 7.1 Cloudflared Deployment

```yaml
# k8s/base/cloudflared/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: rag-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      containers:
        - name: cloudflared
          image: cloudflare/cloudflared:latest
          args:
            - tunnel
            - run
          env:
            - name: TUNNEL_TOKEN
              valueFrom:
                secretKeyRef:
                  name: cloudflared-secrets
                  key: tunnel-token
          resources:
            requests:
              memory: "64Mi"
              cpu: "50m"
            limits:
              memory: "256Mi"
              cpu: "500m"
```

### 7.2 Cloudflare Tunnel Configuration

Update Cloudflare Dashboard:
- `ai4u.strali.solutions` → `http://openwebui:8080`
- `n8n.strali.solutions` → `http://n8n:5678`

Or use config file:

```yaml
# cloudflare/config.yaml (mount as ConfigMap)
tunnel: 9e8b49af-f361-4478-b343-396cb5173a8b
credentials-file: /etc/cloudflared/credentials.json

ingress:
  - hostname: ai4u.strali.solutions
    service: http://openwebui:8080
  - hostname: n8n.strali.solutions
    service: http://n8n:5678
  - service: http_status:404
```

---

## Phase 8: Secrets Management

### 8.1 Using Sealed Secrets (Recommended)

```bash
# Install Sealed Secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Install kubeseal CLI
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
tar xzf kubeseal-0.24.0-linux-amd64.tar.gz
sudo mv kubeseal /usr/local/bin/

# Create sealed secret
kubectl create secret generic openwebui-secrets \
  --namespace rag-demo \
  --from-literal=secret-key='YOUR_SECRET_KEY' \
  --dry-run=client -o yaml | kubeseal -o yaml > k8s/overlays/production/secrets.yaml
```

---

## Phase 9: Migration Execution Checklist

### Pre-Migration
- [ ] Expand LVM volume (+200GB)
- [ ] Run backup script
- [ ] Push all configs to GitHub
- [ ] Test backup restore procedure

### Installation
- [ ] Disable swap
- [ ] Configure sysctl
- [ ] Install k3s/MicroShift
- [ ] Verify cluster health
- [ ] Install ArgoCD

### Deployment
- [ ] Create sealed secrets
- [ ] Apply ArgoCD application
- [ ] Verify all pods running
- [ ] Pull Ollama models
- [ ] Restore data (if needed)

### Validation
- [ ] Test Elasticsearch API
- [ ] Test Ollama models
- [ ] Test OpenWebUI login
- [ ] Test n8n workflows
- [ ] Test search functionality
- [ ] Test via Cloudflare URLs

### Cutover
- [ ] Update Cloudflare tunnel config
- [ ] Verify external access
- [ ] Monitor for 24 hours
- [ ] Remove Docker installation (optional)

---

## Rollback Plan

If migration fails:

```bash
# Stop Kubernetes
sudo systemctl stop k3s  # or microshift

# Restart Docker Compose
cd ~/rag-reference-architecture
docker compose up -d

# Restore data from backup if needed
./scripts/restore-data.sh
```

---

## Timeline Estimate

| Phase | Tasks | Duration |
|-------|-------|----------|
| 1 | Backup & GitHub sync | 1 hour |
| 2-3 | System prep & LVM | 30 min |
| 4 | OpenShift/k3s install | 1 hour |
| 5 | ArgoCD setup | 30 min |
| 6 | Deploy workloads | 1 hour |
| 7-8 | Cloudflare & secrets | 30 min |
| 9 | Testing & validation | 2 hours |

**Total: ~6-8 hours** for complete migration

---

## Next Steps

1. **Confirm OpenShift variant** (MicroShift vs k3s vs full SNO)
2. **Create k8s/ directory structure** with all manifests
3. **Set up sealed secrets**
4. **Schedule migration window**

---

*Document Version: 1.0*
*Last Updated: 2026-01-16*
