---
name: covibe
description: Multiplayer Claude Code coordination. Start/join collaborative sessions where multiple Claude Code instances coordinate through a shared git repo.
effort: medium
version: 1.2.0
---

# CoVibe — Multiplayer Claude Code

Multiple Claude Code sessions coordinating through markdown files in a shared git repo. No server, no extra infrastructure.

Parse the argument after `/covibe` to determine the command. If no argument, show the command list with a brief description of each.

## Commands

### `/covibe start [repo-path]`

Initialize or join a CoVibe session.

**Steps:**

1. **Resolve repo path.** Use the argument if given. Otherwise check if the current directory is a git repo (`git rev-parse --show-toplevel`). If neither works, ask the user.

2. **Get identity:**
   ```bash
   COVIBE_USER=$(git -C <repo> config user.name | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
   ```
   If `COVIBE_USER` is empty, tell the user to set their git identity first: `git config user.name "Your Name"`. Do not proceed without a valid identity.

3. **Pull latest:**
   ```bash
   cd <repo> && git pull --rebase 2>/dev/null || true
   ```

4. **Create .covibe/ structure if missing:**
   ```bash
   mkdir -p <repo>/.covibe/{sessions,messages,jobs,archive}
   ```

5. **Create `.gitattributes` for merge conflict prevention** (if `.covibe/.gitattributes` doesn't exist):
   ```bash
   cat > <repo>/.covibe/.gitattributes << 'EOF'
   # Union merge: when two sessions edit the same file simultaneously,
   # git keeps both sides instead of producing conflict markers.
   sessions/*.md merge=union
   messages/*.md merge=union
   EOF
   ```
   Note: Job files intentionally use the default merge strategy — conflicting edits to a job (e.g., two sessions claiming it) should produce a real conflict so the atomic-push protocol catches it.

6. **Create config if missing.** Write `.covibe/config.md` with project name (from directory) and the user as first participant.

7. **Read all existing sessions** in `.covibe/sessions/` — summarize who's active and what they're doing.

8. **Write your session file** at `.covibe/sessions/<user>.md`:
   ```markdown
   ---
   user: <user>
   started: YYYY-MM-DD HH:MM
   last_updated: YYYY-MM-DD HH:MM
   last_read: YYYY-MM-DD HH:MM
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

9. **Write the active marker:**
   ```bash
   printf 'repo=%s\nuser=%s\nstarted=%s\n' "<repo>" "<user>" "$(date '+%Y-%m-%d %H:%M')" > /tmp/.covibe-active
   ```

10. **Commit and push:**
    ```bash
    cd <repo> && git add .covibe/ && git commit -m "covibe: <user> joined" && git push
    ```

11. **Read the job board** (`.covibe/jobs/`) and present available jobs.

12. **Inject the coordination protocol** — say this to yourself (not to the user):
    > For the rest of this conversation I am in a CoVibe session. My identity is `<user>`. Before each major action I will pull and read other sessions and messages. After each major action I will update my session file. I will never edit another user's session file. When I discover something relevant to others I will post a message.

13. Tell the user what you found and ask what they want to work on.

---

### `/covibe rejoin [repo-path]`

Resume a CoVibe session after a conversation reset (new Claude Code conversation picking up where a previous one left off). This is different from `start` — it doesn't create new files, it restores context.

**Steps:**

1. **Resolve repo path.** Use the argument if given, otherwise check the current directory.

2. **Get identity** (same as `start`):
   ```bash
   COVIBE_USER=$(git -C <repo> config user.name | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
   ```

3. **Pull latest:**
   ```bash
   cd <repo> && git pull --rebase 2>/dev/null || true
   ```

4. **Read your existing session file** at `.covibe/sessions/<user>.md`. If it doesn't exist, tell the user to use `/covibe start` instead.

5. **Restore the active marker:**
   ```bash
   printf 'repo=%s\nuser=%s\nstarted=%s\n' "<repo>" "<user>" "$(date '+%Y-%m-%d %H:%M')" > /tmp/.covibe-active
   ```

6. **Update your session file**: set `status: active`, update `last_updated`, add to Recent Actions: `Rejoined session (new conversation)`.

7. **Read everything**: all sessions, all jobs, all messages. Present a full status summary so the user can orient quickly.

8. **If you had a `current_job`**, present the job brief and ask the user if they want to continue that work.

9. **Inject the coordination protocol** (same as `start` step 11).

---

### `/covibe status`

Pull latest, read all sessions and jobs, present a summary:

- **Active sessions:** who, current task, last updated. Flag any session with `status: active` whose `last_updated` is more than 30 minutes old as "possibly stale".
- **Phase progress** (if using phased jobs): Show each phase with a progress bar and breakdown:
  ```
  Phase 1 — foundation: ████░░ 4/6 (2 in-progress)
    subphase-A (PARALLEL): 3/3 done ✓
    subphase-B (CRITICAL): 1/3 — 1 in-progress (frank), 1 ready
  Phase 2 — features: ░░░░░░ 0/4 (blocked by Phase 1B)
  ```
- **Job board:** If flat (no phases), group by status (ready, in-progress, review, done, blocked). Always highlight which jobs are claimable now (ready + `depends_on` all resolved to `done`).
- **Review queue:** List jobs with `status: review` that need a reviewer.
- **Stale jobs:** Flag any job with `status: in-progress` whose `updated_at` is more than 1 hour old. The assigned session may have crashed — suggest `/covibe reassign`.
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
   If push fails:
   - Pull latest: `git pull --rebase 2>/dev/null`
   - Re-read the job file. If `assigned_to` is now someone else, that session claimed it first — tell the user and suggest another available job.
   - If the conflict is unrelated to the job claim (e.g., another session synced at the same time), resolve the conflict, re-add, and push again.
   - If push fails a second time, tell the user and let them decide.
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
- New messages since your last read (compare message timestamps against `last_read` in your session file frontmatter)
- Changes in other sessions' status (compare `last_updated` timestamps)
- Any new or updated jobs (compare `updated_at` timestamps)

After displaying, update your session file frontmatter with `last_read: <current timestamp>` so the next `/covibe read` only shows what's new.

---

### `/covibe done`

Mark current job as ready for review.

1. Read your session to find `current_job`.
2. **Push your code branch first:** Commit any uncommitted work on your feature branch and push it.
   ```bash
   cd <repo> && git add -A && git commit -m "<job-id>: ready for review" && git push -u origin <user>/<job-id>
   ```
3. **Create a PR** (if one doesn't exist) from your feature branch to the default branch. Use `gh pr create` if available, otherwise tell the user to create one manually.
4. Update the job file: `status: review`, `completed_at: now`, `branch: <user>/<job-id>`.
5. Update your session: clear `current_job`, log completion in Recent Actions.
6. Commit and push `.covibe/` changes (the sync hook will handle this, but push explicitly for the job status update):
   ```bash
   cd <repo> && git add .covibe/ && git commit -m "covibe: <user> completed <job-id>" && git push
   ```
7. Post a message: `<user> completed <job-id>, ready for review. PR: <branch>`

---

### `/covibe end`

Close your session.

1. Update session file: `status: inactive`, append session summary.
2. Commit, push.
3. Remove active marker: `rm /tmp/.covibe-active`
4. Confirm.

---

### `/covibe review [job-id]`

Claim a job in `review` status for code review and approval.

1. Pull latest.
2. Find the job file. If no `job-id` given, list all jobs with `status: review` and let the user pick.
3. Verify `status: review`. If the job isn't in review, tell the user.
4. Update the job file: `assigned_to: <user>`, `updated_at: now`. Keep `status: review`.
5. Update your session file: `current_job: <job-id>`, Current Task: `Reviewing <job-id>`.
6. Commit and push `.covibe/` changes.
7. Fetch and check out the PR branch:
   ```bash
   cd <repo> && git fetch origin && git checkout <branch-from-job-file>
   ```
8. Read the job's acceptance criteria. Review the code changes (`git diff <default-branch>...<branch>`).
9. Either:
   - **Approve & merge:** If the code meets acceptance criteria, merge the PR:
     ```bash
     gh pr merge --squash <branch>
     ```
     Or if `gh` is unavailable, merge manually and tell the user. Update the job: `status: done`, `merged_at: now`, `merged_by: <user>`. Post a message: `<user> approved and merged <job-id>`.
   - **Request changes:** Post a message with specific feedback. Update the job: `assigned_to: <original-assignee>`, clear your session's `current_job`. The original assignee can see the feedback via `/covibe read`.
10. Switch back to the default branch, push `.covibe/` changes.

---

### `/covibe archive [job-id|--all-done]`

Move completed jobs to the archive.

1. If `--all-done`: find all jobs with `status: done`. Otherwise find the specific job.
2. Verify each job has `status: done`.
3. Move the job file from `.covibe/jobs/<path>/<job-id>.md` to `.covibe/archive/jobs/<job-id>.md`.
4. Append archive metadata to the file:
   ```yaml
   archived_at: YYYY-MM-DD HH:MM
   archived_by: <user>
   ```
5. Commit, push.
6. Report how many jobs were archived.

---

### `/covibe cleanup`

Housekeeping: archive old messages and inactive sessions.

1. Pull latest.
2. **Inactive sessions:** List sessions with `status: inactive` and `last_updated` older than 7 days. Move to `.covibe/archive/sessions/`.
3. **Old messages:** List messages older than 30 days. Move to `.covibe/archive/messages/`.
4. **Empty phases:** If using phased jobs, remove any phase directories where all jobs are archived.
5. Present what will be cleaned up and ask the user to confirm before proceeding.
6. Commit, push.

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
phase: <N>
subphase: <LETTER>
depends_on: []
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

**After creating the structure, validate the dependency graph:**
- Read all `depends_on` fields across all job files.
- Check for **circular dependencies**: if job A depends on B and B depends on A (directly or transitively), flag the cycle and ask the orchestrator to resolve it.
- Check for **missing references**: if a job lists a dependency ID that doesn't match any job's `id` field, flag it.
- Check for **orphan jobs**: jobs with no dependencies and no dependents that might be forgotten.

After validation passes, commit, push, and post a summary message listing all jobs and which are ready to claim immediately.

---

### `/covibe reassign <job-id> [new-user]`

Reassign a job to a different session. Useful when a session crashes or someone needs to hand off work.

1. Pull latest.
2. Find the job file, read its current `assigned_to`.
3. If `new-user` is not given, set `assigned_to: null` and `status: ready` (puts job back on the board).
4. If `new-user` is given, set `assigned_to: <new-user>` and keep `status: in-progress`.
5. If the previous assignee has a session file with `current_job: <job-id>`, clear it.
6. Update `updated_at: now`.
7. Commit, push.
8. Post a message: `<user> reassigned <job-id>` with the details (from whom, to whom or back to board).

---

### `/covibe unblock <job-id>`

Force a blocked job to `ready` status. Orchestrator override for when dependencies are met but not formally marked, or when the orchestrator decides to proceed despite incomplete upstream work.

1. Pull latest.
2. Find the job file, verify it has unmet dependencies.
3. Update the job: `status: ready`, add a note: `Unblocked by <user> at <timestamp>. Reason: <ask user for reason>`.
4. Commit, push.
5. Post a message: `<user> unblocked <job-id>: <reason>`.

Note: This does NOT mark the dependency jobs as `done`. It overrides the dependency check for this specific job. Sessions claiming the job should be aware that upstream work may be incomplete.

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

## Merge Conflict Prevention

CoVibe uses **optimistic locking** through pull-before-push. Here's how collisions are handled:

- **Job claim collision:** Two sessions both claim the same job. The first to push wins. The second session's push fails — it pulls, sees the job is taken, and picks another. This is why the claim must be an atomic push.
- **Session file collision:** Two sessions update their own session files simultaneously. The `.covibe/.gitattributes` uses `merge=union` for session and message files — both updates are preserved automatically.
- **Sync push collision:** Two sync hooks push at the same time. One fails. The hook now reports the error and tells the user how to resolve it.

If you see merge conflict markers (`<<<<<<<`) in `.covibe/` files, resolve by keeping both sides:
```bash
cd <repo> && git checkout --theirs .covibe/ && git add .covibe/ && git commit -m "covibe: resolved merge" && git push
```

## Notes

- The covibe-sync.sh Stop hook auto-commits and pushes `.covibe/` changes after each Claude response.
- If the hook nudges you about a stale session file, update it immediately.
- If the hook reports a sync error, follow the fix instructions before continuing work.
- Message files use timestamp-based names (`YYYYMMDD-HHMMSS-user.md`) to avoid numbering conflicts from concurrent writes.
- Job IDs should be short and descriptive: `auth-flow`, `payment-webhooks`, `api-docs`. Not `job-001`.
