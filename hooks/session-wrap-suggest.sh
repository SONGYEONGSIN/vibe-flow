#!/bin/bash
# session-wrap-suggest.sh - Stop Hook
# 세션이 충분히 진행된 후 처음 idle될 때 /session-wrap 안내
# OMC persistent-mode.cjs와 공존: OMC가 block하면 이 메시지는 무시됨
# exit 0 필수

INPUT=$(cat)

echo "$INPUT" | python3 -c "
import sys, json, os

try:
    d = json.load(sys.stdin)
except:
    sys.exit(0)

sid = d.get('session_id', '')
if not sid:
    sys.exit(0)

# 마커 파일로 세션당 1회만 제안
marker = f'/tmp/session-wrap-suggested-{sid}'
if os.path.exists(marker):
    sys.exit(0)

# 세션 통계 확인
stats_file = os.path.expanduser('~/.claude/.session-stats.json')
try:
    with open(stats_file) as f:
        stats = json.load(f)
    session = stats.get('sessions', {}).get(sid, {})
    total_calls = session.get('total_calls', 0)
except:
    sys.exit(0)

# 최소 30회 도구 호출 후에만 제안
if total_calls < 30:
    sys.exit(0)

# 마커 생성 (세션당 1회)
open(marker, 'w').close()

# stdout으로 JSON 출력 (Stop 훅 형식)
print(json.dumps({
    'continue': True,
    'systemMessage': '[Session Wrap 안내] 이번 세션에서 상당한 작업이 진행되었습니다. '
        '세션 마무리 시 /session-wrap을 실행하면 문서 업데이트, 학습 포인트, '
        '후속 작업을 자동으로 정리할 수 있습니다.'
}))
" 2>/dev/null

exit 0
