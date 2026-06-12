# humanizer

## Installation

```bash
claude plugin marketplace add langburd/agent-skills
claude plugin install humanizer@langburd
```

Remove signs of AI-generated writing from text. Based on Wikipedia's
"Signs of AI writing" guide. Detects and fixes inflated symbolism, em dash
overuse, AI vocabulary words, passive voice, rule-of-three phrasing, filler
phrases, and more.

## Skills

| Skill | Trigger |
|---|---|
| `humanizer` | "humanize this", "make this sound less AI", "remove AI patterns", "edit this text" |

## Usage

Point Claude at any text — a file, a selection, or text pasted directly:

```
Use the humanizer skill on this paragraph: …
Humanize docs/blog-post.md
```

The skill edits in place (uses `Read`/`Edit`) or rewrites inline depending on
what you give it.
