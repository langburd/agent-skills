---
name: cv-achievements
description: Use when turning a GitHub user's PR activity into CV achievement bullets for a job entry. If given no data path, it fetches the PRs itself via the bundled fetch-prs.sh (needs gh + jq); if given a JSON file or directory it analyzes that instead. Processes both authored and reviewed PRs in one pass, prints the bullets, and saves them to a timestamped results file beside the data. Does not edit the CV itself.
---

# CV Achievements

Turn PR-activity JSON into a handful of CV achievement bullets (3–6 for most
roles, up to 7 for a long multi-year tenure with many distinct themes, scaled to
the role) for one job entry. Given a directory, this means the authored PRs plus
one reviewed-voice collaboration bullet — one combined list, printed and saved to
a timestamped `results-<stamp>.md` beside the input.

## Input contract

The user supplies a path produced by `fetch-prs.sh` — either ONE JSON file or the
`<out>/<org>/<author>/` **directory** that holds `prs-authored.json` and/or
`prs-reviewed.json`. Its shape:

```json
{ "generated_at": "...", "mode": "authored-all|reviewed",
  "author": "...", "org": "...",
  "incomplete": false, "incomplete_reasons": [],
  "pr_count": 0, "prs": [ ... ] }
```

When given a path, this skill analyzes existing data without fetching. When no
path is given, see Step 0 — it fetches the data for you via the bundled script.

**If the path is a directory** (or both files exist): process **both** files in
one pass. `prs-authored.json` is the spine — ownership voice is the stronger CV
claim, so it produces the bulk of the bullets. `prs-reviewed.json` then
contributes **exactly one** distinct collaboration/gatekeeping bullet appended to
the same list (see the reconciliation note in Step 3). Analyze each file in its
own `mode` (Step 1) — never blend their themes into one bullet — but deliver a
single combined list, not two separate sets the user has to stitch together.

If only one file is present, process that one and skip the other voice.

When `incomplete` is `true`, read `incomplete_reasons` and calibrate the warning
to the reason — do not blanket-warn (see the table below). Always print the
reasons so the user can judge.

| Reason pattern | Impact on bullets | What to tell the user |
|---|---|---|
| `file list truncated at 100 files` / `commit list truncated` | **Low** — `pr_count`, titles, labels intact; theme detection unaffected. Only the few huge PRs understate breadth. | One line: those N PRs are large; breadth is slightly undercounted. Proceed. |
| result cap / search-window / query truncation (whole PRs missing) | **High** — the dataset is genuinely partial. | Tell the user up front, suggest a narrower re-fetch before trusting counts; don't present bullets as a full account. |

## Step 0 — Acquire data

This skill can now fetch its own data. The bundled `fetch-prs.sh` lives beside
this file; reference it as `"$CLAUDE_SKILL_DIR/fetch-prs.sh"` so it resolves
regardless of the current working directory or where the plugin is installed.

**Path A — the user gave an explicit path** (a JSON file or a
`<out>/<org>/<author>/` directory): use it as-is and skip fetching. This
preserves the original input contract.

**Path B — no path was given:** acquire the data, then proceed.

1. Gather inputs:
   - `--author` (GitHub username) — required, ask if missing.
   - `--org` (GitHub org/owner) — required, ask if missing.
   - Mode defaults to BOTH datasets (omit `--mode`). Output dir defaults to
     `.cv-data` (relative to the current working directory).

2. Resolve and show the target directory: `./.cv-data/<org>/<author>/`. Print the
   absolute path it resolves to (run `pwd` if needed) so the user sees exactly
   where data will be written — their workspace, never the plugin cache. Let them
   override the location before any write.

