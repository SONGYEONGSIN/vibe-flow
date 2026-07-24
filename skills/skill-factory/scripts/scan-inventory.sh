#!/usr/bin/env bash
# scan-inventory.sh - Scan all skills, commands, agents and output JSON manifest
# Usage: bash scan-inventory.sh [--scope global|project|all]
# Output: JSON array of {type, name, description, path} objects

set -uo pipefail

# Parse arguments: positional or --scope flag
SCOPE="all"
while [ $# -gt 0 ]; do
  case "$1" in
    --scope)
      if [ -z "${2:-}" ]; then
        echo "Error: --scope requires a value (global|project|all)" >&2
        exit 1
      fi
      SCOPE="$2"; shift 2 ;;
    --scope=*)
      SCOPE="${1#*=}"; shift ;;
    global|project|all)
      SCOPE="$1"; shift ;;
    *)
      echo "Error: Unknown argument '$1'. Usage: scan-inventory.sh [--scope global|project|all]" >&2
      exit 1 ;;
  esac
done

if [ "$SCOPE" != "global" ] && [ "$SCOPE" != "project" ] && [ "$SCOPE" != "all" ]; then
  echo "Error: Invalid scope '$SCOPE'. Must be global, project, or all." >&2
  exit 1
fi

CLAUDE_DIR="${HOME}/.claude"
RESULTS="["
FIRST=true

add_entry() {
  local type="$1" name="$2" desc="$3" path="$4"
  # Escape JSON strings (backslash, quotes, control chars)
  desc=$(printf '%s' "$desc" | tr -d '\r\f\b' | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/ /g' | tr '\n' ' ' | sed 's/  */ /g')
  name=$(printf '%s' "$name" | sed 's/\\/\\\\/g; s/"/\\"/g')
  path=$(printf '%s' "$path" | sed 's/\\/\\\\/g; s/"/\\"/g')

  if [ "$FIRST" = true ]; then
    FIRST=false
  else
    RESULTS+=","
  fi
  RESULTS+=$(printf '\n  {"type":"%s","name":"%s","description":"%s","path":"%s"}' "$type" "$name" "$desc" "$path")
}

extract_yaml_field() {
  local file="$1" field="$2"
  # Extract value between --- delimiters (awk excludes delimiter lines)
  awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$file" 2>/dev/null \
    | grep -E "^${field}:" \
    | head -1 \
    | sed "s/^${field}:[[:space:]]*//" \
    | sed 's/^["'"'"']//' \
    | sed 's/["'"'"']$//' \
    | sed 's/^[>|]-\{0,1\}$//' \
    | tr -s ' '
}

# --- Skills ---
scan_skills() {
  local skills_dir="$1" scope_label="$2"
  if [ ! -d "$skills_dir" ]; then return; fi

  for skill_md in "$skills_dir"/*/SKILL.md; do
    [ -f "$skill_md" ] || continue
    local skill_dir
    skill_dir=$(dirname "$skill_md")
    local name
    name=$(extract_yaml_field "$skill_md" "name")
    [ -z "$name" ] && name=$(basename "$skill_dir")
    local desc
    desc=$(extract_yaml_field "$skill_md" "description")
    [ -z "$desc" ] && desc="(no description)"
    add_entry "skill" "$name" "$desc" "$skill_md"
  done
}

# --- Commands ---
scan_commands() {
  local cmds_dir="$1"
  if [ ! -d "$cmds_dir" ]; then return; fi

  for cmd_file in "$cmds_dir"/*.md; do
    [ -f "$cmd_file" ] || continue
    local name
    name=$(basename "$cmd_file" .md)
    local desc
    desc=$(extract_yaml_field "$cmd_file" "description")
    if [ -z "$desc" ]; then
      # Try first non-empty, non-frontmatter line
      desc=$(sed -n '/^---$/,/^---$/d; /^[[:space:]]*$/d; p' "$cmd_file" 2>/dev/null | head -1 | sed 's/^#* *//')
    fi
    [ -z "$desc" ] && desc="(no description)"
    add_entry "command" "$name" "$desc" "$cmd_file"
  done
}

# --- Agents ---
scan_agents() {
  local agents_dir="$1"
  if [ ! -d "$agents_dir" ]; then return; fi

  for agent_file in "$agents_dir"/*.md; do
    [ -f "$agent_file" ] || continue
    local name
    name=$(basename "$agent_file" .md)
    # Agent files use different frontmatter keys
    local desc=""
    # Try 'description' field first, then 'roleDefinition', then first heading
    desc=$(extract_yaml_field "$agent_file" "description")
    if [ -z "$desc" ]; then
      desc=$(extract_yaml_field "$agent_file" "roleDefinition")
    fi
    if [ -z "$desc" ]; then
      desc=$(grep -m1 "^#" "$agent_file" 2>/dev/null | sed 's/^#* *//')
    fi
    [ -z "$desc" ] && desc="(no description)"
    add_entry "agent" "$name" "$desc" "$agent_file"
  done
}

# Execute scans based on scope
if [ "$SCOPE" = "global" ] || [ "$SCOPE" = "all" ]; then
  scan_skills "${CLAUDE_DIR}/skills" "global"
  scan_commands "${CLAUDE_DIR}/commands"
  scan_agents "${CLAUDE_DIR}/agents"
  # Scan learned skills if directory exists
  if [ -d "${CLAUDE_DIR}/learned" ]; then
    scan_skills "${CLAUDE_DIR}/learned" "global-learned"
  fi
fi

if [ "$SCOPE" = "project" ] || [ "$SCOPE" = "all" ]; then
  if [ -d ".claude/skills" ]; then
    scan_skills ".claude/skills" "project"
  fi
  if [ -d ".claude/commands" ]; then
    scan_commands ".claude/commands"
  fi
  if [ -d ".claude/agents" ]; then
    scan_agents ".claude/agents"
  fi
fi

RESULTS+=$'\n]'
echo "$RESULTS"
