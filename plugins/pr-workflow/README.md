# pr-workflow

## Installation

```bash
claude plugin marketplace add langburd/agent-skills
claude plugin install pr-workflow@langburd
```

PR/MR workflow helpers: fix review findings, address reviewer comments, and
auto-update PR/MR descriptions from code changes.

## Skills

| Skill | What it does | Trigger |
|---|---|---|
| `fix` | Reads code review findings already in the conversation and applies every fix in a single commit | "/fix", "fix all review issues", "apply the fixes" |
| `address-pr-comments` | Autonomously addresses unanswered reviewer comments on the current PR (or all open PRs with `all`) | "address PR comments", "fix review comments", "respond to reviewers" |
| `pr-mr-comment-update` | Analyzes PR/MR changes and rewrites the description/body | "update PR description", "summarize PR", "generate PR body from changes" |

## Prerequisites

- [`gh`](https://cli.github.com/) authenticated for GitHub operations
- [`glab`](https://gitlab.com/gitlab-org/cli) authenticated for GitLab operations (`pr-mr-comment-update` and `address-pr-comments` in MR mode)
