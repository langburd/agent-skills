# langburd/claude-plugins

Personal Claude Code plugin marketplace.
Skills-first, versioned with semver, auto-updating on session start.

## Install

```bash
# Register marketplace
claude plugin marketplace add langburd/claude-plugins

# Install a plugin
claude plugin install hello-world@langburd
```

## Auto-Update (Session Start)

Add to `~/.claude/settings.json` hooks:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "claude plugin marketplace update langburd"
          }
        ]
      }
    ]
  }
}
```

## Plugins

<!-- BEGIN PLUGIN TABLE -->
| Plugin | Version | Description |
|--------|---------|-------------|
| [hello-world](plugins/hello-world) | 1.0.0 | Example starter skill — replace with your own |
<!-- END PLUGIN TABLE -->

## Contributing

Fork, add plugin under `plugins/<name>/`, run `./scripts/sync.sh`, open PR.
CI validates automatically.

### Plugin Structure

```text
plugins/<name>/
├── .claude-plugin/
│   └── plugin.json    # { "name", "version", "description" }
├── skills/
│   └── <skill-name>/
│       └── SKILL.md   # frontmatter: name, description
└── README.md
```

### Workflow

```bash
# Edit skill, bump version in plugin.json, regenerate
./scripts/sync.sh
git add -p && git commit
```
