# work-activity-report

## Installation

```bash
claude plugin marketplace add langburd/agent-skills
claude plugin install work-activity-report@langburd
```

Generate a daily or weekly work-activity report from GitHub PRs, GitLab MRs,
and Jira tickets. Useful for standups, activity logs, or performance reviews.

## Skills

| Skill | Trigger |
|---|---|
| `work-activity-report` | "what did I work on today", "standup report", "activity log for this week", "summarize my PRs and tickets for 2026-06-09" |

## Usage

```
/work-activity-report
/work-activity-report 2026-06-01..2026-06-07
/work-activity-report user:alice 2026-06-09
```

Defaults: current user, today's date, all authenticated platforms (GitHub + GitLab + Jira).

## Prerequisites

- [`gh`](https://cli.github.com/) authenticated for GitHub
- [`glab`](https://gitlab.com/gitlab-org/cli) authenticated for GitLab (optional)
- [`acli`](https://github.com/ankitpokhrel/jira-cli) configured for Jira (optional)
