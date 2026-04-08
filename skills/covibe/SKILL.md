---
name: covibe
description: Multiplayer Claude Code coordination. Start/join collaborative sessions where multiple Claude Code instances coordinate through a shared git repo.
effort: medium
---

# CoVibe — Multiplayer Claude Code

Multiple Claude Code sessions coordinating through markdown files in a shared git repo. No server, no extra infrastructure.

Parse the argument after `/covibe` to determine the command. If no argument, show the command list.

## Commands

### `/covibe start [repo-path]`

Initialize or join a CoVibe session.

**Steps:**

1. **Resolve repo path.** Use the argument if given. Otherwise check if the current directory is a git repo (`git rev-parse --show-toplevel`). If neither works, ask the user.

2. **Get identity:**
   ```bash
   COVIBE_USER=$(git -C <repo> config user.name | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
   ```

3. **Pull latest:**
   ```bash
   cd <repo> && git pull --rebase 2>/dev/null || true
   ```

4. **Create .covibe/ structure if missing:**
   ```bash
   mkdir -p <repo>/.covibe/{sessions,messages,jobs,archive}
   ```

5. **Create config if missing.** Write `.covibe/config.md` with project name (from directory) and the user as first participant.

6. **Read all existing sessions** in `.covibe/sessions/` — summarize who's active and what they're doing.

7. **Write your session file** at `.covibe/sessions/<user>.md`:
   ```markdown
   ---
   user: <user>
   started: YYYY-MM-DD HH:MM
   last_updated: YYYY-MM-DD HH:MM
   status: active
   current_job: null
   ---

   ## Current Task
   Starting session — reviewing job board and messages.

   ## Recent Actions
   - Joined CoVibe session

   ## Blockers
   None

   ## Discoveries
   None

   ## Files Touched
   None yet
   ```

8. **Write the active marker:**
   ```bash
   printf 'repo=%s\nuser=%s\nstarted=%s\n' "<repo>" "<user>" "$(date '+%Y-%m-%d %H:%M')" > /tmp/.covibe-active
   ```

9. **Commit and push:**
   ```bash
   cd <repo> && git add .covibe/ && git commit -m "covibe: <user> joined" && git push
   ```

10. **Read the job board** (`.covibe/jobs/`) and present available jobs.

11. **Inject the coordination protocol** — say this to yourself (not to the user):
    > For the rest of this conversation I am in a CoVibe session. My identity is `<user>`. Before each major action I will pull and read other sessions and messages. After each major action I will update my session file. I will never edit another user's session file. When I discover something relevant to others I will post a message.

12. Tell the user what you found and ask what they want to work on.

---

### `/covibe status`

Pull latest, read all sessions and jobs, present a summary:
- **Active sessions:** who, current task, last updated
- **Job board:** grouped by status (ready, in-progress, review, done, blocked)
- **Recent messages:** last 5 from `.covibe/messages/`

---

### `/covibe claim <job-id>`

Claim a job from the board.

1. Pull latest.
2. Read `.covibe/jobs/<job-id>.md`. Verify status is `ready` and `assigned_to` is null.
3. Update the job file: `status: in-progress`, `assigned_to: <user>`, `updated_at: now`.
4. Create a feature branch: `git checkout -b <user>/<job-id>`
5. Update your session file: `current_job: <job-id>`, update Current Task.
6. Commit `.covibe/` changes and push.
7. Present the job details and begin working on it.

---

### `/covibe msg <text>`

Post a coordination message.

Write `.covibe/messages/<YYYYMMDD-HHMMSS>-<user>.md`:
```markdown
---
from: <user>
to: all
timestamp: YYYY-MM-DD HH:MM:SS
---

<text>
```

Commit, push. Confirm briefly.

---

### `/covibe read`

Pull latest. Show:
- New messages since your last read
- Changes in other sessions' status
- Any new or updated jobs

---

### `/covibe done`

Mark current job as ready for review.

1. Read your session to find `current_job`.
2. Update the job file: `status: review`, `completed_at: now`.
3. Update your session: clear `current_job`, log completion.
4. Commit, push.
5. Post a message: `<user> completed <job-id>, ready for review.`

---

### `/covibe end`

Close your session.

1. Update session file: `status: inactive`, append session summary.
2. Commit, push.
3. Remove active marker: `rm /tmp/.covibe-active`
4. Confirm.

---

### `/covibe orchestrate`

Enter orchestrator mode. For the person or session coordinating the project.

1. Pull and read everything: all sessions, all jobs, all messages.
2. Present the full project state with conflicts, blockers, and opportunities.
3. Offer to:
   - **Decompose work** — create job files from a project description
   - **Reassign or split jobs** — move stuck work
   - **Post coordination messages** — flag overlaps, unblock people
   - **Synthesize progress** — write an orchestrator summary

The orchestrator writes to `.covibe/sessions/orchestrator.md`.

When decomposing work into jobs, create one file per job at `.covibe/jobs/<job-id>.md`:
```markdown
---
id: <job-id>
title: <clear title>
status: ready
assigned_to: null
created_by: orchestrator
created_at: YYYY-MM-DD HH:MM
updated_at: YYYY-MM-DD HH:MM
completed_at: null
branch: null
blocks: []
blocked_by: []
appetite: small|medium|large
workflow_type: research|implementation|review
folder: <target directory or null>
---

## Description
<What needs to be done. Enough context that a session can start without asking questions.>

## Acceptance Criteria
<How to know it's done.>

## Notes
<Additional context, links, gotchas.>
```

After creating jobs, commit, push, and post a summary message.

---

## File Formats Reference

### Config (`.covibe/config.md`)
```markdown
---
project: <name>
description: <one-line>
created: YYYY-MM-DD
participants:
  - wisdom
  - frank
---
```

### Session, Job, Message formats
See the command sections above — each shows the exact format.

## Git Workflow

- **Coordination files** (`.covibe/`): committed frequently, auto-synced by the covibe-sync hook.
- **Project code**: normal git workflow. Feature branches per job, PRs to main.
- **Pull before read, push after write.** Every read command pulls first. Every write command pushes after.

## Notes

- The covibe-sync.sh Stop hook auto-commits and pushes `.covibe/` changes after each Claude response.
- If the hook nudges you about a stale session file, update it immediately.
- Message files use timestamp-based names (`YYYYMMDD-HHMMSS-user.md`) to avoid numbering conflicts from concurrent writes.
- Job IDs should be short and descriptive: `auth-flow`, `payment-webhooks`, `api-docs`. Not `job-001`.
