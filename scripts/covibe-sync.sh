#!/usr/bin/env bash
# covibe-sync.sh — Stop hook: auto-sync .covibe/ and nudge on stale sessions.
# Only fires when a CoVibe session is active (/tmp/.covibe-active exists).
# Always exits 0 (informational, never blocks).

source "$HOME/.claude/scripts/hook-log.sh" 2>/dev/null || true

ACTIVE_FILE="/tmp/.covibe-active"

# Exit early if no active session
if [ ! -f "$ACTIVE_FILE" ]; then
  exit 0
fi

REPO=$(grep '^repo=' "$ACTIVE_FILE" 2>/dev/null | cut -d= -f2-)
USER=$(grep '^user=' "$ACTIVE_FILE" 2>/dev/null | cut -d= -f2-)

if [ -z "$REPO" ] || [ -z "$USER" ]; then
  exit 0
fi

if [ ! -d "$REPO/.covibe" ]; then
  exit 0
fi

SESSION_FILE="$REPO/.covibe/sessions/${USER}.md"
NOW_EPOCH=$(date +%s)
STALE_MINUTES=5
NUDGE_STATE="/tmp/.covibe-nudge"

# Pull latest (quiet, don't block on conflicts)
cd "$REPO" && git pull --rebase --quiet 2>/dev/null || true

# Commit and push any .covibe/ changes
if cd "$REPO" && git status --porcelain .covibe/ 2>/dev/null | grep -q '.'; then
  git add .covibe/ 2>/dev/null
  git commit -m "covibe: ${USER} sync" --quiet 2>/dev/null || true
  git push --quiet 2>/dev/null || true
  hook_log "covibe-sync" "pushed .covibe/ changes" 2>/dev/null || true
fi

# Nudge if session file is stale
if [ -f "$NUDGE_STATE" ]; then
  LAST_NUDGE=$(cat "$NUDGE_STATE" 2>/dev/null || echo 0)
  ELAPSED=$(( NOW_EPOCH - LAST_NUDGE ))
  if [ "$ELAPSED" -lt $(( STALE_MINUTES * 60 )) ]; then
    exit 0
  fi
fi

if [ -f "$SESSION_FILE" ]; then
  MOD_EPOCH=$(stat -f %m "$SESSION_FILE" 2>/dev/null || echo 0)
  ELAPSED=$(( NOW_EPOCH - MOD_EPOCH ))
  if [ "$ELAPSED" -gt $(( STALE_MINUTES * 60 )) ]; then
    echo "-- CoVibe Sync --"
    echo "Session file stale (${STALE_MINUTES}+ min). Update .covibe/sessions/${USER}.md"
    echo "-- End CoVibe Sync --"
    echo "$NOW_EPOCH" > "$NUDGE_STATE"
  fi
fi

exit 0
