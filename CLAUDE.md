# CoVibe — Multiplayer Claude Code

## Overview

A coordination system that lets multiple Claude Code sessions collaborate on the same project. Each person runs their own Claude Code. Sessions communicate through a shared job board and message system in the git repo, auto-pushed so everyone sees updates within seconds.

No server. No extra infrastructure. Just a `/covibe` skill, a coordination rule, an auto-push hook, and markdown files in the repo.

## Components

| Component | Source | Install Target |
|-----------|--------|---------------|
| `/covibe` skill | `skills/covibe/SKILL.md` | `~/.claude/skills/covibe/SKILL.md` |
| Coordination skill | `skills/covibe-coordination/SKILL.md` | `~/.claude/skills/covibe-coordination/SKILL.md` |
| Coordination rule | `rules/covibe-coordination.md` | `~/.claude/rules/covibe-coordination.md` |
| Sync hook | `scripts/covibe-sync.sh` | `~/.claude/scripts/covibe-sync.sh` |

The coordination skill and rule contain the same protocol. Plugin installs use the skill; manual installs can use either. The rule is conditional (activates only when `/tmp/.covibe-active` exists). The skill checks the same marker at the start of each turn.

## Architecture

Sessions coordinate through a `.covibe/` directory inside the target project's git repo:

```
.covibe/
├── config.md       ← project, participants
├── sessions/       ← each user's real-time status
├── jobs/           ← job board with frontmatter
├── messages/       ← coordination messages
└── archive/        ← completed sessions/jobs
```

The sync hook auto-commits and pushes `.covibe/` changes after each Claude response. Pull happens before each read.

## Key Design Decisions

1. **Git is the coordination layer.** No server, no database. Git push/pull is the event bus.
2. **Sessions communicate, they don't share context.** Each person keeps their own Claude Code. Sessions exchange messages and status through files.
3. **Pull-based job claiming.** Sessions browse the board and claim work. No central assignment.
4. **Timestamp-based message names** avoid numbering conflicts from concurrent writes.
5. **The rule only activates when `/tmp/.covibe-active` exists.** Zero overhead when not in a session.

## Phases

- **V1.2 (current):** Full job lifecycle. Review/merge workflow, archive/cleanup, reassign/unblock, DAG validation, phase progress tracking, .gitattributes for merge prevention, hardened sync hook with error reporting.
- **V1.1:** Cross-platform sync hook, rejoin protocol, read tracking, stale session detection.
- **V1.0:** Initial release. Skill + rule + hook.
- **V2:** Agent SDK server with web UI, SSE streaming, rooms.
- **V3:** Spatial Workspace integration — job board and sessions on a 2D canvas.

## Relationships

- **Spatial Workspace** (parent project) — CoVibe is the collaborative layer. V3 renders everything spatially.
- **HHA** — first real use case. CoVibe coordinates Wisdom + Frank on client projects.
- **The Hearth** — CoVibe is a Hearth-distributable kit.
- **PS Events** — event format: room full of people building together through CoVibe.

## Working Conventions

- This repo is public. No secrets, no credentials, no internal URLs.
- Source of truth lives here. `~/.claude/` copies are deployments.
- MIT licensed.
