# GitHub Activity Reference

Commands for collecting one user's GitHub PR activity in a date range.

## Tool choice: `gh` CLI

`gh` is the primary tool. It supports `--jq` natively, `gh search prs` does
date-range filtering server-side, and `gh api` reaches the review endpoints
that search cannot. The GitHub MCP, where available, duplicates this at higher
token cost per call and without the search date flags — use `gh`.

## Identity

```bash
gh api user --jq '{login: .login, name: .name}'
```

Read the login here rather than assuming one. Availability check:

```bash
gh auth status 2>&1 | head -1
```

## Searches

Run these together — they are independent:

```bash
# Created in range
gh search prs --author=<LOGIN> --created=<START>..<END> \
  --json number,title,repository,state,createdAt,url --limit 100

# Merged in range
gh search prs --author=<LOGIN> --merged-at=<START>..<END> \
  --json number,title,repository,closedAt,url --limit 100

# Involved (reviewed, commented, mentioned, assigned)
gh search prs --involves=<LOGIN> --updated=<START>..<END> \
  --json number,title,repository,state,author,updatedAt,url --limit 100

# Reviewed
gh search prs --reviewed-by=<LOGIN> --updated=<START>..<END> \
  --json number,title,repository,state,author,url --limit 100
```

Flag details that cause silent wrong results:

- `--merged-at` is the merge-date filter. `--merged` is a different flag and
  will not do what you want.
- `mergedAt` is **not** a valid `--json` field for search results. Use
  `closedAt`.
- `--limit 100` on every search. The default is far lower and truncates without
  warning.

## Exact review timestamps

`gh search` filters on the PR's `updated` timestamp, not on when the user
reviewed. A PR touched today but reviewed last week appears in today's results
with today's date. For any PR from `--involves` or `--reviewed-by`, fetch the
real review times:

```bash
gh api repos/<OWNER>/<REPO>/pulls/<NUMBER>/reviews \
  --jq '.[] | select(.user.login=="<LOGIN>") | {submitted_at, state}'
```

Review states: `APPROVED`, `CHANGES_REQUESTED`, `COMMENTED`, `DISMISSED`.

Then discard reviews whose `submitted_at` falls outside the requested range.
Skipping this filter is the single most common source of wrong dates in this
report.

## Merge attribution

A user merging someone else's PR is real work that no author-based search
finds:

```bash
gh api repos/<OWNER>/<REPO>/pulls/<NUMBER> --jq '{merged_by: .merged_by.login, merged_at}'
```

Check this on PRs from `--involves` where the author is someone else.

## Per-PR fetches at volume

The two commands above are one call per PR, so a busy week can mean dozens of
round-trips. They are purely mechanical reads with no judgment involved, which
makes them a good fit for batching inside this agent rather than surfacing each
result. Collect the `{owner}/{repo}#{number}` list first, run the fetches, and
return only the merged rows.

## Output rows

```json
{"timestamp_utc": "2026-08-18T07:56:00Z", "action": "Merged",
 "url": "https://github.com/org/repo/pull/123", "project": "org/repo",
 "author": "someone-else", "title": "PROJ-1234 – Title"}
```

Actions: Created, Merged, Approved, Changes Requested, Commented, Closed.
Deduplicate by `(url, action)` — the four searches overlap heavily by design.
GitHub timestamps are UTC — no conversion needed.
