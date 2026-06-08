# cv-achievements

Generate CV achievement bullets for a job entry from your real GitHub PR
activity. Reusable for any GitHub user, any org, and any job.

## Pieces

| File | Role |
|---|---|
| `fetch-prs.sh` | Fetches PR activity into JSON. Run it yourself. |
| `SKILL.md` | Claude skill: reads the JSON and prints candidate bullets for review. |

The script does all GitHub I/O. The skill does all analysis. They share only the
JSON file — neither calls the other.

## Prerequisites

- [`gh`](https://cli.github.com/) installed and authenticated: `gh auth status`.
  Your token needs `repo` read scope for the target org.
- [`jq`](https://jqlang.github.io/jq/) installed.

## Step 1 — Fetch your PRs

```bash
fetch-prs.sh --author <github-user> --org <org>
```

| Flag | Required | Default | Meaning |
|---|---|---|---|
| `--author` | yes | — | GitHub username to fetch PRs for |
| `--org` | yes | — | GitHub org/owner to scope to |
| `--mode` | no | both | `authored-all` or `reviewed`; omit for both |
| `--out` | no | `.cv-data` | output base directory; files land under `<out>/<org>/<author>/` |

Output (gitignored, never committed):

- `.cv-data/<org>/<author>/prs-authored.json` — PRs you opened → "led / built" voice.
- `.cv-data/<org>/<author>/prs-reviewed.json` — PRs by others that you reviewed → "participated" voice.

## Step 2 — Generate bullets

Ask Claude to use the `cv-achievements` skill and point it at the output directory:

> Use the cv-achievements skill on `.cv-data/acme/octocat/`.

The skill reads both JSON files, analyzes the PRs, and prints candidate bullets
(3–6, scaled to the role). It does **not** edit your CV.

## Step 3 — Insert into the CV (manual)

Review/edit the printed bullets, then add the ones you want under the relevant
job entry yourself. This pipeline stops at "here are the candidate bullets."
