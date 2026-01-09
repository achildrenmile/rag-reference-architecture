# GPT4Strali – Reference Architecture Setup Guide

This repository documents a complete, reproducible setup for a modern AI-assisted search and Retrieval-Augmented Generation (RAG) reference architecture using local LLMs, Elasticsearch, MCP-style tool access, and secure public exposure via Cloudflare Tunnel.

The goal is to share practical, architecture-correct knowledge that can be reused with affordable hardware.

---

ARCHITECTURE OVERVIEW

Internet
↓
Cloudflare Access (Login)
↓
Cloudflare Tunnel (cloudflared)
↓
OpenWebUI
↓
Ollama (Local LLM Runtime)
↓
MCP Services (Tool Access)
↓
Elasticsearch (Hybrid Search)

Key properties:
- No public inbound ports
- HTTPS only
- Login required
- CPU-first inference
- GPU optional (cloud or eGPU)
- Docker-based deployment

---

TARGET ENVIRONMENT

Hardware:
- Mini PC with AMD Ryzen 7 / Ryzen 9 CPU
- Minimum 32 GB RAM
- NVMe SSD

Validated on:
- GEEKOM A8 Max (Ryzen 9 8945HS)

Operating System:
- Ubuntu Server 22.04 LTS (headless)

---

REPOSITORY STRUCTURE

README.md
docker-compose.yml
ingest/
mcp/
models/

---

STEP 1 – BIOS AND OS INSTALLATION

1. Enter BIOS
   - Enable UEFI
   - Disable Secure Boot
2. Boot from Ubuntu Server 22.04 LTS USB
3. Install with:
   - Minimal installation
   - OpenSSH enabled
   - Full disk (LVM)
   - No disk encryption
4. Reboot and log in via SSH

---

STEP 2 – BASE SYSTEM PREPARATION

Run as root or sudo user:

sudo apt update && sudo apt full-upgrade -y
sudo apt install -y ca-certificates curl gnupg git htop jq unzip build-essential net-tools

Disable swap (recommended for Elasticsearch):

sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

Set required kernel parameter:

sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/99-elasticsearch.conf

Reboot once after this step.

---

STEP 3 – DOCKER INSTALLATION

Install Docker:

curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker \$USER
newgrp docker

Verify:

docker version

---

STEP 4 – DOCKER COMPOSE STACK

Create docker-compose.yml with the following content:

version: "3.8"

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.12.0
    environment:
      discovery.type: single-node
      xpack.security.enabled: "false"
      ES_JAVA_OPTS: "-Xms8g -Xmx8g"
    volumes:
      - esdata:/usr/share/elasticsearch/data
    ports:
      - "127.0.0.1:9200:9200"
    mem_limit: 12g

  openwebui:
    image: ghcr.io/open-webui/open-webui:main
    environment:
      OLLAMA_BASE_URL: http://host.docker.internal:11434
    ports:
      - "127.0.0.1:3000:8080"
    depends_on:
      - elasticsearch

volumes:
  esdata:

Start the stack:

docker compose up -d

Verify Elasticsearch:

curl http://localhost:9200

---

STEP 5 – OLLAMA (LOCAL LLM RUNTIME)

Install Ollama:

curl -fsSL https://ollama.com/install.sh | sh
sudo systemctl enable ollama
sudo systemctl start ollama

Pull models:

ollama pull mistral:7b-instruct-q4
ollama pull llama3:8b-instruct-q4

Test:

ollama run mistral

---

STEP 6 – OPENWEBUI SETUP

1. Open http://localhost:3000
2. Create admin account
3. Disable public signup
4. Create demo users if required

---

STEP 7 – INGESTION AND EMBEDDINGS

Install dependencies:

pip install sentence-transformers elasticsearch

Example ingestion logic:
- Load documents
- Generate embeddings
- Store text + vector in Elasticsearch

---

STEP 8 – MCP SERVICES (OPTIONAL BUT RECOMMENDED)

Create a small service exposing controlled search or tools using FastAPI.
This service is called by the LLM to access external capabilities without direct system access.

---

STEP 9 – CLOUDFLARE TUNNEL (PUBLIC ACCESS)

Install cloudflared:

sudo apt install -y cloudflared

Authenticate:

cloudflared tunnel login

Create tunnel:

cloudflared tunnel create gpt4strali

Configure /etc/cloudflared/config.yml:

tunnel: <TUNNEL_ID>
credentials-file: /etc/cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: gpt4strali.strali.solutions
    service: http://localhost:3000
  - service: http_status:404

Create DNS route:

cloudflared tunnel route dns gpt4strali gpt4strali.strali.solutions

Enable service:

sudo cloudflared service install
sudo systemctl enable cloudflared
sudo systemctl start cloudflared

---

STEP 10 – CLOUDFLARE ACCESS (LOGIN PROTECTION)

1. Enable Cloudflare Zero Trust
2. Create Access Application
   - Type: Self-hosted
   - Domain: gpt4strali.strali.solutions
3. Configure access policy:
   - Email allowlist or domain restriction
   - Optional OTP or SSO
4. Set session lifetime to 8–24 hours

---

SECURITY CHECKLIST

- No public inbound ports
- All services bound to localhost
- Cloudflare Access enforced
- OpenWebUI authentication enabled
- System survives reboot

---

RECOMMENDED OPERATING MODE

- CPU-first inference
- Quantized 7B–8B models
- GPU optional via cloud or eGPU
- Architecture remains identical across deployments

---

STATUS

This setup is:
- Secure
- Reproducible
- Demo-ready
- Production-grade in architecture
