#!/usr/bin/env bash
# daily-growth-report :: run-once.sh
# Manual runner: snapshot + print diff. Does NOT post to Discord or Notion.
# Useful for first-time setup and debugging.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"

# Pre-flight: notion-api is required for the publish stage. Not needed for
# snapshot/diff, but warn early so members don't hit a wall at 08:00 on day 2.
NOTION_SKILL="$OPENCLAW_HOME/workspace/skills/notion-api/SKILL.md"
if [[ ! -f "$NOTION_SKILL" ]]; then
  echo "WARN: notion-api skill not found at $NOTION_SKILL"
  echo "WARN: snapshot/diff will work, but the Notion publish step will fail."
  echo "WARN: Install notion-api before enabling the cron jobs."
  echo ""
fi

echo ">>> Running snapshot…"
bash "$SKILL_DIR/scripts/snapshot.sh"

echo ""
echo ">>> Diff vs. yesterday (first 200 lines):"
bash "$SKILL_DIR/scripts/diff.sh" | head -200

echo ""
echo ">>> Done. Feed the full diff into an LLM to produce a draft."
echo ">>> See docs/install-guide.md for wiring this into cron."
