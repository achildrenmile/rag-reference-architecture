# RAG Reference Architecture

A complete, reproducible setup for a modern AI-assisted search and Retrieval-Augmented Generation (RAG) system using local LLMs, Elasticsearch, and secure public exposure via Cloudflare Tunnel. Includes EU AI Act compliance features.

## Architecture Overview

```
Internet
    ↓
Cloudflare Tunnel (cloudflared)
    ↓
OpenWebUI (Chat Interface + RAG)
    ↓                ↓
Ollama          Elasticsearch
(LLM Runtime)   (Vector Store)
```

### Key Properties

- No public inbound ports required
- HTTPS only via Cloudflare
- Authentication at application level
- CPU-first inference (GPU optional)
- Docker-based deployment
- Fully self-hosted
- EU AI Act compliant (Article 50 transparency)

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
├── docker-compose.yml     # Container orchestration
├── backup.sh              # Automated backup script
├── .env.example           # Environment variables template
├── .env                   # Actual environment variables (not in repo)
├── .gitignore             # Excluded files
├── static/
│   └── loader.js          # Custom JS for legal footer injection
├── mcpo/
│   └── config.json        # MCPO MCP server configuration
├── CREDENTIALS.md         # Sensitive credentials (not in repo)
├── SECURITY-ASSESSMENT.md # Security assessment details (not in repo)
├── ingest/                # Document ingestion scripts (future)
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
sudo apt install -y ca-certificates curl gnupg git htop jq unzip build-essential net-tools

# Disable swap (recommended for Elasticsearch)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Set Elasticsearch kernel parameter
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/99-elasticsearch.conf

# Reboot
sudo reboot
```

### Step 3: Docker Installation

```bash
# Install Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker version
```

### Step 4: Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/rag-reference-architecture.git
cd rag-reference-architecture
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

### Step 6: Start Services

```bash
# Start all containers
docker compose up -d

# Verify services are running
docker ps
```

### Step 7: Pull LLM Models

```bash
# Pull recommended models
docker exec ollama ollama pull mistral:7b
docker exec ollama ollama pull llama3:8b
docker exec ollama ollama pull phi3:mini

# Verify models
docker exec ollama ollama list
```

### Step 8: Verify Services

```bash
# Check Elasticsearch
curl http://localhost:9200

# Check Ollama
curl http://localhost:11434/api/tags

# Check OpenWebUI
curl -I http://localhost:3000
```

### Step 9: OpenWebUI Initial Setup

1. Access OpenWebUI at `http://localhost:3000` (or via your tunnel URL)
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
   - **Subdomain**: `gpt4strali` (or your choice)
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

Access your instance at: `https://gpt4strali.your-domain.com`

## Service Details

### Elasticsearch

- **Port**: 9200 (localhost only)
- **Version**: 9.0.0
- **Memory**: 4GB heap (configurable)
- **Security**: Disabled (internal use only)
- **Role**: Vector store for RAG (document embeddings)

### Ollama

- **Port**: 11434 (localhost only)
- **Models**: mistral:7b, llama3:8b, phi3:mini
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

## Legal Compliance

### EU AI Act (Article 50)

This setup includes transparency features required by the EU AI Act:

1. **Legal Footer on All Pages**: Via `static/loader.js`, a footer with links to Imprint and Privacy Policy is displayed on all pages including the login screen.

2. **Banner for Logged-in Users**: The `WEBUI_BANNERS` environment variable displays a dismissible info banner after login.

3. **Required Disclosures**: Your Imprint and Privacy Policy should include:
   - AI interaction notice (users are interacting with AI, not humans)
   - AI models used (e.g., Mistral, Llama, Phi-3)
   - Data processing information (local processing, no third-party AI)
   - Deployer responsibility information
   - EU AI Act compliance statement

### Customizing Legal Links

Edit `static/loader.js` to change the Imprint and Privacy Policy URLs:

```javascript
footer.innerHTML = 'By using this service, you agree to our <a href="https://your-domain.com/imprint" ...>Imprint</a> and <a href="https://your-domain.com/privacy" ...>Privacy Policy</a>.';
```

Edit `docker-compose.yml` to update the banner content:

```yaml
WEBUI_BANNERS: '[{"id": "legal-notice", "type": "info", "title": "", "content": "Your message with [links](https://example.com).", "dismissible": true, "timestamp": 1}]'
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

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f openwebui
```

### Update Services

```bash
docker compose pull
docker compose up -d
```

### Backup Data

#### Quick Backup (Online)

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

## Troubleshooting

### Elasticsearch won't start

```bash
# Check vm.max_map_count
cat /proc/sys/vm/max_map_count
# Should be 262144

# Fix if needed
sudo sysctl -w vm.max_map_count=262144
```

### Cloudflared not connecting

```bash
# Check logs
docker logs cloudflared

# Verify token is set
docker exec cloudflared printenv TUNNEL_TOKEN
```

### OpenWebUI can't reach Ollama

```bash
# Verify Ollama is running
docker exec openwebui curl http://ollama:11434/api/tags
```

### Legal footer not showing

```bash
# Verify loader.js is mounted
docker exec openwebui cat /app/backend/open_webui/static/loader.js

# Clear browser cache or use incognito mode
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
- [x] ~~MCP services for tool access~~ (MCPO + DuckDuckGo)
- [ ] GPU acceleration (AMD 780M iGPU - experimental ROCm support)
- [ ] Custom embedding models

## License

MIT License - See LICENSE file for details.
