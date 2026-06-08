---
name: linkedin-post
description: Use when the user wants to write, draft, or create a LinkedIn post — to announce a project, tool, skill, launch, blog, feature, milestone, or any subject they want to share professionally. Triggers on "write a LinkedIn post", "post this on LinkedIn", "draft a LinkedIn announcement", "make a LinkedIn post about X", or when someone has built/shipped something and wants to share it on LinkedIn. Produces a browser-openable HTML preview with copy buttons (plain text + Unicode-bold + first-comment) and a separate model-agnostic image-generation prompt as a .md file. Use even if they don't say the word "LinkedIn" but clearly want a professional social post for a dev/work audience.
---

# LinkedIn Post

Turn a subject into a finished LinkedIn post the user can publish in minutes. Two
deliverables:

1. **`linkedin-post.html`** — a LinkedIn-styled preview the user opens in a
   browser and copies straight into the post box. Copy buttons output exactly
   what LinkedIn receives.
2. **`linkedin-image-prompt.md`** — a prompt the user pastes into an
   image-generation model (Gemini, Midjourney, DALL·E, etc.) to make the post's
   hero image.

Always produce both unless the user says they only want one.

## Why the format is the way it is

LinkedIn is a hostile target and these constraints drive every choice below.
Understanding them lets you adapt instead of following rules blindly:

- **LinkedIn strips all HTML on paste.** The post box is plain-text only. So a
  rendered HTML file is a *preview and a copy tool*, never the thing that gets
  pasted. Bold/headers/colors don't survive — only real characters do.
- **It truncates after ~2–3 lines** with a "…see more" fold. The first two lines
  must carry the hook and stand alone, or the post dies in the feed.
- **It suppresses posts with external links in the body** (off-platform links =
  less reach). The fix everyone uses: put the link in the *first comment* and
  point to it from the body.
- **There's no native bold in the desktop composer.** The only way to get
  emphasis that survives copy-paste is Unicode "math" glyphs (𝗯𝗼𝗹𝗱) — real
  characters, not formatting. Tradeoff: screen-readers garble them, so use them
  sparingly on a few key phrases, never whole paragraphs.

## Workflow

### 1. Understand the subject

Read whatever the subject is — a skill's `SKILL.md`, a repo's README, a feature
diff, a blog draft, a launch note. Get concrete: what does it actually *do*, what
problem does it kill, what's the one non-obvious mechanism that makes it clever?
Generic posts ("excited to announce…") are worthless; specifics are the whole
value. If the subject is thin, ask the user one or two sharp questions rather
than inventing details.

