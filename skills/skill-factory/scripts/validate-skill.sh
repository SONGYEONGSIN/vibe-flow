#!/usr/bin/env bash
# validate-skill.sh - Validate a skill directory structure and content
# Usage: bash validate-skill.sh <skill-directory-path>
# Exit: 0 = valid, 1 = invalid (errors printed to stderr)

set -euo pipefail

SKILL_DIR="${1:?Usage: validate-skill.sh <skill-directory-path>}"
SKILL_DIR="${SKILL_DIR%/}"
ERRORS=0

err() {
  echo "FAIL: $1" >&2
  ERRORS=$((ERRORS + 1))
}

warn() {
  echo "WARN: $1" >&2
}

info() {
  echo "OK:   $1"
}

# 1. Directory exists
if [ ! -d "$SKILL_DIR" ]; then
  err "Directory does not exist: $SKILL_DIR"
  exit 1
fi

# 2. SKILL.md exists
SKILL_MD="$SKILL_DIR/SKILL.md"
if [ ! -f "$SKILL_MD" ]; then
  err "SKILL.md not found in $SKILL_DIR"
  exit 1
fi
info "SKILL.md exists"

# 3. Frontmatter exists and has required fields
HAS_FRONTMATTER=$(head -1 "$SKILL_MD" | grep -c "^---$" || true)
if [ "$HAS_FRONTMATTER" -eq 0 ]; then
  err "SKILL.md missing YAML frontmatter (must start with ---)"
else
  # Verify frontmatter is closed (at least 2 --- delimiters)
  DELIMITER_COUNT=$(grep -c "^---$" "$SKILL_MD" || true)
  if [ "$DELIMITER_COUNT" -lt 2 ]; then
    err "SKILL.md has unclosed frontmatter (found $DELIMITER_COUNT '---' delimiter(s), need at least 2)"
  fi
  # Extract frontmatter
  FRONTMATTER=$(awk '/^---$/{n++; next} n==1{print} n==2{exit}' "$SKILL_MD")

  # Check name field
  if echo "$FRONTMATTER" | grep -qE "^name:"; then
    NAME=$(echo "$FRONTMATTER" | grep -E "^name:" | sed 's/^name:[[:space:]]*//')
    if [ -z "$NAME" ]; then
      err "Frontmatter 'name' field is empty"
    else
      info "name: $NAME"
    fi
  else
    err "Frontmatter missing 'name' field"
  fi

  # Check description field
  if echo "$FRONTMATTER" | grep -qE "^description:"; then
    DESC=$(echo "$FRONTMATTER" | grep -E "^description:" | sed 's/^description:[[:space:]]*//')
    if [ -z "$DESC" ] || [ "$DESC" = ">" ] || [ "$DESC" = "|" ] || [ "$DESC" = ">-" ] || [ "$DESC" = "|-" ]; then
      # Multi-line description (using > or | block scalar indicator)
      DESC="(multi-line)"
    fi
    info "description: present"
  else
    err "Frontmatter missing 'description' field"
  fi
fi

# 4. Line count < 500
LINE_COUNT=$(wc -l < "$SKILL_MD" | tr -d ' ')
if [ "$LINE_COUNT" -gt 500 ]; then
  err "SKILL.md is $LINE_COUNT lines (max 500)"
else
  info "Line count: $LINE_COUNT/500"
fi

# 5. No TODO markers remaining
TODO_COUNT=$(grep -ciE '\[TODO\]|TODO:|\bTODO\b' "$SKILL_MD" 2>/dev/null || true)
if [ "$TODO_COUNT" -gt 0 ]; then
  err "Found $TODO_COUNT TODO markers in SKILL.md"
  grep -niE '\[TODO\]|TODO:|\bTODO\b' "$SKILL_MD" >&2 || true
else
  info "No TODO markers"
fi

# 6. Referenced files exist
# Extract references only from markdown links [text](path), not from code blocks
# Filter to scripts/ and references/ relative paths only
LINK_REFS=$(awk '/^```/{in_block=!in_block; next} !in_block{print}' "$SKILL_MD" \
  | grep -oE '\]\((scripts/[^)]+|references/[^)]+)\)' \
  | sed 's/[]()[]//g' \
  | sort -u || true)

ALL_REFS="$LINK_REFS"
if [ -n "$ALL_REFS" ]; then
  MISSING=0
  while IFS= read -r ref; do
    FULL_PATH="$SKILL_DIR/$ref"
    if [ ! -f "$FULL_PATH" ]; then
      err "Referenced file missing: $ref (expected at $FULL_PATH)"
      MISSING=$((MISSING + 1))
    fi
  done <<< "$ALL_REFS"
  if [ "$MISSING" -eq 0 ]; then
    info "All referenced files exist"
  fi
else
  info "No file references to check"
fi

# 7. Check scripts are executable (if scripts/ exists)
if [ -d "$SKILL_DIR/scripts" ]; then
  for script in "$SKILL_DIR/scripts"/*.sh "$SKILL_DIR/scripts"/*.py; do
    [ -f "$script" ] || continue
    if [ ! -x "$script" ]; then
      warn "Script not executable: $(basename "$script")"
    fi
  done
fi

# 8. Summary
echo ""
if [ "$ERRORS" -eq 0 ]; then
  echo "RESULT: VALID ($SKILL_DIR)"
  exit 0
else
  echo "RESULT: INVALID - $ERRORS error(s) found" >&2
  exit 1
fi
