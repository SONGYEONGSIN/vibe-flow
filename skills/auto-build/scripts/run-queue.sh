#!/bin/bash
# /auto-build run-queue — queue 첫 task pop + 사이클 trigger (Phase 3.0 PR-B)
#
# env:
#   AUTO_BUILD_QUEUE_MAX_CYCLES (기본 3)            — 1 firing당 max cycle cap
#   AUTO_BUILD_QUEUE_DRYRUN (=1)                    — 실제 trigger 안 함, echo만 (smoke test 안전 격리)
#   AUTO_BUILD_QUEUE_DRYRUN_FAIL (=1)               — DRYRUN 중 의도적 abort (smoke test용)
#   AUTO_BUILD_QUEUE_MAX_FIRINGS_PER_DAY (기본 2)   — 1일 max firing cap (Phase 3.1 PR-C1)
#   QUEUE_STORE / QUEUE_LOCK_DIR                    — queue.sh와 동일
#   FIRINGS_STORE                                   — firings 영속화 경로 (Phase 3.1 PR-C1)
#
# 주의 (PR-C2 이후):
#   firings.jsonl / MAX_FIRINGS_PER_DAY는 **local manual `run-queue.sh` 한정**
#   의미로 축소. cloud cron firing은 `RemoteTrigger` cron freq 자체로 cap
#   (1일 N firing). cloud agent는 ephemeral checkout이라 firings.jsonl 접근 불가.
#   cloud 진입점은 `core/skills/auto-build/scripts/run-cloud.sh` (PR-C2).
#
# 동작:
#   1. queue.sh next로 queued 첫 entry pop (running 마킹)
#   2. DRYRUN=1 → echo + status-update done (또는 DRYRUN_FAIL=1이면 aborted)
#   3. DRYRUN=0 → 실 trigger는 Phase 3.1 schedule scope, 본 PR은 echo + warning + aborted
#   4. cycle abort 발생 시 즉시 종료 (R2 정책)
#   5. MAX cycle 도달 또는 큐 empty 시 종료

set -euo pipefail

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
QUEUE_SH="$PROJECT_ROOT/core/skills/auto-build/scripts/queue.sh"

# child queue.sh가 동일 store/lockdir을 보도록 명시 export
# (child shell이 PROJECT_ROOT를 재계산하는 cwd 분기 위험 차단)
export QUEUE_STORE="${QUEUE_STORE:-$PROJECT_ROOT/.claude/memory/auto-build-queue.jsonl}"
export QUEUE_LOCK_DIR="${QUEUE_LOCK_DIR:-$PROJECT_ROOT/.claude/.queue.lock}"
FIRINGS_STORE="${FIRINGS_STORE:-$PROJECT_ROOT/.claude/memory/auto-build-firings.jsonl}"

MAX_RAW="${AUTO_BUILD_QUEUE_MAX_CYCLES:-3}"
# 양의 정수만 허용 — 음수/0/문자열은 기본 3으로 fallback (silent 회피)
if [[ "$MAX_RAW" =~ ^[1-9][0-9]*$ ]]; then
  MAX="$MAX_RAW"
else
  echo "run-queue: AUTO_BUILD_QUEUE_MAX_CYCLES='$MAX_RAW' 무효, 3으로 fallback" >&2
  MAX=3
fi

MAX_FIRINGS_RAW="${AUTO_BUILD_QUEUE_MAX_FIRINGS_PER_DAY:-2}"
if [[ "$MAX_FIRINGS_RAW" =~ ^[1-9][0-9]*$ ]]; then
  MAX_FIRINGS="$MAX_FIRINGS_RAW"
else
  echo "run-queue: AUTO_BUILD_QUEUE_MAX_FIRINGS_PER_DAY='$MAX_FIRINGS_RAW' 무효, 2로 fallback" >&2
  MAX_FIRINGS=2
fi

DRYRUN="${AUTO_BUILD_QUEUE_DRYRUN:-0}"
DRYRUN_FAIL="${AUTO_BUILD_QUEUE_DRYRUN_FAIL:-0}"

# ── firings cap 검사 (Phase 3.1 PR-C1) ──────────────────────
# 당일(UTC) firings.jsonl 라인 수가 MAX_FIRINGS 도달 시 즉시 종료
mkdir -p "$(dirname "$FIRINGS_STORE")"
touch "$FIRINGS_STORE"
TODAY=$(date -u +%Y-%m-%d)
TODAY_COUNT=$(grep -c "\"ts\":\"$TODAY" "$FIRINGS_STORE" 2>/dev/null || echo 0)
# grep -c가 통째 빈 stdout 반환 시 0으로 안전 처리
TODAY_COUNT="${TODAY_COUNT:-0}"
if [ "$TODAY_COUNT" -ge "$MAX_FIRINGS" ]; then
  echo "run-queue: max firings reached ($TODAY_COUNT/$MAX_FIRINGS today) — skip" >&2
  exit 0
fi

# firing 시작 시점 1 라인 append (cycle 루프 외부 — 1 firing = 1 라인)
echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$FIRINGS_STORE"

COUNT=0
while [ "$COUNT" -lt "$MAX" ]; do
  ID=$(bash "$QUEUE_SH" next)
  if [ -z "$ID" ]; then
    echo "run-queue: 큐 비어 있음 (processed $COUNT cycle)"
    break
  fi

  echo "run-queue: cycle $((COUNT+1))/$MAX — entry $ID"

  if [ "$DRYRUN" = "1" ]; then
    if [ "$DRYRUN_FAIL" = "1" ]; then
      bash "$QUEUE_SH" status-update "$ID" "aborted" >/dev/null
      echo "run-queue: cycle $((COUNT+1)) aborted (DRYRUN_FAIL) — 즉시 종료" >&2
      exit 1
    fi
    bash "$QUEUE_SH" status-update "$ID" "done" >/dev/null
    echo "run-queue: cycle $((COUNT+1)) done (DRYRUN)"
  else
    # 실 /auto-build trigger는 Phase 3.1 schedule scope.
    # entry는 running 상태 그대로 보존 — 사용자가 DRYRUN flag 누락한 실수일 수 있어 task 영구 소실(aborted 마킹) 회피.
    if [ "${AUTO_BUILD_QUEUE_CRON_FIRING:-0}" = "1" ]; then
      cat >&2 <<EOM
run-queue: cron-triggered firing 감지 (AUTO_BUILD_QUEUE_CRON_FIRING=1).
  실 trigger 본 PR(C1) 미구현 — manual /schedule 등록 검증만.
  entry $ID 는 'running' 상태로 보존됨 (소실 방지).
EOM
    else
      cat >&2 <<EOM
run-queue: 실 trigger는 미구현 (Phase 3.1 schedule scope).
  entry $ID 는 'running' 상태로 보존됨 (소실 방지).
  복구: bash core/skills/auto-build/scripts/queue.sh status-update $ID queued
  검증: AUTO_BUILD_QUEUE_DRYRUN=1 로 재호출.
EOM
    fi
    exit 1
  fi

  COUNT=$((COUNT+1))
done

echo "run-queue: $COUNT cycle 완료 (MAX=$MAX)"
