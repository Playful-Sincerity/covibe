# CoVibe — Multiplayer Claude Code

Multiple Claude Code sessions coordinating through a shared git repo. No server, no extra infrastructure.

An orchestrator decomposes work into jobs. Individual sessions browse the job board, claim work, execute it, and push results. Reviewers pick up completed work, approve PRs, and merge. Everything lives in git.

## How It Works

```
Orchestrator decomposes project into jobs
    |
Sessions browse .covibe/jobs/, claim one
    |
Working on a feature branch
    |
Done → Review picked up by another session
    |
Approved → Merged to main → Archived
```

Each participant runs their own Claude Code with their own subscription. Sessions coordinate through markdown files in a `.covibe/` directory inside the shared repo, auto-synced by a git hook.

## Install

### As a Claude Code plugin (recommended)

Add this to your `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "playful-sincerity": {
      "source": "github",
      "repo": "Playful-Sincerity/covibe"
    }
  },
  "enabledPlugins": {
    "covibe@playful-sincerity": true
  }
}
```

The skill, coordination guidance, and sync hook all install automatically. The hook fires after each Claude response to auto-commit and push `.covibe/` changes.

### Manual install

```bash
git clone https://github.com/Playful-Sincerity/covibe.git
cd covibe
./install.sh
```

The install script copies the skill, coordination skill, and hook script. It will check if the Stop hook is registered in `settings.json` and tell you what to add if it isn't.

## Commands

| Command | What It Does |
|---------|-------------|
| `/covibe start [repo-path]` | Initialize or join a session |
| `/covibe rejoin [repo-path]` | Resume after a conversation reset |
| `/covibe status` | See all sessions, jobs, and phase progress |
| `/covibe claim <job-id>` | Claim a job from the board |
| `/covibe msg <text>` | Post a coordination message |
| `/covibe read` | Read new messages and updates |
| `/covibe done` | Mark your job as ready for review, create PR |
| `/covibe review [job-id]` | Pick up a job for code review, approve or request changes |
| `/covibe end` | Close your session |
| `/covibe orchestrate` | Decompose work, coordinate, track progress |
| `/covibe reassign <job-id> [user]` | Reassign a job (or put it back on the board) |
| `/covibe unblock <job-id>` | Force a blocked job to ready |
| `/covibe archive [job-id\|--all-done]` | Move completed jobs to archive |
| `/covibe cleanup` | Archive old messages and inactive sessions |

## Repo Structure (during a session)

```
your-project/
├── .covibe/
│   ├── .gitattributes     ← merge conflict prevention
│   ├── config.md          ← project name, participants
│   ├── sessions/
│   │   ├── wisdom.md      ← auto-updated status
│   │   └── frank.md       ← auto-updated status
│   ├── jobs/
│   │   ├── README.md      ← phase map (if phased)
│   │   ├── auth-flow.md   ← job with frontmatter
│   │   └── api-docs.md
│   ├── messages/
│   │   └── 20260408-153000-wisdom.md
│   └── archive/
│       ├── jobs/           ← completed jobs
│       ├── sessions/       ← ended sessions
│       └── messages/       ← old messages
└── <your project files>
```

## Components

| Component | File | What It Does |
|-----------|------|-------------|
| Skill | `skills/covibe/SKILL.md` | `/covibe` commands for managing sessions |
| Coordination | `skills/covibe-coordination/SKILL.md` | Enforces read-before-work, write-after-work protocol |
| Rule | `rules/covibe-coordination.md` | Same protocol as a rule (for manual installs) |
| Hook | `scripts/covibe-sync.sh` | Auto-commits and pushes `.covibe/` changes, reports sync errors |

## Requirements

- Claude Code (any subscription tier)
- A shared git repo that all participants can push to
- Git configured with `user.name` (run `git config user.name "Your Name"` if not set)

## Platform Support

The sync hook works on macOS, Linux, and Windows (Git Bash/WSL). It auto-detects the platform for file timestamp operations and auto-detects your repo's default branch name.

## Troubleshooting

**"Session file stale" nudge keeps appearing:**
Update your session file with `/covibe status` or by working on a task. The hook nudges every 5 minutes when your session file hasn't been modified.

**"CoVibe Sync ERROR" message:**
The sync hook couldn't push your `.covibe/` changes. Follow the fix instructions in the error message. Common causes: rebase conflict, concurrent push, or stash conflict.

**Push conflicts during claim:**
Another session synced at the same time. The claim protocol handles this: pull, re-check the job status, retry if still available.

**Conversation reset (new Claude Code window):**
Use `/covibe rejoin` instead of `/covibe start`. It reads your existing session file and restores context without creating duplicate files.

**Session crashed (someone else's session is stale):**
Use `/covibe reassign <job-id>` to put the job back on the board or assign it to someone else.

**Git identity not found:**
Run `git config user.name "Your Name"` in the shared repo. CoVibe uses this as your session identity.

## License

MIT
