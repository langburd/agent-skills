# Agent Configuration Reference

Per-agent conventions for instruction files and symlink targets.

## Claude Code

| Item | Path | Symlink target |
| --- | --- | --- |
| Instructions | `CLAUDE.md` | `AGENTS.md` |
| Skills | `.claude/skills/` | `../.agents/skills` |
| Settings | `.claude/settings.json` | (not symlinked) |

Claude Code reads `CLAUDE.md` from the project root. When it's a symlink to `AGENTS.md`, Claude loads the universal instructions transparently.

Skills in `.claude/skills/` use YAML frontmatter + markdown format. Other agents won't read these, but the `.agents/skills/` location keeps them organized alongside the universal config.

The `.claude/` directory may also contain `worktrees/`, `settings.json`, and other Claude-specific state. Only `skills/` is migrated.

## Gemini CLI

| Item | Path | Symlink target |
| --- | --- | --- |
| Instructions | `GEMINI.md` | `AGENTS.md` |

Gemini CLI reads `GEMINI.md` from the project root. Simple symlink to `AGENTS.md`.

No skills directory equivalent.

## GitHub Copilot

| Item | Path | Symlink target |
| --- | --- | --- |
| Instructions | `.github/copilot-instructions.md` | `../AGENTS.md` |

Copilot reads custom instructions from `.github/copilot-instructions.md`. The symlink target is `../AGENTS.md` because the file is one directory deep.

The `.github/` directory is created if it doesn't exist.

## Cursor

| Item | Path | Symlink target |
| --- | --- | --- |
| Instructions | `.cursor/rules/agents.md` | `../../AGENTS.md` |

Cursor reads project rules from `.cursor/rules/*.md` (or `.cursorrules` at root). Using `.cursor/rules/agents.md` is the modern approach and allows additional Cursor-specific rules alongside.

The symlink target is `../../AGENTS.md` because the file is two directories deep.

The `.cursor/rules/` directory is created if it doesn't exist.

## Windsurf

| Item | Path | Symlink target |
| --- | --- | --- |
| Instructions | `.windsurfrules` | `AGENTS.md` |

Windsurf reads `.windsurfrules` from the project root. Simple symlink to `AGENTS.md`.

## Augment Code

Augment Code reads `AGENTS.md` natively — no symlink needed. It also supports hierarchical `AGENTS.md` files in subdirectories with deeper files taking precedence.

## Adding New Agents

To support a new agent, add an entry to this file and update:

1. The `get_symlink_source_and_target()` function in `scripts/setup-agents.sh`
2. The agent table in `SKILL.md` Step 3