3. Probe existing data **per file** in that directory — check
   `prs-authored.json` and `prs-reviewed.json` independently:
   - **Neither present** → both will be fetched.
   - **A file is present** → read its `generated_at` and report the age
     (e.g. "authored: fetched 12 days ago"). Read its `incomplete` flag; if
     `true`, also report `incomplete_reasons` so the user can judge.
   - **Only one present** → offer to fetch just the missing one.

   Then ask the user how to proceed: **reuse as-is** / **re-fetch (overwrite)** /
   **fetch only the missing dataset**. Suggest a default from age and the
   `incomplete` flag — stale (e.g. weeks old) or incomplete data leans toward
   re-fetch; fresh complete data leans toward reuse.

4. **Preflight — only if a fetch will actually run.** Verify prerequisites and
   STOP with the exact fix if any is missing (never auto-install):

   ```bash
   command -v gh   >/dev/null || echo "Install GitHub CLI: https://cli.github.com"
   gh auth status  >/dev/null 2>&1 || echo "Authenticate: run  gh auth login"
   command -v jq   >/dev/null || echo "Install jq: https://jqlang.github.io/jq/"
   ```

   If any check fails, report the matching fix and stop — do not run the script.

5. Run the script for whichever datasets need fetching:

   ```bash
   # Fetch both (default):
   bash "$CLAUDE_SKILL_DIR/fetch-prs.sh" --author <a> --org <o> --out .cv-data

   # Fetch only the missing one:
   bash "$CLAUDE_SKILL_DIR/fetch-prs.sh" --author <a> --org <o> --mode authored-all --out .cv-data
   bash "$CLAUDE_SKILL_DIR/fetch-prs.sh" --author <a> --org <o> --mode reviewed     --out .cv-data
   ```

   Re-fetch is a clean overwrite — the script recreates each dataset file in full,
   so no merge handling is needed.

6. Hand the resulting `./.cv-data/<org>/<author>/` directory to Step 1 and
   continue exactly as for a user-supplied directory.

## Step 1 — Read mode, pick voice

Read the top-level `mode` field:

| mode | Meaning | Voice (verbs) |
|---|---|---|
| `authored-all` | Work the author led/built | Ownership: Designed, Led, Built, Architected, Migrated, Automated |
| `reviewed` | Work the author joined as a team member | Contribution: Contributed to, Participated in, Supported, Helped deliver |

## Step 2 — Analyze prs[]

Bodies are usually empty and titles carry the ticket-style summary
(e.g. `INF-3184 Add new image versions for metrics-server and cluster-autoscaler`).
So the title tells you *what* a PR did; `files[]` tells you *which technology and
which subsystem* — the part a bullet needs to name a stack and group related work.
Use them together, with `files[]` as the sharpening signal, not the lead.

### 2a — Detect the tech stack from file extensions and paths

A PR's file extensions are a reliable fingerprint of the technology, even when the
title is terse. Map them to the stack you'd actually name on a CV:

| Signal in `files[].name` | Technology to name |
|---|---|
| `.tf`, `.hcl`, `.tftpl`, `.tf.json` | Terraform / Terragrunt (IaC) |
| `.ts` + `cdktf.json` under a CDK/infra path | CDKTF (TypeScript IaC) |
| `.yaml`/`.yml` under `playbooks/`, `roles/`, `inventory/` | Ansible |
| `.yaml`/`.yml` with k8s kinds, `charts/`, `Chart.yaml`, `values.yaml` | Kubernetes / Helm |
| `.github/workflows/*.yml` | GitHub Actions CI/CD |
| `.gitlab-ci.yml`, `.gitlab/` | GitLab CI |
| `*.sentinel`, `policies/`, `sentinel.hcl` | Policy-as-code / governance |
| `Dockerfile`, `*.dockerfile` | Docker / container images |
| `argocd/`, `applicationset`, `*.app.yaml` | ArgoCD / GitOps |
| `.go`, `go.mod`, `go.sum` | Go (compiled services / CLI tooling) |
| `.py` under `services/<name>/`, `adapters/`, `plugins/`, with `pyproject.toml`/`Pipfile` | Python application / backend service |
| `.py`, `.sh` as standalone scripts (`scripts/`, `tasks/`, root) | Python / Bash tooling and automation |
| `.vue`, `.jsx`/`.tsx`, `.scss`/`.css`, `.svelte` (genuine authorship — see caution below) | Frontend (Vue / React / etc.) |

