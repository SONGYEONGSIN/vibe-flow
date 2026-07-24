#!/bin/bash
# /auto-build schedule 등록 helper — RemoteTrigger create payload 생성 (Phase 3.1 F10/F11/F12 fix)
#
# 사용:
#   bash core/skills/auto-build/scripts/schedule-register.sh "<cron-expression>"
#   RUN_ONCE_AT=<RFC3339> bash core/skills/auto-build/scripts/schedule-register.sh --once
#
# 필수 env (DRYRUN=0 실 paste 시):
#   RT_ENVIRONMENT_ID — 사용자 계정별 Anthropic environment ID (claude.ai/code/routines 에서 확인)
#
# 선택 env:
#   RT_ROUTINE_NAME (기본 "vibe-flow auto-build")
#   RT_MODEL (기본 "claude-sonnet-4-6")
#   REPO_URL (기본 `git remote get-url origin`)
#   SCHEDULE_REGISTER_DRYRUN=1 — 실제 등록 안 함, payload JSON만 stdout (smoke 안전 격리)
#
# 출력:
#   stdout — RemoteTrigger create payload JSON (action+body wrapper). 사용자가 그대로
#            RemoteTrigger tool action="create" + body=<payload.body> 형태로 paste 가능
#
# 정책 (PR-C1.1 → F10 fix):
#   payload.body는 실 RemoteTrigger API spec와 일치 (job_config.ccr.environment_id /
#   events[].data.message.content / session_context.sources[].git_repository.url /
#   mcp_connections:[] 명시). 사용자가 별도 변환 불필요.

set -u

# ── 인자 파싱 ──────────────────────────────────────────────
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

# ── Payload 생성 (F10 fix: 실 RemoteTrigger API spec) ──────
DRYRUN="${SCHEDULE_REGISTER_DRYRUN:-0}"
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
TEMPLATE_PATH="$PROJECT_ROOT/core/skills/auto-build/data/cloud-prompt-template.md"

if [ ! -f "$TEMPLATE_PATH" ]; then
  echo "cloud-prompt-template.md not found at $TEMPLATE_PATH" >&2
  exit 3
fi

# 실 등록(DRYRUN=0)에서만 RT_ENVIRONMENT_ID 필수 — dryrun은 smoke 호환 위해 placeholder 허용
RT_ENVIRONMENT_ID_VALUE="${RT_ENVIRONMENT_ID:-}"
if [ "$DRYRUN" != "1" ] && [ -z "$RT_ENVIRONMENT_ID_VALUE" ]; then
  echo "error: RT_ENVIRONMENT_ID env required (계정별 Anthropic environment ID — claude.ai/code/routines 에서 확인)" >&2
  exit 4
fi
RT_ENVIRONMENT_ID_VALUE="${RT_ENVIRONMENT_ID_VALUE:-env_REPLACE_WITH_YOUR_ID}"

# defaults
RT_ROUTINE_NAME_VALUE="${RT_ROUTINE_NAME:-vibe-flow auto-build}"
RT_MODEL_VALUE="${RT_MODEL:-claude-sonnet-4-6}"
REPO_URL_RAW="${REPO_URL:-$(git remote get-url origin 2>/dev/null || echo '<unknown>')}"
# sources[].git_repository.url은 .git suffix 없는 형태 사용 (R8/R9 routine 패턴)
REPO_URL_VALUE="${REPO_URL_RAW%.git}"

# F-K14 뿌리(순서): 값싼 환경 검사(claude CLI)를 uuid 생성보다 먼저 —
# 실 등록 경로에서 uuidgen/python3 부재(exit 5)가 claude 부재(exit 2)를 가리지 않게.
if [ "$DRYRUN" != "1" ] && ! command -v claude >/dev/null 2>&1; then
  echo "claude CLI not found — install Claude Code first" >&2
  exit 2
fi

# message UUID (RemoteTrigger 각 events entry 고유)
# F-K14: uuidgen 없는 플랫폼(일부 Windows git-bash) 폴백 — python3 uuid
if command -v uuidgen >/dev/null 2>&1; then
  MSG_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
