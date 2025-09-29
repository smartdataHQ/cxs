# README_FIRST.md: Quick Setup for MimIR On-Prem (Best Practices - UP TO DATE)

## Best Practices Overview (Synced with Latest Compose)
- **Security**: Secrets in `.env.sensitive` only (delivered encrypted; never commit). Use tools like `pass` or 1Password for generation/storage. For prod, use Docker secrets or external vaults (e.g., HashiCorp Vault) instead of env files.
- **Separation & Coverage**: Non-sensitive in `.env.non-sensitive` (commit-safe, ALL non-secret vars covered). Sensitive keys-only in `.env.sensitive` (ALL secrets covered, empty values to fill). Customer overrides non-sensitive. Later env files take precedence.
- **Validation**: Always run `docker compose config` to preview merged config before `up`. Installers check ALL required secrets (e.g., Docker PAT, DB passwords, API keys like OPENAI/VOYAGE).
- **Resource Management**: Compose has CPU/memory limits to prevent OOM. Adjust in yml for your hardware.
- **Healthchecks**: Services wait for healthy deps (`condition: service_healthy`). Monitor with `docker compose ps`.
- **Prod Tips**: Use Docker Swarm for scaling. Enable TLS. Scan images with Trivy (`docker scout`). Backup volumes regularly.
- **gitignore**: Add `.env.sensitive`, `.env*`, `certs/*.pem` to prevent leaks. Examples are safe to commit.

## Before Running install.sh (or install.ps1 on Windows)

1. **Prepare Non-Sensitive File** (Defaults; safe to edit/share - Complete Coverage):
   - Copy `.env.example.non-sensitive` to `.env.non-sensitive`.
   - Customize if needed (e.g., `DOCKER_SUBNET` for network conflicts, `TLS_ENABLED=true` for HTTPS, worker counts for performance). All non-secret vars (ports, models, URLs) are pre-filled with defaults.

2. **Prepare Sensitive Secrets File** (Secure; do FIRST - Keys-Only Template):
   - Copy `.env.example.sensitive` to `.env.sensitive`.
   - Fill provided values (ALL secrets covered):
     - Docker: `DOCKER_PAT` (read-only token per customer).
     - DB: Strong passwords for `CLICKHOUSE_PASSWORD`, `REDIS_PASSWORD` (use `openssl rand -base64 16`).
     - AI: Keys like `OPENAI_API_KEY`, `VOYAGE_API_KEY`, `UNSTRUCTURED_API_KEY` (provided securely).
     - Secrets: Random `SECRET_KEY` (`openssl rand -base64 32`), OIDC if SSO.
   - Validate: Ensure all REQUIRED vars filled (installer checks).

3. **Optional: TLS for HTTPS** (Best practice for prod/exposed setups):
   - Generate certs: Install mkcert (`brew install mkcert; mkcert -install; mkcert localhost`) or use openssl:
     ```
     openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ./certs/privkey.pem -out ./certs/fullchain.pem -subj "/CN=localhost"
     ```
   - Place in `./certs/`.
   - Set `TLS_ENABLED=true` in `.env.non-sensitive`.

4. **Add to .gitignore** (Essential for security):
   ```
   .env.sensitive
   .env.non-sensitive  # If customized with any secrets
   certs/*.pem
   mimir-onprem/.env*
   ```

5. **Run Installer** (Supports multiple env files; validates ALL secrets):
   - `./install.sh --target mimir-onprem --env-file .env.non-sensitive,.env.sensitive` (macOS/Linux).
   - `.\install.ps1 -TargetDirectory mimir-onprem -EnvFile ".env.non-sensitive,.env.sensitive"` (Windows).
   - Flags: `--no-up` (setup/download only), `--ref main` (Git ref for .local fetch).
   - What it does: Fetches from GitHub, reminds to copy examples if needed, validates ALL required secrets (fails if missing, e.g., OPENAI_API_KEY empty), logs into Docker (using .env.sensitive PAT), runs `docker compose up -d` with absolute paths to env files (ensures compose finds values post-run).
   - Profiles: Add `--profile auth` to enable SSO (oauth2-proxy); `--profile ai` for ML services.

   **Manual Run** (Recommended for testing/best practice validation):
   ```
   cd mimir-onprem/.local
   docker compose --env-file ../.env.non-sensitive --env-file ../.env.sensitive -f docker-compose.mimir.onprem.yml config  # Preview merged config (no secrets shown; ALL vars covered)
   docker compose --env-file ../.env.non-sensitive --env-file ../.env.sensitive -f docker-compose.mimir.onprem.yml up -d  # Start (absolute paths ensure values loaded)
   docker compose --env-file ../.env.non-sensitive --env-file ../.env.sensitive -f docker-compose.mimir.onprem.yml ps  # Check health (ALL services)
   ```
   - Installer uses absolute paths, so compose finds files even from target dir. Values merge: non-sensitive defaults + sensitive overrides.

## Access & Verification
- UI: http://localhost (or https://localhost if TLS enabled). Login if SSO on.
- API: http://localhost/api/ (test health: curl http://localhost/api/health).
- Logs: `docker compose logs -f mimir-server` (run with env files for full context; covers ALL vars).
- Stats: `docker stats` to monitor resources (limits applied).
- Scale: `docker compose up -d --scale mimir-server=2` (adjust limits in yml).

## Troubleshooting (Common Best Practice Fixes - Synced)
- **Missing Secrets**: Installer exits with error listing ALL required (e.g., "No VOYAGE_API_KEY in .env.sensitive"). Check .env.sensitive for coverage.
- **Overrides Not Working**: Use `docker compose config`—verify sensitive vars appear last (ALL 47 vars from compose covered).
- **Port Conflicts**: Update ports in compose.yml or `PUBLIC_BASE_URL`/`DOCKER_SUBNET` in .env.non-sensitive. Restart: `docker compose down`.
- **Healthcheck Failures**: Services won't start until deps healthy. Check logs (`docker compose logs clickhouse`). Increase start_period if slow boot. Endpoints: /health or /ping (assumed; adjust in yml if service-specific).
- **Resource OOM**: AI services (embeddings) may hit memory limits—bump in x-resource-limits & yml. Monitor: `docker stats`.
- **Model Downloads Slow/First Run**: ~GBs for HF models; use `HF_TOKEN` in .env.sensitive. Pre-pull: `docker compose pull`.
- **TLS Errors**: Ensure certs match PUBLIC_HOSTNAME. Test: `curl -k https://localhost/healthz`.
- **Cleanup/Reset**: `docker compose down -v --remove-orphans` (removes volumes/data for fresh start).

This setup mirrors the repo's K8s manifests for consistency (ALL vars synced). For advanced prod (e.g., Swarm, auto-backups), extend with scripts. Questions? See main README.md.
