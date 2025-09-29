# README_FIRST.md: 3-Step Setup for MimIR On-Prem

1. **Download and Run Script** (No clone needed; auto-handles env for all platforms):
   - **macOS/Linux**:
     ```
     curl -L -o install.sh https://raw.githubusercontent.com/smartdataHQ/cxs/main/.local/install.sh && chmod +x install.sh && ./install.sh --target mimir-onprem
     ```
   - **Windows (PowerShell)**: Copy and paste this one-liner into PowerShell (select all and right-click to paste):
     ```
     Invoke-WebRequest -Uri https://raw.githubusercontent.com/smartdataHQ/cxs/main/.local/install.ps1 -OutFile install.ps1; .\install.ps1 -TargetDirectory mimir-onprem
     ```
     - **Copy Tip**: Highlight the command above, copy (Ctrl+C), open PowerShell, paste (right-click or Ctrl+V), and press Enter. The script handles the rest.

2. **Fill Secrets When Prompted**:
   - The script auto-downloads env templates and opens an editor (nano/Notepad) for .env.sensitive.
   - Fill required values (e.g., DOCKER_PAT, OPENAI_API_KEY from provided secure info).
   - Save and press Enter in the terminal to continue (skips if pre-filled with --no-interactive).

3. **Access**:
   - UI: http://localhost (or https://localhost if TLS enabled).
   - API: http://localhost/api/.
   - Verify: From mimir-onprem/.local, `docker compose ps` (all healthy?).
   - Logs: `docker compose logs -f mimir-server`.
   - Stop: `docker compose down` from mimir-onprem/.local.

Done! Script handles fetch, env setup, and start. For help, see script usage.
