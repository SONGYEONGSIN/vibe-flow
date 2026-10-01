#!/bin/bash
# F-R09 (audit round R): docs/MIGRATION.md 의 글로벌 심볼릭 루프가 skills/agents/rules
# 를 한 묶음으로 처리했으나, setup.sh 가 이미 core/rules/*.md 를 프로젝트마다
# .claude/rules/ 로 설치하므로 rules 의 전역 심볼릭은 완전 중복(frontmatter 없는
# 5종 문서가 "user private global" + "project instructions" 로 2회 주입).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$REPO_ROOT/docs/MIGRATION.md"
PASS=0; FAIL=0
ok() { echo "  ✓ $1"; PASS=$((PASS+1)); }
ng() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }

echo "Test: MIGRATION.md 글로벌 심볼릭 루프 — rules 중복 제거 (F-R09)"

LOOP_LINE=$(grep -n '^for link in' "$DOC" || true)
case "$LOOP_LINE" in
  *rules*) ng "symlink 루프에 rules 가 여전히 포함됨: $LOOP_LINE" ;;
  *skills*agents*) ok "symlink 루프가 skills agents 만 포함 (rules 제거됨)" ;;
  *) ng "symlink 루프 라인을 찾을 수 없음" ;;
esac

if grep -q 'ln -s .*core/rules .*\.claude/rules' "$DOC"; then
  ng "core/rules → .claude/rules 전역 심볼릭 생성 라인이 여전히 존재"
else
  ok "core/rules → .claude/rules 전역 심볼릭 생성 라인 제거 확인"
fi

echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ ALL TESTS PASSED"; exit 0; }
echo "✗ TESTS FAILED"; exit 1
