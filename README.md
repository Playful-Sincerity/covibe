# CoVibe — Multiplayer Claude Code

Multiple Claude Code sessions coordinating through a shared git repo. No server, no extra infrastructure.

An orchestrator decomposes work into jobs. Individual sessions browse the job board, claim work, execute it, and push results. Messages flow between sessions for coordination. Everything lives in git.

## How It Works

```
Orchestrator decomposes project into jobs
    |
Sessions browse .covibe/jobs/, claim one
    |
Working on a feature branch
    |
Done → Review job picked up by someone else
    |
Approved → PR to main
```

Each participant runs their own Claude Code with their own subscription. Sessions coordinate through markdown files in a `.covibe/` directory inside the shared repo, auto-synced by a git hook.

## Install

Copy the three components to your Claude Code config:

```bash
# Skill
cp -r skills/covibe/ ~/.claude/skills/covibe/

# Rule (activates only during CoVibe sessions)
cp rules/covibe-coordination.md ~/.claude/rules/

# Hook script
cp scripts/covibe-sync.sh ~/.claude/scripts/
chmod +x ~/.claude/scripts/covibe-sync.sh
```

Then add the hook to your `~/.claude/settings.json` in the `Stop` hooks array:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/scripts/covibe-sync.sh"
          }
        ]
      }
    ]
  }
}
```

## Usage

### Start a session

```
/covibe start ~/projects/my-shared-repo
```

This reads your git identity, writes a session file, and shows you what others are working on.

### See what everyone's doing

```
/covibe status
```

### Claim a job from the board

```
/covibe claim auth-flow
```

### Send a message to other sessions

```
/covibe msg "Found a bug in the webhook handler — heads up if you're touching auth"
```

### Read latest updates

```
/covibe read
```

### Mark your job done (ready for review)

```
/covibe done
```

### End your session

```
/covibe end
```

### Enter orchestrator mode (decompose work, coordinate)

```
/covibe orchestrate
```

## Repo Structure (during a session)

```
your-project/
├── .covibe/
│   ├── config.md          ← project name, participants
│   ├── sessions/
│   │   ├── wisdom.md      ← auto-updated status
│   │   └── frank.md       ← auto-updated status
│   ├── jobs/
│   │   ├── auth-flow.md   ← job with frontmatter
│   │   └── api-docs.md
│   ├── messages/
│   │   └── 20260408-153000-wisdom.md
│   └── archive/
└── <your project files>
```

## Components

| Component | File | What It Does |
|-----------|------|-------------|
| Skill | `skills/covibe/SKILL.md` | `/covibe` commands for managing sessions |
| Rule | `rules/covibe-coordination.md` | Enforces read-before-work, write-after-work throughout the conversation |
| Hook | `scripts/covibe-sync.sh` | Auto-commits and pushes `.covibe/` changes, nudges on stale sessions |

## Requirements

- Claude Code (any subscription tier)
- A shared git repo that all participants can push to
- Git configured with `user.name`

## License

MIT
