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

# ── 인자 파싱 ──────────────────────────────────────────────
# 사용법:
#   $0 "<cron-expression>"                  — 재귀 cron 모드
#   RUN_ONCE_AT=<RFC3339> $0 --once         — 1회용 모드
MODE="cron"
CRON_EXPR=""
RUN_ONCE_AT_VALUE="${RUN_ONCE_AT:-}"

if [ "${1:-}" = "--once" ]; then
  MODE="once"
  if [ -n "${2:-}" ]; then
    echo "error: --once 모드에서는 cron expression 인자 사용 불가 (RUN_ONCE_AT env로 시각 지정)" >&2
    exit 1
  fi
  if [ -z "$RUN_ONCE_AT_VALUE" ]; then
    echo "error: --once 모드는 RUN_ONCE_AT env (RFC 3339 UTC) 필수" >&2
    exit 1
  fi
  # RFC 3339 형식 검증 (YYYY-MM-DDTHH:MM:SSZ)
  if ! [[ "$RUN_ONCE_AT_VALUE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
    echo "error: RUN_ONCE_AT='$RUN_ONCE_AT_VALUE' invalid RFC 3339 UTC (expected YYYY-MM-DDTHH:MM:SSZ)" >&2
    exit 1
  fi
else
  CRON_EXPR="${1:-}"
  if [ -z "$CRON_EXPR" ]; then
    echo "usage: $0 \"<cron-expression>\"  (cron 모드)" >&2
    echo "       RUN_ONCE_AT=<RFC3339> $0 --once  (1회용 모드)" >&2
    echo "example: $0 \"0 */6 * * *\"" >&2
    exit 1
  fi
fi

# ── cron expression validation (cron 모드만) ───────────────
if [ "$MODE" = "cron" ]; then
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

  # 1h min interval check — RemoteTrigger API는 1시간 미만 cron 거부
  MINUTE_FIELD="${FIELDS[0]}"
  if ! [[ "$MINUTE_FIELD" =~ ^[0-9]+$ ]] || [ "$((10#$MINUTE_FIELD))" -gt 59 ]; then
    echo "invalid cron expression: interval too short — 1 hour minimum required (minute field must be a single integer 0-59, got '$MINUTE_FIELD')" >&2
    exit 1
  fi
fi

# ── Payload 생성 (PR-C1.1 cloud-native) ────────────────────
# RemoteTrigger create API payload JSON 빌드:
#   - body.schedule.cron: <CRON_EXPR>
#   - body.prompt: cloud-prompt-template.md 본문 (placeholder 치환됨)
# env: REPO_URL (기본 `git remote get-url origin`), BRANCH (기본 main)

DRYRUN="${SCHEDULE_REGISTER_DRYRUN:-0}"
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
TEMPLATE_PATH="$PROJECT_ROOT/core/skills/auto-build/data/cloud-prompt-template.md"

if [ ! -f "$TEMPLATE_PATH" ]; then
  echo "cloud-prompt-template.md not found at $TEMPLATE_PATH" >&2
  exit 3
fi

# env defaults
REPO_URL="${REPO_URL:-$(git remote get-url origin 2>/dev/null || echo '<unknown>')}"
BRANCH="${BRANCH:-main}"

# placeholder 치환 (sed로 단순 치환 — &/\는 escape, # delimiter)
TEMPLATE_BODY=$(sed -e "s#{{REPO_URL}}#${REPO_URL//\#/\\#}#g" \
                    -e "s#{{BRANCH}}#${BRANCH//\#/\\#}#g" \
                    "$TEMPLATE_PATH")

# payload JSON 빌드 (jq -n으로 안전한 string escape)
# MODE에 따라 schedule 필드 분기: cron OR run_once_at
if [ "$MODE" = "once" ]; then
  PAYLOAD=$(jq -nc \
    --arg run_once "$RUN_ONCE_AT_VALUE" \
    --arg prompt "$TEMPLATE_BODY" \
    --arg repo "$REPO_URL" \
    --arg branch "$BRANCH" \
    '{
      action: "create",
      body: {
        schedule: { run_once_at: $run_once },
        prompt: $prompt,
        repo_url: $repo,
        branch: $branch
      }
    }')
  DISPLAY_SCHED="run_once_at=$RUN_ONCE_AT_VALUE"
else
  PAYLOAD=$(jq -nc \
    --arg cron "$CRON_EXPR" \
    --arg prompt "$TEMPLATE_BODY" \
    --arg repo "$REPO_URL" \
    --arg branch "$BRANCH" \
    '{
      action: "create",
      body: {
        schedule: { cron: $cron },
        prompt: $prompt,
        repo_url: $repo,
        branch: $branch
      }
    }')
  DISPLAY_SCHED="$CRON_EXPR"
fi

if [ "$DRYRUN" = "1" ]; then
  # legacy 한 줄(PR-C1)은 stderr로 분리 — stdout은 JSON only (jq 파이프 안전)
  echo "would register: $DISPLAY_SCHED" >&2
  echo "$PAYLOAD"
  exit 0
fi

# ── 실 등록 (DRYRUN=0) ─────────────────────────────────────
# RemoteTrigger API는 claude.ai 인증 필요 — `claude` CLI 호출로 위임
if ! command -v claude >/dev/null 2>&1; then
  echo "claude CLI not found — install Claude Code first" >&2
  exit 2
fi

# 실 호출은 사용자 manual 권장 — 자동 호출은 보안/비용 이유로 안내만 출력
cat >&2 <<EOM
Manual step required:
  1. Open Claude Code interactive session
  2. Invoke: /schedule (load skill)
  3. Paste the following payload to RemoteTrigger create:

$PAYLOAD

  Or use the Anthropic dashboard: https://claude.ai/code/routines
EOM
echo "$PAYLOAD"
exit 0
