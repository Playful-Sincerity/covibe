# CoVibe Coordination Protocol

This rule activates only when a CoVibe session is running. Check by reading `/tmp/.covibe-active`. If the file doesn't exist, ignore everything below.

## Activation Check

At the start of each conversation turn where you haven't checked recently:
```bash
cat /tmp/.covibe-active 2>/dev/null
```
If it returns content, parse `repo=` and `user=` values. You are in a CoVibe session.

## Identity

You are `<user>` from the active marker. All `.covibe/` files you create use this identity. You may ONLY write to your own session file (`.covibe/sessions/<user>.md`). Never edit another user's session file or modify their job assignments.

## Before Major Work

Before starting any substantial task (not simple lookups or quick edits):

1. Pull latest: `cd <repo> && git pull --rebase 2>/dev/null || true`
2. Read other session files in `.covibe/sessions/` that updated since your last check
3. Check `.covibe/messages/` for new messages
4. If another session's current work overlaps with what you're about to do, flag it to the user before proceeding

## After Major Actions

After completing a task, making a significant decision, or discovering something:

1. Update your session file at `.covibe/sessions/<user>.md`:
   - `last_updated` timestamp
   - `Current Task` section (replace, don't append)
   - `Recent Actions` (append the latest, keep last ~10)
   - `Discoveries` if something is relevant to other sessions
   - `Files Touched` with paths
2. If a discovery matters to others right now, write a message file at `.covibe/messages/`

## Conflict Detection

Watch for and flag:
- Another session editing the same files you're touching
- Job dependency changes that affect your current work
- Blockers resolved that unblock other sessions

## Session File Hygiene

Your session file is a real-time snapshot, not a growing log. Replace the `Current Task` section with each new task. Keep `Recent Actions` trimmed to the last ~10 entries. The file should be useful to someone scanning it in 5 seconds.

## Auto-Sync

The `covibe-sync.sh` Stop hook handles committing and pushing `.covibe/` changes after each response. You don't need to manually commit coordination files unless the hook isn't running (e.g., during `start` and `end` commands where you commit explicitly).
