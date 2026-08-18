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

## Privacy

Slack DMs and group DMs contribute **metadata only** by default — participants,
message counts, dates, no message text. Ask explicitly to include DM content in
a given report. Channel activity, already visible to the channel, includes
topic detail.

## Prerequisites

At least one of:

- [`gh`](https://cli.github.com/) authenticated — GitHub PRs
- [`glab`](https://gitlab.com/gitlab-org/cli) authenticated — GitLab MRs
  (requires `jq`, since `glab api` has no `--jq` flag)
- [`acli`](https://developer.atlassian.com/cloud/acli/) authenticated —
  Jira tickets. The Atlassian MCP works as a fallback.
- Slack MCP connected — Slack discussions
