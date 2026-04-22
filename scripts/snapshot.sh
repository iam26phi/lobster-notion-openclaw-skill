#!/usr/bin/env bash
# daily-growth-report :: snapshot.sh
# Builds today's snapshot into the shadow git repo and commits it.
# Idempotent: running twice on the same day produces two commits with identical content
# (the second is an empty commit marker — harmless).
set -euo pipefail

OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
SKILL_DIR="$OPENCLAW_HOME/skills/daily-growth-report"
EVO_DIR="$OPENCLAW_HOME/workspace/self-evolution"
SNAP_DIR="$EVO_DIR/snapshots"
LOG_DIR="$EVO_DIR/logs"
CONFIG="${DAILY_GROWTH_CONFIG:-$SKILL_DIR/config.json}"

mkdir -p "$SNAP_DIR" "$LOG_DIR"

if [[ ! -f "$CONFIG" ]]; then
  echo "[snapshot] ERROR: config file not found at $CONFIG" >&2
  echo "[snapshot] Hint: cp config.example.json config.json and fill in IDs" >&2
  exit 2
fi

# Use TZ from config so members in different timezones still file under the intended date.
TZ_CONFIG="$(jq -r '.timezone // "Asia/Tokyo"' "$CONFIG")"
TODAY="$(TZ="$TZ_CONFIG" date +%Y-%m-%d)"
LOG="$LOG_DIR/snapshot-$TODAY.log"

log() { echo "[$(TZ="$TZ_CONFIG" date +%FT%T%z)] $*" | tee -a "$LOG"; }

# Initialize shadow git repo on first run
if [[ ! -d "$SNAP_DIR/.git" ]]; then
  log "first run: initializing shadow git repo at $SNAP_DIR"
  git -C "$SNAP_DIR" init -q
  git -C "$SNAP_DIR" config user.name "daily-growth-report"
  git -C "$SNAP_DIR" config user.email "daily-growth-report@openclaw.local"
  git -C "$SNAP_DIR" config commit.gpgsign false

  # Belt-and-suspenders: rsync exclusions are primary defense, but a .gitignore
  # inside the shadow repo catches anything that slips through.
  cat > "$SNAP_DIR/.gitignore" <<'GITIGNORE'
*.env
*.env.*
credentials/
secrets/
*.key
*.pem
*.p12
auth-profiles.json
lcm.db
lcm.db-*
GITIGNORE
  # Note: NO "bootstrap" empty commit — the first real snapshot should be commit 1
  # so diff.sh's `commits_total < 2` check correctly flags first_run.
fi

# Read config (portable — works on bash 3.2)
TRACKED=()
while IFS= read -r line; do
  [[ -n "$line" ]] && TRACKED+=("$line")
done < <(jq -r '.tracked_paths[]' "$CONFIG")

EXCLUDED=()
while IFS= read -r line; do
  [[ -n "$line" ]] && EXCLUDED+=("$line")
done < <(jq -r '.excluded_paths[]' "$CONFIG")

# Build rsync exclude args. Always exclude nested .git to avoid git add
# treating sub-repos as gitlinks (which would hide content changes).
RSYNC_EXCLUDES=(--exclude='.git/' --exclude='.git')
for pat in "${EXCLUDED[@]}"; do
  RSYNC_EXCLUDES+=(--exclude="$pat")
done

# Clear stale tracked content (but keep .git and the .gitignore we just wrote)
find "$SNAP_DIR" -mindepth 1 -maxdepth 1 ! -name '.git' ! -name '.gitignore' -exec rm -rf {} +

