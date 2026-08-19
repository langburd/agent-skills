# work-activity-report

## Installation

```bash
claude plugin marketplace add langburd/agent-skills
claude plugin install work-activity-report@langburd
```

Generate a daily or weekly work-activity report from GitHub PRs, GitLab MRs,
Jira tickets, and Slack discussions. Each source is fetched by a parallel
subagent, then merged into one chronological, time-sorted view — useful for
standups, activity logs, or performance-review prep. Identity is resolved from
each platform's authenticated user, so no usernames are hardcoded.

## Skills

| Skill | Trigger |
|---|---|
| `work-activity-report` | "what did I work on today", "standup report", "activity log for this week", "summarize my PRs and tickets for 2026-06-09", "what was I doing last Tuesday" |

## Usage

```
/work-activity-report
/work-activity-report 2026-06-01..2026-06-07
/work-activity-report user:alice 2026-06-09
```

Defaults: authenticated user, today's date, all authenticated platforms.
Sources that are unavailable are skipped and named in the report, so a missing
token never reads as "no activity".

Each report is saved to `~/work-activity-reports/`, named for its date range,
and the skill offers a thematic Slack summary drafted into your own DM — never
sent, so you edit it before anyone else sees it.

## Privacy

Reports record the **subject** of a conversation, never its content. "PR #6378
review request" or "TFE SAML troubleshooting", never a quote or a paraphrase of
what anyone said. This applies to channels and DMs alike.

DMs are included by default when reporting on **yourself**, because a great deal
of real work happens there — troubleshooting, review requests, access approvals,
onboarding — and omitting it understates the week. Threads that turn out to be
personal are recorded as `(personal)` with a message count and nothing else.

When reporting on **someone else**, DMs contribute participants and counts only.
Their conversation subjects are not yours to summarize.

## Prerequisites

At least one of:

- [`gh`](https://cli.github.com/) authenticated — GitHub PRs
- [`glab`](https://gitlab.com/gitlab-org/cli) authenticated — GitLab MRs
  (requires `jq`, since `glab api` has no `--jq` flag)
- [`acli`](https://developer.atlassian.com/cloud/acli/) authenticated —
  Jira tickets. The Atlassian MCP works as a fallback.
- Slack MCP connected — Slack discussions
