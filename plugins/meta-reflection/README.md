# meta-reflection

## Installation

```bash
claude plugin marketplace add langburd/agent-skills
claude plugin install meta-reflection@langburd
```

Self-reflection and session-history skills. Improve your Claude instructions
over time and search past conversations.

## Skills

| Skill | What it does | Trigger |
|---|---|---|
| `reflection` | Analyzes the current session and updates the project's `CLAUDE.md` | "reflect", "update CLAUDE.md", "capture what we learned" |
| `reflection-global` | Same, but targets the global `~/CLAUDE.md` for cross-project patterns | "reflect globally", "update global instructions" |
| `session-history` | Search and browse past Claude Code conversation transcripts | "what did we decide last week", "find how I solved X before" |

## Prerequisites

`session-history` reads Claude Code's local transcript files
(`~/.claude-axonius/history.jsonl` and per-project session files). No setup
needed — files are created automatically by Claude Code.
