# AI Setup

Katalog `ai/` zawiera instalator Bash:
- `install_ai.sh`

Instalator PowerShell jest w `win_utils/ai/install_ai.ps1`.

Instalują wyłącznie:
- Claude Code
- Codex
- Antigravity CLI (`install_ai.sh`)

Sposób instalacji:
- Claude Code: natywny installer Anthropic zgodny z oficjalną dokumentacją
- Codex: oficjalny standalone installer OpenAI
- Antigravity CLI: oficjalny installer Google

Skrypty zostawiają globalne konfiguracje, agentów, skills oraz pliki projektowe bez zmian.

## Uruchamianie

Unix-like, WSL:

```bash
bash ai/install_ai.sh
```

Tylko Codex:

```bash
bash ai/install_ai.sh --codex
```

Tylko Claude Code:

```bash
bash ai/install_ai.sh --claude
```

PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\win_utils\ai\install_ai.ps1
```

albo:

```powershell
pwsh -File .\win_utils\ai\install_ai.ps1
```

Tylko Codex:

```powershell
pwsh -File .\win_utils\ai\install_ai.ps1 -Codex
```

Tylko Claude Code:

```powershell
pwsh -File .\win_utils\ai\install_ai.ps1 -Claude
```

## Wymagania

- Claude Code:
  - `curl` oraz `bash` dla `install_ai.sh` na systemach Unix-like
  - PowerShell dla `install_ai.ps1`
  - na Windows także Git for Windows zgodnie z dokumentacją Claude Code
- Codex:
  - `curl` oraz `sh` dla `install_ai.sh` na systemach Unix-like

Skrypty nie instalują Node.js ani innych dodatkowych toolchainów. Zakres to tylko instalacja `Claude Code`, `Codex` oraz `Antigravity CLI` w Bash.

## Uwaga

Instalatory nie tworzą ani nie modyfikują żadnych plików typu `AGENTS.md`, `CLAUDE.md`, agentów, skills ani konfiguracji w katalogach domowych narzędzi.
