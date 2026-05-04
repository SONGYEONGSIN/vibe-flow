#!/bin/bash
set -u
# sleep-build-safety.sh — PreToolUse 안전 hook for /sleep-build 자율 사이클
#
# SLEEP_BUILD_MODE=1 일 때만 활성. 비-자율 모드(env 미설정)에는 영향 0.
# 차단 규약: stderr에 사유 출력 + exit 2 (Claude Code PreToolUse 차단).
#
# 차단 카테고리:
#   1. destructive op  — rm -rf, git reset --hard, git push --force, --no-verify, chmod 777, fork bomb
#   2. token cap       — (T4)
#   3. file count cap  — (T4)

# 자율 모드 아니면 즉시 통과
if [ "${SLEEP_BUILD_MODE:-}" != "1" ]; then
  exit 0
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# Bash 외에는 destructive 패턴 검증 X (Write/Edit는 결과 파일 검증이 security-lint 책임)
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

block() {
  local reason="$1"
  echo "[sleep-build-safety] BLOCKED — ${reason}" >&2
  echo "[sleep-build-safety] command: ${CMD}" >&2
  echo "[sleep-build-safety] 자율 사이클은 destructive op 금지. 수동 사이클로 전환 후 재시도." >&2
  exit 2
}

# 1. rm -rf (root, home, 임의 절대 경로)
if echo "$CMD" | grep -qE '\brm\s+(-[a-zA-Z]*r[a-zA-Z]*f|--recursive\s+--force|--force\s+--recursive|-fr|-rf)\b'; then
  block "rm -rf 패턴 — 자율 모드에서 destructive 삭제 금지"
fi

# 2. git reset --hard
if echo "$CMD" | grep -qE '\bgit\s+reset\s+(--hard|--mixed.*--hard)'; then
  block "git reset --hard — uncommitted 변경 손실 위험"
fi

# 3. git push --force (--force-with-lease 포함, 자율 모드는 모두 차단)
if echo "$CMD" | grep -qE '\bgit\s+push\b.*(--force(-with-lease)?|-f\b)'; then
  block "git push --force — remote 히스토리 덮어쓰기 위험"
fi

# 4. --no-verify (commit/push hook bypass)
if echo "$CMD" | grep -qE '\bgit\s+(commit|push)\b.*--no-verify'; then
  block "git commit/push --no-verify — pre-commit hook bypass 금지"
fi

# 5. chmod 777 (권한 과다 부여)
if echo "$CMD" | grep -qE '\bchmod\s+(-R\s+)?777\b'; then
  block "chmod 777 — 과도한 권한 부여 금지"
fi

# 6. fork bomb
if echo "$CMD" | grep -qE ':\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:'; then
  block "fork bomb 패턴 — 시스템 리소스 고갈 위험"
fi

# 7. dd 디스크 직접 쓰기 (보너스 — destructive)
if echo "$CMD" | grep -qE '\bdd\s+.*\bof=/dev/(sda|nvme|disk|hda)'; then
  block "dd 디스크 직접 쓰기 — 데이터 파괴 위험"
fi

# 8. mkfs / 포맷
if echo "$CMD" | grep -qE '\bmkfs\.[a-z0-9]+\b|\bformat\s+(/dev/|[A-Z]:)'; then
  block "mkfs / format — 파일시스템 파괴 위험"
fi

# ──────────────────────────────────────────────────────────────
# T4: token cap (현재 사이클 누적 토큰 초과 시 차단)
# ──────────────────────────────────────────────────────────────
TOKEN_CAP="${SLEEP_BUILD_TOKEN_CAP:-130000}"
RUNS_LOG=".claude/memory/sleep-build-runs.jsonl"

if [ -f "$RUNS_LOG" ] && [ -n "${SLEEP_BUILD_RUN_ID:-}" ]; then
  # 현재 run_id의 모든 라인 중 가장 최근 tokens_in/tokens_out 합산
  CUR_TOKENS=$(jq -r --arg rid "$SLEEP_BUILD_RUN_ID" '
      select(.run_id == $rid) | (.tokens_in // 0) + (.tokens_out // 0)
    ' "$RUNS_LOG" 2>/dev/null | awk '{s+=$1} END {print s+0}')

  if [ -n "$CUR_TOKENS" ] && [ "$CUR_TOKENS" -gt "$TOKEN_CAP" ] 2>/dev/null; then
    echo "[sleep-build-safety] BLOCKED — token cap 초과" >&2
    echo "[sleep-build-safety] 누적: ${CUR_TOKENS} / cap: ${TOKEN_CAP}" >&2
    echo "[sleep-build-safety] exit_reason=token_cap_exceeded — 사이클 abort 권장" >&2
    exit 2
  fi
fi

# ──────────────────────────────────────────────────────────────
# T4: file count cap (HARD-GATE 20+ 자율 차단)
# ──────────────────────────────────────────────────────────────
FILE_CAP="${SLEEP_BUILD_FILE_CAP:-19}"

# 현재 branch가 sleep-build branch(feat/sleep-*)일 때만 검사
CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if echo "$CUR_BRANCH" | grep -qE '^feat/sleep-'; then
  # main과의 diff 파일 수 (merge-base 기준 — main으로부터 분기 시점)
  BASE=$(git merge-base HEAD main 2>/dev/null || echo "")
  if [ -n "$BASE" ]; then
    CHANGED=$(git diff --name-only "$BASE"..HEAD 2>/dev/null | wc -l | tr -d ' ')
    # uncommitted 변경 (tracked modified + untracked) 모두 합산 — porcelain 사용
    UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    TOTAL=$((CHANGED + UNCOMMITTED))

    if [ "$TOTAL" -gt "$FILE_CAP" ] 2>/dev/null; then
      echo "[sleep-build-safety] BLOCKED — file count cap 초과" >&2
      echo "[sleep-build-safety] 변경 파일: ${TOTAL} / cap: ${FILE_CAP} (HARD-GATE 20+ 진입 직전)" >&2
      echo "[sleep-build-safety] exit_reason=file_cap_exceeded — 사이클 abort, 수동 plan 분할 권장" >&2
      exit 2
    fi
  fi
fi

exit 0
