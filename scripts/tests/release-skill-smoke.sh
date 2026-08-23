#!/bin/bash
# /release 스킬 계약 smoke test (audit F-AA17/F-AA18)
# 실행: bash scripts/tests/release-skill-smoke.sh
#
# v2.5.0 컷에서 스킬 절차가 두 군데서 현실과 어긋났고 둘 다 손으로 메웠다:
#   1. 절차에 `.claude-plugin/*.json` 버전 필드가 없다 — 태그만 올라가고 선언 버전은
#      2.4.0 에 남는다. v2.4.0 때도 릴리즈 커밋(9903f2f)에서 수동 반영됐다.
#   2. `git push origin main --tags` — 브랜치 보호(2026-08-05) 도입 후 main 직접 push 는
#      remote 가 거부한다. 릴리즈 커밋은 PR 을 타야 한다.
# 손으로 메운 절차는 다음 사람이 같은 자리에서 다시 막힌다. 계약으로 고정한다.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$REPO_ROOT/core/skills/release/SKILL.md"
PJ="$REPO_ROOT/.claude-plugin/plugin.json"
MJ="$REPO_ROOT/.claude-plugin/marketplace.json"

PASS=0
FAIL=0
ok() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
ng() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

[ -f "$SKILL" ] || { echo "release/SKILL.md 부재"; exit 1; }

echo "Test RS1: 절차가 버전 필드 동기화를 지시"
if grep -q 'plugin.json' "$SKILL" && grep -q 'marketplace.json' "$SKILL"; then
  ok "RS1.1 plugin.json/marketplace.json 버전 갱신이 절차에 있다"
else
  ng "RS1.2 버전 필드 미언급 — 태그만 오르고 선언 버전은 직전 릴리즈에 남는다"
fi

echo "Test RS2: 브랜치 보호와 충돌하는 main 직접 push 지시 부재"
if grep -qE 'git push origin main --tags|git push .*main .*--tags' "$SKILL"; then
  ng "RS2.1 main 직접 push 지시 잔존 — 보호 브랜치가 거부한다(절차가 중단됨)"
else
  ok "RS2.2 main 직접 push 지시 없음"
fi

echo "Test RS3: 릴리즈 커밋의 PR 경로 명시"
if grep -qE 'PR|풀 리퀘스트' "$SKILL"; then
  ok "RS3.1 릴리즈 커밋을 PR 로 올리는 경로가 명시됨"
else
  ng "RS3.2 PR 경로 없음 — 보호 브랜치에서 어떻게 넣는지 절차가 침묵"
fi

echo "Test RS4: 선언 버전 3곳 상호 일치 (실측)"
v1=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$PJ" | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
vs=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$MJ" | sed 's/.*"\([^"]*\)"$/\1/')
bad=""
for v in $vs; do [ "$v" = "$v1" ] || bad="$bad $v"; done
if [ -n "$v1" ] && [ -z "$bad" ]; then
  ok "RS4.1 plugin.json($v1) == marketplace.json 전 필드"
else
  ng "RS4.2 버전 불일치: plugin=$v1 marketplace=$vs — 한쪽만 올린 릴리즈"
fi

echo ""
echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ ALL TESTS PASSED"; exit 0; } || { echo "✗ SOME TESTS FAILED"; exit 1; }
