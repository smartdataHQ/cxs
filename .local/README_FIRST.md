# README_FIRST.md: 3-Step Setup for MimIR On-Prem

1. **Download and Run Script** (No clone needed; auto-handles env for all platforms):
   - **Prerequisites**: Make sure Docker Desktop is installed and running (download from https://docker.com)
   - **macOS/Linux**:
     ```
     curl -L -o install.sh https://raw.githubusercontent.com/smartdataHQ/cxs/main/.local/install.sh && chmod +x install.sh && ./install.sh --target mimir-onprem
     ```
   - **Windows (PowerShell)**: Copy and paste this one-liner into PowerShell (select all and right-click to paste):
     ```
     Invoke-WebRequest -Uri https://raw.githubusercontent.com/smartdataHQ/cxs/main/.local/install.ps1 -OutFile install.ps1; .\install.ps1 -TargetDirectory mimir-onprem
     ```
     - **Copy Tip**: Highlight the command above, copy (Ctrl+C), open PowerShell, paste (right-click or Ctrl+V), and press Enter. The script handles the rest.
   - The script will check Docker availability and test functionality before proceeding.

2. **Answer Simple Questions About Your Setup** (6 easy steps):
   - The script walks you through each secret with clear prompts and progress indicators.
   - **For passwords** (databases, encryption): Just press Enter to auto-generate strong, secure ones.
   - **For API keys**: Enter the keys provided to you securely (DOCKER_PAT, OPENAI_API_KEY, etc.).
   - **For optional items**: Press Enter to skip (Azure, SSO, etc.).
   - Takes 2-3 minutes with helpful descriptions, auto-generation, and format validation.

3. **Access**:
   - UI: http://localhost (or https://localhost if TLS enabled).
   - API: http://localhost/api/.
   - Verify: From mimir-onprem/.local, `docker compose --env-file ../.env.non-sensitive --env-file ../.env.sensitive ps` (all healthy?).
   - Logs: `docker compose --env-file ../.env.non-sensitive --env-file ../.env.sensitive logs -f mimir-server`.
   - Stop: `docker compose --env-file ../.env.non-sensitive --env-file ../.env.sensitive down` from mimir-onprem/.local.

Done! Script handles fetch, env setup, and start. For help, see script usage.
