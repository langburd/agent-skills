---
name: work-activity-report
description: Use when the user asks for a summary of work activity, daily/weekly standup report, what someone worked on, activity log, or needs to see all PRs, MRs, and Jira tickets touched during a specific date range
---

# Work Activity Report

Generate comprehensive work activity reports by searching GitHub PRs, GitLab MRs, and Jira tickets for a specific user and date range.

## Required Information

Before searching, collect:

- **GitHub username** - default: `langburd` (used for GitHub searches)
- **GitLab username** - default: same as GitHub username (used for GitLab searches; confirm if different)
- **Jira email** - default: derive from GitHub/GitLab profile, or ask the user
- **Date range** in `YYYY-MM-DD` format (e.g., `2026-01-20` to `2026-01-22`) - **default: today**
- **Platforms to search** - default: both GitHub and GitLab (skip a platform if user specifies only one)

If no user is specified, use the defaults above.
If no date range is specified, search for **today's activity only** (current date).

## Platform Detection

If not specified by the user, check which platforms are relevant:

```bash
# Check if GitHub CLI is authenticated
gh auth status 2>&1 | head -1

# Check if GitLab CLI is authenticated
glab auth status 2>&1 | head -1
```

Search all authenticated platforms by default. Skip a platform if auth fails or user explicitly excludes it.

### Fetching Jira Email from GitHub/GitLab

If searching for another user and Jira email is not provided, try fetching from GitHub profile first, then GitLab:

```bash
# From GitHub
gh api users/USERNAME --jq '{email: .email, name: .name}'

# From GitLab (if GitHub returns null name)
glab api users --jq '.[] | select(.username=="USERNAME") | {email: .public_email, name: .name}'
```

**Note:** The email pattern is typically `firstname.lastname@<org-domain>.com`. If the profile email doesn't match or is null, construct it from the user's display name.

**IMPORTANT:** Names may appear in different orders (e.g., "Doe John" instead of "John Doe"). Try both orderings:

```bash
NAME="John Doe"
EMAIL1=$(echo "$NAME" | awk '{print tolower($1"."$2)"@your-org.com"}')  # john.doe@
EMAIL2=$(echo "$NAME" | awk '{print tolower($2"."$1)"@your-org.com"}')  # doe.john@
```

### Validating Jira Email

Before running all Jira searches, validate the email format with a quick check:

```bash
acli jira workitem search --jql "(assignee = 'EMAIL' OR reporter = 'EMAIL') ORDER BY updated DESC" --limit 1 --json
```

**Validation logic:**

- If results returned → email format is correct
- If empty `[]` → likely wrong email format, try the other format

**Strategy:**

1. Construct both email formats from profile name
2. Run validation query with format 1
3. If empty, run validation query with format 2
4. Use whichever format returns results
5. If both return empty, try the **Jira ticket fallback** (below)
6. If fallback fails, user may have no Jira activity (proceed with code-platform-only report)

### Fallback: Discover Jira Name from PR/MR Titles

**When to use:** GitHub/GitLab name and Jira name may be completely different (e.g., "Samantha Duncan" on GitHub vs "Samantha Petherson" in Jira).

If both email formats return empty, extract Jira ticket keys from PR/MR titles and look up the ticket:

```bash
# 1. Look at PR/MR titles from search results for Jira ticket keys (e.g., "DEVOPS-9090", "INF-1234")
# 2. Fetch the ticket to see reporter/assignee names
acli jira workitem view TICKET-KEY --json

# 3. Extract the actual Jira name from reporter or assignee
# Example response: "reporter": {"display_name": "Samantha Petherson"}

# 4. Construct email from discovered Jira name
# "Samantha Petherson" → samantha.petherson@your-org.com
```

**Why this works:** Users often reference their Jira tickets in PR/MR titles. The ticket's reporter/assignee reveals their actual Jira display name.

## GitHub PR Search

**CRITICAL:** Use `gh search prs` with proper date flags. Verify the current year.

### Step 1: Initial Search Commands (run in parallel)

```bash
# PRs created by user in date range
gh search prs --author=USERNAME --created=START_DATE..END_DATE_PLUS_1 \
  --json number,title,repository,state,createdAt,url --limit 100

# PRs merged by user in date range
gh search prs --author=USERNAME --merged-at=START_DATE..END_DATE_PLUS_1 \
  --json number,title,repository,closedAt,url --limit 100

# PRs user was involved with (reviewed, commented, etc.)
gh search prs --involves=USERNAME --updated=START_DATE..END_DATE_PLUS_1 \
  --json number,title,repository,state,author,updatedAt,url --limit 100

# PRs reviewed by user
gh search prs --reviewed-by=USERNAME --updated=START_DATE..END_DATE_PLUS_1 \
  --json number,title,repository,state,author,url --limit 100
```

### Step 2: Get Exact Review Timestamps (CRITICAL)

**Why this is needed:** `gh search` uses the PR's `updated` timestamp, NOT individual review timestamps.

