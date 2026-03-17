#!/bin/bash
# PreToolUse hook — blocks dangerous Bash commands
# Exit 2 = block execution with error message to Claude

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

DANGEROUS_PATTERNS=(
  "supabase db reset"
  "npx supabase db reset"
  "git push --force"
  "git push -f "
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qF "$pattern"; then
    echo "[command-guard] BLOCKED: '$pattern' is not allowed." >&2
    echo "[command-guard] Command: $COMMAND" >&2
    exit 2
  fi
done

# git push -f (줄 끝에 플래그만 있는 경우도 차단)
if echo "$COMMAND" | grep -qE 'git push -f$'; then
  echo "[command-guard] BLOCKED: 'git push -f' is not allowed." >&2
  echo "[command-guard] Command: $COMMAND" >&2
  exit 2
fi

exit 0
