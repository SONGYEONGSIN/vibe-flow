#!/bin/bash
set -u
# PostToolUseFailure hook: 도구 실행 실패 시 구조화된 에러 분류 + 복구 힌트
#
# Hermes Agent error_classifier 패턴 적용.
# 13개 에러 클래스로 분류하고 재시도 가능 여부 + 복구 제안을 제공한다.
# 기존 dual-write (JSON + SQLite + JSONL) 패턴 유지.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
ERROR=$(echo "$INPUT" | jq -r '.error // empty' 2>/dev/null)

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$PROJECT_ROOT" ] && exit 0

METRICS_DIR="${PROJECT_ROOT}/.claude/metrics"
mkdir -p "$METRICS_DIR" 2>/dev/null || true

# ── 에러 분류 함수 ──────────────────────────────────────────
# 입력: error_string, tool_name
# 출력: error_class|retryable|recovery (파이프 구분)

classify_error() {
  local error="$1"
  local tool="$2"
  local error_lower
  error_lower=$(echo "$error" | tr '[:upper:]' '[:lower:]')

  local error_class="unknown"
  local retryable="false"
  local recovery="에러 내용을 확인하고 수동으로 대응하세요."

  case "$error_lower" in
    *"401"*|*"403"*|*"unauthorized"*|*"eauth"*|*"invalid api key"*|*"authentication"*)
      error_class="auth"; retryable="false"
      recovery="인증 토큰 확인. 환경변수 또는 .env 파일 점검." ;;
    *"429"*|*"rate limit"*|*"too many requests"*|*"quota"*)
      error_class="rate_limit"; retryable="true"
      recovery="잠시 대기 후 재시도. 요청 빈도를 줄이세요." ;;
    *"etimedout"*|*"timeout"*|*"esockettimedout"*|*"request timed out"*)
      error_class="timeout"; retryable="true"
      recovery="네트워크 상�� 확인. 타임아웃 값 증가 고려." ;;
    *"context_length"*|*"context window"*|*"maximum context"*|*"token limit"*)
      error_class="context_overflow"; retryable="false"
      recovery="컨텍스트 축소 필요. /compact 실행 권장." ;;
    *"json"*|*"parse error"*|*"syntaxerror"*|*"unexpected token"*|*"malformed"*)
      error_class="format_error"; retryable="false"
      recovery="입출력 JSON 포맷 확인. jq로 검증." ;;
    *"build"*|*"webpack"*|*"vite"*|*"esbuild"*|*"rollup"*|*"next build"*)
      error_class="build_error"; retryable="false"
      recovery="빌드 설정 확인. 의존성 설치 상태 점검." ;;
    *"fail"*|*"vitest"*|*"jest"*|*"assert"*|*"expected"*|*"received"*)
      error_class="test_error"; retryable="false"
      recovery="실패 테스트 로그 분석. 예상값과 실제값 비교." ;;
    *"eslint"*|*"lint"*|*"prettier"*|*"formatting"*)
      error_class="lint_error"; retryable="false"
      recovery="린트 규칙 확인. --fix 옵션 시도." ;;
    *"ts"[0-9]*|*"typescript"*|*"type error"*|*"tsc"*|*"type '"*"' is not"*)
      error_class="type_error"; retryable="false"
      recovery="타입 정의 확인. 타입 선언 파일 점검." ;;
    *"econnrefused"*|*"enotfound"*|*"network"*|*"fetch failed"*|*"dns"*)
      error_class="network"; retryable="true"
      recovery="네트워크 연결 확인. URL/포트 점검." ;;
    *"eacces"*|*"permission denied"*|*"eperm"*|*"access denied"*)
      error_class="permission"; retryable="false"
      recovery="파일 권한 확인. chmod/chown 필요." ;;
    *"enoent"*|*"no such file"*|*"not found"*|*"module_not_found"*|*"cannot find"*)
      error_class="not_found"; retryable="false"
      recovery="파일/모듈 경로 확인. 존재 여부 점검." ;;
  esac

  echo "${error_class}|${retryable}|${recovery}"
}

# ── 에러 분류 실행 ──────────────────────────────────────────

CLASSIFIED=$(classify_error "$ERROR" "$TOOL_NAME")
ERROR_CLASS=$(echo "$CLASSIFIED" | cut -d'|' -f1)
RETRYABLE=$(echo "$CLASSIFIED" | cut -d'|' -f2)
RECOVERY=$(echo "$CLASSIFIED" | cut -d'|' -f3)

# ── EVENT JSON 생성 ─────────────────────────────────────────

DATE=$(date +%Y-%m-%d)
METRICS_FILE="${METRICS_DIR}/daily-${DATE}.json"

EVENT=$(jq -n \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg tool "$TOOL_NAME" \
  --arg error "$ERROR" \
  --arg ec "$ERROR_CLASS" \
  --arg retry "$RETRYABLE" \
  --arg rec "$RECOVERY" \
  '{timestamp: $ts, type: "tool_failure", tool: $tool, error: $error,
   error_class: $ec, retryable: ($retry == "true"), recovery: $rec}')

# ── JSON 메트릭 기록 ───────────────────────────────────────

if [ -f "$METRICS_FILE" ]; then
  jq --argjson evt "$EVENT" '.events += [$evt]' "$METRICS_FILE" > "${METRICS_FILE}.tmp" && mv "${METRICS_FILE}.tmp" "$METRICS_FILE"
else
  echo "{\"date\": \"${DATE}\", \"events\": [${EVENT}]}" > "$METRICS_FILE"
fi

# ── SQLite 이중 기록 (best-effort) ─────────────────────────

STORE_JS="${PROJECT_ROOT}/.claude/scripts/store.js"
if [ -f "$STORE_JS" ] && command -v node &>/dev/null; then
  echo "$EVENT" | node "$STORE_JS" append-failure 2>/dev/null || true
fi

# ── events.jsonl 실시간 스트림 기록 ────────────────────────

EVENTS_FILE="${PROJECT_ROOT}/.claude/events.jsonl"
echo "$EVENT" | jq -c '. + {status: "error", ts: .timestamp}' >> "$EVENTS_FILE" 2>/dev/null || true

# ── 복구 힌트 제공 ─────────────────────────────────────────

echo "{\"additionalContext\": \"[tool-failure] [${ERROR_CLASS}] ${RECOVERY}\"}"

exit 0