elif command -v python3 >/dev/null 2>&1; then
  MSG_UUID=$(python3 -c "import uuid; print(uuid.uuid4())")
else
  echo "uuidgen/python3 not found — required for message UUID" >&2
  exit 5
fi

# F11: prompt 본문은 git clone block 제거됨 (sources가 자동 checkout)
# placeholder 치환 — 본문에 변수 토큰 남아있으면 sed로 안전 치환
TEMPLATE_BODY=$(sed -e "s#{{REPO_URL}}#${REPO_URL_VALUE//\#/\\#}#g" "$TEMPLATE_PATH")

# session_context.allowed_tools — 폐루프 5-phase에 필요한 최소 도구.
# F-N02 (audit R14): Phase 2 AUDIT 는 /audit 스킬을 호출하고 dimension agent 를 병렬
# dispatch 한다(audit/SKILL.md: allowed-tools ... Agent). Agent/Task 없이는 firing 시
# Phase 2 가 툴 부재로 죽어 폐루프 analyze 가 단락된다. 검증된 활성 routine(prompt-evolve)
# 셋과 정합. cloud-loop-prompt-smoke.sh L5 가 이 grant 를 템플릿 /audit 배선에 묶어 고정.
ALLOWED_TOOLS_JSON='["Bash","Read","Write","Edit","Glob","Grep","Agent","Task"]'

# payload body 빌드 — schedule 필드는 MODE에 따라 최상위 run_once_at 또는 cron_expression
if [ "$MODE" = "once" ]; then
  SCHEDULE_KEY="run_once_at"
  SCHEDULE_VAL="$RUN_ONCE_AT_VALUE"
  DISPLAY_SCHED="run_once_at=$RUN_ONCE_AT_VALUE"
else
  SCHEDULE_KEY="cron_expression"
  SCHEDULE_VAL="$CRON_EXPR"
  DISPLAY_SCHED="$CRON_EXPR"
fi

# F12: mcp_connections:[] 명시 — 미지정 시 cloud가 4개 connector 자동 attach 회피
PAYLOAD=$(jq -nc \
  --arg name "$RT_ROUTINE_NAME_VALUE" \
  --arg env_id "$RT_ENVIRONMENT_ID_VALUE" \
  --arg prompt "$TEMPLATE_BODY" \
  --arg repo "$REPO_URL_VALUE" \
  --arg uuid "$MSG_UUID" \
  --arg model "$RT_MODEL_VALUE" \
  --argjson tools "$ALLOWED_TOOLS_JSON" \
  --arg sched_key "$SCHEDULE_KEY" \
  --arg sched_val "$SCHEDULE_VAL" \
  '{
    action: "create",
    body: ({
      name: $name,
      job_config: {
        ccr: {
          environment_id: $env_id,
          events: [{
            data: {
              message: { content: $prompt, role: "user" },
              parent_tool_use_id: null,
              session_id: "",
              type: "user",
              uuid: $uuid
            }
          }],
          session_context: {
            allowed_tools: $tools,
            model: $model,
            sources: [{ git_repository: { url: $repo } }]
          }
        }
      },
      mcp_connections: []
    } + { ($sched_key): $sched_val })
  }')

if [ "$DRYRUN" = "1" ]; then
  echo "would register: $DISPLAY_SCHED" >&2
  echo "$PAYLOAD"
  exit 0
fi

# ── 실 등록 (DRYRUN=0) — claude CLI 검사는 uuid 생성 전에 수행됨 (F-K14) ──
cat >&2 <<EOM
Manual step required:
  1. Open Claude Code interactive session
  2. RemoteTrigger tool 호출 — action="create" + body=<아래 payload의 body 객체>
     (또는 /schedule 스킬 사용)
  3. 응답에서 routine id 확인 (trig_...)

  payload (실 API spec — 그대로 paste 가능):

$PAYLOAD

  Dashboard: https://claude.ai/code/routines
EOM
echo "$PAYLOAD"
exit 0
