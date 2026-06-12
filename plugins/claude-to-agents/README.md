# claude-to-agents

## Installation

```bash
claude plugin marketplace add langburd/agent-skills
claude plugin install claude-to-agents@langburd
```

Migrate a project from Claude-specific instruction files (`CLAUDE.md`,
`.claude/skills/`) to the universal [AGENTS.md](https://agents.md) standard.
Creates symlinks so every configured AI agent (Augment, Gemini, Copilot,
Cursor, Windsurf, …) shares one source of truth.

## Skills

| Skill | Trigger |
|---|---|
| `claude-to-agents` | "convert to agents.md", "make instructions universal", "migrate from CLAUDE.md", "share instructions across AI tools" |

## What it does

1. Rewrites Claude-specific language in `CLAUDE.md` to be agent-agnostic
2. Runs `scripts/setup-agents.sh` to move files and wire up symlinks
3. Handles four starting states: CLAUDE.md only, AGENTS.md only, both (conflict), or neither (scaffold)

## Prerequisites

- Bash (for `setup-agents.sh`)
- The project you want to migrate checked out locally
