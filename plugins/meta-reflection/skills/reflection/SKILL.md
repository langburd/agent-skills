---
name: reflection
description: Analyze conversation to improve the project's CLAUDE.md. Use this at the end of any session, after correcting Claude, after explaining something twice, or when you notice Claude guessing about project conventions. Trigger with "reflect", "update CLAUDE.md", "capture what we learned", or "improve project instructions". Even if the session felt smooth, there may be implicit knowledge worth documenting.
---

# CLAUDE.md Reflection

Analyze this conversation to improve the project's CLAUDE.md for future sessions.

## Scope

This skill targets **project-specific context** — naming conventions, architecture decisions, tooling, repo structure, and workflow patterns unique to this codebase.

- If an issue is about how Claude behaves or communicates across all projects, note it for `/reflection-global` instead (to update `~/CLAUDE.md`).
- If a finding is about user preferences or Claude's behavior style, it likely belongs in the **memory system** (`~/.claude/projects/*/memory/`), not CLAUDE.md. CLAUDE.md is for project context; memory is for user preferences and feedback about Claude's behavior.

## When to Use

- Claude misunderstood a request in this session
- A preference or pattern had to be corrected or explained
- A recurring workflow isn't captured in project instructions
- Claude's behavior was inconsistent with the project's conventions
- Context was missing that should be documented
- Something worked unexpectedly well and should be preserved

## Workflow

### Phase 1: Analysis

Review the conversation history first, then read the project CLAUDE.md (if it exists) to identify what's missing or inconsistent.

Look for moments where:

1. **Misunderstandings occurred** - You interpreted instructions incorrectly
2. **Context was missing** - You needed information that should be documented
3. **Patterns were unclear** - You had to ask or guess about conventions
4. **Workflow friction** - Steps that could be streamlined with better guidance
5. **Repeated corrections** - The user corrected you multiple times on the same issue
6. **What worked well** - A non-obvious approach was validated; preserving it prevents future drift

For each finding, determine:

- **What happened**: Specific moment in the conversation
- **Root cause**: What was missing or unclear in CLAUDE.md
- **Proposed fix**: Exact text to add or modify
- **Destination**: Project CLAUDE.md, `~/CLAUDE.md` (global), or memory system

### Phase 2: Interaction

Present all findings grouped by destination. Wait for user approval per finding.
If a proposed change is rejected, refine or move on.

Only propose improvements when there's clear evidence of recurring issues or missing context — not every session needs changes.

### Phase 3: Implementation

For each approved change:

1. Edit CLAUDE.md directly (create if it doesn't exist, adding new sections at the end)
2. Run `pre-commit run --files CLAUDE.md` to validate — skip silently if pre-commit isn't configured or if it fails on unrelated checks
3. For findings destined for `~/CLAUDE.md`, remind the user to run `/reflection-global`
4. For findings destined for memory, write the appropriate memory file under `~/.claude/projects/<project>/memory/`

## Common Mistakes

- Proposing changes based on a single edge case — look for patterns across the conversation
- Rewriting sections that are working well — surgical edits only
- Adding rules that duplicate existing ones — check for overlap before adding
- Putting user behavior preferences in CLAUDE.md — those belong in memory
- Putting global patterns in the project CLAUDE.md — escalate to `/reflection-global`

## Output Format

```markdown
## Reflection Summary

### Issue 1: [Brief title]

**What happened:**
> [Quote or describe the specific conversation moment]

**Root cause:**
The CLAUDE.md doesn't specify [what was missing]

**Proposed addition to CLAUDE.md:**
Add to section `[Section Name]`:
> [Exact text to add]

**Destination:** Project CLAUDE.md / ~/CLAUDE.md / memory

---

### Issue 2: [Brief title]
[...]
```

## If No Issues Found

Say so briefly. Not every session needs CLAUDE.md changes.
