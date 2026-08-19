#!/bin/bash
# karpathy-principles.md 최소 설계 체크리스트 인용 정합성 smoke test (audit F-Q16)
# 실행: bash scripts/tests/karpathy-principles-ref-smoke.sh
#
# core/rules/karpathy-principles.md 는 frontmatter 가 없어 글로벌 상시로드된다.
# "최소 설계 체크리스트"는 rules/discipline.md 로 T1 라운드에 이관됐으나(conventions.md:11
# 이 스스로 이 사실을 명시), 78행 인용이 구 위치 rules/conventions.md 를 여전히 가리켜
# 같은 파일 20행 인용과 자기모순됐다.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET="$REPO_ROOT/core/rules/karpathy-principles.md"

PASS=0
FAIL=0
ok() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
ng() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

echo "=== karpathy-principles.md 체크리스트 인용 정합성 (F-Q16) ==="

[ -f "$TARGET" ] || { echo "  ✗ 대상 파일 없음: $TARGET"; FAIL=$((FAIL + 1)); }

# 체크리스트를 언급하는 모든 라인이 rules/discipline.md 를 가리켜야 하고,
# 구 위치 rules/conventions.md 를 가리키면 안 된다.
STALE=$(grep -n "체크리스트" "$TARGET" | grep -c "rules/conventions\.md" || true)
[ "$STALE" -eq 0 ] && ok "체크리스트 인용이 rules/conventions.md 를 가리키지 않음" \
  || ng "체크리스트 인용 ${STALE}건이 여전히 rules/conventions.md 를 가리킴 (rules/discipline.md 로 이관됨)"

FRESH=$(grep -n "체크리스트" "$TARGET" | grep -c "rules/discipline\.md" || true)
[ "$FRESH" -ge 2 ] && ok "체크리스트 인용 ${FRESH}건 모두 rules/discipline.md 로 정합" \
  || ng "rules/discipline.md 인용 ${FRESH}건 (기대 ≥2)"

echo ""
echo "=== 결과 ==="
echo "  통과: $PASS / 실패: $FAIL"

[ "$FAIL" -eq 0 ]
