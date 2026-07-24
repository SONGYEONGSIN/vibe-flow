#!/bin/bash
# DB Guard - PreToolUse Hook
# Blocks dangerous SQL patterns: DROP, TRUNCATE, DELETE without WHERE, ALTER DROP
#
# Hook trigger: PreToolUse, matcher: mcp__supabase__execute_sql, mcp__supabase__apply_migration
# Exit codes: 0 = allow, 2 = block

# Read tool call JSON from stdin
INPUT=$(cat)

QUERY=$(echo "$INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
ti = data.get('tool_input', {})
# execute_sql uses 'query', apply_migration uses 'sql' or 'statements'
print(ti.get('query', ti.get('sql', ti.get('statements', ''))))
" 2>/dev/null)

if [[ -z "$QUERY" ]]; then
    # No query found, allow (might be a different tool input format)
    exit 0
fi

# Normalize to uppercase for pattern matching
QUERY_UPPER=$(echo "$QUERY" | tr '[:lower:]' '[:upper:]')

# Block DROP TABLE/DATABASE/SCHEMA
if echo "$QUERY_UPPER" | grep -qE '\bDROP\s+(TABLE|DATABASE|SCHEMA)\b'; then
    echo "BLOCKED: DROP statement detected" >&2
    echo "Query: ${QUERY:0:200}" >&2
    exit 2
fi

# Block TRUNCATE
if echo "$QUERY_UPPER" | grep -qE '\bTRUNCATE\b'; then
    echo "BLOCKED: TRUNCATE statement detected" >&2
    echo "Query: ${QUERY:0:200}" >&2
    exit 2
fi

# Block DELETE without WHERE
if echo "$QUERY_UPPER" | grep -qE '\bDELETE\s+FROM\b' && ! echo "$QUERY_UPPER" | grep -qE '\bWHERE\b'; then
    echo "BLOCKED: DELETE without WHERE clause" >&2
    echo "Query: ${QUERY:0:200}" >&2
    exit 2
fi

# Block ALTER TABLE ... DROP COLUMN (destructive schema change)
if echo "$QUERY_UPPER" | grep -qE '\bALTER\s+TABLE\b.*\bDROP\b'; then
    echo "BLOCKED: ALTER TABLE DROP detected" >&2
    echo "Query: ${QUERY:0:200}" >&2
    exit 2
fi

# Safe query - allow
exit 0
