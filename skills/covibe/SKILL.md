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
- **Job board:** If phased, show the phase structure with status per phase (e.g., "Phase 1: 3/5 done, 2 in-progress"). If flat, group by status (ready, in-progress, review, done, blocked). Always highlight which jobs are claimable now (ready + dependencies met).
- **Recent messages:** last 5 from `.covibe/messages/`

---

### `/covibe claim <job-id>`

Claim a job from the board. **The claim MUST be pushed before any other action.**

1. Pull latest.
2. Find the job file — search `.covibe/jobs/` recursively for a file whose `id` frontmatter matches `<job-id>` (handles both flat and phased structures).
3. Verify `status: ready` and `assigned_to: null`. Also check that all jobs listed in `Dependencies` or `blocked_by` have `status: done`.
4. Update the job file: `status: in-progress`, `assigned_to: <user>`, `updated_at: now`.
5. Update your session file: `current_job: <job-id>`, update Current Task.
6. **ATOMIC PUSH TO MAIN — immediately after steps 4-5, commit and push `.covibe/` to main in a SINGLE Bash call. No other tool calls between editing the files and pushing.** `.covibe/` changes always live on main so all sessions can see them regardless of what branch they're on.
   ```bash
   cd <repo> && git add .covibe/ && git commit -m "covibe: <user> claimed <job-id>" && git push
   ```
   If push fails (conflict), pull and re-check — if someone else claimed it first, tell the user and suggest another job.
7. **Then** create a feature branch for the actual code work: `git checkout -b <user>/<job-id>`. Code goes on this branch. `.covibe/` syncs are handled by the covibe-sync hook which always pushes `.covibe/` to main even from a feature branch.
8. Present the full job brief (context, task, acceptance criteria) and begin working on it.

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

#### Decomposing Work — Phased Job Structure

When decomposing work, create a phased directory structure under `.covibe/jobs/`. This uses the multi-session decomposition format so jobs are both a coordination tool and self-contained session briefs.

**Directory structure:**
```
.covibe/jobs/
├── README.md                                  ← Phase map + visual dependency graph
├── phase-1-<name>/
│   ├── README.md                              ← Subphase dependency graph + launch order
│   ├── subphase-A-PARALLEL-no-deps/
│   │   ├── 01-<job-name>.md
│   │   └── 02-<job-name>.md
│   └── subphase-B-CRITICAL-needs-A/
│       └── 01-<job-name>.md
├── phase-2-<name>/
│   └── ...
```

**Directory naming conventions:**
- Top-level phases: `phase-{N}-{name}` — numbers for ordering
- Subphases: `subphase-{LETTER}-{TYPE}-{dependency}`
  - TYPE: `PARALLEL` (can run alongside others) or `CRITICAL` (must complete before next)
  - Dependency: `no-deps`, `needs-setup`, `needs-subphase-X`

**Each job file is a session brief with CoVibe frontmatter:**
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
appetite: small|medium|large
workflow_type: research|implementation|review
folder: <target directory or null>
---

# Session Brief: <TITLE>

**Dependencies:** <None — can start immediately | Needs phase-1/subphase-A to complete>
**Can run parallel with:** <Other jobs that can run simultaneously>
**Feeds into:** <What downstream work uses this output>

## Context
<What this project is, where it lives, enough for a cold start>

Read these files first:
- <CLAUDE.md path>
- <Key files needed>

## Task
<Clear, specific instructions. Enough detail to execute without asking questions.>

## Acceptance Criteria
<How to know it's done. Specific, measurable.>

## Notes
<Additional context, links, gotchas.>
```

**README at each level:**
- Top-level `jobs/README.md`: full phase map with ASCII dependency graph, overall scope
- Each phase `README.md`: subphase launch order, which subphases are parallel vs critical

**For simple projects** (3-5 jobs, no phases needed): use flat files directly in `.covibe/jobs/` with the same session-brief format. Only create the phased structure when there are genuine phases with dependencies.

After creating the structure, commit, push, and post a summary message listing all jobs and which are ready to claim immediately.

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
