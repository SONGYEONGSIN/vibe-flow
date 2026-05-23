#!/bin/bash
# /auto-build schedule 등록 helper — Claude Code schedule 스킬 호출 wrapper (Phase 3.1 PR-C1)
#
# 사용:
#   bash core/skills/auto-build/scripts/schedule-register.sh "<cron-expression>"
#
# env:
#   SCHEDULE_REGISTER_DRYRUN=1 — 실제 schedule 등록 안 함, "would register: ..." stdout만 출력 (smoke 안전 격리)
#
# 동작:
#   1. cron expression 5 필드 정규식 검증 (실패 시 exit 1)
#   2. DRYRUN=1 → stdout "would register: <expr>" + exit 0
#   3. DRYRUN=0 → claude CLI 존재 검사 (없으면 exit 2) → claude /schedule 호출
#
# 정책 (PR-C1):
#   실 등록(DRYRUN=0)은 사용자 manual 호출 권장. cron firing 시 run-queue.sh가
#   AUTO_BUILD_QUEUE_CRON_FIRING=1 env로 진입하여 orchestrator가 cron 컨텍스트 인지.

set -u

CRON_EXPR="${1:-}"

if [ -z "$CRON_EXPR" ]; then
  echo "usage: $0 \"<cron-expression>\"" >&2
  echo "example: $0 \"*/30 * * * *\"" >&2
  exit 1
fi

# ── cron expression validation ─────────────────────────────
# 5 필드(공백 분리) — 각 필드는 `*`, `*/N`, 숫자, 콤마, 하이픈만 허용
# noglob: `*` 단독 필드가 디렉토리 글로브로 확장되는 것 방지
set -f
read -ra FIELDS <<< "$CRON_EXPR"
set +f

if [ "${#FIELDS[@]}" -ne 5 ]; then
  echo "invalid cron expression: 5 fields required (got ${#FIELDS[@]})" >&2
  exit 1
fi

for f in "${FIELDS[@]}"; do
  if ! [[ "$f" =~ ^(\*|\*/[0-9]+|[0-9,\-]+)$ ]]; then
    echo "invalid cron expression: field '$f' has invalid format" >&2
    exit 1
  fi
done

# ── DRYRUN 분기 ────────────────────────────────────────────
DRYRUN="${SCHEDULE_REGISTER_DRYRUN:-0}"
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
RUN_QUEUE_PATH="$PROJECT_ROOT/core/skills/auto-build/scripts/run-queue.sh"

if [ "$DRYRUN" = "1" ]; then
  echo "would register: $CRON_EXPR"
  echo "  command: AUTO_BUILD_QUEUE_CRON_FIRING=1 bash $RUN_QUEUE_PATH"
  exit 0
fi

# ── 실 등록 (DRYRUN=0) ─────────────────────────────────────
if ! command -v claude >/dev/null 2>&1; then
  echo "claude CLI not found — install Claude Code first" >&2
  exit 2
fi

# Claude Code /schedule 슬래시 스킬 호출
# 등록 payload: AUTO_BUILD_QUEUE_CRON_FIRING=1 + run-queue.sh 절대 경로
echo "registering schedule: $CRON_EXPR"
claude /schedule "$CRON_EXPR" "AUTO_BUILD_QUEUE_CRON_FIRING=1 bash $RUN_QUEUE_PATH"
