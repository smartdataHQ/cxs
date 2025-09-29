# README_FIRST.md: 3-Step Setup for MimIR On-Prem (All Platforms - Frictionless)

1. **Download and Run Script** (No clone needed; auto-handles env for all platforms):
   - macOS/Linux: `curl -L -o install.sh https://raw.githubusercontent.com/smartdataHQ/cxs/main/.local/install.sh && chmod +x install.sh && ./install.sh --target mimir-onprem`
   - Windows (PowerShell): `Invoke-WebRequest -Uri https://raw.githubusercontent.com/smartdataHQ/cxs/main/.local/install.ps1 -OutFile install.ps1 && .\install.ps1 -TargetDirectory mimir-onprem`
   - The script auto-downloads env templates, copies to .env.non-sensitive (ready) and .env.sensitive (opens editor for fill), waits for you to fill secrets, fetches the stack, and starts services.

2. **Fill Secrets in Editor** (Interactive on all platforms):
   - Script opens native editor: nano/vi on macOS/Linux (fill DOCKER_PAT, API keys, etc., save, Enter to continue).
   - On Windows: Opens Notepad for .env.sensitive—fill, save, Enter in PowerShell.
   - Skip interactive with --no-interactive (or -NoInteractive) if pre-filled.
   - Required: DOCKER_PAT, DB passwords, OPENAI_API_KEY, etc. (provided securely).

3. **Access**:
   - UI: http://localhost (or https if TLS enabled).
   - API: http://localhost/api/.
   - Verify: From mimir-onprem/.local, `docker compose ps` (all healthy?).
   - Logs: `docker compose logs -f mimir-server`.
   - Stop: `docker compose down` from mimir-onprem/.local.

Done! Script handles everything—fill secrets when prompted. For help, rerun with --help.
