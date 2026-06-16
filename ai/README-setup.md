# AI Setup

Katalog `ai/` zawiera instalator Bash:
- `install_ai.sh`


Instalują wyłącznie:
- Claude Code
- Codex
- Antigravity CLI

Sposób instalacji:
- Claude Code: oficjalny installer Anthropic
- Codex CLI: oficjalny installer OpenAI
- Antigravity CLI: oficjalny installer Google

## Uruchamianie

```bash
bash ai/install_ai.sh
```

Tylko Claude Code:

```bash
bash ai/install_ai.sh --claude
```
Tylko Codex:

```bash
bash ai/install_ai.sh --codex
```

Tylko Antigravity CLI:

```bash
bash ai/install_ai.sh --antigravity
```

## Wymagania

- Claude Code:
  - `curl` oraz `sh` dla `install_ai.sh` na systemach Unix-like
- Codex:
  - `curl` oraz `sh` dla `install_ai.sh` na systemach Unix-like
- Antigravity CLI:
  - `curl` oraz `sh` dla `install_ai.sh` na systemach Unix-like
