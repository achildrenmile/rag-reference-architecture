# RAG Reference Architecture

A complete, reproducible setup for a modern AI-assisted search and Retrieval-Augmented Generation (RAG) system using local LLMs, Elasticsearch, and secure public exposure via Cloudflare Tunnel. Includes EU AI Act compliance features.

## Architecture Overview

```
Internet
    ↓
Cloudflare Tunnel (cloudflared)
    ↓                    ↓
OpenWebUI            n8n
(Chat + RAG)    (Workflow Automation)
    ↓                ↓
Ollama          Elasticsearch
(LLM Runtime)   (Vector Store)
    ↓
Kubernetes (k3s) / Docker Compose
```

### Key Properties

- No public inbound ports required
- HTTPS only via Cloudflare
- Authentication at application level
- CPU-first inference (GPU optional)
- **Kubernetes (k3s)** or Docker Compose deployment
- Fully self-hosted
- EU AI Act compliant (Article 50 transparency)

## About This Reference Architecture

This repository provides a fully functional RAG (Retrieval-Augmented Generation) reference architecture designed for learning, evaluation, and proof-of-concept demonstrations. It showcases how local LLMs, vector search, and workflow automation can work together to build intelligent document retrieval systems — entirely self-hosted and without external API dependencies. While the demo is production-quality code, it is intentionally scoped as a starting point rather than a turnkey enterprise solution.

Production deployments require careful consideration of data governance, access controls, infrastructure scaling, monitoring, and organizational change management. For regulated industries or EU AI Act compliance, additional measures — including risk classification, transparency documentation, human oversight mechanisms, and audit trails — must be architected to meet specific legal and operational requirements. This demo illustrates the technical foundations; achieving full compliance requires professional assessment tailored to your context.

