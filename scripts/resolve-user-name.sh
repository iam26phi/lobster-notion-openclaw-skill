#!/usr/bin/env bash
# daily-growth-report :: resolve-user-name.sh
# Idempotent bootstrap for config.user_name.
# On first run: reads workspace/USER.md to find a human-readable name,
# writes it into config.json, then echoes it to stdout.
# On subsequent runs: just echoes the stored name.
# Order of lookup: config.user_name → USER.md「What to call them」→ USER.md「Name」→ config.agent_id.
set -euo pipefail

OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
SKILL_DIR="$OPENCLAW_HOME/skills/daily-growth-report"
CONFIG="${DAILY_GROWTH_CONFIG:-$SKILL_DIR/config.json}"
USER_MD="$OPENCLAW_HOME/workspace/USER.md"

if [[ ! -f "$CONFIG" ]]; then
  echo "[resolve-user-name] ERROR: config not found at $CONFIG" >&2
  exit 2
fi

current="$(jq -r '.user_name // ""' "$CONFIG")"
if [[ -n "$current" && "$current" != "null" ]]; then
  echo "$current"
  exit 0
fi

extract_md_field() {
  local field="$1"
  [[ -f "$USER_MD" ]] || return 1
  # Matches lines like: "- **What to call them:** 26" or "- **Name:** 26"
  local line
  line="$(grep -m1 -E "^[[:space:]]*-[[:space:]]+\*\*${field}:\*\*" "$USER_MD" 2>/dev/null || true)"
  [[ -z "$line" ]] && return 1
  # Strip prefix up to and including the colon+bold-close, then trim spaces.
  local val
  val="$(echo "$line" | sed -E "s/^[[:space:]]*-[[:space:]]+\*\*${field}:\*\*[[:space:]]*//; s/[[:space:]]+$//")"
  # Reject placeholder-ish values
  case "$val" in
    ""|"（未提供）"|"(未提供)"|"TBD"|"TODO"|"REPLACE_ME") return 1 ;;
  esac
  echo "$val"
}

resolved=""
if val="$(extract_md_field 'What to call them' 2>/dev/null)"; then
  resolved="$val"
elif val="$(extract_md_field 'Name' 2>/dev/null)"; then
  resolved="$val"
else
  resolved="$(jq -r '.agent_id // "user"' "$CONFIG")"
fi

# Persist to config.json (atomic)
tmp="$(mktemp)"
jq --arg n "$resolved" '.user_name = $n' "$CONFIG" > "$tmp"
mv "$tmp" "$CONFIG"

echo "$resolved"
