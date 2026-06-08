# langburd/agent-skills

Personal Claude Code plugin marketplace.
Skills-first, versioned with semver, auto-updating via native marketplace autoUpdate.

## Install

### Terminal (CLI)

```bash
claude plugin marketplace add langburd/agent-skills
claude plugin install hello-world@langburd
```

### Claude Code slash commands

```
/plugin marketplace add langburd/agent-skills
/plugin install hello-world@langburd
```

## Auto-Update

Claude Code can auto-apply newer plugin versions at startup by comparing
installed versions against this marketplace's index. Third-party marketplaces
have auto-update disabled by default — enable it in `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "langburd": {
      "source": {
        "source": "github",
        "repo": "langburd/agent-skills"
      },
      "autoUpdate": true
    }
  }
}
```

`claude plugin marketplace add langburd/agent-skills` registers the entry; set
`"autoUpdate": true` on it (or toggle via `/plugin` → Marketplaces). No
SessionStart hook is needed — version comparison and update application are
built into Claude Code.

## Plugins

<!-- BEGIN PLUGIN TABLE -->
| Plugin | Version | Description |
|--------|---------|-------------|
| [cv-achievements](plugins/cv-achievements) | 1.0.0 | Turn GitHub PR activity into CV achievement bullets for a job entry |
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
