# Mímir Agent On‑Prem (Docker Compose)

This directory provides a single docker‑compose stack to run the Mímir agent on‑prem with a small footprint. Only the web entrypoint is exposed; all other services are internal.

## Components
- ClickHouse: local document store and vector database
- Redis: local cache
- cxs-services: local document utilities (no Postgres)
- cxs-anonymization: PII masking service backing document processing
- cxs-embeddings: Transformer-based embeddings service (Qwen3 default)
- mimir-server: application backend and agent
- mimir-ui: web UI
- oauth2-proxy: OIDC SSO (Entra ID ready)
- nginx: TLS termination + reverse proxy in front of UI/API and oauth2-proxy

## Prerequisites
- Docker Desktop or Docker Engine with Compose v2
- Python 3, curl, and tar (required by install.sh)
- A DNS name for the service (e.g., `mimir.local`) or a hosts file entry
- TLS certs for your hostname
  - Place `fullchain.pem` and `privkey.pem` under `.local/certs/` (configurable via `TLS_CERTS_DIR`)
  - To generate a self‑signed cert for testing:
    - `mkdir -p .local/certs`
    - `openssl req -x509 -newkey rsa:2048 -nodes -keyout .local/certs/privkey.pem -out .local/certs/fullchain.pem -days 365 -subj "/CN=mimir.local"`

## Automated Install
- Scripts `install.sh` (macOS/Linux) and `install.ps1` (Windows) fetch the `.local` stack via the GitHub contents API (default branch or `GITHUB_REF`) and optionally run `docker compose up` for you.
- Both scripts require Docker, the Docker Compose plugin (or `docker-compose` binary), and standard archive tools (`curl` + `tar` on macOS/Linux, `Invoke-WebRequest` + `Expand-Archive` on Windows).
- Provide Docker Hub credentials via `DOCKER_USERNAME` and `DOCKER_PAT` in your env file (optional `DOCKER_REGISTRY`, defaults to `docker.io`); the scripts log in before pulling `quicklookup/*` images.
- Optional: set `GITHUB_TOKEN` (env var or env file) to avoid GitHub API rate limits or access private forks; use `GITHUB_REF` (or `--ref`/`-GitRef`) to target a specific branch/tag/SHA.

**macOS/Linux**
- `curl -fsSL https://raw.githubusercontent.com/smartdataHQ/cxs/main/.local/install.sh -o install.sh`
- `chmod +x install.sh`
- `./install.sh --target mimir-onprem --env-file /path/to/mimir-onprem.env` (add `--no-up` to download only; omit `--env-file` if `.local/.env` already exists; append `--ref my-branch` to pin a git ref).

**Windows (PowerShell)**
- `Invoke-WebRequest https://raw.githubusercontent.com/smartdataHQ/cxs/main/.local/install.ps1 -OutFile install.ps1`
- `powershell -ExecutionPolicy Bypass -File .\install.ps1 -TargetDirectory mimir-onprem -EnvFile C:\path\mimir-onprem.env` (append `-NoUp` to skip compose; drop `-EnvFile` if `.local\.env` is present; add `-GitRef my-branch` to pin a git ref).


## Configuration
All configuration is via environment variables (no secrets are committed). Use the example file provided and adjust as needed:

1) Copy the example and edit values

```
cp .local/mimir-onprem.env .local/.env
# Edit .local/.env
```

2) Or provide env files explicitly

```
docker compose -f .local/docker-compose.mimir.onprem.yml \
  --env-file .local/mimir-onprem.env.example \
  --env-file .local/secrets.env \
  up -d
```

- Recommended: keep sensitive values in a separate `secrets.env` that is not committed
- Variables are documented inline in `.local/mimir-onprem.env.example`

### Mandatory variables (minimum)
- PUBLIC_BASE_URL (e.g., `https://mimir.local`)
- TLS_CERTS_DIR (directory containing `fullchain.pem` and `privkey.pem`)
- CLICKHOUSE_PASSWORD
- REDIS_PASSWORD
- CONTEXT_SUITE_JWT_SECRET_KEY
- TOKEN_SECRET_KEY
- LLM provider credentials (choose at least one):
  - OpenAI: `OPENAI_API_KEY`
  - Azure OpenAI: `AZURE_OPENAI_API_KEY`, `AZURE_OPENAI_API_BASE`, `AZURE_OPENAI_API_VERSION`, `AZURE_OPENAI_API_TYPE`
  - Voyage: `VOYAGE_API_KEY`
  - Unstructured: `UNSTRUCTURED_API_KEY` (and optionally `UNSTRUCTURED_API_URL`)
