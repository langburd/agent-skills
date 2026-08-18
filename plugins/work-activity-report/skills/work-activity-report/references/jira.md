# Jira Activity Reference

Commands for collecting one user's Jira activity in a date range.

## Tool choice: both, for different jobs

Neither tool does the whole job. Use each for what it can actually do:

| Job | Tool | Why |
| --- | --- | --- |
| Find which tickets the user touched | `acli` | `currentUser()` in JQL removes email resolution entirely; output pipes to `jq` |
| Get timestamps for those tickets | Atlassian MCP `searchJiraIssuesUsingJql` | **`acli` cannot return them at all** |

This split is not a preference — it was measured. `acli jira workitem search`
rejects the timestamp fields outright:

```text
✗ Error: fields 'created, updated, resolutiondate, project' are not allowed
```

Its default field set (`issuetype,key,assignee,priority,status,summary`) has no
dates in it, and `acli jira workitem view <KEY> --json` returns `created`,
`updated`, and `resolutiondate` as `null` alongside the null `changelog`.

So: run the JQL below through `acli` to get the ticket keys cheaply, then make
one MCP call for the timestamps of those keys. If the MCP is unavailable, report
Jira activity date-only and say so — the tickets are still correct, only the
times are missing.

When `acli` is the unavailable one instead, the MCP accepts the same JQL and can
do both jobs alone.

## Identity

```bash
acli jira auth status
```

Returns the authenticated site and email:

```text
✓ Authenticated
  Site: your-org.atlassian.net
  Email: first.last@your-org.com
```

Both values matter. The email identifies the user; the **site** is what builds
ticket URLs (`https://<site>/browse/<KEY>`). Never hardcode a Jira domain —
read it here so the skill works for any org.

## Queries

For the **authenticated user**, prefer `currentUser()` — it needs no email and
cannot be wrong:

Keep `--fields` to the allowed set — `key,summary,status,issuetype,assignee`
works; adding date or project fields errors the whole query out. Derive the
project from the key prefix (`INF-3706` → `INF`) rather than requesting it.

```bash
# Created in range
acli jira workitem search --jql "reporter = currentUser() AND created >= '<START>' AND created <= '<END> 23:59'" \
  --fields "key,summary,status,issuetype" --json --limit 100

# Assigned and touched in range
acli jira workitem search --jql "assignee = currentUser() AND updated >= '<START>' AND updated <= '<END> 23:59'" \
  --fields "key,summary,status,issuetype" --json --limit 100

# Resolved in range
acli jira workitem search --jql "assignee = currentUser() AND resolved >= '<START>' AND resolved <= '<END_PLUS_1>'" \
  --fields "key,summary,status" --json --limit 100

# Status transitions the user performed
acli jira workitem search --jql "status changed BY currentUser() DURING ('<START>', '<END_PLUS_1>')" \
  --fields "key,summary,status" --json --limit 100
```

Pipe through `jq` to keep the payload small — even the allowed field set carries
avatar URL collections per user:

```bash
... --json --limit 100 | jq '[.[] | {key, summary: .fields.summary, status: .fields.status.name}]'
```

Then fetch timestamps for the collected keys in one MCP call:

```text
searchJiraIssuesUsingJql
  jql:    "key IN (INF-3706, INF-3705, INF-3701)"
  fields: ["key", "created", "updated", "resolutiondate"]
```

For **another user**, substitute the email. Everything else is identical:

```bash
acli jira workitem search --jql "assignee = '<EMAIL>' AND updated >= '<START>' AND updated <= '<END> 23:59'" \
  --fields "key,summary,status,issuetype" --json --limit 100
```

### `changed BY` needs an accountId, not an email

The `assignee`/`reporter` fields accept an email, but the `BY` predicate does
not. `status changed BY '<EMAIL>'` fails with:

```text
the user '<EMAIL>' does not exist and cannot be used in the 'by' predicate
```

Use `currentUser()` for the authenticated user. For anyone else, resolve their
Atlassian accountId first — the Atlassian MCP's `lookupJiraAccountId` does this
directly — then:

```bash
acli jira workitem search --jql "status changed BY '<ACCOUNT_ID>' DURING ('<START>', '<END_PLUS_1>')" \
  --fields "key,summary,status,updated,project" --json --limit 100
```

If the accountId cannot be resolved, drop this query rather than guessing, and
note in the report that transitions were not covered for that user. A dropped
query with a note is recoverable; a silently empty one is not.

## Resolving another user's email

Only needed when reporting on someone else. Two reliable routes, in order:

1. **Ask.** One question beats several failing queries.
2. **Look them up in Jira directly** rather than guessing a format:

   ```bash
   acli jira workitem search --jql "assignee is not EMPTY AND assignee ~ '<PARTIAL NAME>'" \
     --fields "assignee" --json --limit 5 | jq -r '.[].fields.assignee | .emailAddress // .displayName' | sort -u
   ```

Deriving an email by string-munging a display name is a last resort. Name
order varies by directory ("Doe John" vs "John Doe"), display names diverge
from Jira accounts, and each wrong guess costs a query that returns a
misleading empty result. If you do fall back to guessing, validate with a
`--limit 1` query before running the full set, and treat an empty result as
"wrong email" rather than "no activity".

## Known limitation: no per-transition timestamps

`acli jira workitem view <KEY> --json` returns a `changelog` key, but the API
leaves it **`null`**. There is no changelog/history subcommand.

The practical consequence: you can learn *that* a user moved a ticket during a
range (via `status changed BY ... DURING`), but not the exact minute. Report
Jira transitions at date granularity and say so, rather than borrowing the
ticket's `updated` timestamp and presenting it as the transition time — that
timestamp reflects the most recent change by anyone, so it is frequently just
wrong.

If exact transition times genuinely matter, the Atlassian MCP's
`getJiraIssue` with changelog expansion is the only route, at significantly
higher token cost per ticket. Worth it for a handful of tickets, not for a
weekly sweep.

## Output rows

Return one row per distinct action:

```json
{"timestamp_utc": "2026-08-18T08:30:00Z", "date_only": false, "action": "Created",
 "url": "https://your-org.atlassian.net/browse/PROJ-1234", "project": "PROJ",
 "title": "Ticket summary"}
```

Which actions carry a real time, and which do not:

| Action | Source field | Time available? |
| --- | --- | --- |
| Created | `created` (via MCP) | Yes — full timestamp |
| Updated | `updated` (via MCP) | Yes — full timestamp |
| Resolved | `resolutiondate` (via MCP) | Yes — full timestamp |
| Status changed | none (changelog is null) | **No — date only** |

The first three come from the MCP timestamp call, not from `acli`. Copy the
value through as returned and convert to UTC — Jira sends an offset (e.g.
`2026-08-18T11:30:00.000+0300`), and the offset it uses does not necessarily
match the user's own profile timezone, so read it rather than assuming.

Two failure modes to avoid, both of which produce a confident wrong report:

- **Don't zero-fill an unknown time.** `"2026-08-18T00:00:00Z"` with
  `date_only: false` claims the work happened at midnight, and the merged report
  will sort it there. If only the date is known, set `date_only: true` and leave
  `timestamp_utc` as the bare date.
- **Don't mark a known time as date-only.** Created, Updated, and Resolved all
  have real timestamps; discarding them costs the report its chronology, which is
  the main thing it exists to show.

Deduplicate by `(url, action)` — the queries overlap by design, since a ticket
created and resolved in the same range legitimately appears in both. An
`Updated` row is only worth emitting when no more specific action for that
ticket exists on the same day; otherwise it restates the Created or Resolved row.
