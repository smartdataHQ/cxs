# Mímir Agent On‑Prem (Docker Compose)

This directory provides a single docker‑compose stack to run the Mímir agent on‑prem with a small footprint. Only the web entrypoint is exposed; all other services are internal.

## Components
- ClickHouse: local document store and vector database
- Redis: local cache
- cxs-services: local document utilities (no Postgres)
- mimir-server: application backend and agent
- mimir-ui: web UI
- oauth2-proxy: OIDC SSO (Entra ID ready)
- nginx: TLS termination + reverse proxy in front of UI/API and oauth2-proxy

## Prerequisites
- Docker Desktop or Docker Engine with Compose v2
- A DNS name for the service (e.g., `mimir.local`) or a hosts file entry
- TLS certs for your hostname
  - Place `fullchain.pem` and `privkey.pem` under `.local/certs/` (configurable via `TLS_CERTS_DIR`)
  - To generate a self‑signed cert for testing:
    - `mkdir -p .local/certs`
    - `openssl req -x509 -newkey rsa:2048 -nodes -keyout .local/certs/privkey.pem -out .local/certs/fullchain.pem -days 365 -subj "/CN=mimir.local"`

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
```
# Option A: run from project root.
# The compose file now explicitly loads .local/.env, .local/mimir-onprem.env and .local/secrets.env,
# so you can simply edit/create those files under .local/ and run from the repo root.
cp .local/mimir-onprem.env .local/.env  # or edit .local/.env directly
DOCKER_HOST=${DOCKER_HOST:-} \
docker compose --project-name mimir-on-pre \
  -f .local/docker-compose.mimir.onprem.yml up -d
```

```
# Option B: run from inside the .local directory using the same-directory env file
cd .local
cp mimir-onprem.env .env  # or use --env-file mimir-onprem.env
DOCKER_HOST=${DOCKER_HOST:-} docker compose -f docker-compose.mimir.onprem.yml up -d
# alternatively, without renaming:
DOCKER_HOST=${DOCKER_HOST:-} docker compose -f docker-compose.mimir.onprem.yml --env-file mimir-onprem.env up -d
```

Or with explicit env file(s):
```
docker compose -f .local/docker-compose.mimir.onprem.yml \
  --env-file .local/mimir-onprem.env up -d
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
- Logs: json‑file driver with rotation (50 MB × 3)
- Stop: `docker compose -f .local/docker-compose.mimir.onprem.yml down`
- Stop and remove data: add `-v` (removes ClickHouse/Redis volumes)
- Inspect effective config: `docker compose -f .local/docker-compose.mimir.onprem.yml --env-file .local/mimir-onprem.env.example config`

## Troubleshooting
- If the site is unreachable, ensure your chosen `DOCKER_SUBNET` doesn’t conflict with LAN/VPN subnets
- TLS errors: verify `fullchain.pem`/`privkey.pem` paths and hostname match `PUBLIC_BASE_URL`
- SSO loops: double‑check OIDC issuer, client credentials, and redirect URI
- Service status: `docker compose -f .local/docker-compose.mimir.onprem.yml ps` and `... logs -f <service>`

## Notes
- Images are pinned to amd64; on Apple Silicon, Docker will run them under emulation
- This README references shared standards; for general platform principles see `docs/k8s-standards.md`, `docs/solution-version-policy.md`, and `FIRST_PRINCIPLES.md`
