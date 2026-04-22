#!/usr/bin/env bash
# daily-growth-report :: diff.sh
# Prints a machine-readable diff of yesterday → today, intended to be piped into
# an LLM prompt. Sections are separated by markers so the LLM can parse them.
set -euo pipefail

OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
SKILL_DIR="$OPENCLAW_HOME/skills/daily-growth-report"
EVO_DIR="$OPENCLAW_HOME/workspace/self-evolution"
SNAP_DIR="$EVO_DIR/snapshots"
CONFIG="${DAILY_GROWTH_CONFIG:-$SKILL_DIR/config.json}"

if [[ ! -d "$SNAP_DIR/.git" ]]; then
  echo "ERROR: no snapshot repo yet — run snapshot.sh first" >&2
  exit 2
fi

# Use TZ from config so date in META matches the intended Tokyo day.
TZ_CONFIG="Asia/Tokyo"
if [[ -f "$CONFIG" ]]; then
  TZ_CONFIG="$(jq -r '.timezone // "Asia/Tokyo"' "$CONFIG")"
fi

# Byte-safe truncation that won't cut UTF-8 codepoints in half.
# Reads at most N lines OR stops when accumulated bytes exceed CAP.
truncate_safely() {
  local cap="${1:-80000}"
  awk -v cap="$cap" '{
    if (total + length($0) + 1 > cap) { exit }
    total += length($0) + 1
    print
  }'
}

cd "$SNAP_DIR"

COMMIT_COUNT=$(git rev-list --count HEAD)

echo "=== META ==="
echo "date: $(TZ="$TZ_CONFIG" date +%Y-%m-%d)"
echo "timezone: $TZ_CONFIG"
echo "commits_total: $COMMIT_COUNT"
if [[ "$COMMIT_COUNT" -lt 2 ]]; then
  echo "first_run: true"
  exit 0
fi
echo "first_run: false"
echo ""

echo "=== STAT ==="
git diff --stat HEAD~1 HEAD || true
echo ""

echo "=== NAMES ==="
git diff --name-status HEAD~1 HEAD || true
echo ""

echo "=== PATCH ==="
git diff HEAD~1 HEAD --unified=2 -- \
  ':(exclude)**/_manifest.txt' \
  ':(exclude)vendor/_heads.txt' \
  | truncate_safely 80000
echo ""

echo "=== MANIFESTS ==="
for f in skills/_manifest.txt extensions/_manifest.txt vendor/_heads.txt agents/_manifest.txt; do
  if git show "HEAD~1:$f" >/dev/null 2>&1; then
    echo "--- $f ---"
    diff <(git show "HEAD~1:$f" 2>/dev/null || true) <(git show "HEAD:$f" 2>/dev/null || true) || true
  fi
done
