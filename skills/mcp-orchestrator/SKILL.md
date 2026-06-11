---
name: mcp-orchestrator
description: |
  Manage on-demand MCP servers across sessions. Use this skill when the user's
  task would benefit from an MCP that is currently disabled (e.g. docker),
  when the user asks to enable/disable/list MCPs, when the user mentions
  context-token budget for MCPs, or when an MCP-flavored task could be done
  with a CLI fallback in the meantime. Detects intent, checks state via
  `~/.factory/bin/toggle-mcp.sh`, suggests the right toggle, and falls back
  to CLI through Execute while the user restarts the droid CLI.
license: MIT
metadata:
  version: v1
  publisher: jcibernet
---

# MCP Orchestrator

You help the user keep their MCP roster lean. Some MCPs are intentionally
**disabled by default** to save context tokens, and are only enabled when a
task actually benefits from them.

## Hard constraint (read first)

MCPs are **loaded once at droid CLI startup**. You CANNOT enable a disabled
MCP and immediately use its tools in the current session. Enabling only takes
effect on the **next** droid session. Never claim otherwise.

**Good news: restarting is cheap and non-destructive.** Droid persists:

- Session state in `~/.factory/sessions/` — resumable with `droid -r`
- Specs in `~/.factory/specs/`
- History in `~/.factory/history.json`
- `AGENTS.md` per workspace
- Skills, droids, background process registry

So the canonical "toggle + restart + resume" flow is fast (~3-5s + resume) and
loses nothing important. Treat it as a normal operation, not a disruption.

Therefore the right play is always one of:

1. **MCP already enabled** → just use it.
2. **MCP disabled but task is doable via CLI** → use the CLI fallback via
   Execute. Do not bug the user.
3. **MCP disabled and CLI fallback is poor** → tell the user the exact toggle
   command + the restart + resume command. Reassure them the session is
   preserved.

## Source of truth

- Config: `~/.factory/mcp.json`
- Toggle script: `~/.factory/bin/toggle-mcp.sh`
- Catalog doc (per workspace, if present): `./AGENTS.md`

Run `~/.factory/bin/toggle-mcp.sh status` whenever you are unsure which MCPs
are currently active. Do this **before** suggesting a toggle.

## Intent → MCP mapping

| User intent / signal | Candidate MCP | CLI fallback (Execute) |
|---|---|---|
| "list containers", "docker logs", "build image", "compose up" | `docker` | `docker ps`, `docker logs`, `docker build`, `docker compose ...` |
| browser automation, scrape page, E2E test, multi-step interaction | `playwright` | None — suggest enabling Playwright MCP |
| one-shot screenshot + devtools dump (console/network/a11y/perf) | (none) | `visual-debug <url>` — use this BEFORE suggesting Playwright MCP |
| "create a Neon branch", manage Neon projects/roles | `neon-admin` | `neonctl` if installed, otherwise suggest enabling |
| read-only SQL on felzbooks dev DB | `postgres-felzbooks-dev` | `psql` if available + creds known |
| read-only SQL on finaudit prod DB | `finaudit-prod-postgres` | `psql` — but warn it is prod |
| GitHub PR/issue/repo data, workflow runs | `github` | `gh` CLI |
| Linear issues | `linear` | `linear-cli` if installed |
| Notion pages | `notion` | (no clean fallback) |
| Sentry issues | `sentry` | (no clean fallback) |

If the intent is ambiguous, ask **one** focused question rather than guessing.

## Decision procedure

When invoked, follow this loop:

1. **Identify** which MCP(s) the task would benefit from, using the table above.
2. **Check state**:
   ```bash
   ~/.factory/bin/toggle-mcp.sh status
   ```
3. **Branch**:
   - If the target MCP is **enabled** → proceed using its tools.
   - If **disabled** and the **CLI fallback is good enough** for this task
     (see table) → use the fallback via Execute. Mention in one short line
     that "the `<name>` MCP is disabled; using `<cli>` instead."
   - If **disabled** and the **CLI fallback is poor** → output:
     ```
     This task is much easier with the `<name>` MCP.
     It is currently disabled to save ~<tokens> tokens of context.

     Run (session is preserved, this is safe):
       ~/.factory/bin/toggle-mcp.sh enable <name>
       exit
       droid -r       # resumes the most recently modified session
     ```
     Then STOP. Do not try to brute-force the task with a poor fallback.

4. **Hygiene** (optional, only when the user is clearly done):
   If the user just finished an isolated heavy task (e.g. a one-off Playwright
   scrape), you may suggest:
   ```bash
   ~/.factory/bin/toggle-mcp.sh disable <name>
   ```
   to free context for the next session. Never do this silently.

## Commands cheat sheet

```bash
# Inspect
~/.factory/bin/toggle-mcp.sh list      # all MCPs + status + type
~/.factory/bin/toggle-mcp.sh status    # enabled set + estimated token cost

# Toggle (one or many)
~/.factory/bin/toggle-mcp.sh enable docker
~/.factory/bin/toggle-mcp.sh disable playwright notion
~/.factory/bin/toggle-mcp.sh on docker
~/.factory/bin/toggle-mcp.sh off playwright
```

## Restart + resume cheat sheet

`/resume` is **not a slash command**. Resumption is a CLI flag set when
launching droid. The relevant invocations:

```bash
# Resume the most recently modified session (most common after a toggle)
droid -r
droid --resume

# Resume a specific session by ID
droid -r <sessionId>
droid --resume <sessionId>

# Fork a session (copy + resume the copy)
droid --fork <sessionId>

# Find sessions to resume
ls -lt ~/.factory/sessions/ | head -5     # by modification time
droid search "<keywords>"                  # full-text across sessions
```

What survives a restart (and is therefore "free" to do):

- Session messages, tool results, specs, history, AGENTS.md, skills, droids,
  background-process registry, files on disk.

What does NOT survive:

- Live in-memory state of the previous run (e.g. an open Playwright page —
  re-open it after resume).
- Environment variables set inside Execute calls (they reset every call
  anyway, so no change in behavior).

Recommended phrasing to the user when proposing a restart:

> "Session state is preserved. Run the toggle, `exit`, then `droid -r` to
> pick up exactly where we left off."

## What you must NEVER do

- Never edit `~/.factory/mcp.json` directly when the toggle script is
  available — use the script so a timestamped backup is created.
- Never claim a toggle takes effect mid-session.
- Never enable multiple heavy MCPs "just in case". Enable the minimum set
  the current task needs.
- Never disable an MCP without telling the user.
- Never call an MCP tool you have not verified is currently loaded. If it
  is in the **Deferred tools** list, load it with `ToolSearch`. If it is
  neither loaded nor deferred, it is unavailable this session.
- Never tell the user to "type `/resume`" — that is not a slash command in
  the chat. Resumption is `droid -r` from the shell.

## Output style

- Be concise. One short paragraph + the command block is enough.
- When suggesting a toggle, always print the exact command the user should
  run, including the restart instruction.
- When using the CLI fallback, run it directly via Execute without asking
  permission — the user has already opted into the "standard" scope.