- OIDC SSO: `OIDC_ISSUER_URL`, `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`, `OAUTH2_PROXY_COOKIE_SECRET`
- Observability: `EVENTS_SERVER_KEY` (target endpoint defaults to `https://inbox.contextsuite.com/api/s/s2s/track`)

### Registry Access
- Required for install scripts: set `DOCKER_USERNAME` and `DOCKER_PAT` in `.local/.env` (or the file passed via `--env-file`).
- Optional: override `DOCKER_REGISTRY` if your images are mirrored elsewhere (defaults to `docker.io`).

### GitHub Access
- The installers use the GitHub contents API; set `GITHUB_TOKEN` in your env file (or export it) for higher rate limits or private repos.
- Override `GITHUB_REF` (env var or env file) or pass `--ref`/`-GitRef` to target a specific branch, tag, or commit.

### Local Demo Mode (no‑SSO)
For local demos/testing without SSO or event egress:
- Set `NO_SSO=true` to disable SSO
- Set `NO_OBSERVABILITY=true` to disable sending events to Inbox
- Optionally switch Nginx to a no‑SSO config (bypasses oauth2‑proxy):
  - `NGINX_CONF=./nginx/default.nosso.conf`

Example:
```
NO_SSO=true
NO_OBSERVABILITY=true
NGINX_CONF=./nginx/default.nosso.conf
```

### Networking
- Only ports 80 and 443 are exposed on the host via `mimir-nginx`
- All other services communicate on an internal Docker bridge network
- The network subnet can be customized to avoid conflicts (see `DOCKER_SUBNET`, `DOCKER_GATEWAY` in the env example)

## Start
After running the install script, all files are in your target directory (e.g., `mimir-onprem/`):

```bash
cd mimir-onprem
docker compose up -d
```

The env files (`.env.non-sensitive` and `.env.sensitive`) are automatically discovered by Docker Compose in the same directory.

For manual setup without the install script:
```bash
# From the deployment directory
docker compose -f docker-compose.mimir.onprem.yml \
  --env-file .env.non-sensitive \
  --env-file .env.sensitive \
  up -d
```

## Verify
- Health: `curl -k https://<your-host>/healthz` returns `ok`
- UI: open `https://<your-host>/` (SSO flow via oauth2-proxy)
- API readiness (proxied): `https://<your-host>/api/status/ready`

## SSO (OIDC / Entra ID)
1) Register an application in Entra ID (OIDC)
   - Redirect URI: `https://<your-host>/oauth2/callback`
   - Grant scopes: `openid profile email`
2) Fill env vars: `OIDC_ISSUER_URL` (e.g., `https://login.microsoftonline.com/<tenant-id>/v2.0`), `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`, `OAUTH2_PROXY_COOKIE_SECRET`
3) Ensure your `PUBLIC_BASE_URL` matches the hostname used above

Notes
- oauth2-proxy protects the UI; the API is reachable under `/api/` and can be further protected if needed
- WebSockets are proxied by nginx

## External Services & Egress
- SSP (remote) and related endpoints are accessed over HTTPS
- Observability events and post‑chat reports are sent to the Inbox endpoint specified by `INBOX_EVENTS_ENDPOINT` (defaults to `https://inbox.contextsuite.com/api/s/s2s/track`)
- No Kafka or Postgres are used locally in this setup

## Operations
From your deployment directory (e.g., `mimir-onprem/`):

- **View logs**: `docker compose logs -f [service-name]`
- **Check status**: `docker compose ps`
- **Stop**: `docker compose down`
- **Stop and remove data**: `docker compose down -v` (removes ClickHouse/Redis volumes)
- **Inspect config**: `docker compose config`

## Troubleshooting
- If the site is unreachable, ensure your chosen `DOCKER_SUBNET` doesn't conflict with LAN/VPN subnets
- TLS errors: verify `fullchain.pem`/`privkey.pem` paths and hostname match `PUBLIC_BASE_URL`
- SSO loops: double‑check OIDC issuer, client credentials, and redirect URI
- Service status: `docker compose ps` and `docker compose logs -f <service>`

## Notes
- Images are pinned to amd64; on Apple Silicon, Docker will run them under emulation
- This README references shared standards; for general platform principles see `docs/k8s-standards.md`, `docs/solution-version-policy.md`, and `FIRST_PRINCIPLES.md`
