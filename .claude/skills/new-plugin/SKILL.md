---
name: new-plugin
description: Scaffold a new plugin bundle in this marketplace — creates plugin.json, SKILL.md with correct frontmatter, per-plugin README, then runs sync.sh.
disable-model-invocation: true
---

# New Plugin

Create a new plugin bundle. Usage: `/new-plugin <plugin-name> "Short description"`

## Steps

1. **Validate input**: `$ARGUMENTS` must contain a plugin name (kebab-case) and optional description. If missing, ask for both before proceeding.

2. **Create directory structure**:

   ```
   plugins/<name>/
   ├── .claude-plugin/
   │   └── plugin.json
   ├── skills/
   │   └── <name>/
   │       └── SKILL.md
   └── README.md
   ```

3. **Write `plugins/<name>/.claude-plugin/plugin.json`**:

   ```json
   {
     "name": "<name>",
     "version": "1.0.0",
     "description": "<description>"
   }
   ```

   - `name` must match the directory name exactly (kebab-case)
   - No `type` field

4. **Write `plugins/<name>/skills/<name>/SKILL.md`**:

   ```markdown
   ---
   name: <name>
   description: <description> — describe the trigger condition and what it does
   ---

   # <Title Case Name>

   TODO: replace with actual skill content.
   ```

5. **Write `plugins/<name>/README.md`**:

   ```markdown
   # <name>

   > <description>

   ## Install

   ```bash
   claude plugin install <name>@langburd
   ```

   ## Skills

   | Skill | Description |
   |-------|-------------|
   | `<name>` | <description> |

   ## Version History

   | Version | Changes |
   |---------|---------|
   | 1.0.0 | Initial release |

   ```

6. **Run `./scripts/sync.sh`** to register the new plugin in `marketplace.json` and update the README catalog table.

7. **Show a summary** of files created and remind the user to:
   - Fill in the TODO in `SKILL.md` with actual skill content
   - Run end-to-end install test before considering the plugin done