Treat this as a starting map, not a closed list — these examples skew toward infra
because that's one author's stack, but the method is stack-agnostic: read whatever
the files plainly indicate (Go, Rust, Java, frontend, data pipelines, …) and name the
technology the *bulk* of a cluster's files point to.

Two judgment calls the extensions alone won't make:

- **Application vs. script.** `.py`/`.go` under a named `services/<name>/` (or
  `adapters/`, `plugins/`) directory, especially with build/manifest files, is a
  *shipped service* — a stronger CV claim than a one-off script in `scripts/`. The
  path tells you which; name it accordingly ("built a service" vs "wrote tooling").
- **Authored vs. generated/synth output.** Not every file in a PR was hand-written.
  Generated and vendored files inflate counts without proving skill: CDKTF emits
  `cdktf.out/*.json` (and `*.tf.json`) from a small `.ts` change; lockfiles
  (`*.lock.hcl`, `package-lock.json`, `go.sum`), a `terraform fmt` sweep, or a
  bulk `.vue`/`.tsx`/`.scss` rename all balloon file/line totals. Weigh the
  *authored source* — count the `.ts`/`.go`/`.py`/`.tf` a human wrote, not the
  emitted artifacts. A surge of generated or moved files in a *single* PR is the
  tell; confirm a real skill with the per-PR count of authored files across
  *several* PRs (the `any()` pattern below), not the raw file tally — one 30-file
  rename or a 500-file synth dump becomes a fake "major effort" otherwise.

### 2b — Cluster the work

- **Primary cluster key: top-level path prefix**, then `repository`. The directory a
  PR touches is usually the project boundary — `ecr/images/` + `ecr/charts/` is one
  "container image / ECR management" theme; `playbooks/` is an Ansible-automation
  theme; `.github/workflows/` is a CI theme — even across PRs with unrelated titles.
- Within a path cluster, group by recurring themes in `title` / `labels`.
- **Also cluster by named subject across repos/paths.** A single accomplishment
  often spans several locations: a service named `foo` might appear as app code in
  `services/foo/`, a `charts/foo/` Helm chart, an `argocd/foo` manifest, and the
  `deployments/foo` Terraform that runs it — across two or three repos. When the same
  name recurs, that's *one* end-to-end "designed, built, and shipped X" theme, a
  strong CV bullet. Don't fragment it into a separate bullet per repo.
- Merge clusters that describe the same accomplishment; a bullet is a *theme*, not a PR.

When counting how many PRs fall in a cluster with `jq`, match at the PR level with
`any(...)`, not a bare `.files[]` predicate — the latter iterates files and counts a
PR once *per matching file*, badly inflating large clusters. Use:
`[ .prs[] | select(any(.files[]?.name; test("^deployments/cloudflare"))) ] | length`

Starter recon block — run these first to surface clusters before reading titles
(`$F` = the JSON path):

```bash
# repos and tenure window
jq -r '[.prs[].repository]|group_by(.)|map({r:.[0],n:length})|sort_by(-.n)|.[][]' "$F"
jq -r '[.prs[].mergedAt // .prs[].createdAt]|min,max' "$F"
# PR-level histogram of top-level path prefixes (NOT file-level — see any() above)
jq -r '[.prs[]|[.files[]?.name|split("/")[0]]|unique[]]|group_by(.)|map({p:.[0],n:length})|sort_by(-.n)|.[][]' "$F"
# count PRs matching one cluster regex
jq -r '[.prs[]|select(any(.files[]?.name; test("REGEX")))]|length' "$F"
```

Note the inner `unique` in the histogram — it dedups paths *within* a PR so each
PR contributes at most once per prefix (a file-level `split` would re-inflate).

### 2c — Weight clusters (what's CV-worthy)

- **Breadth of meaningful change** is the strongest signal: distinct non-trivial
  files across multiple repos/subsystems > one large auto-generated or vendored file.
