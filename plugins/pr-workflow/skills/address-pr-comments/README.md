# Address PR Comments

A Claude Code skill that autonomously finds and addresses unanswered review comments across all your open PRs in the Axonius GitHub org.

## What It Does

1. Discovers all open PRs authored by you with unanswered reviewer comments
2. Dispatches parallel agents (one per PR) to analyze and address each comment
3. Makes code changes, posts replies, commits, pushes, undrafts PRs, and re-requests reviews
4. Produces a final report summarizing all actions taken

## Usage

```text
/address-pr-comments            # Full autonomous mode
/address-pr-comments dry-run    # Analyze and plan, but don't execute
```

## Modes

| Mode | Code Changes | GitHub Replies | Push | Undraft | Re-request Reviews |
| --- | --- | --- | --- | --- | --- |
| **Full** | Yes | Yes | Yes | Yes | Yes |
| **Dry-run** | Yes (in worktree) | No | No | No | No |

**Dry-run** writes code changes into persistent worktrees under `.worktrees/` so you can inspect them with `git diff` before committing to full mode.

## How It Works

- Uses GitHub GraphQL API to discover PRs with unresolved threads where the last comment isn't from you
- Creates isolated git worktrees for each PR (supports cross-repo PRs via bare clones)
- Agents classify each comment as **actionable** (code change needed), **discussion** (reply only), or **uncertain** (flagged for human review)
- Uncertain/conflicting comments are presented to you for guidance rather than guessed at

## Requirements

- `gh` CLI authenticated with GitHub
- Git access to the relevant repositories