When the PR set is large (more than ~8 PRs), offload these per-PR `gh api`
fetches to the `cli-runner` agent (`subagent_type: "cli-runner"`, runs on
Haiku) rather than inline. Pass it the `{OWNER}/{REPO}#{NUMBER}` list and the
command templates below, and have it return the merged JSON. These are pure
mechanical reads with no judgment, so a cheap model fits and the many
round-trips stay off the session model. For a handful of PRs, run inline — the
handoff overhead isn't worth it.

For each PR from `--involves` and `--reviewed-by` results, fetch the user's actual review timestamps:

```bash
gh api repos/OWNER/REPO/pulls/NUMBER/reviews \
  --jq '.[] | select(.user.login=="USERNAME") | {submitted_at, state}'
```

**Review states:** APPROVED, CHANGES_REQUESTED, COMMENTED, DISMISSED

### Step 3: Check Who Merged PRs

```bash
gh api repos/OWNER/REPO/pulls/NUMBER --jq '{merged_by: .merged_by.login, merged_at}'
```

### Important Notes

- Use `--merged-at` for merge date filtering (NOT `--merged`)
- `mergedAt` is NOT a valid JSON field for search results - use `closedAt` instead
- The `--involves` flag catches PRs where user reviewed, commented, or was mentioned
- Always use `--limit 100` to capture all activity
- End date should be +1 day to include full day (e.g., for Jan 20-22, use `..2026-01-23`)

## GitLab MR Search

**CRITICAL:** Use `glab api` for date-filtered MR searches. The `glab mr list` command lacks granular date filtering.

### Step 1: Initial MR Search Commands (run in parallel)

```bash
# MRs created by user in date range
glab api merge_requests \
  -F author_username=GITLAB_USERNAME \
  -F created_after=START_DATEt00:00:00Z \
  -F created_before=END_DATE_PLUS_1t00:00:00Z \
  --paginate --jq '.[] | {iid, title, web_url, project_id, created_at, state}'

# MRs merged by user in date range
glab api merge_requests \
  -F author_username=GITLAB_USERNAME \
  -F state=merged \
  -F updated_after=START_DATEt00:00:00Z \
  -F updated_before=END_DATE_PLUS_1t00:00:00Z \
  --paginate --jq '.[] | select(.merged_at >= "START_DATE") | {iid, title, web_url, project_id, merged_at}'

# MRs where user is a reviewer/assigned
glab api merge_requests \
  -F reviewer_username=GITLAB_USERNAME \
  -F updated_after=START_DATEt00:00:00Z \
  -F updated_before=END_DATE_PLUS_1t00:00:00Z \
  --paginate --jq '.[] | {iid, title, web_url, project_id, updated_at, author}'
```

### Step 2: Get Exact Approval Timestamps

For each MR from reviewer results, fetch actual approval timestamps:

```bash
# Get approvals on a specific MR
glab api projects/PROJECT_ID/merge_requests/MR_IID/approvals \
  --jq '.approved_by[] | select(.user.username=="GITLAB_USERNAME") | {created_at: "N/A - use MR updated_at"}'

# Get user's notes/comments on an MR with timestamps
glab api projects/PROJECT_ID/merge_requests/MR_IID/notes \
  --jq '.[] | select(.author.username=="GITLAB_USERNAME") | {created_at, body}'
```

**Note:** GitLab approval timestamps are not directly exposed via API; use the MR's `updated_at` as a proxy when needed.

### Step 3: Check Who Merged MRs

```bash
glab api projects/PROJECT_ID/merge_requests/MR_IID \
  --jq '{merged_by: .merged_by.username, merged_at}'
```

### GitLab Important Notes

- GitLab `project_id` is the numeric ID from the MR object; use it for subsequent API calls
- Use ISO 8601 timestamps (`2026-01-20t00:00:00Z`) for `created_after`/`created_before`
- `--paginate` is required to get all results beyond the first page
- `glab api merge_requests` searches across ALL accessible projects; scope to a group if needed: `glab api groups/GROUP_ID/merge_requests`

## Jira Ticket Search

**CRITICAL:** Use `acli` for Jira queries.

### Search Commands (run in parallel)

```bash
# Tickets created by user in date range
acli jira workitem search --jql "reporter = 'EMAIL' AND created >= 'START_DATE' AND created <= 'END_DATE 23:59'" --json --limit 100

# Tickets with status changed by user in date range
acli jira workitem search --jql "status changed BY 'EMAIL' DURING ('START_DATE', 'END_DATE_PLUS_1')" --json --limit 100

# Tickets resolved by user in date range
acli jira workitem search --jql "resolved >= 'START_DATE' AND resolved <= 'END_DATE_PLUS_1' AND assignee = 'EMAIL'" --json --limit 100

# Tickets assigned to user and updated in date range
acli jira workitem search --jql "assignee = 'EMAIL' AND updated >= 'START_DATE' AND updated <= 'END_DATE_PLUS_1'" --json --limit 100
```

### JQL Tips