**Live Demo**: [ai4u.strali.solutions](https://ai4u.strali.solutions) | **Showcase**: [ai4u.strali.solutions/showcase](https://ai4u.strali.solutions/showcase)

If you're exploring RAG for your organization, we offer consulting, architecture review, and implementation services to help you move from proof-of-concept to production with confidence. [Contact Strali Solutions](https://strali.solutions/#kontakt) to discuss your requirements.

## Target Environment

### Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | AMD Ryzen 7 / Intel i7 | AMD Ryzen 9 |
| RAM | 32 GB | 64 GB |
| Storage | 256 GB NVMe SSD | 512 GB+ NVMe SSD |

### Validated Hardware

- GEEKOM A8 Max (AMD Ryzen 9 8945HS, 32GB RAM)

### Operating System

- Ubuntu Server 22.04 LTS or 24.04 LTS (headless)

## Repository Structure

```
.
├── README.md              # This file (public documentation)
├── SECURITY.md            # Security hardening guide (public)
├── docker-compose.yml     # Docker Compose orchestration (legacy)
├── backup.sh              # Automated backup script
├── .env.example           # Environment variables template (Docker)
├── .env                   # Actual environment variables (not in repo)
├── .gitignore             # Excluded files
├── k8s/                   # Kubernetes (k3s) manifests
│   ├── apps/              # Argo CD Application definitions (GitOps)
│   │   ├── root.yaml      # App-of-apps root application
│   │   ├── argocd.yaml    # Argo CD self-management
│   │   ├── headlamp.yaml  # Kubernetes Web UI
│   │   └── rag-demo.yaml  # RAG stack application
│   ├── infrastructure/    # Helm values for platform components
│   │   ├── argocd/
│   │   └── headlamp/
│   ├── base/              # Base Kustomize manifests
│   │   ├── namespace.yaml
│   │   ├── kustomization.yaml
│   │   ├── elasticsearch/
│   │   ├── ollama/
│   │   ├── openwebui/
│   │   ├── n8n/
│   │   ├── mcpo/
│   │   └── cloudflared/
│   └── overlays/
│       └── production/
│           ├── kustomization.yaml
│           ├── static/               # Static files for ConfigMap
│           ├── secrets.yaml.example  # Secrets template
│           └── secrets.yaml          # Actual secrets (not in repo)
├── scripts/
│   ├── install-k3s.sh         # k3s installation script
│   ├── deploy-k3s.sh          # k3s deployment script
│   ├── disk-monitor.sh        # Uptime Kuma push monitor for disk space
│   └── ingest-samples.sh      # Ingest sample documents into RAG
├── static/
│   ├── loader.js          # Custom JS for legal footer injection
│   ├── search.html        # Semantic search UI
│   └── showcase.html      # Feature showcase page
├── mcpo/
│   └── config.json        # MCPO MCP server configuration
├── n8n/
│   ├── rag-ingestion-workflow.json      # RAG pipeline workflow
│   ├── semantic-search-workflow.json    # Vector search API workflow
│   └── scheduled-ingestion-workflow.json # RSS auto-ingestion workflow
├── n8n-custom/
│   └── nginx.conf              # Nginx proxy config for legal footer injection
├── demo/
│   ├── RAG_Architecture_Guide.md  # Knowledge base demo document
│   └── prompt_templates.md        # Demo prompt templates
├── sample-docs/               # Sample company documents for RAG demo
│   ├── 01-employee-onboarding.txt
│   ├── 02-it-security-policy.txt
│   ├── 03-expense-policy.txt
│   ├── 04-api-documentation.txt
│   ├── 05-remote-work-guidelines.txt
│   ├── 06-engineering-practices.txt
│   ├── 07-support-procedures.txt
│   └── 08-benefits-overview.txt
├── CREDENTIALS.md         # Sensitive credentials (not in repo)
├── SECURITY-ASSESSMENT.md # Security assessment details (not in repo)
└── models/                # Model configurations (future)
```

## Setup Guide

### Step 1: BIOS and OS Installation

1. Enter BIOS:
   - Enable UEFI
   - Disable Secure Boot

2. Install Ubuntu Server:
   - Minimal installation
   - OpenSSH enabled
   - Full disk with LVM
   - No disk encryption

3. Reboot and connect via SSH

### Step 2: Base System Preparation

```bash
# Update system
sudo apt update && sudo apt full-upgrade -y

# Install dependencies
sudo apt install -y ca-certificates curl gnupg git htop jq unzip net-tools

# Reboot
sudo reboot
```

### Step 3: Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/rag-reference-architecture.git
cd rag-reference-architecture
```

---

## Deployment Options

Choose **one** of the following deployment methods:

- **[Option A: Kubernetes (k3s)](#option-a-kubernetes-k3s-deployment)** - Recommended for production
- **[Option B: Docker Compose](#option-b-docker-compose-deployment)** - Simpler setup for development

---

## Option A: Kubernetes (k3s) Deployment

### Step 4: Install k3s

```bash
# Run the installation script
sudo ./scripts/install-k3s.sh
```

This script:
- Disables swap
- Configures kernel modules and sysctl settings
- Installs k3s with Traefik and ServiceLB disabled
- Sets up kubeconfig for your user

After installation, log out and back in, or run:
```bash
export KUBECONFIG=~/.kube/config
```

### Step 5: Configure Secrets

```bash
# Copy the secrets template
cp k8s/overlays/production/secrets.yaml.example k8s/overlays/production/secrets.yaml

# Edit with your values
nano k8s/overlays/production/secrets.yaml
```

Required secrets:
- `openwebui-secrets.secret-key` - Random 32-byte hex string for session encryption
- `cloudflared-secrets.tunnel-token` - Cloudflare Tunnel token
- `mcpo-secrets.github-token` - GitHub personal access token (optional)

Generate a secret key:
```bash
openssl rand -hex 32
```

### Step 6: Deploy to k3s

```bash
# Run the deployment script
./scripts/deploy-k3s.sh
```

This script:
- Creates the static files ConfigMap
- Applies all Kustomize manifests
- Waits for pods to be ready
- Pulls required Ollama models (nomic-embed-text, phi3:mini)

### Step 7: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n rag-demo

# Check services
kubectl get svc -n rag-demo

# View logs
kubectl logs -n rag-demo deployment/openwebui
```

### Step 8: Access Services (k3s)

For local access via port forwarding:
```bash
# OpenWebUI (main interface)
kubectl port-forward -n rag-demo svc/openwebui 8080:8080

# n8n (workflow automation)
kubectl port-forward -n rag-demo svc/n8n 5678:5678

# Elasticsearch (vector database)
kubectl port-forward -n rag-demo svc/elasticsearch 9200:9200
```

### Step 9: Pull Additional Models (k3s)

```bash
# Core models
kubectl exec -n rag-demo deployment/ollama -- ollama pull mistral:7b
kubectl exec -n rag-demo deployment/ollama -- ollama pull llama3.1:8b

# Specialized models
kubectl exec -n rag-demo deployment/ollama -- ollama pull llava        # Vision
kubectl exec -n rag-demo deployment/ollama -- ollama pull llama3.2:3b  # Fast/efficient
kubectl exec -n rag-demo deployment/ollama -- ollama pull gemma2:2b    # Fast/efficient

# Verify models
kubectl exec -n rag-demo deployment/ollama -- ollama list
```

### Step 10: Import n8n Workflows (k3s)

1. Access n8n via port forwarding or your tunnel URL
2. Import workflows from the `n8n/` directory:
   - `rag-ingestion-workflow.json` - Document ingestion pipeline
   - `semantic-search-workflow.json` - Vector search API
   - `scheduled-ingestion-workflow.json` - RSS auto-ingestion (optional)
3. Activate the workflows

---

## GitOps with Argo CD (Optional)

For production deployments, this repository supports full GitOps using Argo CD with the **app-of-apps pattern**. This enables:

- **Declarative configuration**: All cluster state defined in Git
- **Automatic sync**: Changes pushed to `main` are automatically deployed
- **Self-healing**: Manual cluster changes are reverted to match Git
- **Audit trail**: Git history provides complete change log

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Argo CD                              │
│                   (GitOps Controller)                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────┐│
│  │    root      │  │   argocd     │  │      headlamp       ││
│  │ (app-of-apps)│ │(self-managed)│  │   (Kubernetes UI)    ││
│  └──────┬───────┘  └──────────────┘  └─────────────────────┘│
│         │                                                   │
│         ▼                                                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                    rag-demo                         │    │
│  │  (Elasticsearch, Ollama, OpenWebUI, n8n, MCPO, etc.)│    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Applications Managed

| Application | Type | Description |
|-------------|------|-------------|
| `root` | App-of-Apps | Manages all other applications |
| `argocd` | Helm | Argo CD self-management |
| `headlamp` | Helm | Kubernetes Web UI for cluster visibility |
| `rag-demo` | Kustomize | The RAG stack (from `k8s/overlays/production`) |

### Setup GitOps

1. **Install Argo CD** (if not already installed):
   ```bash
   helm repo add argo https://argoproj.github.io/argo-helm
   helm install argocd argo/argo-cd \
     --namespace argocd --create-namespace \
     --set configs.params."server\.insecure"=true \
     --set dex.enabled=false \
     --set notifications.enabled=false
   ```

2. **Bootstrap the app-of-apps**:
   ```bash
   kubectl apply -f k8s/apps/root.yaml
   ```

3. **Verify applications**:
   ```bash
   kubectl get applications -n argocd
   ```

### GitOps Workflow

Once set up, the workflow is:

1. Edit manifests in `k8s/` directory
2. Commit and push to `main`
3. Argo CD automatically syncs within ~3 minutes
4. View status in Argo CD UI or via `kubectl get applications -n argocd`

### Secrets Handling

Secrets are **not stored in Git** (security best practice). They must be applied manually:

```bash
# Apply secrets separately
kubectl apply -f k8s/overlays/production/secrets.yaml
```

For advanced secrets management, consider:
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [External Secrets Operator](https://external-secrets.io/)
- [HashiCorp Vault](https://www.vaultproject.io/)

### Access Argo CD UI

```bash
# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:80

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

---

## Option B: Docker Compose Deployment

### Step 4: Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker version
```

### Step 5: Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit with your values
nano .env
```

Required variables (see `.env.example` for details):
- `TUNNEL_TOKEN` - Cloudflare Tunnel token
- `WEBUI_SECRET_KEY` - Random secret for session encryption

### Step 6: Start Services

```bash
# Start all containers
docker compose up -d

# Verify services are running
docker ps
```

### Step 7: Pull LLM Models (Docker)

```bash
# Pull core models
docker exec ollama ollama pull mistral:7b
docker exec ollama ollama pull llama3.1:8b
docker exec ollama ollama pull phi3:mini

# Pull optional specialized models
docker exec ollama ollama pull llava          # Vision/image understanding
docker exec ollama ollama pull llama3.2:3b    # Fast responses

# Verify models
docker exec ollama ollama list
```

### Step 8: Verify Services (Docker)

```bash
# Check Elasticsearch
curl http://localhost:9200

# Check Ollama
curl http://localhost:11434/api/tags

# Check OpenWebUI
curl -I http://localhost:3000
```

---

## Common Setup Steps

### OpenWebUI Initial Setup

1. Access OpenWebUI at your URL (port 8080 for k3s, port 3000 for Docker)
2. Create admin account on first access
3. Configure settings:
   - **Admin Settings** → **General** → Disable "Enable New Sign Ups"
   - Create additional users as needed (e.g., demo user)

### Step 10: Cloudflare Tunnel Setup

#### Create Tunnel in Cloudflare Dashboard

1. Go to [Cloudflare Zero Trust](https://one.dash.cloudflare.com/)
2. Navigate to **Networks** → **Tunnels** → **Create a tunnel**
3. Choose **Cloudflared** connector
4. Name your tunnel (e.g., `rag-node-01`)
5. Copy the tunnel token

#### Configure Public Hostname

1. In tunnel settings, go to **Public Hostname** tab
2. Add hostname:
   - **Subdomain**: `ai4u` (or your choice)
   - **Domain**: `your-domain.com`
   - **Service Type**: HTTP
   - **URL**: `openwebui:8080`

> **Important**: Use container name `openwebui:8080`, not `localhost:3000`

#### Add Token to Environment

```bash
# Edit .env file
nano .env

# Add your tunnel token
TUNNEL_TOKEN=eyJhIjo...your_token_here
```

#### Restart Cloudflared

```bash
docker compose up -d cloudflared
docker logs cloudflared
```

Look for: `INF Registered tunnel connection`

### Step 11: Verify Public Access

Access your instance at: `https://ai4u.your-domain.com`

## Service Details

### Elasticsearch

- **Port**: 9200 (localhost only)
- **Version**: 9.0.0
- **Memory**: 4GB heap (configurable)
- **Security**: Disabled (internal use only)
- **Role**: Vector store for RAG (document embeddings)

### Ollama

- **Port**: 11434 (localhost only)
- **Models**: See [Available Models](#available-models) section
- **Data**: Persisted in Docker volume

### OpenWebUI

- **Port**: 3000 (localhost only)
- **Backend**: Connects to Ollama via Docker network
- **Data**: Persisted in Docker volume
- **Customizations**: Legal footer via `static/loader.js`
- **RAG**: Elasticsearch vector store with hybrid search enabled

### Cloudflared

- **Function**: Secure tunnel to Cloudflare edge
- **Protocol**: QUIC
- **Authentication**: Token-based

## RAG (Retrieval-Augmented Generation)

### Overview

RAG allows users to chat with their own documents. The system retrieves relevant content from uploaded documents and uses it as context for LLM responses.

### Configuration

| Setting | Value |
|---------|-------|
| Vector Database | Elasticsearch 9.0.0 |
| Embedding Model | `sentence-transformers/all-MiniLM-L6-v2` |
| Hybrid Search | Enabled (BM25 + vector search) |

### Environment Variables

```yaml
VECTOR_DB: elasticsearch
ELASTICSEARCH_URL: http://elasticsearch:9200
ENABLE_RAG_HYBRID_SEARCH: "true"
```

### How to Use

1. **Upload Documents**:
   - Go to **Workspace** → **Knowledge**
   - Create a new knowledge base
   - Upload documents (PDF, TXT, DOCX, MD, CSV, etc.)

2. **Chat with Documents**:
   - Start a new chat
   - Type `#` to see available knowledge bases
   - Select a knowledge base to include as context
   - Ask questions about your documents

### Supported File Types

- PDF documents
- Plain text (.txt)
- Markdown (.md)
- Word documents (.docx)
- CSV files
- And more...

## Available Models

Models suitable for CPU-only inference (tested on AMD Ryzen 9 8945HS, 32GB RAM):

| Model | Size | Best For | Notes |
|-------|------|----------|-------|
| phi3:mini | 2.2 GB | Fast responses, resource-efficient | Good default for demos |
| gemma2:2b | 1.6 GB | Fast, efficient general chat | Google's efficient model |
| llama3.2:3b | 2.0 GB | Balanced speed/quality | Latest Llama release |
| mistral:7b | 4.1 GB | General chat, reasoning | Excellent quality |
| llama3.1:8b | 4.7 GB | General purpose, longer context | High quality |
| llava | 4.7 GB | Vision/image understanding | Multimodal (images) |
| nomic-embed-text | 274 MB | Embeddings for RAG | Required for vector search |

### Model Selection Guide

- **General Chat**: Use `mistral:7b` or `llama3.1:8b` for best quality
- **Image Analysis**: Use `llava` for describing images, reading diagrams, OCR
- **Fast Responses**: Use `phi3:mini`, `gemma2:2b`, or `llama3.2:3b` for quick interactions
- **RAG Embeddings**: `nomic-embed-text` is required for the semantic search workflow

### Hardware Considerations

For CPU-only inference (no NVIDIA GPU):
- 2B-3B models: Fast responses, good for demos
- 7B-8B models: Better quality, slower on CPU
- Larger models (13B+): Not recommended without GPU

## MCP Tools

### Overview

MCP (Model Context Protocol) allows LLMs to use external tools like web search, file operations, and GitHub access. This setup uses MCPO (MCP-to-OpenAPI proxy) to connect OpenWebUI with MCP servers.

### Architecture

```
OpenWebUI → MCPO (proxy) → MCP Servers (DuckDuckGo, Filesystem, GitHub)
```

### Available MCP Servers

| Server | Description | API Key Required |
|--------|-------------|------------------|
| **duckduckgo** | Web search and content fetching | No |
| **filesystem** | Read/write files in /data volume | No |
| **github** | Repository access, issues, PRs | Optional (for rate limits) |

### Environment Variables

```yaml
# Required for MCP tools to persist after restart
WEBUI_SECRET_KEY: ${WEBUI_SECRET_KEY}

# Optional: GitHub token for higher API rate limits
GITHUB_TOKEN: ${GITHUB_TOKEN:-}
```

Generate keys:
```bash
# WebUI secret key
openssl rand -hex 32

# GitHub token: https://github.com/settings/tokens
# Scope: public_repo (read-only public repo access)
```

### MCPO Configuration

The MCPO config file (`mcpo/config.json`):
```json
{
  "mcpServers": {
    "duckduckgo": {
      "command": "uvx",
      "args": ["duckduckgo-mcp-server"]
    },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/data"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

### Setup in OpenWebUI

1. Go to **Admin Settings** → **External Tools**
2. Click **+ Add Server** for each tool:

| Tool | Type | URL | Auth |
|------|------|-----|------|
| DuckDuckGo | OpenAPI | `http://mcpo:8000/duckduckgo` | None |
| Filesystem | OpenAPI | `http://mcpo:8000/filesystem` | None |
| GitHub | OpenAPI | `http://mcpo:8000/github` | None |

### Using Tools in Chat

1. Start a **New Chat**
2. Click the **tools** button near the input field
3. Enable desired tools
4. Example prompts:
   ```
   Search the web for latest AI news
   List files in the /data directory
   Get information about the tensorflow/tensorflow repository
   ```

### Available Tool Functions

**DuckDuckGo:**
| Function | Description |
|----------|-------------|
| `search` | Web search |
| `fetch_content` | Fetch and parse web page content |

**Filesystem:**
| Function | Description |
|----------|-------------|
| `read_file` | Read file contents |
| `write_file` | Write content to file |
| `list_directory` | List directory contents |
| `create_directory` | Create new directory |
| `move_file` | Move/rename files |
| `get_file_info` | Get file metadata |

**GitHub:**
| Function | Description |
|----------|-------------|
| `search_repositories` | Search GitHub repos |
| `get_file_contents` | Read file from repo |
| `list_issues` | List repository issues |
| `get_issue` | Get issue details |
| `create_issue` | Create new issue |
| `list_pull_requests` | List PRs |
| `get_pull_request` | Get PR details |

### Adding More MCP Servers

Edit `mcpo/config.json` and restart:
```bash
docker compose restart mcpo
```

## n8n Workflow Automation

### Overview

n8n provides visual workflow automation for demonstrating the RAG pipeline. It shows how documents flow through ingestion, chunking, embedding, and storage.

**Access**: https://n8n.strali.solutions

### RAG Ingestion Pipeline

The included workflow demonstrates the complete RAG process:

```
Document Upload → Extract Metadata → Chunk Text → Generate Embedding → Store in Elasticsearch
     (webhook)                        (500 chars)    (nomic-embed-text)    (vector index)
```

### Using the Workflow

**Via API (webhook):**
```bash
curl -X POST https://n8n.strali.solutions/webhook/ingest \
  -H "Content-Type: application/json" \
  -d '{
    "title": "My Document",
    "content": "Document text content here...",
    "source": "api"
  }'
```

**Via n8n UI:**
1. Log in to n8n
2. Open "RAG Document Ingestion Pipeline" workflow
3. View execution history to see document flow
4. Test with the "Test workflow" button

### Environment Variables

```yaml
N8N_WEBHOOK_URL: https://n8n.your-domain.com
N8N_HOST: n8n.your-domain.com
N8N_EDITOR_BASE_URL: https://n8n.your-domain.com
```

### Importing Workflows

Import the RAG workflow from the repository:

1. In n8n, click **Add workflow** (+)
2. Click **⋮** menu → **Import from URL**
3. URL: `https://raw.githubusercontent.com/achildrenmile/rag-reference-architecture/main/n8n/rag-ingestion-workflow.json`
4. Activate the workflow

## Demo Resources

### Demo Files

The `/data/demo` directory contains sample files for demonstrating MCP filesystem capabilities:

| File | Description |
|------|-------------|
| `welcome.md` | Welcome guide with feature overview |
| `sample_data.csv` | Employee data for analysis demos |
| `example.py` | Python code for code review demos |
| `config.json` | JSON config for file reading demos |

**Example prompts** (with filesystem tool enabled):
```
List all files in /data/demo and describe each one
Read /data/demo/sample_data.csv and calculate the average salary by department
Analyze the Python code in /data/demo/example.py and suggest improvements
```

### Knowledge Base Demo

The `demo/RAG_Architecture_Guide.md` file contains a technical guide about this RAG system. Upload it to a Knowledge base to demonstrate RAG capabilities:

1. Go to **Workspace** → **Knowledge**
2. Create new knowledge base: "RAG Architecture"
3. Upload `demo/RAG_Architecture_Guide.md`
4. In chat, type `#RAG` and select the knowledge base
5. Ask questions like: "What embedding model does this system use?"

### Prompt Templates

See `demo/prompt_templates.md` for ready-to-use prompts organized by category:

- **General Chat**: Facts, creative writing, summarization
- **Code Generation**: Python functions, debugging, code explanation
- **Vision/Image**: Image description, diagram analysis, OCR
- **Web Search**: Current events, research, fact checking
- **Filesystem**: File listing, data analysis, file creation
- **GitHub**: Repository info, code search, issue viewing
- **RAG**: Document Q&A, multi-document analysis

### Sample Company Documents

The `sample-docs/` directory contains fictional company documents for demonstrating RAG capabilities:

| Document | Description |
|----------|-------------|
| Employee Onboarding Guide | Day 1-14 onboarding process, equipment, benefits |
| IT Security Policy | Password requirements, 2FA, data classification |
| Expense Reimbursement Policy | Travel, meals, equipment, submission process |
| Product API Documentation | REST API endpoints, authentication, rate limits |
| Remote Work Guidelines | Core hours, communication, home office setup |
| Engineering Best Practices | Code review, testing, git workflow, deployment |
| Customer Support Procedures | Response times, escalation, ticket workflow |
| Company Benefits Overview | Health, retirement, PTO, wellness, perks |

**Ingest sample documents:**

```bash
# Run the ingestion script
./scripts/ingest-samples.sh

# Or specify a custom endpoint
./scripts/ingest-samples.sh https://n8n.strali.solutions
```

**Manual ingestion via API:**

```bash
curl -X POST https://n8n.strali.solutions/webhook/ingest \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Document Title",
    "source": "Department Name",
    "content": "Full document content here..."
  }'
```

**Sample queries to test:**

- "What are the password requirements?"
- "How much is the home office budget?"
- "What is the API rate limit?"
- "How do I submit expenses?"
- "What benefits do we offer?"

### Semantic Search UI

A standalone search interface for querying the vector database directly:

**Access**: https://ai4u.strali.solutions/search

Features:
- Direct vector similarity search against Elasticsearch
- Shows cosine similarity scores as percentages
- Visual pipeline display (Query → Embed → Search → Results)

**Requirements**: The "Semantic Search API" workflow must be active in n8n.

**API Endpoint**:
```bash
curl -X POST https://n8n.strali.solutions/webhook/search \
  -H "Content-Type: application/json" \
  -d '{"query": "your search query", "limit": 5}'
```

### Vision Model Demo (llava:7b)

The `/data/demo/images/` directory contains a guide for demonstrating the vision model:

1. In OpenWebUI, select **llava:7b** model
2. Upload any image using the attachment button
3. Try prompts like:
   - "Describe this image in detail"
   - "Extract all text visible in this image"
   - "Explain the architecture shown in this diagram"

### Scheduled RSS Ingestion

Automatically ingest content from RSS feeds into the RAG pipeline:

1. Import workflow: `n8n/scheduled-ingestion-workflow.json`
2. Default: Fetches top Hacker News stories every 6 hours
3. Customize the RSS URL in the "Fetch RSS Feed" node
4. Activate to start automatic ingestion

## Legal Compliance

### EU AI Act (Article 50)

This setup includes transparency features required by the EU AI Act. All AI-powered tools display legal footers with links to Imprint and Privacy Policy.

### Legal Footer Implementation

| Tool | URL | Implementation | File |
|------|-----|----------------|------|
| **OpenWebUI** | ai4u.strali.solutions | JavaScript injection + banners | `static/loader.js` |
| **Semantic Search** | ai4u.strali.solutions/search | HTML footer | `static/search.html` |
| **n8n** | n8n.strali.solutions | nginx proxy injection | `n8n-custom/nginx.conf` |

### How Each Implementation Works

**1. OpenWebUI (loader.js)**

A custom JavaScript file is mounted into OpenWebUI that injects a legal footer on every page, including the login screen:

```javascript
// static/loader.js - Auto-injects footer with legal links
footer.innerHTML = 'By using this service, you agree to our <a href="...">Imprint</a> and <a href="...">Privacy Policy</a>.';
```

Additionally, the `WEBUI_BANNERS` environment variable displays a dismissible info banner after login.

**2. Semantic Search (HTML)**

The search interface includes a fixed-position footer directly in the HTML:

```html
<footer style="position: fixed; bottom: 0; ...">
    This service uses AI for semantic search. By using this service, you agree to our
    <a href="https://strali.solutions/impressum">Imprint</a> and
    <a href="https://strali.solutions/datenschutz">Privacy Policy</a>.
</footer>
```

**3. n8n (nginx proxy)**

Since n8n doesn't support custom HTML injection, an nginx reverse proxy (`n8n-proxy`) intercepts responses and injects the footer using `sub_filter`:

```nginx
# n8n-custom/nginx.conf
sub_filter '</body>' '<div id="n8n-legal-footer">...legal links...</div></body>';
sub_filter_once on;
sub_filter_types text/html;
proxy_set_header Accept-Encoding "";  # Disable gzip for sub_filter to work
```

The Cloudflare Tunnel points to `n8n-proxy:5679` instead of `n8n:5678` directly.

### Required Disclosures

Your Imprint and Privacy Policy should include:

- **AI Interaction Notice**: Users are interacting with AI systems, not humans
- **AI Platforms List**: All AI-powered services (chat, search, workflow automation)
- **AI Models Used**: e.g., Mistral 7B, Llama 3 8B, Phi-3, nomic-embed-text
- **Data Processing**: Local processing on own infrastructure, no third-party AI providers
- **Deployer Responsibility**: Contact information for the responsible operator
- **EU AI Act Compliance Statement**: Commitment to Article 50 transparency obligations

### Customizing Legal Links

**OpenWebUI (loader.js):**
```javascript
// Edit static/loader.js
footer.innerHTML = 'By using this service, you agree to our <a href="https://your-domain.com/imprint" ...>Imprint</a> and <a href="https://your-domain.com/privacy" ...>Privacy Policy</a>.';
```

**OpenWebUI Banner (docker-compose.yml):**
```yaml
WEBUI_BANNERS: '[{"id": "legal-notice", "type": "info", "content": "Your message with [links](https://example.com).", "dismissible": true, "timestamp": 1}]'
```

**Semantic Search (search.html):**
```html
<!-- Edit static/search.html footer section -->
<a href="https://your-domain.com/imprint">Imprint</a>
<a href="https://your-domain.com/privacy">Privacy Policy</a>
```

**n8n (nginx.conf):**
```nginx
# Edit n8n-custom/nginx.conf sub_filter line
sub_filter '</body>' '<div id="n8n-legal-footer">...your links...</div></body>';
```

After editing, restart the affected services:
```bash
docker compose restart openwebui n8n-proxy
```

## Security Configuration

### Network Security

- All services bound to `127.0.0.1` (localhost only)
- No public inbound ports required
- Cloudflare Tunnel provides secure ingress

### Application Security

- OpenWebUI: User authentication required
- Public signup: Disabled by default
- Admin creates user accounts manually

### Access Control Options

| Method | Description |
|--------|-------------|
| **OpenWebUI Auth Only** | Users need credentials to login |
| **Cloudflare Access** | Additional authentication layer (requires payment method on file) |
| **Shared Demo Account** | Single demo user for controlled sharing |

### Demo Access Setup

For controlled demo access without Cloudflare Access:
1. Disable public signup in OpenWebUI
2. Create a demo user account manually
3. Share credentials only on request
4. All users share the same chat history

## Maintenance

### View Logs

**k3s:**
```bash
# All pods
kubectl logs -n rag-demo -l app --all-containers

# Specific service
kubectl logs -n rag-demo deployment/openwebui -f
kubectl logs -n rag-demo deployment/n8n -f
kubectl logs -n rag-demo deployment/ollama -f
```

**Docker Compose:**
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f openwebui
```

### Update Services

**k3s:**
```bash
# Re-apply manifests (pulls latest images if tags changed)
kubectl apply -k k8s/overlays/production

# Force restart a deployment
kubectl rollout restart deployment/openwebui -n rag-demo
```

**Docker Compose:**
```bash
docker compose pull
docker compose up -d
```

### Check Status

**k3s:**
```bash
# Pod status
kubectl get pods -n rag-demo

# Service endpoints
kubectl get svc -n rag-demo

# PVC status
kubectl get pvc -n rag-demo

# Resource usage
kubectl top pods -n rag-demo
```

### Backup Data

#### k3s Backup

Backup PersistentVolumeClaims:
```bash
# List PVCs
kubectl get pvc -n rag-demo

# Backup a specific PVC (example: openwebui-data)
kubectl exec -n rag-demo deployment/openwebui -- tar -czvf - /app/backend/data > openwebui-backup.tar.gz

# Backup Elasticsearch data
kubectl exec -n rag-demo deployment/elasticsearch -- tar -czvf - /usr/share/elasticsearch/data > elasticsearch-backup.tar.gz
```

#### Docker Compose Backup (Online)

Backup without stopping services using Docker containers to access volumes:

```bash
cd ~/rag-reference-architecture
BACKUP_NAME="rag-backup-$(date +%Y%m%d-%H%M%S)"

# Backup configuration files
tar -czvf /tmp/${BACKUP_NAME}-config.tar.gz \
  docker-compose.yml .env mcpo/ static/ .gitignore README.md SECURITY.md

# Backup OpenWebUI data (database, uploads, embeddings)
docker run --rm \
  -v rag-reference-architecture_openwebui-data:/data \
  -v /tmp:/backup \
  alpine tar -czvf /backup/${BACKUP_NAME}-openwebui.tar.gz -C /data .

# Backup Ollama models (~11GB for default models)
docker run --rm \
  -v rag-reference-architecture_ollama-data:/data \
  -v /tmp:/backup \
  alpine tar -czvf /backup/${BACKUP_NAME}-ollama.tar.gz -C /data .

# Backup Elasticsearch data
docker run --rm \
  -v rag-reference-architecture_esdata:/data \
  -v /tmp:/backup \
  alpine tar -czvf /backup/${BACKUP_NAME}-esdata.tar.gz -C /data .

# List backup files
ls -lh /tmp/${BACKUP_NAME}*.tar.gz
```

#### Backup to Remote Storage

Transfer backups to a NAS or remote server:

```bash
# Example: Transfer to NAS via SSH
BACKUP_NAME="rag-backup-20260114-133206"  # Use your backup timestamp
REMOTE_HOST="user@nas.example.com"
REMOTE_PATH="/volume1/backups/rag-node-01"

# Create remote directory
ssh $REMOTE_HOST "mkdir -p $REMOTE_PATH"

# Transfer files (using input redirection for compatibility)
for file in /tmp/${BACKUP_NAME}*.tar.gz; do
  ssh $REMOTE_HOST "cat > $REMOTE_PATH/$(basename $file)" < $file
done

# Verify transfer
ssh $REMOTE_HOST "ls -lh $REMOTE_PATH"
```

#### Expected Backup Sizes

| Component | Typical Size | Contents |
|-----------|--------------|----------|
| config | ~10 KB | docker-compose.yml, .env, mcpo/, static/ |
| openwebui | ~1 GB | Database, uploads, embedding models cache |
| ollama | ~11 GB | LLM models (mistral:7b, llama3:8b, phi3:mini) |
| esdata | ~5 MB | Elasticsearch indices (grows with RAG usage) |

#### Restore from Backup

```bash
cd ~/rag-reference-architecture
BACKUP_NAME="rag-backup-20260114-133206"  # Use your backup timestamp
BACKUP_PATH="/path/to/backups"  # Local path or mount point

# Stop services
docker compose down

# Restore configuration files
tar -xzvf ${BACKUP_PATH}/${BACKUP_NAME}-config.tar.gz -C ~/rag-reference-architecture/

# Restore OpenWebUI data
docker run --rm \
  -v rag-reference-architecture_openwebui-data:/data \
  -v ${BACKUP_PATH}:/backup \
  alpine sh -c "rm -rf /data/* && tar -xzvf /backup/${BACKUP_NAME}-openwebui.tar.gz -C /data"

# Restore Ollama models
docker run --rm \
  -v rag-reference-architecture_ollama-data:/data \
  -v ${BACKUP_PATH}:/backup \
  alpine sh -c "rm -rf /data/* && tar -xzvf /backup/${BACKUP_NAME}-ollama.tar.gz -C /data"

# Restore Elasticsearch data
docker run --rm \
  -v rag-reference-architecture_esdata:/data \
  -v ${BACKUP_PATH}:/backup \
  alpine sh -c "rm -rf /data/* && tar -xzvf /backup/${BACKUP_NAME}-esdata.tar.gz -C /data"

# Start services
docker compose up -d

# Verify services
docker ps
```

#### Automated Weekly Backup

An automated backup script runs weekly via systemd timer:

| Setting | Value |
|---------|-------|
| Schedule | Every Sunday at 3:00 AM |
| Retention | 2 weeks (last 2 backups kept) |
| Destination | Synology NAS via SSH |
| Skipped | Ollama models (rarely change, ~11GB) |

**Components:**
- `backup.sh` - Backup script in repo root
- `~/.config/systemd/user/rag-backup.service` - Systemd service
- `~/.config/systemd/user/rag-backup.timer` - Weekly timer
- `~/rag-reference-architecture/backup.log` - Backup log file

**Manual Commands:**

```bash
# Check timer status
systemctl --user status rag-backup.timer

# View next scheduled run
systemctl --user list-timers rag-backup.timer

# Run backup manually
~/rag-reference-architecture/backup.sh

# View backup log
tail -50 ~/rag-reference-architecture/backup.log
```

**Setup Requirements:**
- SSH key authentication from rag-node-01 to NAS
- NAS must be reachable via local network (192.168.x.x)
- User lingering enabled: `loginctl enable-linger $USER`

### Restart Services

```bash
docker compose restart
```

## Monitoring

### Overview

The platform is monitored via Uptime Kuma (external) with both HTTP endpoint checks and push-based monitors.

### Monitored Services

| Service | URL | Type | Description |
|---------|-----|------|-------------|
| OpenWebUI | `https://ai4u.strali.solutions` | HTTP | Main AI chat interface |
| Semantic Search | `https://ai4u.strali.solutions/search` | HTTP | Vector search UI |
| n8n | `https://n8n.strali.solutions` | HTTP | Workflow automation |
| Elasticsearch | `http://192.168.1.32:9200` | HTTP | Vector database (LAN) |
| Ollama | `http://192.168.1.32:11434/api/tags` | HTTP | LLM runtime (LAN) |
| Disk Space | Push monitor | Push | Alerts if <10GB free |

### LAN Access for Monitoring

Elasticsearch and Ollama ports are bound to `0.0.0.0` to allow monitoring from the local network:

```yaml
elasticsearch:
  ports:
    - "0.0.0.0:9200:9200"  # LAN accessible

ollama:
  ports:
    - "0.0.0.0:11434:11434"  # LAN accessible
```

### Disk Space Monitor

A push-based monitor sends disk space status to Uptime Kuma every 5 minutes.

**Script:** `scripts/disk-monitor.sh`

**How it works:**
- Checks free disk space on root partition
- Pushes "up" status if ≥10GB free
- Pushes "down" status if <10GB free (triggers alert)
- Includes disk usage in status message

**Systemd Timer:**
```bash
# Check timer status
systemctl --user status disk-monitor.timer

# View next run
systemctl --user list-timers disk-monitor.timer

# Run manually
~/rag-reference-architecture/scripts/disk-monitor.sh
```

**Setup (if not already configured):**
```bash
# Create systemd user directory
mkdir -p ~/.config/systemd/user

# Create service file
cat > ~/.config/systemd/user/disk-monitor.service << EOF
[Unit]
Description=Disk Space Monitor for Uptime Kuma

[Service]
Type=oneshot
ExecStart=%h/rag-reference-architecture/scripts/disk-monitor.sh
EOF

# Create timer file
cat > ~/.config/systemd/user/disk-monitor.timer << EOF
[Unit]
Description=Run disk monitor every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

# Enable and start
systemctl --user daemon-reload
systemctl --user enable --now disk-monitor.timer
```

## Troubleshooting

### Elasticsearch won't start

```bash
# Check vm.max_map_count
cat /proc/sys/vm/max_map_count
# Should be 262144

# Fix if needed
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/99-elasticsearch.conf
```

### Cloudflared not connecting

**k3s:**
```bash
# Check logs
kubectl logs -n rag-demo deployment/cloudflared

# Verify secret exists
kubectl get secret -n rag-demo cloudflared-secrets
```

**Docker Compose:**
```bash
# Check logs
docker logs cloudflared

# Verify token is set
docker exec cloudflared printenv TUNNEL_TOKEN
```

### OpenWebUI can't reach Ollama

**k3s:**
```bash
# Check Ollama service
kubectl get svc -n rag-demo ollama

# Test connectivity from OpenWebUI pod
kubectl exec -n rag-demo deployment/openwebui -- curl http://ollama:11434/api/tags
```

**Docker Compose:**
```bash
# Verify Ollama is running
docker exec openwebui curl http://ollama:11434/api/tags
```

### Pods stuck in Pending (k3s)

```bash
# Check PVC status
kubectl get pvc -n rag-demo

# Describe pod for events
kubectl describe pod -n rag-demo <pod-name>

# Check local-path-provisioner logs
kubectl logs -n kube-system -l app=local-path-provisioner
```

### Legal footer not showing

**k3s:**
```bash
# Verify ConfigMap exists
kubectl get configmap -n rag-demo openwebui-static-files

# Recreate static files ConfigMap
kubectl create configmap openwebui-static-files \
    --from-file=search.html=static/search.html \
    --from-file=showcase.html=static/showcase.html \
    --from-file=loader.js=static/loader.js \
    -n rag-demo --dry-run=client -o yaml | kubectl apply -f -

# Restart OpenWebUI to pick up changes
kubectl rollout restart deployment/openwebui -n rag-demo
```

**Docker Compose:**
```bash
# Verify loader.js is mounted
docker exec openwebui cat /app/backend/open_webui/static/loader.js

# Clear browser cache or use incognito mode
```

### n8n webhooks not working (k3s)

```bash
# Check n8n logs
kubectl logs -n rag-demo deployment/n8n

# Verify workflow is active
# In n8n UI, check that workflows are toggled "Active"

# Re-import workflows if needed
# 1. Delete existing workflow in n8n UI
# 2. Import from n8n/*.json files
# 3. Activate the workflow
```

## Credentials Management

Sensitive information is stored separately:

- **`.env`**: Contains `TUNNEL_TOKEN` - not committed to git
- **`CREDENTIALS.md`**: Contains all credentials, IPs, URLs - not committed to git

Use `.env.example` as a template for required environment variables.

## Future Enhancements

- [x] ~~Document ingestion pipeline~~ (via OpenWebUI Knowledge)
- [x] ~~Embedding generation~~ (sentence-transformers)
- [x] ~~RAG query integration~~ (Elasticsearch vector store)
- [x] ~~MCP services for tool access~~ (MCPO + DuckDuckGo, Filesystem, GitHub)
- [x] ~~Vision model~~ (llava:7b for image understanding)
- [x] ~~Code generation model~~ (codellama:7b)
- [x] ~~Demo resources~~ (prompt templates, sample files)
- [ ] GPU acceleration (AMD 780M iGPU - experimental ROCm support)
- [ ] Custom embedding models

## License

MIT License - See LICENSE file for details.
