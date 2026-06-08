# langburd/agent-skills

Personal Claude Code plugin marketplace.
Skills-first, versioned with semver, auto-updating via native marketplace autoUpdate.

## Install

### Terminal (CLI)

```bash
claude plugin marketplace add langburd/agent-skills
claude plugin install cv-achievements@langburd
```

### Claude Code slash commands

```
/plugin marketplace add langburd/agent-skills
/plugin install cv-achievements@langburd
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
| [cv-achievements](plugins/cv-achievements) | 1.1.0 | Turn GitHub PR activity into CV achievement bullets for a job entry |
| [linkedin-post](plugins/linkedin-post) | 0.1.0 | Turn any subject into a ready-to-post LinkedIn post: an HTML preview with copy buttons plus an image-generation prompt |
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
