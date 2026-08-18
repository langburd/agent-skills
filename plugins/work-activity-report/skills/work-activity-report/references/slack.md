# Slack Activity Reference

Collecting a user's Slack participation for an activity report.

## Privacy first

This source is different in kind from the others. A PR is a work artifact
intended to be seen; a DM is a private conversation that may cover people,
compensation, incidents, or health. Activity reports get pasted into standups,
shared with managers, and dropped into performance reviews.

So the default is **metadata only for DMs and group DMs**: who, how many
messages, which day. No message text. Channel activity — which is already
visible to everyone in the channel — can include topic detail.

Include DM content only when the user asks for it in that specific invocation
("include what we discussed in DMs"). Standing permission is not a thing here;
each report is a fresh decision, because each report may have a different
audience. If a DM turns out to be materially work-relevant, name the
conversation and let the user decide whether to open it.

Search results make this easy to enforce — the result label distinguishes
`DM with Alice, Bob` from `#channel-name` directly, so no extra call is needed
to classify a hit.

## Tool

The Slack MCP `slack_search_public_and_private` covers public channels, private
channels, DMs, and group DMs in one interface. There is no CLI equivalent and
no "list all my activity" endpoint — this is search-only.

Identity:

```text
slack_read_user_profile   # no user_id → returns the authenticated user
```

## Timestamps are in local time, not UTC

Results come back in the workspace/user timezone (e.g. `2026-08-18 16:19:48
IDT`), while every other source in this report is UTC. Convert before merging,
or Slack rows will sit hours away from the PRs they relate to and the
chronology will quietly mislead. Note the offset you applied.

## The sweep

Search is capped at **20 results per call** with cursor pagination. Exhaustive
coverage of a chatty week is many calls, so the default is a bounded sweep:
a fixed set of targeted searches, each 1–2 pages.

Always use explicit `after:`/`before:` modifiers rather than relying on
relevance ordering to approximate a date range — relevance sorting will happily
return last month's message.

Note `after:`/`before:` are **exclusive**, so widen by a day on each side and
filter the returned timestamps.

```text
# Messages the user sent
query: "from:me after:<START_MINUS_1> before:<END_PLUS_1>"
sort: "timestamp", limit: 20, include_context: false, response_format: "concise"

# Messages directed at the user
query: "to:me after:<START_MINUS_1> before:<END_PLUS_1>"

# Mentions of the user by others
query: "<@USER_ID> after:<START_MINUS_1> before:<END_PLUS_1>"

# Threads the user took part in
query: "from:me is:thread after:<START_MINUS_1> before:<END_PLUS_1>"
```

`include_context: false` and `response_format: "concise"` matter — context
messages multiply the response size several-fold and are not needed to
establish participation.

For another user, swap `from:me` → `from:<@USER_ID>` and drop the `to:me`
search (their DMs are not yours to read, and the API will correctly refuse).

## Report caps honestly

When a search hits its page cap and a cursor remains, say so in the output:
`Slack: bounded sweep, 4 searches × 2 pages; #busy-channel truncated`.

An unstated cap reads as "that was everything", which turns a sampling
limitation into a false claim about someone's week. Follow the cursor further
only when the user asks for exhaustive coverage.

## Output: topics, not a chat log

Every message as a row is noise — nobody's standup needs "Thank you" at
16:19:48. Group by conversation and report the user's role in it.

```json
{"date": "2026-08-18", "channel": "#cloud-infrastructure-public",
 "is_private_dm": false, "topic": "Terraform state lock troubleshooting",
 "role": "Answered", "message_count": 4,
 "permalink": "https://org.slack.com/archives/C05.../p178..."}
```

Roles: Raised, Answered, Decided, Participated, Mentioned.

For DMs, omit `topic` and set `channel` to participant names only:

```json
{"date": "2026-08-18", "channel": "DM with Kevin Gardiner",
 "is_private_dm": true, "role": "Participated", "message_count": 2}
```

Derive the topic from channel messages you are already returning — don't spend
extra calls fetching thread bodies purely to label a topic. Use
`slack_read_thread` only when a thread is clearly central to the day's work and
its subject cannot be inferred from the matched message.

Two details worth getting right:

- **Permalinks are best-effort.** Search results embed one only sometimes. Emit
  the permalink when the result carries it and omit the field otherwise — don't
  spend a call per row chasing one, and don't emit a constructed URL you haven't
  verified.
- **Skip the user's self-DM.** A DM whose only participant is the user is a
  personal scratchpad, not a conversation with anyone. Counting it inflates the
  collaboration picture.

Return timestamps as the search gave them, tagged with their zone (e.g.
`local_time: "16:19:48", local_tz: "IDT"`), and let the caller convert. Relabeling
local time as UTC yourself is the one error here that cannot be caught later.
