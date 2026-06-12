---
name: reflection-global
description: Analyze conversation to improve global ~/CLAUDE.md with cross-project preferences and behavior patterns. Use this when Claude repeated a mistake it makes everywhere, when you had to re-explain a preference that should apply to all projects, or when you notice a communication or workflow pattern worth capturing globally. Trigger with "reflect globally", "update global instructions", "capture cross-project preference", or "improve global CLAUDE.md". Also use when /reflection surfaces findings that aren't project-specific.
---

# Global CLAUDE.md Reflection

Analyze this conversation to improve `~/CLAUDE.md` for future sessions across all projects.

## Scope

This skill targets **global, cross-project behavior** — how Claude communicates, preferred tools, workflow patterns, and user preferences that apply everywhere.

- If an issue is specific to a single project's conventions, architecture, or tooling, use `/reflection` instead to update that project's `CLAUDE.md`.
- If a finding is about user preferences or feedback about Claude's behavior *style*, consider whether it belongs in the **memory system** (`~/.claude/projects/*/memory/`) rather than `~/CLAUDE.md`. `~/CLAUDE.md` is for durable instructions; memory is for contextual preferences and behavioral feedback.

## When to Use

- Claude misunderstood a request in this session
- A preference or pattern had to be corrected or explained
- A recurring workflow isn't captured in global instructions
- Claude's behavior was inconsistent with stated preferences across projects
- Something worked unexpectedly well and should be reinforced globally

## Workflow

### Phase 1: Analysis

Review the conversation history first, then read `~/CLAUDE.md` to identify what's missing or inconsistent.

Look for moments where:

1. **Misunderstandings occurred** - You interpreted instructions incorrectly
2. **Preferences were missing** - User had to re-explain a cross-project preference
3. **Patterns were unclear** - You had to ask or guess about conventions that apply globally
4. **Workflow friction** - Steps that could be streamlined with better global guidance
5. **Repeated corrections** - The user corrected you multiple times on the same issue
6. **What worked well** - A non-obvious approach was validated; worth reinforcing globally

For each finding, determine:

- **What happened**: Specific moment in the conversation
- **Root cause**: What was missing or unclear in `~/CLAUDE.md`
- **Proposed fix**: Exact text to add or modify
- **Destination**: `~/CLAUDE.md` (global instructions) or memory system (behavioral feedback)

### Phase 2: Interaction

Present all findings grouped by destination. Wait for user approval per finding.
If a proposed change is rejected, refine or move on.

Only propose improvements when there's clear evidence of recurring issues or missing context — not every session needs changes.

### Phase 3: Implementation

For each approved change:

1. Edit `~/CLAUDE.md` directly using the Edit tool
2. For findings destined for memory, write the appropriate memory file under `~/.claude/projects/-Users-<username>--claude/memory/`

## Common Mistakes

- Proposing changes based on a single edge case — look for patterns across the conversation
- Rewriting sections that are working well — surgical edits only
- Adding rules that duplicate existing ones — check for overlap before adding
- Putting project-specific conventions here — those belong in the project's `CLAUDE.md`
- Putting behavioral feedback in `~/CLAUDE.md` when it belongs in memory

## Output Format

```markdown
## Reflection Summary

### Issue 1: [Brief title]

**What happened:**
> [Quote or describe the specific conversation moment]

**Root cause:**
The ~/CLAUDE.md doesn't specify [what was missing]

**Proposed addition to ~/CLAUDE.md:**
Add to section `[Section Name]`:
> [Exact text to add]

**Destination:** ~/CLAUDE.md / memory

---

### Issue 2: [Brief title]
[...]
```

## If No Issues Found

Say so briefly. Not every session needs `~/CLAUDE.md` changes.
