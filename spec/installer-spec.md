# Installer Spec (Draft)

## 1. Supported deployment modes

### bot-only
Deploy Bedolaga bot stack (bot + postgres + redis) for an already-existing Remnawave environment.

### cabinet-only
Deploy Bedolaga Cabinet against an already-running Bedolaga backend with Cabinet API enabled.
If a local Remnawave panel is already installed on the same host, installer should prefer integrating cabinet routes into the existing Remnawave reverse proxy (`/opt/remnawave/nginx.conf` or `/opt/remnawave/caddy/Caddyfile`) instead of creating a second conflicting proxy stack.

### bot+cabinet
Deploy full customer-facing stack with generated secrets.
On clean hosts this may include a dedicated proxy path. On hosts with an existing local Remnawave panel, installer should prefer reverse-proxy integration mode (`integrate-remnawave`) and merge Bedolaga routes into the panel proxy layer.

---

## 2. First target platform
- Debian 12/13
- Ubuntu 22.04/24.04
- x86_64 first

---

## 3. Mandatory preflight checks
- root/sudo available
- Docker present or installable
- Docker Compose plugin or legacy `docker-compose` present/installable
- enough RAM/disk
- ports `80/443` availability (when proxy mode)
- domain resolves to host (for public TLS mode)
- git/curl/openssl available
- no conflicting container names/networks unless approved
- detect whether host is clean or already hosting Remnawave/other `/opt` services
- if `/opt/remnawave*` exists, default to coexist mode with preserve-existing network policy
- explicit bot/cabinet local bind ports with conflict detection before prepare/deploy
+
+## 3.1 Host safety modes
+- `clean` — for fresh VPS bootstrap; installer may prepare dependencies and minimal firewall baseline
+- `coexist` — for servers with existing panel/services; installer must preserve unrelated open ports and apply only additive network changes by default
+
+## 3.2 Network safety rule
+- Installer must **not** blindly close unrelated open ports on an existing host
+- Default policy on non-clean hosts: `preserve-existing`
+- Firewall changes should be additive unless operator explicitly requests stricter cleanup

---

## 4. Output artifacts
- project directory under `/opt/bedolaga-stack` (default)
- generated `.env`
- generated `docker-compose.override.yml` if needed
- generated `Caddyfile` or `nginx.conf`
- optional `install-report.txt`
- optional `postinstall-check.sh`

---

## 5. Secrets policy
Installer generates by default:
- postgres password
- cabinet jwt secret
- web api default token
- webhook secret(s) where applicable

Installer never hardcodes production defaults from upstream `.env.example`.

---

## 6. Verification targets
### Bot
- docker health OK
- `/health` reachable
- postgres/redis healthy
- remnawave connectivity check passes

### Cabinet
- static frontend reachable
- `/api/*` routed to bot backend
- CORS origin matches cabinet domain
- Telegram username baked correctly

### Combined
- cabinet homepage loads
- API returns non-frontend response
- no container crashloop

---

## 7. Scale-readiness requirements
- idempotent reruns where possible
- explicit version pinning support
- pull/update path
- backup-safe config regeneration
- readable logs and failure reasons
- simple operator UX with minimal required prompts

## 8. Host bootstrap stage
- supported first on Debian 12/13 and Ubuntu 22.04/24.04
- installs missing base tooling: `git`, `curl`, `openssl`, `gettext-base`
- installs Docker runtime and compose-compatible command
- enables and starts Docker service
- `clean` mode may install reverse-proxy package and prepare minimal firewall baseline
- `coexist` mode must avoid destructive changes and skip blind proxy package takeover by default
