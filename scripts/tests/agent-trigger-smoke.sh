#!/bin/bash
# agent-trigger-smoke.sh — agent 호출 조건 명시 계약 (audit F-AA10)
# 실행: bash scripts/tests/agent-trigger-smoke.sh
#
# Claude Code 는 "사용자가 요청하지 않은 서브에이전트 호출 금지" 를 규칙으로 둔다.
# 그런데 agent description 이 호출 조건 없이 역할만 서술하면("코드 구현 전문
# 에이전트"), 평범한 작업 요청에도 서브에이전트가 붙어 사용자가 예상 못 한
# 병렬 dispatch 와 요금이 발생한다 — 특히 fan-out 이 세션 모델을 상속하면 배가 된다.
#
# 계약: 모든 agent description 은 **호출 조건을 명시**해야 한다. 둘 중 하나다.
#   (a) 사용자 요청 트리거 — "…요청 시" 예시를 포함
#   (b) 스킬 내부 전용   — "내부 전용" 을 명시해 직접 호출 대상이 아님을 선언
# 조건 없는 역할-only description 은 두 경우 어디에도 속하지 않아 오호출을 부른다.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
AGENT_DIR="$REPO_ROOT/core/agents"

PASS=0; FAIL=0
ok() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
ng() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

echo "Test AT1: agent description 이 호출 조건을 명시"
missing=""
total=0
for f in "$AGENT_DIR"/*.md; do
  [ -f "$f" ] || continue
  total=$((total + 1))
  name=$(basename "$f" .md)
  # frontmatter(첫 --- ~ 두번째 ---) 안의 description 블록만 검사
  fm=$(awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f' "$f")
  if printf '%s' "$fm" | grep -qE '요청 시|내부 전용'; then
    continue
  fi
  missing="$missing $name"
done
if [ -z "$missing" ]; then
  ok "AT1.1 전 agent($total) 가 호출 조건 명시 (요청 시 / 내부 전용)"
else
  ng "AT1.2 조건 미표기:$missing — 요청 없이 서브에이전트가 뜰 수 있다"
fi

echo "Test AT2: 스킬 내부 전용 agent 는 직접 호출 대상이 아님을 선언"
# 다른 스킬이 오케스트레이션용으로만 쓰는 agent 들. 사용자가 직접 부를 일이 없으므로
# "내부 전용" 을 명시해 Claude 가 자발적으로 집지 않게 한다.
for name in comparator moderator validator; do
  f="$AGENT_DIR/$name.md"
  [ -f "$f" ] || { ng "AT2 $name.md 부재"; continue; }
  fm=$(awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f' "$f")
  if printf '%s' "$fm" | grep -q '내부 전용'; then
    ok "AT2 $name — 내부 전용 선언"
  else
    ng "AT2 $name — 내부 전용 미선언 (사용자 요청 없이 호출될 수 있다)"
  fi
done

echo
echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ ALL TESTS PASSED"; exit 0; } || { echo "✗ SOME TESTS FAILED"; exit 1; }
