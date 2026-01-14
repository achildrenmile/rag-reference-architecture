# Security Guide

This document outlines security best practices and hardening steps for the RAG Reference Architecture deployment.

## Architecture Security

```
Internet
    ↓
Cloudflare (DDoS, WAF, Rate Limiting)
    ↓
Cloudflare Tunnel (encrypted, no public ports)
    ↓
OpenWebUI (authentication required)
    ↓
Internal Services (localhost only)
```

### Key Security Properties

- No public inbound ports (except SSH for management)
- All services bound to localhost (127.0.0.1)
- Cloudflare Tunnel provides secure ingress
- Authentication required for all API endpoints
- HTTPS enforced via Cloudflare

## Security Checklist

### 1. SSL/TLS Configuration

**What to verify:**
- TLS 1.3 or TLS 1.2 minimum
- Strong cipher suites (AES-256-GCM preferred)
- Valid certificate with proper chain

**How to test:**
```bash
# Check TLS version and cipher
curl -vvI https://your-domain.com 2>&1 | grep -E "SSL|TLS|subject:|expire"

# Or use openssl
openssl s_client -connect your-domain.com:443 -tls1_3
```

**Expected result:**
- TLSv1.3 with TLS_AES_256_GCM_SHA384 or similar

---

### 2. HTTP Security Headers

**Required headers:**

| Header | Recommended Value | Purpose |
|--------|-------------------|---------|
| X-Frame-Options | DENY or SAMEORIGIN | Prevents clickjacking |
| X-Content-Type-Options | nosniff | Prevents MIME sniffing |
| X-XSS-Protection | 1; mode=block | XSS filter (legacy browsers) |
| Referrer-Policy | strict-origin-when-cross-origin | Controls referrer info |
| Permissions-Policy | geolocation=(), camera=() | Restricts browser features |

**How to test:**
```bash
curl -s -I https://your-domain.com | grep -iE "x-frame|x-content|x-xss|referrer|permissions"
```

**How to fix (Cloudflare):**
1. Dashboard → Rules → Transform Rules → Modify Response Header
2. Create rule matching your hostname
3. Add headers as "Set static" operations

---

### 3. Rate Limiting

**Purpose:** Prevent brute-force attacks on login endpoint

**Recommended configuration:**
- Endpoint: `/api/v1/auths/signin`
- Limit: 5 requests per 10 seconds per IP
- Action: Block for 1-5 minutes

**How to test:**
```bash
# Send multiple rapid requests
for i in {1..10}; do
  curl -s -o /dev/null -w "Request $i: HTTP %{http_code}\n" \
    -X POST "https://your-domain.com/api/v1/auths/signin" \
    -H "Content-Type: application/json" \
    -d '{"email":"test@test.com","password":"wrong"}'
  sleep 0.1
done
```

**Expected result:**
- First few requests: HTTP 400 (invalid credentials)
- Subsequent requests: HTTP 429 (rate limited)

**How to fix (Cloudflare):**
1. Dashboard → Security → Security rules → Rate limiting rules
2. Create rule for login endpoint
3. Set threshold and block duration

---

### 4. Authentication Security

**What to verify:**
- Public signup is disabled
- Generic error messages (don't reveal if email exists)
- Session tokens are secure

**How to test:**
```bash
# Test signup is disabled
curl -s -X POST "https://your-domain.com/api/v1/auths/signup" \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","email":"test@test.com","password":"Test123"}'
# Expected: Permission denied

# Test error messages don't leak info
curl -s -X POST "https://your-domain.com/api/v1/auths/signin" \
  -H "Content-Type: application/json" \
  -d '{"email":"nonexistent@test.com","password":"wrong"}'
# Expected: Generic "incorrect email or password" message
```

**OpenWebUI settings to verify:**
- Admin Settings → General → "Enable New Sign Ups" = OFF

---

### 5. API Endpoint Protection

**What to verify:**
- All sensitive endpoints require authentication
- No information leakage from public endpoints

**Endpoints that MUST require authentication:**
```
/api/v1/users/
/api/v1/chats/
/api/v1/models
/api/v1/memories/
/api/v1/documents/
/ollama/api/tags
```

**How to test:**
```bash
# Test without authentication
curl -s "https://your-domain.com/api/v1/chats/"
# Expected: {"detail":"Not authenticated"}
```

**Public endpoints (acceptable):**
```
/api/config     - Returns version and feature flags
/api/version    - Returns version only
/health         - Returns health status
```

---

### 6. Network Security

**What to verify:**
- Services bound to localhost only
- No unnecessary ports exposed
- SSH properly secured

**How to test (on server):**
```bash
# Check listening ports
ss -tlnp

# Expected: Only these should be public
# 0.0.0.0:22 (SSH)

# These should be localhost only (127.0.0.1):
# - Port 3000 (OpenWebUI)
# - Port 9200 (Elasticsearch)
# - Port 11434 (Ollama)
```

---

### 7. Information Disclosure

**What to verify:**
- Server version not exposed in headers
- No sensitive files accessible
- Robots.txt blocks indexing

**How to test:**
```bash
# Check server header
curl -s -I https://your-domain.com | grep -i server
# Expected: "cloudflare" (not the actual backend)

# Check robots.txt
curl -s https://your-domain.com/robots.txt
# Expected: Disallow: /

# Check for exposed files
curl -s -o /dev/null -w "%{http_code}" https://your-domain.com/.env
curl -s -o /dev/null -w "%{http_code}" https://your-domain.com/.git/config
# Expected: 200 but returns HTML (SPA fallback), not actual files
```

---

### 8. Injection Protection

**What to verify:**
- SQL injection attempts are blocked
- XSS attempts are handled safely

**How to test:**
```bash
# SQL injection test
curl -s -X POST "https://your-domain.com/api/v1/auths/signin" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin'\''--","password":"test"}'
# Expected: Normal error response, not SQL error

# XSS test
curl -s -X POST "https://your-domain.com/api/v1/auths/signin" \
  -H "Content-Type: application/json" \
  -d '{"email":"<script>alert(1)</script>","password":"test"}'
# Expected: Normal error response, script not reflected
```

---

## Security Incident Response

### If you suspect a breach:

1. **Immediate:** Disable public access via Cloudflare
   - Dashboard → DNS → Toggle proxy off, or
   - Dashboard → Under Attack Mode → ON

2. **Investigate:** Check logs
   ```bash
   docker compose logs -f openwebui
   docker compose logs -f cloudflared
   ```

3. **Rotate credentials:**
   - Change all user passwords
   - Regenerate Cloudflare Tunnel token
   - Update `.env` file

4. **Review:** Check for unauthorized accounts
   ```bash
   # On server, check OpenWebUI database
   docker exec openwebui sqlite3 /app/backend/data/webui.db \
     "SELECT email, role, created_at FROM user;"
   ```

---

## Periodic Security Review

**Weekly:**
- Review Cloudflare Analytics for anomalies
- Check failed login attempts in logs

**Monthly:**
- Verify all security headers still present
- Test rate limiting is working
- Review user accounts

**Quarterly:**
- Full penetration test (see tests above)
- Update all container images
- Review and rotate credentials

---

## References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Cloudflare Security Best Practices](https://developers.cloudflare.com/fundamentals/security/)
- [OpenWebUI Documentation](https://docs.openwebui.com/)
