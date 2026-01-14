# RAG Reference Architecture - Technical Guide

## Overview

This document describes the RAG (Retrieval-Augmented Generation) Reference Architecture, a self-hosted AI system that combines local LLMs with document retrieval capabilities.

## System Components

### 1. Ollama (LLM Runtime)
- Runs large language models locally
- Supports multiple model formats (GGUF, etc.)
- CPU-first inference with optional GPU acceleration
- Models: Mistral 7B, Llama3 8B, Phi3 Mini, CodeLlama 7B, LLaVA 7B

### 2. Elasticsearch (Vector Store)
- Version: 9.0.0
- Stores document embeddings for semantic search
- Hybrid search: combines BM25 (keyword) + vector similarity
- Single-node deployment for simplicity

### 3. OpenWebUI (Chat Interface)
- Modern web-based chat interface
- Supports RAG with knowledge bases
- MCP tool integration (web search, filesystem, GitHub)
- Multi-user support with authentication

### 4. Cloudflare Tunnel
- Secure public access without open ports
- HTTPS termination at Cloudflare edge
- Zero-trust network architecture

### 5. MCPO (MCP Proxy)
- Bridges OpenWebUI with MCP servers
- Provides web search via DuckDuckGo
- Filesystem access to /data volume
- GitHub repository access

## RAG Pipeline

### Document Ingestion
1. User uploads document to Knowledge base
2. Document is chunked into smaller segments
3. Each chunk is embedded using sentence-transformers
4. Embeddings stored in Elasticsearch index

### Query Processing
1. User asks a question
2. Question is embedded using same model
3. Elasticsearch finds similar document chunks
4. Retrieved chunks added to LLM context
5. LLM generates answer using retrieved context

### Embedding Model
- Model: `sentence-transformers/all-MiniLM-L6-v2`
- Dimensions: 384
- Optimized for semantic similarity

## Available Models

| Model | Size | Best For |
|-------|------|----------|
| mistral:7b | 4.4 GB | General chat, reasoning |
| llama3:8b | 4.7 GB | General purpose, longer context |
| phi3:mini | 2.2 GB | Fast responses, resource-efficient |
| codellama:7b | 4.0 GB | Code generation and analysis |
| llava:7b | 4.7 GB | Image understanding, vision tasks |
| qwen2:1.5b | 1.0 GB | Quick responses, low latency |

## MCP Tools

### DuckDuckGo Search
- Web search for current information
- Content fetching from URLs
- No API key required

### Filesystem
- Read/write files in /data directory
- Directory listing and file info
- Useful for data processing tasks

### GitHub
- Search public repositories
- Read file contents from repos
- List and view issues/PRs
- Optional token for higher rate limits

## Security Features

- All services bound to localhost only
- Cloudflare provides HTTPS and DDoS protection
- Rate limiting via Cloudflare rules
- Security headers (X-Frame-Options, CSP, etc.)
- Authentication required for access

## Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | AMD Ryzen 7 | AMD Ryzen 9 |
| RAM | 32 GB | 64 GB |
| Storage | 256 GB NVMe | 512 GB+ NVMe |

## EU AI Act Compliance

This system includes transparency features:
- Legal footer on all pages
- Info banner for logged-in users
- Links to Imprint and Privacy Policy
- Disclosure that users interact with AI

## Backup Strategy

- Weekly automated backups to NAS
- Retention: 2 weeks (last 2 backups)
- Includes: config, OpenWebUI data, Elasticsearch
- Excludes: Ollama models (can be re-downloaded)

## Common Operations

### Pull New Model
```bash
docker exec ollama ollama pull model:tag
```

### Check Service Status
```bash
docker compose ps
docker compose logs -f service_name
```

### Restart Services
```bash
docker compose restart
```

### Manual Backup
```bash
~/rag-reference-architecture/backup.sh
```
