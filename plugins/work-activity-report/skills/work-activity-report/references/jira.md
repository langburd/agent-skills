# Jira Activity Reference

Commands for collecting one user's Jira activity in a date range.

## Tool choice: `acli` first, Atlassian MCP as fallback

`acli` (Atlassian's official CLI) is the primary tool. It wins on three
measured grounds:

- **`currentUser()` works in JQL.** When reporting on the authenticated user
  there is no need to resolve an email address at all. This removes the entire
  class of "guess the email format" failures.
- **`--fields` trims the payload.** Jira issue JSON is enormous by default.
  Restricting fields keeps responses small.
- **Output pipes to `jq`.** Cheap local filtering instead of returning bulk
  JSON into the model's context.

Use the Atlassian MCP (`searchJiraIssuesUsingJql`) only when `acli` is absent
or unauthenticated. It accepts the same JQL, so the queries below transfer
directly — only the invocation changes.

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

```bash
# Created in range
acli jira workitem search --jql "reporter = currentUser() AND created >= '<START>' AND created <= '<END> 23:59'" \
  --fields "key,summary,status,issuetype,created,project" --json --limit 100

# Assigned and touched in range
acli jira workitem search --jql "assignee = currentUser() AND updated >= '<START>' AND updated <= '<END> 23:59'" \
  --fields "key,summary,status,issuetype,updated,project" --json --limit 100

# Resolved in range
acli jira workitem search --jql "assignee = currentUser() AND resolved >= '<START>' AND resolved <= '<END_PLUS_1>'" \
  --fields "key,summary,status,resolutiondate,project" --json --limit 100

# Status transitions the user performed
acli jira workitem search --jql "status changed BY currentUser() DURING ('<START>', '<END_PLUS_1>')" \
  --fields "key,summary,status,updated,project" --json --limit 100
```

For **another user**, substitute the email. Everything else is identical:

```bash
acli jira workitem search --jql "assignee = '<EMAIL>' AND updated >= '<START>' AND updated <= '<END> 23:59'" \
  --fields "key,summary,status,updated,project" --json --limit 100
```

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

Set `date_only: true` for status transitions, where only the date is known.
Deduplicate by `(url, action)` — the queries overlap by design, since a ticket
created and resolved in the same range legitimately appears in both.
