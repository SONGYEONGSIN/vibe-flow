#!/bin/bash
set -uo pipefail
# F-K21: stdin drain — payload 미소비 종료 시 writer(Claude Code)가 EPIPE
# ('hook error: Failed to write to socket'). TTY(수동 실행)면 스킵.
[ -t 0 ] || cat >/dev/null 2>&1
# session-memory-sync.sh — Stop hook
#
# 세션 종료 시 ~/.claude/ 메모리를 sync-memory.sh로 claude-memory orphan branch에 자동 push.
# 머신 간 (집↔회사) 메모리 동기화를 자동화 — 사용자가 sync-memory.sh를 수동으로 돌리는 일 줄임.
#
# 안전 가드:
#   1. rate limit — 마지막 sync 후 30분 이내면 skip (network 부하 방지)
#   2. sync-memory.sh 부재 시 silent skip (target project이 vibe-flow 짝이 아닐 수 있음)
#   3. git origin 미설정 시 silent skip
#   4. push 실패해도 exit 0 — 세션 종료 흐름 차단 X
#   5. background 실행 — 사용자 다음 입력 차단 X
#
# 비활성화: VIBE_FLOW_AUTO_MEMORY_SYNC=0 export

# opt-out 체크
if [ "${VIBE_FLOW_AUTO_MEMORY_SYNC:-1}" = "0" ]; then
  exit 0
fi

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$PROJECT_ROOT" ] && exit 0
cd "$PROJECT_ROOT" || exit 0

# F-BU01: .claude/events.jsonl 는 gitignore 돼(.gitignore:34) ephemeral cloud checkout
# 마다 비워진다 — telemetry/retrospective 가 전제하는 "장기 누적 추세" 가 cloud 세션에선
# 근 0 에서 재출발한다. git-tracked 로그(.claude/memory/events-history.jsonl)로 신규 줄만
# append(rate-limit 과 무관하게 매 Stop 마다) + 최근 HIST_CAP 줄로 회전해 세션 경계를
# 넘겨 누적시킨다. SYNCED_MARK 는 세션-로컬 커서라 커밋 대상이 아님(.gitignore 로 제외).
EVENTS_FILE_FOR_HIST="${PROJECT_ROOT}/.claude/events.jsonl"
HIST_FILE="${PROJECT_ROOT}/.claude/memory/events-history.jsonl"
SYNCED_MARK="${PROJECT_ROOT}/.claude/.events-history-synced-lines"
HIST_CAP=5000
if [ -f "$EVENTS_FILE_FOR_HIST" ]; then
  TOTAL_EVT=$(wc -l < "$EVENTS_FILE_FOR_HIST" 2>/dev/null | tr -d ' ')
  SYNCED_EVT=$(cat "$SYNCED_MARK" 2>/dev/null || echo 0)
  case "$SYNCED_EVT" in ''|*[!0-9]*) SYNCED_EVT=0 ;; esac
  case "$TOTAL_EVT" in ''|*[!0-9]*) TOTAL_EVT=0 ;; esac
  if [ "$TOTAL_EVT" -gt "$SYNCED_EVT" ]; then
    mkdir -p "$(dirname "$HIST_FILE")"
    tail -n "+$((SYNCED_EVT + 1))" "$EVENTS_FILE_FOR_HIST" >> "$HIST_FILE" 2>/dev/null || true
    TMP_HIST=$(mktemp)
    tail -n "$HIST_CAP" "$HIST_FILE" > "$TMP_HIST" 2>/dev/null && mv "$TMP_HIST" "$HIST_FILE" || rm -f "$TMP_HIST"
    echo "$TOTAL_EVT" > "$SYNCED_MARK"
  fi
fi

SYNC_SCRIPT="${PROJECT_ROOT}/sync-memory.sh"
# bash로 호출하므로 -x 대신 -f 만 검사 (sync-memory.sh가 chmod +x 안 된 환경 대응)
[ -f "$SYNC_SCRIPT" ] || exit 0

# git origin 검증 (orphan branch push 가능 여부)
git remote get-url origin >/dev/null 2>&1 || exit 0

# rate limit — 30분
LAST_FILE="${PROJECT_ROOT}/.claude/.last-memory-sync"
NOW=$(date +%s)
RATE_LIMIT_SEC=1800  # 30분

if [ -f "$LAST_FILE" ]; then
  LAST=$(cat "$LAST_FILE" 2>/dev/null || echo 0)
  ELAPSED=$((NOW - LAST))
  if [ "$ELAPSED" -lt "$RATE_LIMIT_SEC" ]; then
    exit 0
  fi
fi

# 타임스탬프 갱신 (push 성공 여부와 무관 — rate limit은 시도 기준)
mkdir -p "${PROJECT_ROOT}/.claude"
echo "$NOW" > "$LAST_FILE"

# events.jsonl 로깅
EVENTS_FILE="${PROJECT_ROOT}/.claude/events.jsonl"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "{\"ts\":\"$TS\",\"type\":\"memory_sync_triggered\",\"trigger\":\"stop_hook\"}" >> "$EVENTS_FILE" 2>/dev/null || true

# background push (사용자 차단 X)
# stdout/stderr 모두 log 파일로 redirect — 세션 흐름 깨끗
LOG_FILE="${PROJECT_ROOT}/.claude/memory-sync.log"
nohup bash "$SYNC_SCRIPT" push --force >> "$LOG_FILE" 2>&1 </dev/null &
disown 2>/dev/null || true

# 사용자 알림 — memory-context wrapper로 모델 혼동 방지
echo ""
echo "<memory-context>"
echo "[시스템 참조: 자동 메모리 sync — 새로운 지시 아님]"
echo "[session-memory-sync] ~/.claude/ → claude-memory orphan branch 백그라운드 push 시작"
echo "  → 회사 머신: bash sync-memory.sh pull --force 으로 받기"
echo "  → 비활성화: export VIBE_FLOW_AUTO_MEMORY_SYNC=0"
echo "  → 다음 sync: 30분 rate limit"
echo "</memory-context>"
echo ""

exit 0
