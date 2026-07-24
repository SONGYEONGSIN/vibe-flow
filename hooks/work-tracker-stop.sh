#!/bin/bash
# work-tracker-stop.sh - Stop Hook
# 세션 종료 이벤트를 buffer.jsonl에 기록하고 동기화 트리거
# [C2 fix] eval 제거 → Python에서 전체 로직 처리 (인젝션 방지)
# exit 0 필수 (세션 방해 금지)

INPUT=$(cat)
SYNC_SCRIPT="$HOME/.claude/scripts/work-tracker-sync.sh"

echo "$INPUT" | python3 -c "
import sys, json, os, socket
from datetime import datetime, timezone, timedelta

try:
    d = json.load(sys.stdin)
except:
    sys.exit(0)

sid = d.get('session_id', '')
if not sid:
    sys.exit(0)

hostname = socket.gethostname().split('.')[0]
kst = timezone(timedelta(hours=9))
ts = datetime.now(kst).isoformat()

rec = {
    'event': 'session_end',
    'session_id': sid,
    'hostname': hostname,
    'ts': ts
}

buffer = os.path.expanduser('~/.claude/work-log/buffer.jsonl')
with open(buffer, 'a') as f:
    f.write(json.dumps(rec, ensure_ascii=False) + '\n')

# 세션 마커 삭제
sessions_dir = os.path.expanduser('~/.claude/work-log/.sessions')
marker = os.path.join(sessions_dir, sid)
try:
    os.remove(marker)
except:
    pass
" 2>/dev/null

# 동기화 스크립트 존재 시 백그라운드 실행
if [[ -x "$SYNC_SCRIPT" ]]; then
    "$SYNC_SCRIPT" &
fi

exit 0
