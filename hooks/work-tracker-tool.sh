#!/bin/bash
# work-tracker-tool.sh - PostToolUse Hook
# 추적 대상 도구 사용을 buffer.jsonl에 기록
# [C2 fix] eval 제거 → Python에서 전체 로직 처리 (인젝션 방지)
# exit 0 필수 (세션 방해 금지)

INPUT=$(cat)

echo "$INPUT" | python3 -c "
import sys, json, os, socket
from datetime import datetime, timezone, timedelta

try:
    d = json.load(sys.stdin)
except:
    sys.exit(0)

sid = d.get('session_id', '')
tool = d.get('tool_name', '')
if not sid or not tool:
    sys.exit(0)

TRACKED = {
    'Bash': 'bash',
    'Write': 'write', 'Edit': 'write', 'NotebookEdit': 'write',
    'Task': 'agent', 'SendMessage': 'agent',
    'TaskCreate': 'agent', 'TaskUpdate': 'agent',
    'EnterPlanMode': 'plan', 'ExitPlanMode': 'plan',
    'Skill': 'interaction',
}

is_mcp = False
mcp_server = None
category = ''

if tool in TRACKED:
    category = TRACKED[tool]
elif tool.startswith('mcp__'):
    is_mcp = True
    parts = tool.split('__')
    mcp_server = parts[1] if len(parts) > 1 else None
    category = 'mcp'
else:
    sys.exit(0)

hostname = socket.gethostname().split('.')[0]
kst = timezone(timedelta(hours=9))
ts = datetime.now(kst).isoformat()

rec = {
    'event': 'tool_use',
    'session_id': sid,
    'hostname': hostname,
    'tool_name': tool,
    'tool_category': category,
    'is_mcp': is_mcp,
    'mcp_server': mcp_server,
    'ts': ts
}

buffer = os.path.expanduser('~/.claude/work-log/buffer.jsonl')
with open(buffer, 'a') as f:
    f.write(json.dumps(rec, ensure_ascii=False) + '\n')
" 2>/dev/null

exit 0
