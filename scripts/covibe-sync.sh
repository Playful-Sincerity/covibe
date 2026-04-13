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
COVIBE_USER=$(grep '^user=' "$ACTIVE_FILE" 2>/dev/null | cut -d= -f2-)

if [ -z "$REPO" ] || [ -z "$COVIBE_USER" ]; then
  exit 0
fi

if [ ! -d "$REPO/.covibe" ]; then
  exit 0
fi

SESSION_FILE="$REPO/.covibe/sessions/${COVIBE_USER}.md"
NOW_EPOCH=$(date +%s)
STALE_MINUTES=5
NUDGE_STATE="/tmp/.covibe-nudge"
SYNC_FAILED=false

# Detect the repo's default branch
default_branch() {
  local ref
  ref=$(git -C "$REPO" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|^refs/remotes/origin/||')
  if [ -n "$ref" ]; then
    echo "$ref"
    return
  fi
  for b in main master; do
    if git -C "$REPO" show-ref --verify --quiet "refs/heads/$b" 2>/dev/null; then
      echo "$b"
      return
    fi
  done
  echo "main"
}

# Cross-platform file modification time (epoch seconds)
file_mod_epoch() {
  stat -c %Y "$1" 2>/dev/null && return  # GNU/Linux
  stat -f %m "$1" 2>/dev/null && return  # macOS/BSD
  echo 0
}

# Report sync errors visibly so the user knows
sync_error() {
  echo "-- CoVibe Sync ERROR --"
  echo "$1"
  if [ -n "$2" ]; then
    echo "Fix: $2"
  fi
  echo "-- End CoVibe Sync ERROR --"
  SYNC_FAILED=true
}

DEFAULT_BRANCH=$(default_branch)

# Always push .covibe/ to the default branch, even when on a feature branch.
# Code stays on the feature branch; coordination stays on the default branch.
cd "$REPO" || exit 0
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

if git status --porcelain .covibe/ 2>/dev/null | grep -q '.'; then
  if [ "$CURRENT_BRANCH" = "$DEFAULT_BRANCH" ]; then
    # Already on default branch — pull, commit, push
    if ! git pull --rebase --quiet 2>/dev/null; then
      # Rebase conflict — abort and notify
      git rebase --abort --quiet 2>/dev/null || true
      sync_error "Rebase conflict on $DEFAULT_BRANCH while pulling." \
        "cd \"$REPO\" && git pull --rebase  (resolve conflicts manually)"
    fi
    if [ "$SYNC_FAILED" = false ]; then
      git add .covibe/ 2>/dev/null
      git commit -m "covibe: ${COVIBE_USER} sync" --quiet 2>/dev/null || true
      if ! git push --quiet 2>/dev/null; then
        sync_error "Push to $DEFAULT_BRANCH failed (likely a concurrent push)." \
          "cd \"$REPO\" && git pull --rebase && git push"
      fi
    fi
  else
    # On a feature branch — stash only if needed, switch to default, commit .covibe/, switch back
    NEEDS_STASH=false
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
      NEEDS_STASH=true
    fi
    if [ "$NEEDS_STASH" = true ]; then
      if ! git stash --quiet --include-untracked 2>/dev/null; then
        sync_error "Failed to stash changes before switching to $DEFAULT_BRANCH." \
          "cd \"$REPO\" && git stash  (check for conflicts)"
        exit 0
      fi
    fi
    if ! git checkout "$DEFAULT_BRANCH" --quiet 2>/dev/null; then
      # Failed to switch — restore stash and bail
      if [ "$NEEDS_STASH" = true ]; then
        git stash pop --quiet 2>/dev/null || true
      fi
      sync_error "Could not switch to $DEFAULT_BRANCH." \
        "cd \"$REPO\" && git checkout $DEFAULT_BRANCH"
      exit 0
    fi
    if ! git pull --rebase --quiet 2>/dev/null; then
      git rebase --abort --quiet 2>/dev/null || true
      sync_error "Rebase conflict on $DEFAULT_BRANCH." \
        "cd \"$REPO\" && git checkout $DEFAULT_BRANCH && git pull --rebase"
      # Switch back even on failure
      git checkout "$CURRENT_BRANCH" --quiet 2>/dev/null || true
      if [ "$NEEDS_STASH" = true ]; then
        git stash pop --quiet 2>/dev/null || sync_error "Stash pop also failed." \
          "cd \"$REPO\" && git stash pop  (resolve conflicts)"
      fi
      exit 0
    fi
    # Restore .covibe/ changes from the feature branch
    git checkout "$CURRENT_BRANCH" -- .covibe/ 2>/dev/null || true
    git add .covibe/ 2>/dev/null
    if ! git diff --cached --quiet .covibe/ 2>/dev/null; then
      git commit -m "covibe: ${COVIBE_USER} sync" --quiet 2>/dev/null || true
      if ! git push --quiet 2>/dev/null; then
        sync_error "Push to $DEFAULT_BRANCH failed from feature branch." \
          "cd \"$REPO\" && git checkout $DEFAULT_BRANCH && git push"
      fi
    fi
    # Switch back to feature branch
    if ! git checkout "$CURRENT_BRANCH" --quiet 2>/dev/null; then
      sync_error "Could not return to branch '$CURRENT_BRANCH'." \
        "cd \"$REPO\" && git branch -a  (check if branch still exists)"
    fi
    if [ "$NEEDS_STASH" = true ]; then
      if ! git stash pop --quiet 2>/dev/null; then
        sync_error "Stash pop failed — your working changes are saved in git stash." \
          "cd \"$REPO\" && git stash list  (then git stash pop or git stash drop)"
      fi
    fi
  fi
  if [ "$SYNC_FAILED" = false ]; then
    hook_log "covibe-sync" "pushed .covibe/ to $DEFAULT_BRANCH" 2>/dev/null || true
  fi
else
  # No .covibe/ changes — just pull latest for visibility
  if [ "$CURRENT_BRANCH" = "$DEFAULT_BRANCH" ]; then
    git pull --rebase --quiet 2>/dev/null || true
  fi
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
  MOD_EPOCH=$(file_mod_epoch "$SESSION_FILE")
  ELAPSED=$(( NOW_EPOCH - MOD_EPOCH ))
  if [ "$ELAPSED" -gt $(( STALE_MINUTES * 60 )) ]; then
    echo "-- CoVibe Sync --"
    echo "Session file stale (${STALE_MINUTES}+ min). Update .covibe/sessions/${COVIBE_USER}.md"
    echo "-- End CoVibe Sync --"
    echo "$NOW_EPOCH" > "$NUDGE_STATE"
  fi
fi

exit 0
