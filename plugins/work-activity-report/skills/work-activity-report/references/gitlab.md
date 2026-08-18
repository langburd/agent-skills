# GitLab Activity Reference

Commands for collecting one user's GitLab MR activity in a date range.

## Two `glab` facts that break the obvious approach

**`glab api` has no `--jq` flag.** Unlike `gh`, it errors with
`Unknown flag: --jq`. Pipe to the external `jq` binary instead. Every command
below does this.

**`reviewer_username` silently returns `[]`.** The `merge_requests` endpoint
accepts the parameter and returns an empty array regardless of reality. This is
the dangerous kind of failure: it looks identical to "this person reviewed
nothing", so a report built on it under-reports review work without any error.
Use the events endpoint (below) for review activity instead.

## Identity

```bash
glab api user | jq '{username, name, public_email, id}'
```

Capture both `username` (for MR queries) and `id` (required for the events
endpoint). Never assume a username — read it here.

Availability check:

```bash
glab auth status 2>&1 | head -1
```

## Authored MRs

```bash
# Created in range
glab api --paginate "merge_requests?author_username=<USERNAME>&created_after=<START>T00:00:00Z&created_before=<END_PLUS_1>T00:00:00Z&per_page=100&scope=all" \
  | jq '[.[] | {iid, title, url: .web_url, project: .references.full, created_at, state, merged_at, merged_by: .merged_by.username}]'

# Merged in range (filter client-side: updated_after is coarser than merged_at)
glab api --paginate "merge_requests?author_username=<USERNAME>&state=merged&updated_after=<START>T00:00:00Z&per_page=100&scope=all" \
  | jq --arg s "<START>" --arg e "<END_PLUS_1>" '[.[] | select(.merged_at >= $s and .merged_at < $e) | {iid, title, url: .web_url, project: .references.full, merged_at, merged_by: .merged_by.username}]'
```

`--paginate` is required; without it you get only the first page and a
quietly truncated report.

## Review and other activity: the events endpoint

One call covers what would otherwise be N per-MR probes:

```bash
glab api --paginate "users/<USER_ID>/events?after=<START_MINUS_1>&before=<END_PLUS_1>&per_page=100" \
  | jq '[.[] | {action_name, target_type, target_title, created_at, project_id}]'
```

Observed `action_name` values: `opened`, `closed`, `merged`, `accepted`,
`approved`, `pushed to`, `pushed new`, `commented on`.

Map them to report actions:

| `action_name` | Report action |
| --- | --- |
| `opened` | Created |
| `approved` | Approved |
| `accepted` / `merged` | Merged |
| `commented on` | Commented |
| `closed` | Closed |
| `pushed to` / `pushed new` | Pushed (usually omit — noisy, and the MR row covers it) |

Note the `after`/`before` bounds here are **exclusive dates, not timestamps**,
which is why `after` is the day *before* your start date. Verify the returned
`created_at` values fall in range and drop the strays.

## Project paths without extra calls

MR objects carry `references.full` (e.g. `group/subgroup/repo!975`). Use it
directly. Resolving `project_id` to a path via a second API call per MR is
wasted work.

## Scoping to a group

`merge_requests` searches everything visible to the token, which on a large
instance is slow. Scope when the user names a group:

```bash
glab api --paginate "groups/<GROUP_ID_OR_PATH>/merge_requests?author_username=<USERNAME>&created_after=<START>T00:00:00Z&per_page=100" | jq '...'
```

URL-encode nested group paths (`group%2Fsubgroup`).

## Output rows

```json
{"timestamp_utc": "2026-08-04T16:46:24Z", "action": "Created",
 "url": "https://gitlab.com/group/repo/-/merge_requests/975",
 "project": "group/repo", "author": "username", "title": "[INF-3686] Title"}
```

Deduplicate by `(url, action)`. GitLab timestamps are already UTC (`Z`) — no
conversion needed, unlike Slack.
