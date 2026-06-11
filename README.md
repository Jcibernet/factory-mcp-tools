# factory-mcp-tools

> On-demand MCP management for [Factory Droid](https://factory.ai) — keep your context budget lean by enabling MCPs only when you need them.

A small toolkit that turns Factory's MCP roster into a **pay-as-you-go** resource instead of an always-on tax on your context window.

Includes:

- **`toggle-mcp.sh`** — list / enable / disable MCP servers in `~/.factory/mcp.json` with backups and token-cost estimates.
- **`mcp-orchestrator` skill** — a Factory skill that teaches Droid how to detect when an MCP would help, check if it's enabled, fall back to CLI when possible, and tell you exactly how to bring an MCP online (`toggle-mcp.sh enable <name>` + `droid -r`).

---

## Why?

By default, every MCP server you configure in `~/.factory/mcp.json` is loaded into the session at startup. Each one costs context tokens for its tool schemas:

| MCP | Approx tokens |
|---|---|
| playwright | ~3,500 |
| docker | ~2,800 |
| github | ~2,000 |
| neon-admin | ~1,500 |
| notion | ~1,500 |
| linear | ~1,200 |
| sentry | ~1,000 |
| postgres-* | ~80 each |

If you have 8–10 MCPs configured "just in case", that's easily **10–15k tokens** of context gone before you write a single prompt. Most sessions only need 1–2 of them.

This toolkit lets you keep MCPs **configured but disabled**, and bring them online only for the task at hand.

---

## Install

```bash
git clone https://github.com/Jcibernet/factory-mcp-tools.git
cd factory-mcp-tools

# 1) Install the toggle script
mkdir -p ~/.factory/bin
cp bin/toggle-mcp.sh ~/.factory/bin/
chmod +x ~/.factory/bin/toggle-mcp.sh

# 2) (Optional) install the skill globally
mkdir -p ~/.factory/skills/mcp-orchestrator
cp skills/mcp-orchestrator/SKILL.md ~/.factory/skills/mcp-orchestrator/

# 3) Add ~/.factory/bin to PATH (optional but recommended)
echo 'export PATH="$HOME/.factory/bin:$PATH"' >> ~/.bashrc   # or ~/.zshrc
```

---

## Usage

```bash
# Inspect
toggle-mcp.sh list                       # all MCPs + enabled/disabled + type
toggle-mcp.sh status                     # enabled set + estimated context cost

# Toggle (one or many)
toggle-mcp.sh enable docker
toggle-mcp.sh disable playwright notion linear
toggle-mcp.sh on docker                  # alias
toggle-mcp.sh off playwright             # alias
```

Each toggle makes a timestamped backup of `~/.factory/mcp.json` at `~/.factory/mcp.json.bak-<epoch>` before writing.

### Apply changes

MCPs are loaded at Droid CLI startup, so toggles take effect on the **next** session:

```bash
toggle-mcp.sh enable docker
exit          # exit the current droid session
droid -r      # resume the same session with the new MCP set loaded
```

Session state (messages, specs, tool history) is preserved by Droid, so the restart-and-resume cycle is non-destructive.

### Example output

```
$ toggle-mcp.sh status
Enabled  (3): playwright, postgres-felzbooks-dev, finaudit-prod-postgres
Disabled (6): sentry, notion, github, linear, neon-admin, docker
Estimated context cost of enabled MCPs: ~3660 tokens
```

---

## The `mcp-orchestrator` skill

A Factory skill that teaches Droid the **policy** around on-demand MCPs.

What it does, in plain English:

1. Detects when a user request would benefit from an MCP (e.g. "list my containers" → docker).
2. Runs `toggle-mcp.sh status` to see what's currently loaded.
3. If the MCP is already enabled → uses it.
4. If disabled but a CLI fallback is good enough → uses the CLI silently (e.g. `docker ps` via Execute).
5. If disabled and the fallback is poor → prints the exact toggle + restart + resume commands and stops.
6. Never edits `mcp.json` directly (always via `toggle-mcp.sh` so backups happen).
7. Never claims a toggle takes effect mid-session.

Install:

```bash
mkdir -p ~/.factory/skills/mcp-orchestrator
cp skills/mcp-orchestrator/SKILL.md ~/.factory/skills/mcp-orchestrator/
```

The skill becomes available in your next Droid session and is auto-invoked when relevant.

---

## How `toggle-mcp.sh` decides token costs

The estimates are intentionally rough — they live as a static table inside the script. They're meant to give you a "this is roughly 3.5k vs 80" sense, not an exact budget. Adjust the table to your own measurements if you care about precision.

```bash
# inside toggle-mcp.sh
declare -A TOKENS=(
  [playwright]=3500
  [docker]=2800
  [github]=2000
  ...
)
```

---

## Companion tool

If you mainly use Playwright MCP for **one-shot visual debugging** (screenshot + console + network + a11y + perf), check out [**visual-debug**](https://github.com/Jcibernet/visual-debug) — a single-file CLI that gives an AI agent the same browser visibility with **zero MCP context cost**. Pair the two:

- Keep Playwright MCP **disabled** by default.
- For one-shot inspection: `visual-debug http://localhost:3000` via Execute.
- Only enable Playwright MCP when you need multi-step interactive flows.

---

## Contributing

PRs welcome. Keep the toggle script POSIX-leaning bash + Python (already installed everywhere Droid runs). Keep the skill prompt under 200 lines.

---

## License

MIT © Juan Cibernet
