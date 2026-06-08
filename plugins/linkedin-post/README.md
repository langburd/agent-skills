# linkedin-post

## Installation

```bash
claude plugin marketplace add langburd/agent-skills
claude plugin install linkedin-post@langburd
```

Turn any subject — a project, tool, skill, launch, blog, or milestone — into a
ready-to-publish LinkedIn post. Just ask Claude to write a LinkedIn post about
something and point it at the source (a repo, a `SKILL.md`, a feature, a note).

## What you get

| File | Role |
|---|---|
| `linkedin-post.html` | Browser preview styled like a LinkedIn card, with copy buttons that output exactly what LinkedIn receives (plain text, Unicode-bold, and the first comment). |
| `linkedin-image-prompt.md` | A model-agnostic prompt to paste into Gemini / Midjourney / DALL·E for the post's hero image. |

## Why an HTML file

LinkedIn strips all HTML on paste — the post box is plain text only. So the HTML
is a *preview and a copy tool*, not the thing you paste. The buttons handle the
LinkedIn realities for you:

- **Plain text** — clean and accessible, what most posts should use.
- **Unicode bold** — fake-bold via math glyphs (𝗯𝗼𝗹𝗱) that survive copy-paste,
  for a few key phrases. Screen-readers garble these, so it's used sparingly.
- **First comment** — the install command / repo link lives here, not in the post
  body, because LinkedIn suppresses reach on posts with external links in the
  body.

## Pieces

| Path | Role |
|---|---|
| `skills/linkedin-post/SKILL.md` | The workflow: research → write → fill HTML → write image prompt. |
| `skills/linkedin-post/assets/post-template.html` | The HTML preview template (copy-button engine). |
| `skills/linkedin-post/references/image-prompt-guide.md` | How to write the image prompt. |
