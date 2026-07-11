#!/bin/bash
# hooks-stdin-drain-smoke.sh — F-K21: 등록 훅의 stdin drain 계약 검증
#
# Claude Code(writer)는 모든 훅 stdin 에 payload 를 파이프로 쓴다. 훅이 drain 전에
# 종료하면 writer 가 EPIPE → "hook error: Failed to write to socket" 반복 표출
# (F-K20 = skill-tracker 단건, F-K21 = 나머지 훅 전수 계약화).
#
# 검증 2단:
#   1) 정적 게이트 — settings.template.json 에 등록된 모든 훅 소스가
#      stdin 소비 패턴을 포함해야 함 (신규 훅 재발 방지)
#   2) 런타임 스팟 — 부작용 없는 훅(uncommitted-warn)에 120KB 파이프,
#      writer SIGPIPE(141) 없음 확인 (pipe buffer 64KB 초과로 결정적 재현)
#
# 실행: bash scripts/tests/hooks-stdin-drain-smoke.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE="$REPO_ROOT/settings/settings.template.json"

PASS=0
FAIL=0

# ── 1) 정적 게이트 ─────────────────────────────────────────
echo "=== 1) 등록 훅 전수 — stdin 소비 패턴 존재 (정적) ==="
while IFS= read -r cmd; do
  # 등록 경로는 .claude/hooks/* — CI fresh clone 에는 core/hooks/* 만 존재 (sync 로 동일)
  src="$REPO_ROOT/core/hooks/$(basename "$cmd")"
  if [ ! -f "$src" ]; then
    echo "  ✗ $(basename "$cmd") — core/hooks 에 소스 없음"
    FAIL=$((FAIL + 1))
    continue
  fi
  if grep -qE '\$\(cat\)|cat >|cat -|/dev/stdin' "$src"; then
    echo "  ✓ $(basename "$cmd")"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $(basename "$cmd") — stdin 미소비 (EPIPE 위험)"
    FAIL=$((FAIL + 1))
  fi
done < <(jq -r '.hooks | to_entries[] | .value[].hooks[].command' "$TEMPLATE" | sort -u)

# ── 2) 런타임 스팟 — writer SIGPIPE 재현/방지 ─────────────
echo "=== 2) uncommitted-warn 120KB 파이프 — writer SIGPIPE 없음 (런타임) ==="
NOGIT=$(mktemp -d)
cd "$NOGIT"
printf 'x%.0s' $(seq 1 120000) | bash "$REPO_ROOT/core/hooks/uncommitted-warn.sh" >/dev/null 2>&1
rc=("${PIPESTATUS[@]}")
if [ "${rc[0]}" = "141" ]; then
  echo "  ✗ writer SIGPIPE(141) — stdin 미소비 (EPIPE 재현)"
  FAIL=$((FAIL + 1))
else
  echo "  ✓ writer 정상 종료 (exit ${rc[0]})"
  PASS=$((PASS + 1))
fi
cd /; rm -rf "$NOGIT"

echo
echo "=== 결과 ==="
echo "  통과: $PASS / 실패: $FAIL"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
