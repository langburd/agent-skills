# Image Prompt Guide

How to write `linkedin-image-prompt.md` — the prompt the user pastes into an
image model to make the post's hero image. Model-agnostic core; model quirks in a
notes section at the end.

## Goal

One conceptual illustration that reads instantly at LinkedIn thumbnail size. The
**metaphor carries the image**, not the rendering polish. The strongest pattern
is a left→right transformation that mirrors the post's own arc: messy input on
the left → some transforming element in the center → polished output on the
right. If the subject isn't a "transformation", find the single image that
captures its core idea (a funnel, a bridge, a lens, a key).

## Structure of the .md file

Produce a file with these sections:

```markdown
# Image Generation Prompt — <subject> LinkedIn post

For any image model. Paste the main prompt directly. LinkedIn aspect ratios:
**1.91:1** (1200×627) for the in-feed link/share image, or **1:1** (1080×1080)
for a square feed post.

## Primary prompt

> <one dense paragraph — see "Writing the primary prompt" below>

## Composition note (LinkedIn crop)

> <safe-margin instruction — see below>

## Negative / avoid

- <list — see below>

## Variations to try

| Variant | Tweak to append |
| --- | --- |
| ... | ... |

## Model notes

- <Gemini / Midjourney / DALL·E quirks — see below>
```

## Writing the primary prompt

One dense paragraph. Be concrete about composition, because vague prompts produce
generic art. A reliable skeleton:

> A clean, modern conceptual illustration for a [audience] LinkedIn post,
> [aspect-ratio] wide format. LEFT THIRD: [the messy/raw input, described with
> specific recognizable elements]. CENTER: [the transforming element], where
> [what visibly happens]. RIGHT THIRD: [the polished output, tied back to the
> input so the transformation reads]. Style: flat-modern vector illustration with
> subtle depth and soft gradients, generous negative space, professional and
> optimistic. Color palette: [2–3 colors, e.g. deep indigo-to-slate background
> with warm amber and electric teal accents]. No real text, no readable words —
> abstract shapes and icon glyphs only. No logos, no watermark, no signature
> mark. High detail, crisp edges, tech-blog hero quality.

Tips:

- Name **specific, recognizable glyphs** for the audience (e.g. a Terraform `.tf`
  tag, a Docker whale, a git branch icon) — they signal a real domain instead of
  generic clip-art.
- Spell out the *mapping* if there is one ("each input element terminates at its
  own output point") — that's what makes the metaphor legible.
- Naming the layout in thirds (LEFT/CENTER/RIGHT) makes models place elements
  predictably.

## Composition note (LinkedIn crop)

LinkedIn's 1.91:1 link preview crops the sides hard. Keep the focal element
dead-center and pull side elements inward so nothing essential gets clipped.
Include this safety instruction in the file:

> Compose with safe margins: focal element centered, side elements pulled toward
> the middle third, ample empty background on the far left and far right so a
> center crop loses nothing essential.

## Negative / avoid (default list)

- No gibberish or fake-language text — garbled words read as low-effort, and
  crops chop them mid-word.
- No watermark, signature, or model-badge mark in any corner.
- No literal human faces or stock-photo people.
- No corporate-cliché handshake / lightbulb imagery.
- No cluttered background — preserve negative space for optional overlay text.

## Variations to try (offer 3–4)

Give the user a few one-line append-able tweaks so they can re-roll without
rewriting, e.g.:

| Variant | Tweak to append |
| --- | --- |
| Calmer / corporate | "Mute the palette to a soft two-tone split instead of a full spectrum." |
| Darker / terminal | "Near-black background with faint neon circuit traces." |
| Isometric | "Render as a 3D isometric scene on a grid platform." |
| Square (feed post) | "Compose for a 1:1 square crop, focal element centered." |

## Model notes

Keep the primary prompt model-agnostic. Add a notes section for quirks:

- **Generate at the target aspect ratio from the start** — don't upscale/crop a
  square into 1.91:1; you lose the composition.
- **If the model still renders text**, append: "all labels are abstract icon
  glyphs, zero alphabetic characters."
- **Gemini (Imagen / "Nano Banana"):** stamps a visible ✨ sparkle in the
  bottom-right corner and embeds an invisible SynthID watermark. Crop the visible
  badge before posting (the invisible one can't be removed and is irrelevant for
  posting). Easiest crop on macOS — keep the top-left region and drop the corner:

  ```bash
  # WxH+Xoffset+Yoffset — trims the bottom-right corner where the ✨ sits
  magick input.png -crop 2660x1360+0+0 +repage output.png   # adjust to your image size
  # or, no ImageMagick: open in Preview, drag-select all but the corner, ⌘K crop, ⌘S
  ```

  Generating at a wider aspect ratio puts the badge in margin you'd crop for
  LinkedIn anyway.
- **Midjourney / DALL·E:** no visible watermark; `--ar 1.91:1` (MJ) or request
  the aspect ratio directly. They tend to add text unless told not to — keep the
  "no readable words" negative.

## Pick-the-winner rule

When the user shows you candidate renders, judge on the **metaphor read** first
(does the left→right / core-idea transformation land?), then legibility at
thumbnail size, then polish. The clearest-reading candidate beats the prettiest
one — the image's job is to communicate the post's idea in a feed.