- Then: PR count in the cluster, recency (`mergedAt`/`createdAt`), and presence of
  governance/quality artifacts (`*.sentinel`, `CODEOWNERS`, `.pre-commit-config.*`)
  which signal "established standards/compliance," a CV-worthy theme in itself.
- Treat raw `additions`+`deletions` as a *weak* proxy only — a 2000-line diff can be
  a single `terraform fmt` or a lockfile regen. Let `files[]` sanity-check linecounts.

### 2d — Discard noise

A PR is noise if `files[]` and `title` show no substantive change. Drop it when:

- Every file is config/lint/format/test scaffolding only — matches just
  `.pre-commit-config.*`, `.yamllint`, `.yamlfmt`, `.editorconfig`, `*.md`, or `test_*`.
- It's a dependency/version bump, a revert, or a typo/whitespace fix.
- The title flags it as non-work: `DO NOT MERGE`, `Test`, `WIP`, `Fix mistake`,
  `Revert`, `bump`.

### 2e — Grounding

For thin/empty `body`, infer the change from `files[].name` + `commits[].message` +
diffstat — and state only what those plainly support. Name the stack and subsystem
(files prove those); do **not** invent outcomes (cost %, SLA, audit results) that the
data cannot show. If a cluster's impact is unclear, describe the work plainly.

## Step 3 — Produce bullets

- Aim for 3–6 bullets, scaled to tenure and signal. A short stint or thin
  dataset should get fewer (2–3); a multi-year role carries 5–6. A long tenure
  (5+ years) with many genuinely distinct themes can run to 7 — but only when
  each extra bullet is its own real accomplishment, not padding. The rule is
  one-bullet-per-theme, not a target count: if merging two thin themes reads
  stronger, merge them; never split one accomplishment to hit a number.
- Match the existing `index.md` job-entry style: `-` bullets, action-verb first, past tense, impact-oriented.
- No PR numbers, no URLs, no repo names in the bullet text.
- Each bullet = one distinct theme. Merge overlapping clusters.
- Use the voice chosen in Step 1.
- Ground every claim in the data. State only impact you can support from
  titles, labels, files, commit messages, and diffstat. If a cluster's impact is
  unclear, describe the work plainly rather than inventing an outcome.

**Reconciling `authored` and `reviewed`.** When both modes exist for the same
author, their themes usually *mirror* — the person who builds a subsystem also
reviews changes to it. So the authored bullets carry the work, and the reviewed
file contributes **one** bullet only: the distinct
collaboration/mentorship/gatekeeping point that ownership voice can't make on its
own (e.g. "core reviewer for the platform — vetted ~N pull requests across the X
and Y codebases to uphold quality standards"). Ground it in what the reviewed data
*supports*: review volume (`pr_count`) and repo/path breadth are solid; do not
claim "reviewed N distinct contributors" unless the data carries a per-PR author
field (it often doesn't — say so if asked). Never restate an authored
accomplishment in reviewed voice; that double-counts one body of work. If the
reviewed themes add no point beyond what authored already says, it's fine to skip
the bullet rather than force a weak one.

## Step 4 — Print and save

1. Print the candidate bullets, grouped under the target job entry (ask the user
   which job if ambiguous), so they can review them in the conversation.
2. Save the same combined list to a **timestamped `results-<stamp>.md` inside the
   input directory**, where `<stamp>` comes from `date +%Y-%m-%d-%H%M` run in the
   shell (e.g. `.cv-data/<org>/<author>/results-2026-06-06-1825.md`). The
   timestamp keeps each run as its own file rather than clobbering the last —
   handy for comparing successive passes. Save beside the source data, out of the
   site itself. Use a top heading naming the job entry, then the `-` bullets —
   authored bullets first, the single reviewed bullet last.
3. Stop there. This skill does NOT touch `index.md` and does NOT call any other
   skill. Inserting bullets into the actual CV is a separate, explicit step the
   user takes afterward (the `update-cv` skill, by hand, etc.).
