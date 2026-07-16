#!/bin/bash
# validate.sh REQUIRED_HOOKS 실측화 스모크 (F-M10, audit R13) — fixture RED/GREEN
# vibe-flow repo(core/hooks 존재)면 리터럴 대신 실측 enumerate 가 요구 목록이 되는지,
# downstream(core/ 부재)이면 리터럴 폴백이 유지되는지 검증. F-H04/F-K04 idiom 의 hooks 판.
# 실행: bash scripts/tests/validate-hooks-manifest-smoke.sh
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VAL="$REPO_ROOT/validate.sh"
PASS=0; FAIL=0
check() { # label expect(1=present,0=absent) pattern output
  if [ "$2" = "1" ]; then
    if echo "$4" | grep -q "$3"; then echo "  ✓ $1"; PASS=$((PASS+1)); else echo "  ✗ $1 ('$3' 미출현)"; FAIL=$((FAIL+1)); fi
  else
    if echo "$4" | grep -q "$3"; then echo "  ✗ $1 ('$3' 출현)"; FAIL=$((FAIL+1)); else echo "  ✓ $1"; PASS=$((PASS+1)); fi
  fi
}

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ── fixture 1: repo 형 (core/hooks 존재) — 실측 h1/h2 중 h2 미러 누락 ──
R="$TMP/repo"
mkdir -p "$R/core/hooks" "$R/.claude/hooks"
printf 'echo h1\n' > "$R/core/hooks/h1.sh"
printf 'echo h2\n' > "$R/core/hooks/h2.sh"
printf 'echo common\n' > "$R/core/hooks/_common.sh"   # 제외 대상 (유틸)
printf 'echo h1\n' > "$R/.claude/hooks/h1.sh"          # h2.sh 미러 없음 → 누락 flag 기대
OUT1="$(VIBE_FLOW_ROOT="$R" bash "$VAL" "$R" 2>&1)"

echo "Test V1 (F-M10): repo 형 — core/hooks 실측 기준으로 h2.sh 누락 flag"
check "measured-missing-h2" 1 "h2.sh 누락" "$OUT1"
echo "Test V2 (F-M10): repo 형 — 리터럴 목록 미적용 (command-guard 미요구)"
check "no-literal-fallthrough" 0 "command-guard.sh 누락" "$OUT1"

# ── fixture 2: downstream 형 (core/ 부재) — 리터럴 폴백 유지 ──
D="$TMP/down"
mkdir -p "$D/.claude/hooks"
OUT2="$(VIBE_FLOW_ROOT="$D" bash "$VAL" "$D" 2>&1)"
echo "Test V3 (F-M10): downstream 형 — 리터럴 폴백 (command-guard 요구)"
check "literal-fallback" 1 "command-guard.sh 누락" "$OUT2"

echo ""; echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
