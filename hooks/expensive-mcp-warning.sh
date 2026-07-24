#!/bin/bash
# Expensive MCP Warning - PreToolUse Hook
# Warns before calling expensive MCP tools (hyperbrowser, playwright)
#
# Hook trigger: PreToolUse (specific expensive MCP tools)
# Exit codes: 0 = allow (warns but never blocks)

# Read tool call JSON from stdin
INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)

# List of expensive MCP tools
EXPENSIVE_TOOLS=(
    "mcp__hyperbrowser__browser_use_agent"
    "mcp__hyperbrowser__openai_computer_use_agent"
    "mcp__hyperbrowser__claude_computer_use_agent"
    "mcp__playwright__browser_run_code"
)

for expensive in "${EXPENSIVE_TOOLS[@]}"; do
    if [[ "$TOOL_NAME" == "$expensive" ]]; then
        echo "WARNING: High-cost MCP call: $TOOL_NAME"
        echo "This tool uses a browser instance and incurs high costs."
        echo "Consider lightweight alternatives: scrape_webpage, browser_snapshot, etc."
        # Block - require user approval
        exit 2
    fi
done

exit 0
