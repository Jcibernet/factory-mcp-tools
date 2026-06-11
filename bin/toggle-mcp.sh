#!/usr/bin/env bash
# toggle-mcp.sh — Enable/disable MCP servers in ~/.factory/mcp.json on demand.
#
# Usage:
#   toggle-mcp.sh list                 # show all MCPs and their status
#   toggle-mcp.sh enable <name>        # enable an MCP (and optionally others)
#   toggle-mcp.sh disable <name>       # disable an MCP
#   toggle-mcp.sh on <name> [name...]  # alias for enable (multiple)
#   toggle-mcp.sh off <name> [name...] # alias for disable (multiple)
#   toggle-mcp.sh status               # show enabled count + estimated tokens
#
# NOTE: Changes take effect on the NEXT droid session. Restart your droid CLI
# (exit and re-open) for the toggle to apply.

set -euo pipefail

CONFIG="${HOME}/.factory/mcp.json"

if [[ ! -f "$CONFIG" ]]; then
  echo "Error: $CONFIG not found" >&2
  exit 1
fi

# Approximate token costs per MCP (rough, based on tool schema size)
declare -A TOKENS=(
  [playwright]=3500
  [docker]=2800
  [github]=2000
  [notion]=1500
  [linear]=1200
  [sentry]=1000
  [neon-admin]=1500
  [postgres-felzbooks-dev]=80
  [finaudit-prod-postgres]=80
)

cmd_list() {
  python3 - <<PY
import json, os
with open("$CONFIG") as f: d = json.load(f)
print(f"{'NAME':<28} {'STATUS':<10} {'TYPE':<8}")
print("-" * 50)
for name, cfg in sorted(d.get("mcpServers", {}).items()):
    status = "DISABLED" if cfg.get("disabled") else "enabled"
    typ = cfg.get("type", "stdio")
    print(f"{name:<28} {status:<10} {typ:<8}")
PY
}

cmd_status() {
  python3 - <<PY
import json
with open("$CONFIG") as f: d = json.load(f)
tokens = {
  "playwright":3500,"docker":2800,"github":2000,"notion":1500,
  "linear":1200,"sentry":1000,"neon-admin":1500,
  "postgres-felzbooks-dev":80,"finaudit-prod-postgres":80,
}
enabled = [n for n,c in d["mcpServers"].items() if not c.get("disabled")]
disabled = [n for n,c in d["mcpServers"].items() if c.get("disabled")]
total = sum(tokens.get(n, 500) for n in enabled)
print(f"Enabled  ({len(enabled)}): {', '.join(enabled) or '(none)'}")
print(f"Disabled ({len(disabled)}): {', '.join(disabled) or '(none)'}")
print(f"Estimated context cost of enabled MCPs: ~{total} tokens")
PY
}

cmd_set() {
  local state="$1"; shift
  local names=("$@")
  if [[ ${#names[@]} -eq 0 ]]; then
    echo "Error: no MCP name given" >&2; exit 1
  fi
  cp "$CONFIG" "${CONFIG}.bak-$(date +%s)"
  python3 - "$state" "${names[@]}" <<'PY'
import json, sys
state = sys.argv[1]   # "true" or "false"
names = sys.argv[2:]
p = "/home/jcibernet/.factory/mcp.json"
with open(p) as f: d = json.load(f)
disabled_val = (state == "true")
missing = []
for n in names:
    if n not in d["mcpServers"]:
        missing.append(n); continue
    d["mcpServers"][n]["disabled"] = disabled_val
with open(p,"w") as f: json.dump(d, f, indent=2)
for n in names:
    if n in missing:
        print(f"  ! not found: {n}")
    else:
        verb = "disabled" if disabled_val else "enabled"
        print(f"  {verb}: {n}")
print("\nRestart droid CLI for changes to take effect.")
PY
}

case "${1:-help}" in
  list|ls)        cmd_list ;;
  status|st)      cmd_status ;;
  enable|on)      shift; cmd_set "false" "$@" ;;
  disable|off)    shift; cmd_set "true"  "$@" ;;
  help|-h|--help|*)
    sed -n '2,15p' "$0" ;;
esac
