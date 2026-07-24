# Skill Templates by Type

Select the template that best matches the pattern being converted to a skill.

## Type 1: Workflow Skill

Best for: sequential multi-step processes, pipelines, procedures.

```yaml
---
name: <skill-name>
description: >
  <What it does>. Use when <trigger conditions>.
  <Additional trigger keywords>.
disable-model-invocation: true
argument-hint: "[optional flags]"
---
```

```markdown
# <Skill Name>

## Overview
<1-2 sentences: what this skill automates and why>

## Prerequisites
- <Required tools/configs>

## Workflow

### Step 1: <Action>
<Instructions with concrete commands/examples>

### Step 2: <Action>
<Instructions>

### Step 3: <Action>
<Instructions>

## Output Format
<Expected output template>

## Error Handling
<Common failures and recovery>
```

**Examples:** orchestrate, handoff-verify, commit-push-pr

---

## Type 2: Task/Tool Skill

Best for: collections of related operations, utility toolkits.

```markdown
# <Skill Name>

## Overview
<1-2 sentences>

## Quick Start
<Most common operation with minimal example>

## Operations

### <Operation 1>
**When:** <trigger>
**How:**
<Steps/commands>

### <Operation 2>
**When:** <trigger>
**How:**
<Steps/commands>

## Configuration
<Optional settings>
```

**Examples:** nano-pdf, fix, react-tools

---

## Type 3: Reference/Guidelines Skill

Best for: standards, specifications, domain knowledge.

```markdown
# <Skill Name>

## Overview
<1-2 sentences>

## Guidelines

### <Category 1>
<Rules with examples>

### <Category 2>
<Rules with examples>

## Checklist
- [ ] <Verification item>
- [ ] <Verification item>

## Examples
<Good vs bad patterns>
```

**Examples:** coding-standards, brand-guidelines, security-review

---

## Type 4: Verification Skill

Best for: automated checks, validation, compliance.

```markdown
# <Skill Name>

## Purpose
1. <Check category>
2. <Check category>

## When to Run
- <Trigger condition>

## Related Files
| File | Purpose |
|------|---------|
| `path/to/file` | <Why it's checked> |

## Workflow

### Step N: <Check Name>
**File:** `path/to/file`
**Check:** <What to verify>
```bash
<detection command>
```
**Pass:** <Expected result>
**Fail:** <How to fix>

## Output Format
| Check | Status | Details |
|-------|--------|---------|
| ... | PASS/FAIL | ... |

## Exceptions
- <Not a violation: explanation>
```

**Examples:** verify-i18n, verify-openclaw-config, verify-refund-api

---

## Frontmatter Best Practices

### Description Writing Guide

The `description` field is the **primary trigger**. Include:

1. **What** the skill does (first sentence)
2. **When** to use it (trigger conditions)
3. **Trigger keywords** in both Korean and English

Example:
```yaml
description: >
  Analyze session patterns and convert to reusable skills.
  Use when: "make this a skill", "extract skill", "skill factory",
  "session to skill", "automate this workflow".
```

### Argument Hints

Common patterns:
```yaml
argument-hint: "[--dry-run]"                    # Single flag
argument-hint: "[target-name]"                  # Positional
argument-hint: "[--flag1] [--flag2 value]"      # Multiple
argument-hint: "[--scope global|project]"       # Enum
```

## Resource Organization

### When to Use scripts/
- Deterministic operations (file scanning, validation, scoring)
- Repeatedly rewritten code
- Operations needing exact reliability

### When to Use references/
- Detailed decision logic
- Domain-specific knowledge
- Configuration catalogs
- Information Claude should reference but not always load

### File Naming
- Scripts: `verb-noun.sh` or `verb-noun.py` (e.g., `scan-inventory.sh`)
- References: `noun.md` or `noun-noun.md` (e.g., `decision-tree.md`)
- Keep names under 30 characters