If the user gives facts (numbers, names, URLs), use them verbatim and don't
embellish. **Never invent metrics, dates, or specifics** — a made-up "saved 40%"
or a fake-precise reference reads as data when it isn't, and erodes trust the
moment a reader checks. (In the reference example, an invented `PR #2,184` had to
be fixed twice; don't repeat that.)

### 2. Write the post body

Structure that works (adapt, don't force):

- **Hook (lines 1–2):** a sharp, specific claim or reframe that makes someone
  stop scrolling — and that stands alone, because everything after line 2 is
  hidden behind "…see more". Avoid "I'm excited to share". Lead with the idea,
  the tension, or the surprising truth.
- **The problem / why it matters:** ground the reader in a pain they recognize.
- **What it is:** one or two sentences, plainly.
- **How it works / what's good:** 3–4 emoji-led bullets (🔹 reads clean on
  LinkedIn). Each bullet = one concrete capability with a *why it's clever*, not
  a feature list. Bold the opening phrase of each (this becomes Unicode-bold).
  Pick the 3–4 *most* interesting points and cut the rest — a tight post that
  someone finishes beats a thorough one they abandon at the fold. Go to 5 only
  when the subject genuinely has that many distinct, surprising ideas that each
  earn their line; never pad to hit a number.
- **A grounding/honesty beat:** what it deliberately doesn't do, or where the
  human stays in control. This reads as confidence, not hedging.
- **Link pointer:** if there's an install command, repo, or URL, do **not** put
  it in the body. Replace it with a one-line pointer: *"It's open source —
  install command + repo in the first comment 👇"*.
- **Engagement question:** one question that invites replies (comments drive
  reach more than likes). Just one ask — don't stack it with "please star".
- **Hashtags:** 5–8 relevant ones on the last line.

Use one 👇 at most, on the comment pointer. Keep paragraphs short — walls of text
lose mobile readers.

**Keep the whole post short.** Reader attention is the budget, and dropoff after
the "…see more" fold is steep. Aim for something a person finishes in one breath:
a tight hook, a sentence or two of problem, a sentence of what-it-is, 3–4
bullets, the honesty beat, the question. If a paragraph isn't pulling its weight,
cut it. Length is a cost, not a signal of effort.

### 3. Write the first comment

The external link lives here. Keep it short:

- The install command / repo URL / link the body pointed to.
- An optional soft, low-key ask (*"⭐ if it helps"*) — comment only, never the
  body. A direct "please star my repo" in the post reads as begging and lowers
  perceived value; in the comment it's fine.

### 4. Build the HTML preview

Read `assets/post-template.html` and fill the `{{PLACEHOLDERS}}`. Don't rewrite
the file — the copy-button JavaScript (Unicode-bold glyph mapping, plain/comment
copy, `file://` clipboard fallback, line-break preservation) is the reusable
engine and must stay byte-for-byte. Only replace placeholders:

| Placeholder | Fill with |
| --- | --- |
| `{{POST_TITLE}}` | short title for the browser tab |
| `{{AUTHOR_NAME}}` | the user's name (ask if unknown; or a sensible default) |
| `{{AVATAR_INITIALS}}` | 1–2 initials from the name |
| `{{POST_BODY}}` | the full post, with HTML conventions below |
| `{{FIRST_COMMENT}}` | the first-comment text |

**Inside `{{POST_BODY}}`:**

- It sits in a `white-space: pre-wrap` div, so **real newlines** between
  paragraphs render as written — use actual line breaks, not `<br>`.
- Wrap each phrase you want emphasized in `<b>…</b>`. The "Copy with Unicode
  bold" button converts only these to glyphs. Bold the lead phrase of each
  bullet and maybe one phrase in the hook — not whole sentences.
- Put the hashtag line in `<span class="tags">…</span>` so it renders blue in the
  preview and stays plain (un-bolded) in both copies.
- Use the emoji bullets (🔹) directly as text.

Save as `linkedin-post.html` next to the subject (or where the user asks), then
open it: `open linkedin-post.html` (macOS) so the user sees it immediately.

The preview shows two stacked cards (post + first comment) and three copy
buttons: **plain text**, **Unicode-bold**, **first comment**.

### 5. Write the image prompt

Create `linkedin-image-prompt.md`. Aim for one strong conceptual illustration
that reads at thumbnail size. The metaphor matters more than the polish: a clear
left→right "before → after" transformation, or a single visual that captures the
core idea. Build it from `references/image-prompt-guide.md` — read that file for
the full template, the negative-prompt list, aspect-ratio/crop-safety rules, and
the model-specific notes (including Gemini's watermark). Keep the prompt
model-agnostic in the main block; put model quirks in a notes section.

## Quality bar

- The first two lines work as a standalone hook — read them in isolation and ask
  "would this stop me scrolling?"
- The post is short — 3–4 bullets, no padding. If you could cut a paragraph
  without losing a real idea, cut it.
- Every claim traces to a real fact about the subject. Zero invented numbers.
- Bullets are specific and explain *why*, not just *what*.
- The external link is in the comment, not the body.
- The HTML opens in a browser and all three copy buttons produce clean output.

## Reference example

The `cv-achievements` post that seeded this skill lives at
`plugins/cv-achievements/linkedin-post.{md,html}` and
`plugins/cv-achievements/linkedin-image-prompt.md` in this repo — a worked
example of the hook, the bullet voice, the comment split, and the image prompt.
Read it when you want a concrete model of the target quality.
