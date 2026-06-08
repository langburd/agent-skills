---
name: claude-to-agents
description: >
  Migrate a project from Claude-specific instruction files (CLAUDE.md, .claude/skills/) to the universal AGENTS.md
  standard, creating symlinks so every configured AI agent shares one source of truth. Handles four starting states:
  CLAUDE.md only, AGENTS.md only, both (conflict), or neither (scaffold). Use this skill whenever the user wants to
  convert to agents.md, make project instructions universal or agent-agnostic, set up or adopt the agents.md standard,
  migrate from CLAUDE.md, share instructions across multiple AI tools (Augment, Claude, Gemini, Copilot, Cursor,
  Windsurf), or move .claude/skills to .agents/skills. Also triggers on phrases like "make instructions work for
  other agents", "new dev uses a different AI tool", or any mention of the agents.md spec. Do NOT use this skill
  when the user just wants to edit CLAUDE.md/AGENTS.md content, review existing instructions, or configure
  .claude/settings.json — those are content editing tasks, not migration.
---

# CLAUDE.md to AGENTS.md Migration

Migrate a project from Claude-specific instruction files to the universal [AGENTS.md](https://agents.md) standard.
AGENTS.md becomes the single source of truth, with symlinks so each agent's native config file points back to it.

## Overview

The migration has two parts:

1. **Content transformation** (you do this) — rewrite Claude-specific language to be agent-agnostic
2. **File structure setup** (helper script does this) — move files, create symlinks, wire up agents

## Step 1: Identify the Project

Ask the user which project to migrate if not already clear. Confirm the project root path.

## Step 2: Detect Current State

Run the helper script to detect the current state:

```bash
bash ~/.claude/skills/claude-to-agents/scripts/setup-agents.sh --project-dir <path> --detect
```

The script reports one of four states:

| State | Condition | Action |
| --- | --- | --- |
| A | `CLAUDE.md` exists, no `AGENTS.md` | Full migration: transform content + create structure |
| B | `AGENTS.md` exists (with or without symlinks) | Create missing symlinks only |
| C | Both `CLAUDE.md` and `AGENTS.md` exist (not symlinked) | Conflict — resolve with user, then State B |
| D | Neither exists | Scaffold from template, then State B |

## Step 3: Choose Agents

Ask the user which agents to configure. Present this table:

| Agent | Symlink created | Notes |
| --- | --- | --- |
| `claude` | `CLAUDE.md` → `AGENTS.md`, `.claude/skills` → `../.agents/skills` | Default, almost always wanted |
| `gemini` | `GEMINI.md` → `AGENTS.md` | Gemini CLI |
| `copilot` | `.github/copilot-instructions.md` → `../AGENTS.md` | GitHub Copilot |
| `cursor` | `.cursor/rules/agents.md` → `../../AGENTS.md` | Cursor |
| `windsurf` | `.windsurfrules` → `AGENTS.md` | Windsurf |

Default to `claude` only. Multiple agents can be selected comma-separated.

Read `~/.claude/skills/claude-to-agents/references/agent-configs.md` for full details on each agent's conventions if needed.

## Step 4: Handle Each State

### State A — CLAUDE.md Only (Full Migration)

This is the core workflow. Do these in order:

**4A.1 — Check for uncommitted changes:**
Run `git status` on the project. If `CLAUDE.md` has uncommitted changes, warn the user and ask them to commit or stash first. Do not proceed until the working tree is clean for the files you'll touch.

**4A.2 — Read and transform content:**
Read the full `CLAUDE.md`. Transform it to be agent-agnostic using these rules:

| Pattern | Replacement |
| --- | --- |
| "Claude", "Claude Code" when referring to the agent | "the AI assistant" or "the agent" |
| "# Global Claude Code Settings" or similar headings | Contextual heading like "# AI Coding Guidelines" |
| "Use the Read tool", "Use the Edit tool" | "Read the file", "Edit the file" |
| "Use the Grep/Glob tool" | "Search for..." |
| "Use the Bash tool" | "Run the command" |
| "Use the Write tool" | "Create/write the file" |
| Tool-specific capitalized names (Read, Edit, Bash, etc.) used as tool references | Lowercase action verbs |

Apply these contextually — understand the sentence meaning, don't do blind find-replace. Preserve all non-Claude-specific content exactly as-is.

**4A.3 — Extract Claude-specific config:**
Identify sections that are inherently Claude-specific and cannot be made universal:

- Skill auto-loading rules (e.g., `/acli`, `/github-cli`)
- MCP tool preferences (e.g., `mcp__auggie__*`)
- Claude Code-specific hooks or settings references

For these:

- If the content maps to a setting → note it for `.claude/settings.json` (merge, don't overwrite)
- If it's textual guidance that only applies to Claude → place in a `## Claude Code` section at the bottom of AGENTS.md (this is rarely needed)

**4A.4 — Write AGENTS.md:**
Write the transformed content to `AGENTS.md` in the project root.

**4A.5 — Show the user what changed:**
Present a summary of transformations made. If anything was ambiguous, ask the user to confirm.

**4A.6 — Run the helper script:**

```bash
bash ~/.claude/skills/claude-to-agents/scripts/setup-agents.sh --project-dir <path> --agents <agent-list> --apply
```

This moves `.claude/skills/` → `.agents/skills/`, creates all symlinks, and updates `.gitignore`.

**4A.7 — Handle subdirectory CLAUDE.md files:**
Check for CLAUDE.md files in subdirectories:

```bash
find <path> -name "CLAUDE.md" -not -path "*/.git/*" -not -path "*node_modules/*" -not -path "*/.worktrees/*" -not -path "*/.claude/worktrees/*"
```

If found, flag them to the user and offer to convert each one (repeat the content transformation for each).

### State B — AGENTS.md Already Exists

1. Briefly scan `AGENTS.md` for Claude-specific language. If found, offer to clean it up.
2. Run the helper script to create missing symlinks:

   ```bash
   bash ~/.claude/skills/claude-to-agents/scripts/setup-agents.sh --project-dir <path> --agents <agent-list> --apply
   ```

### State C — Both Exist (Conflict)

1. Read both files
2. Show the user a summary of differences
3. Ask: "Which file should be the source of truth, or should I merge them?"
4. Based on user choice, write the final `AGENTS.md` and proceed as State B

### State D — Neither Exists

1. Ask the user what the project is about and what sections to include
2. Scaffold `AGENTS.md` with standard sections based on the [agents.md spec](https://agents.md):
   - Project overview
   - Build and test commands
   - Code style guidelines
   - Development environment
3. Proceed as State B

## Step 5: Verify

After the script runs, verify the setup:

```bash
bash ~/.claude/skills/claude-to-agents/scripts/setup-agents.sh --project-dir <path> --agents <agent-list> --verify
```

Report results to the user. If any symlinks are broken, diagnose and fix.

## Step 6: Offer to Commit

If there are changes, offer to commit them. Respect the user's git workflow preferences — don't commit unless asked. Suggest a message like:

```text
feat: migrate CLAUDE.md to AGENTS.md standard

Convert project instructions to the universal AGENTS.md format.
CLAUDE.md is now a symlink to AGENTS.md. Skills moved to .agents/skills/.
```

## Important Guidelines

- Never modify the global `~/.claude/CLAUDE.md` — this skill is for per-project files only
- Never push to remote — only local operations
- Preserve all existing `.claude/settings.json` content when merging
- Keep AGENTS.md under 200 lines if possible (per Augment's recommendation for token efficiency)
- When in doubt about whether something is Claude-specific, ask the user
- If the project has a `.claude/worktrees/` directory, leave it alone
