---
name: work-activity-report
description: Use when the user asks what they or someone else worked on — daily/weekly standup reports, activity logs, "what did I do this week", performance-review prep, or a summary of PRs, MRs, Jira tickets, and Slack discussions over a date range. Gathers from GitHub, GitLab, Jira, and Slack in parallel and returns one chronological report. Use this even when the user names only one platform ("show my PRs from Monday") or doesn't name any ("what was I doing last Tuesday").
---

# Work Activity Report

Build one chronological report of a person's work across GitHub PRs, GitLab
MRs, Jira tickets, and Slack discussions.

The value is in the merge. Each platform can answer "what happened here", but
only a combined, time-sorted view shows an actual working day — the ticket
opened at 09:00, the MR that closed it at 14:00, the Slack thread where it got
decided in between.

## Parameters

| Parameter | Default |
| --- | --- |
| User | The authenticated user on each platform (resolve it, never assume) |
| Date range | Today |
| Sources | Every platform that is authenticated |

Accept ranges as `YYYY-MM-DD` or `YYYY-MM-DD..YYYY-MM-DD`. Relative phrasing
("this week", "last 3 days") is fine — resolve it against the current date and
state the resolved range in the output so the reader can check it.

Verify the current year before searching. A date range in the wrong year
returns a confident, empty, entirely wrong report.

## Step 1: Preflight

Run these together and read identity from the results. Hardcoding a username
means the skill silently reports on the wrong person when someone else uses it.

```bash
gh api user --jq '{login: .login, name: .name}'
glab api user | jq '{username, name, id}'
acli jira auth status
```

Plus `slack_read_user_profile` with no `user_id` for the Slack identity.

Usernames often differ across platforms, and there is no reliable way to derive
one from another. When a platform is authenticated but its username looks
unrelated to the others, ask rather than guess — one question is cheaper than a
plausible-looking report about nobody.

**A source that fails preflight is skipped and named in the output.** This
matters more than it sounds: a missing GitLab token produces an empty MR list,
which is indistinguishable from a week with no MRs. Silence there turns a setup
problem into a false statement about someone's work.

For a report on **another user**, skip Jira's `currentUser()` path and resolve
their identity per `references/jira.md`.

## Step 2: Fan out, one agent per source

Dispatch one subagent per active source **in a single message** so they run
concurrently. Give each: its reference file path, the resolved identity, the
date range, and the output row shape.

| Source | Reference |
| --- | --- |
| GitHub | `references/github.md` |
| GitLab | `references/gitlab.md` |
| Jira | `references/jira.md` |
| Slack | `references/slack.md` |

These agents run fixed command sets and return structured rows. There is no
judgment in the fetching, so a small fast model (Haiku) handles them well and
keeps bulk JSON out of the main context — where it would otherwise crowd out
the actual work of assembling the report. Use `cli-runner` or an equivalent
cheap agent type for the three CLI sources; Slack needs an agent with MCP
access.

Instruct each agent to return **rows only** — no prose summary, no
interpretation. Judgment stays here, where the full picture is visible.

If an agent returns nothing, distinguish "ran fine, no activity" from "could
not run". Have it say which.

## Step 3: Merge

1. **Deduplicate** by `(url, action)`. Overlap is by design — the searches are
   deliberately redundant so nothing is missed.
2. **Filter to range.** Some results legitimately fall outside it: `gh search`
   matches on PR update time rather than review time, and Slack's date
   modifiers are exclusive. Drop what falls outside.
3. **Normalize to UTC.** Slack returns workspace-local time (e.g. IDT); the
   others return UTC. Convert Slack rows before sorting or they land hours from
   the work they relate to. Say which timezone the tables use.
4. **Sort chronologically** by actual action time.
5. **Group by day.**

## Output

Use tables throughout. One table per platform per day, omitting any platform
with no activity that day.

```markdown
## 2026-08-18 (Tuesday)

### GitHub PRs

| Time (UTC) | Action | PR | Repository | Author | Title |
|---|---|---|---|---|---|
| 07:56 | Merged | https://github.com/org/repo/pull/123 | org/repo | langburd | PROJ-1234 – Title |

### GitLab MRs

| Time (UTC) | Action | MR | Project | Author | Title |
|---|---|---|---|---|---|
| 09:12 | Created | https://gitlab.com/group/repo/-/merge_requests/42 | group/repo | langburd | INF-5678 – Title |

### Jira Tickets

| Time (UTC) | Action | Ticket | Project | Summary |
|---|---|---|---|---|
| 08:30 | Created | https://your-org.atlassian.net/browse/PROJ-1234 | PROJ | Ticket summary |
| (date only) | Status changed | https://your-org.atlassian.net/browse/PROJ-5678 | PROJ | Another ticket |

### Slack Discussions

| Time (UTC) | Channel | Topic | Role | Msgs |
|---|---|---|---|---|
| 12:54 | #cloud-infrastructure-public | Terraform state lock | Answered | 4 |
| 13:39 | DM with Kevin Gardiner | (private) | Participated | 2 |

---
```

Jira transitions show `(date only)` in the time column — see the changelog
limitation in `references/jira.md`. Don't substitute the ticket's `updated`
timestamp, which reflects the last change by anyone and is usually not the
user's action.

DM rows carry participant names and counts, no topic or content, unless the
user asked for DM detail in this invocation.

### Summary

```markdown
## Summary

Range: 2026-08-17..2026-08-18 · Sources: GitHub, GitLab, Jira, Slack

| Metric | Count |
|---|---|
| GitHub PRs created / merged / reviewed | N / N / N |
| GitHub PRs merged for others | N |
| GitLab MRs created / merged / approved | N / N / N |
| Jira tickets created / resolved / transitioned | N / N / N |
| Slack threads participated | N |

| Category | Items |
|---|---|
| GitHub repositories | repo1, repo2 |
| GitLab projects | group/repo1 |
| Jira projects | PROJ1, PROJ2 |
| Slack channels | #chan1, #chan2 |
```

### Coverage note

Close with what was skipped or capped:

```markdown
**Coverage:** GitLab skipped (glab not authenticated). Slack bounded sweep
(4 searches × 2 pages); #busy-channel had more results. Times in UTC
(Slack converted from IDT).
```

This is the difference between a report someone can trust and one that quietly
overstates its own completeness. A reader who knows GitLab was skipped can go
look; a reader who doesn't will conclude there were no MRs.

## Pitfalls

| Issue | Cause and fix |
| --- | --- |
| Wrong year in results | Verify the current year before searching |
| GitHub merges missing | Use `--merged-at`, not `--merged` |
| GitHub `mergedAt` field error | Not valid in search JSON — use `closedAt` |
| GitHub reviews on wrong day | `gh search` matches PR update time; fetch real times via `gh api .../reviews` |
| "Merged by" work missing | Author searches never find it; check `merged_by` |
| GitLab commands erroring on `--jq` | `glab api` has no `--jq` — pipe to external `jq` |
| GitLab reviews all empty | `reviewer_username` returns `[]` silently — use `users/:id/events` |
| GitLab results truncated | `--paginate` is required |
| Jira transition times wrong | `changelog` is `null`; report date-only |
| Jira email guessing fails | Use `currentUser()` for self; look the user up rather than munging names |
| Slack rows hours off | Results are workspace-local, not UTC — convert |
| Slack range includes stray dates | `after:`/`before:` are exclusive — widen, then filter |
| Report looks empty but isn't | An unauthenticated source was skipped without saying so |