# Copy tracked paths
for pat in "${TRACKED[@]}"; do
  # Strip trailing slash for consistent handling
  pat="${pat%/}"
  shopt -s nullglob
  # Expand glob relative to OPENCLAW_HOME; literal paths expand to themselves
  matches=($OPENCLAW_HOME/$pat)
  shopt -u nullglob
  if [[ ${#matches[@]} -eq 0 ]]; then
    log "skip (no match): $pat"
    continue
  fi
  for src in "${matches[@]}"; do
    [[ -e "$src" ]] || { log "skip (missing): $src"; continue; }
    rel="${src#$OPENCLAW_HOME/}"
    dst="$SNAP_DIR/$rel"
    mkdir -p "$(dirname "$dst")"
    if [[ -d "$src" ]]; then
      rsync -a --delete "${RSYNC_EXCLUDES[@]}" "$src/" "$dst/" 2>>"$LOG" || log "rsync warn: $src"
    else
      rsync -a "${RSYNC_EXCLUDES[@]}" "$src" "$dst" 2>>"$LOG" || log "rsync warn: $src"
    fi
  done
done

# Generate manifests (listing-only representations for noisy dirs)
MANIFEST_SKILLS=$(jq -r '.manifests.skills_list // false' "$CONFIG")
MANIFEST_AGENTS=$(jq -r '.manifests.agents_list // false' "$CONFIG")
MANIFEST_EXTENSIONS=$(jq -r '.manifests.extensions_list // false' "$CONFIG")
MANIFEST_VENDOR_HEADS=$(jq -r '.manifests.vendor_heads // false' "$CONFIG")

if [[ "$MANIFEST_SKILLS" == "true" && -d "$OPENCLAW_HOME/skills" ]]; then
  mkdir -p "$SNAP_DIR/skills"
  ls -1 "$OPENCLAW_HOME/skills" | sort > "$SNAP_DIR/skills/_manifest.txt" || true
fi

if [[ "$MANIFEST_AGENTS" == "true" && -d "$OPENCLAW_HOME/agents" ]]; then
  mkdir -p "$SNAP_DIR/agents"
  ls -1 "$OPENCLAW_HOME/agents" | sort > "$SNAP_DIR/agents/_manifest.txt" || true
fi

if [[ "$MANIFEST_EXTENSIONS" == "true" && -d "$OPENCLAW_HOME/extensions" ]]; then
  mkdir -p "$SNAP_DIR/extensions"
  ls -1 "$OPENCLAW_HOME/extensions" | sort > "$SNAP_DIR/extensions/_manifest.txt" || true
fi

if [[ "$MANIFEST_VENDOR_HEADS" == "true" && -d "$OPENCLAW_HOME/vendor" ]]; then
  mkdir -p "$SNAP_DIR/vendor"
  : > "$SNAP_DIR/vendor/_heads.txt"
  for d in "$OPENCLAW_HOME/vendor"/*; do
    [[ -d "$d/.git" ]] || continue
    name="$(basename "$d")"
    head="$(git -C "$d" rev-parse --short HEAD 2>/dev/null || echo "-")"
    subj="$(git -C "$d" log -1 --pretty=%s 2>/dev/null || echo "-")"
    echo "$name $head $subj" >> "$SNAP_DIR/vendor/_heads.txt"
  done
fi

# De-noise snapshots by stripping volatile runtime fields per config.noise_filters.
# Filter keys are JSON paths relative to the file. For cron/jobs.json the fields
# apply to each element of .jobs[].
apply_noise_filter() {
  local rel="$1"      # path relative to snapshot root (e.g. "cron/jobs.json")
  local abs="$SNAP_DIR/$rel"
  [[ -f "$abs" ]] || return 0

  # Collect fields for this path
  local fields=()
  while IFS= read -r f; do
    [[ -n "$f" ]] && fields+=("$f")
  done < <(jq -r --arg p "$rel" '.noise_filters[$p][]? // empty' "$CONFIG")

  [[ ${#fields[@]} -eq 0 ]] && return 0

  # Build a single `del(.a, .b, ...)` expression
  local del_expr="del("
  local first=1
  for f in "${fields[@]}"; do
    [[ $first -eq 1 ]] && first=0 || del_expr+=", "
    del_expr+=".$f"
  done
  del_expr+=")"

  # cron/jobs.json is structured as {jobs: [...]}, so apply del inside map.
  # For flat JSON, the agent can add a different entry; we special-case here.
  local filter
  case "$rel" in
    cron/jobs.json) filter=".jobs |= map($del_expr)" ;;
    *)              filter="$del_expr" ;;
  esac

  if ! jq "$filter" "$abs" > "$abs.tmp"; then
    log "warn: jq denoise failed for $rel"
    rm -f "$abs.tmp"
    return 0
  fi
  mv "$abs.tmp" "$abs"
}

while IFS= read -r rel; do
  [[ -n "$rel" ]] && apply_noise_filter "$rel"
done < <(jq -r '.noise_filters // {} | keys[]?' "$CONFIG")

# Commit (allow empty — lets us mark the day even if nothing changed)
cd "$SNAP_DIR"
git add -A
if git diff --cached --quiet; then
  log "no changes since last snapshot"
  git commit --allow-empty -m "snapshot $TODAY (no changes)" -q
else
  git commit -m "snapshot $TODAY" -q
  log "committed snapshot for $TODAY"
fi

log "snapshot done"
