#!/bin/bash
set -uo pipefail
# run-log.sh — sleep-build 사이클 이벤트 jsonl append helper
#
# 사용법:
#   run-log.sh start <run_id> [key=value ...]
#   run-log.sh abort <run_id> [key=value ...]
#   run-log.sh done  <run_id> [key=value ...]
#
# 출력: .claude/memory/sleep-build-runs.jsonl 에 1 라인 append
# 키 예: phase, branch, spec_file, plan_id, tokens_in, tokens_out, files_changed, pr_url, exit_reason

usage() {
  echo "Usage: $0 {start|abort|done} <run_id> [key=value ...]" >&2
  exit 1
}

[ $# -lt 2 ] && usage

EVENT="$1"
RUN_ID="$2"
shift 2

case "$EVENT" in
  start|abort|done) ;;
  *) echo "[run-log] invalid event: $EVENT" >&2; usage ;;
esac

# 경로는 NFC 정규화 (macOS NFD/NFC 한글 경로 user memory 규칙)
PROJECT_ROOT="$(pwd)"
if command -v python3 >/dev/null 2>&1; then
  PROJECT_ROOT=$(python3 -c "import sys, unicodedata; print(unicodedata.normalize('NFC', sys.argv[1]))" "$PROJECT_ROOT")
fi

LOG_DIR=".claude/memory"
LOG_FILE="${LOG_DIR}/sleep-build-runs.jsonl"
mkdir -p "$LOG_DIR"

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# jq로 추가 키-값 누적 — 인자가 없으면 빈 객체
EXTRA_OBJ='{}'
for kv in "$@"; do
  if [[ "$kv" == *=* ]]; then
    K="${kv%%=*}"
    V="${kv#*=}"
    # 숫자면 number, 아니면 string으로 jq에 전달
    if [[ "$V" =~ ^-?[0-9]+$ ]]; then
      EXTRA_OBJ=$(echo "$EXTRA_OBJ" | jq --arg k "$K" --argjson v "$V" '.[$k] = $v')
    else
      EXTRA_OBJ=$(echo "$EXTRA_OBJ" | jq --arg k "$K" --arg v "$V" '.[$k] = $v')
    fi
  fi
done

# 최종 JSON 라인 — atomic append (단일 echo, OS-level 줄 단위 atomic)
LINE=$(jq -nc \
  --arg ts "$TS" \
  --arg run_id "$RUN_ID" \
  --arg event "$EVENT" \
  --arg root "$PROJECT_ROOT" \
  --argjson extra "$EXTRA_OBJ" \
  '{ts: $ts, run_id: $run_id, event: $event, project_root: $root} + $extra')

echo "$LINE" >> "$LOG_FILE"
