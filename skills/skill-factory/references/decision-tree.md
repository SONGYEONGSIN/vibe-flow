# Decision Tree: CREATE / UPDATE / MERGE / SKIP

## Similarity Thresholds

| Score | Verdict | Action |
|-------|---------|--------|
| >= 0.8 | SKIP | Near-duplicate. Do not create. Inform user of existing skill. |
| 0.6-0.8 | MERGE | Significant overlap. Extend existing skill with new patterns. |
| 0.3-0.6 | UPDATE | Partial overlap. Consider adding to existing or forking. |
| < 0.3 | CREATE | Novel pattern. Safe to create new skill. |

## Decision Flow

```
Input: candidate pattern + similarity results

1. Run similarity-scorer.py against manifest
2. Take top match score

IF score >= 0.8 (SKIP):
  -> "Pattern already covered by '{name}'"
  -> Show existing skill path
  -> Ask user: "Force create anyway?" (rare)

ELSE IF score 0.6-0.8 (MERGE):
  -> "Pattern overlaps with '{name}' ({score}%)"
  -> Present diff: what candidate adds vs what exists
  -> Ask user:
     a) MERGE into existing (add missing sections)
     b) CREATE separate anyway (if genuinely distinct use case)
     c) SKIP (do nothing)

ELSE IF score 0.3-0.6 (UPDATE):
  -> "Partial similarity with '{name}' ({score}%)"
  -> Present both options:
     a) UPDATE existing (add new patterns as subsection)
     b) CREATE new skill (if different enough in purpose)
  -> Default: CREATE (lower overlap suggests distinct concept)

ELSE (score < 0.3, CREATE):
  -> "No significant overlap found"
  -> Proceed to skill creation
  -> No user confirmation needed for the decision itself
```

## Multiple Match Handling

When top 3+ results all score >= 0.3:
- Present all matches to user
- Highlight the best match
- Let user choose: merge into which, or create new

## Edge Cases

### Same Domain, Different Purpose
Example: `verify-api` (validation) vs `api-builder` (generation)
- Domain overlap is high, but purpose differs
- Rely on description similarity (weight 0.4) to differentiate
- When in doubt, CREATE separately

### Name Collision
If candidate name matches existing exactly:
- Score will be >= 0.8 on name dimension
- But if descriptions diverge, total may be lower
- Flag to user: "Same name but different purpose. Rename recommended."

### Cross-Type Matches
Candidate skill matches existing agent or command:
- Different types serve different roles
- Agent: autonomous, has its own context
- Skill: triggered by user, runs in main context
- Command: shortcut, simpler than skill
- Flag the match but default to CREATE (different type)
