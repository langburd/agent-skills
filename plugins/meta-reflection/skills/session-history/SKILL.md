---
name: session-history
description: Use when you need to recall past conversations, find how a problem was solved before, look up previous decisions, search for context from earlier sessions, or when the user asks about conversation history
license: MIT
metadata:
  inspired-by: https://kentgigger.com/posts/claude-code-conversation-history
---

# Session History

Search and browse your own past Claude Code conversation history.

## Storage Layout

| Location | Contents |
| --- | --- |
| `~/.claude-axonius/history.jsonl` | Global index: every prompt, timestamp, project, session ID |
| `~/.claude-axonius/projects/<encoded-path>/sessions-index.json` | Per-project session summaries, message counts, branches |
| `~/.claude-axonius/projects/<encoded-path>/<session-id>.jsonl` | Full conversation transcripts (JSONL) |

## Tool

`~/.claude-axonius/skills/session-history/search-sessions.sh` - Run `--help` for full usage.

### Commands

| Command | Purpose | Example |
| --- | --- | --- |
| `list` | Recent sessions across all projects | `list -n 10 -p tf-infrastructure` |
| `search` | Find sessions by keyword in summaries | `search "bedrock" -n 5` |
| `read` | Full conversation transcript | `read <session-id>` |
| `grep` | Search within conversation content | `grep "lifecycle ignore" -n 5` |
| `projects` | List all projects with session counts | `projects` |
| `prompts` | Recent prompts from global history | `prompts -n 20 -p tf-modules` |
| `help` | Show full usage with all flags | `help` |

### Common Filters

All commands support: `-n NUM` (limit), `-p PROJECT` (project substring), `--after DATE`, `--before DATE`, `--json` (machine output).

## Workflow

1. **Find relevant sessions**: `search` by keyword or `list` filtered by project/branch
2. **Read transcript**: `read <session-id>` for the full conversation
3. **Deep search**: `grep` to find specific text across all conversations

## Built-in Claude Code Commands

| Command | Purpose |
| --- | --- |
| `claude --resume` | Interactive session picker |
| `claude -c` | Continue most recent session |
| `/resume` | Resume picker within active session |
| `Ctrl+R` | Reverse-search previous prompts |
