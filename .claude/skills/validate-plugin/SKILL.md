---
name: validate-plugin
description: Run sync.sh --check and pre-commit on a named plugin to surface validation errors before committing.
disable-model-invocation: true
---

# Validate Plugin

Validate a plugin bundle (or the whole marketplace). Usage: `/validate-plugin [plugin-name]`

## Steps

1. **Run the drift-check gate**:

   ```bash
   ./scripts/sync.sh --check
   ```

   This validates all plugin structure and checks that `marketplace.json` and
   the README catalog table are in sync with source. Exits non-zero if any
   plugin fails validation or generated files are out of date.

2. **If a specific plugin name was given in `$ARGUMENTS`**, also report any
   issues found for that plugin specifically (filter `sync.sh` output).

3. **Run pre-commit** on plugin files:

   ```bash
   pre-commit run --files plugins/<name>/**
   ```

   If no plugin name given, run on all files:

   ```bash
   pre-commit run --all-files
   ```

4. **Report results**: show pass/fail per hook, and for any failures show
   the exact error output with file paths and line numbers.

5. **If validation passed**: confirm the plugin is ready to commit and
   remind the user to run the end-to-end install test:

   ```bash
   claude plugin marketplace add /absolute/path/to/agent-skills
   claude plugin install <plugin-name>@langburd
   ```