- For `DURING` clauses, end date should be +1 day
- Use `'EMAIL'` with quotes for email addresses
- `status changed BY` captures status transitions made by the user
- Get ticket details with `acli jira workitem view TICKET_KEY --json` for resolution dates

## Output Format

**CRITICAL:** Always use tables for ALL output. Present results chronologically, sorted by date and time.

### Daily Summary Template

Each day gets one table per platform plus one Jira table, all sorted by time:

```markdown
## [DATE] ([Day of Week])

### GitHub PRs

| Time (UTC) | Action | PR | Repository | Author | Title |
|------------|--------|----|------------|--------|-------|
| 07:56 | Merged | https://github.com/my-org/repo/pull/123 | repo | username | PROJ-1234 – Title |
| 17:08 | Approved | https://github.com/my-org/repo/pull/125 | repo | other-user | PROJ-9999 – Review title |

### GitLab MRs

| Time (UTC) | Action | MR | Project | Author | Title |
|------------|--------|----|---------|--------|-------|
| 09:12 | Created | https://gitlab.com/group/repo/-/merge_requests/42 | repo | username | INF-5678 – Title |
| 15:30 | Approved | https://gitlab.com/group/repo/-/merge_requests/43 | repo | other-user | INF-0000 – Review title |

### Jira Tickets

| Time (UTC) | Action | Ticket | Project | Summary |
|------------|--------|--------|---------|---------|
| 08:30 | Created | https://your-org.atlassian.net/browse/PROJ-1234 | PROJ | Ticket summary |
| 14:15 | Resolved | https://your-org.atlassian.net/browse/PROJ-5678 | PROJ | Another ticket |

---
```

**Key formatting rules:**

- Omit a platform's table entirely if there is no activity for that day on that platform
- Include day of week in date header (e.g., "2026-01-27 (Monday)")
- Use horizontal rule `---` between days
- Actions: Created, Merged, Approved, Commented, Changes Requested

### Summary Statistics

Always present statistics as a table:

```markdown
## Summary

| Metric | Count |
|--------|-------|
| GitHub PRs created | N |
| GitHub PRs merged (own) | N |
| GitHub PRs merged (others' - as merger) | N |
| GitHub PRs reviewed/approved | N |
| GitLab MRs created | N |
| GitLab MRs merged (own) | N |
| GitLab MRs merged (others' - as merger) | N |
| GitLab MRs reviewed/approved | N |
| Jira tickets created | N |
| Jira tickets resolved | N |
| Jira tickets status changed | N |

| Category | Items |
|----------|-------|
| GitHub repositories touched | repo1, repo2 |
| GitLab projects touched | group/repo1, group/repo2 |
| Jira projects touched | PROJ1, PROJ2 |
```

## Workflow

1. **Collect parameters** - username(s), email, date range, platforms
2. **Detect platforms** - check `gh auth status` and `glab auth status`
3. **Derive Jira email** (if not provided) - fetch profile from GitHub then GitLab, construct both email formats
4. **Validate Jira email** - run validation query with format 1, if empty try format 2
5. **Fallback if needed** - extract Jira ticket key from PR/MR titles, fetch ticket, discover actual Jira name
6. **Run GitHub searches in parallel** (if GitHub active) - all 4 search commands
7. **Run GitLab searches in parallel** (if GitLab active) - all 3 search commands
8. **Run Jira searches in parallel** - all 4 JQL queries
9. **Get review timestamps** - fetch actual review/approval times via API for both platforms
10. **Check merge attribution** - check `merged_by` for both GitHub and GitLab
11. **Deduplicate results** - same PR/MR/ticket may appear in multiple searches
12. **Filter by date** - review timestamps may fall outside update date; filter to requested range
13. **Sort chronologically** - by actual action timestamp
14. **Format output** - use daily summary template
15. **Add statistics** - summary counts at the end

## Common Pitfalls

| Issue | Solution |
| ----- | -------- |
| Wrong year in dates | Verify current year before searching |
| Missing merged GitHub PRs | Use `--merged-at` not `--merged` flag |
| Missing GitHub reviews on specific days | Fetch timestamps via `gh api repos/.../pulls/N/reviews` |
| GitHub reviews showing wrong date | `gh search` uses PR update time - must use API for exact times |
| Missing "merged by" activity (GitHub) | Check `merged_by` via `gh api repos/.../pulls/N` |
| Missing "merged by" activity (GitLab) | Check `merged_by` via `glab api projects/ID/merge_requests/IID` |
| GitLab `glab mr list` missing results | Use `glab api merge_requests` with date filters instead |
| GitLab pagination missing results | Always use `--paginate` with `glab api` |
| GitLab approval timestamps unavailable | Use MR `updated_at` as proxy; note it in output |
| Jira DURING clause errors | End date must be +1 day |
| Incomplete Jira results | Run multiple JQL queries to cover all activity types |
| Jira email not found | Profile name order may be reversed - try both `first.last@` and `last.first@` |
| GitHub and Jira names completely different | Extract Jira ticket key from PR/MR titles, fetch ticket, use reporter/assignee display_name |
