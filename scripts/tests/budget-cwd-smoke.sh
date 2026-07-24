#!/bin/bash
# budget SKILL.md — /budget --tokens 의 cwd 매칭이 Windows 경로구분자에 견고한가 (F-N03).
#
# 배경 (audit R14):
#   git rev-parse --show-toplevel 는 POSIX 슬래시("C:/Users/..."), 그러나 Claude Code
#   session-log 의 .cwd 는 Windows 백슬래시("C:\\Users\\...")로 저장된다. SKILL.md 가
#   `.cwd == $cwd` 로 exact-match 하면 Windows 에서 상시 0건 → "session-log 없음" 오출력.
#   F-K13/K14(jq CRLF)와 같은 뿌리 클래스("POSIX 가정 vs Windows 실환경")의 경로구분자 축.
#
# 본 스모크는 플랫폼 무관하게 백슬래시 cwd fixture 를 *주입*해 회귀를 고정한다 (ubuntu 에서도
# RED). fixture 의 백슬래시는 jq gsub 로 생성한다 — heredoc/printf 리터럴 \\ 는 일부 쉘 계층에서
# 접히므로 사용하지 않는다.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL="$REPO_ROOT/core/skills/budget/SKILL.md"
PASS=0; FAIL=0
ok() { echo "  ✓ $1"; PASS=$((PASS+1)); }
ng() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM
LOG="$TMP/session.jsonl"

# 프로젝트 경로(슬래시, git rev-parse 형태) 와 그 백슬래시 변환형(로그 .cwd 형태)
PROJ="C:/Users/tester/proj"
# fixture: .cwd 를 백슬래시로 (jq gsub 로 생성 — 리터럴 escaping 회피)
jq -nc --arg p "$PROJ" '{type:"assistant",cwd:($p|gsub("/";"\\")),
  timestamp:"2026-07-24T00:00:00Z",
  message:{model:"claude-opus-4-8",usage:{input_tokens:10,output_tokens:20}}}' > "$LOG"

echo "=== fixture 무결성 ==="
CWD_VAL=$(jq -r '.cwd' "$LOG")
# 로그 .cwd 가 실제로 백슬래시를 담고 있어야 테스트가 유의미
case "$CWD_VAL" in
  *'\'*) ok "fixture .cwd 백슬래시 형태 ($CWD_VAL)" ;;
  *) ng "fixture .cwd 에 백슬래시 없음 ($CWD_VAL) — 테스트 무의미" ;;
esac

echo "=== 매칭 idiom 대조 ==="
# 현행(bare) idiom: 백슬래시 cwd 에 대해 0건이어야 한다 (결함 재현)
OLD=$(jq -n --arg cwd "$PROJ" '[inputs|select(.type=="assistant" and .cwd==$cwd)]|length' "$LOG" 2>/dev/null)
[ "$OLD" = "0" ] && ok "bare '.cwd == \$cwd' 는 백슬래시에 0건 (결함 재현)" || ng "bare idiom 이 $OLD 건 — 재현 실패"

# 교정 idiom: 백슬래시를 슬래시로 정규화 후 비교 → 1건
NEW=$(jq -n --arg cwd "$PROJ" '[inputs|select(.type=="assistant" and ((.cwd|gsub("\\\\";"/"))==$cwd))]|length' "$LOG" 2>/dev/null)
[ "$NEW" = "1" ] && ok "정규화 idiom 은 1건 매칭 (경로구분자 무관)" || ng "정규화 idiom 이 $NEW 건 (want 1)"

echo "=== SKILL.md 소스 가드 ==="
# SKILL.md 가 실제로 교정 idiom 을 채택했는가 (behavioral 재현이 copy 를 검증하는 drift 차단)
if grep -qF 'and .cwd == $cwd' "$SKILL"; then
  ng "SKILL.md 에 bare '.cwd == \$cwd' 잔존 — Windows 매칭 0건 회귀"
else
  ok "SKILL.md bare idiom 부재"
fi
if grep -qF '.cwd | gsub' "$SKILL"; then
  ok "SKILL.md 경로구분자 정규화 존재 (F-N03)"
else
  ng "SKILL.md 정규화 부재 — .cwd | gsub 미도입"
fi

# 최종 가드: SKILL.md 에서 추출한 *실제* select 절을 fixture 에 적용해 1건이 나오는가.
# behavioral 재현이 인라인 copy 가 아니라 SKILL.md 원문을 검증하도록 묶는다.
CLAUSE=$(grep -F '(.cwd | gsub' "$SKILL" | head -1 | sed 's/^[[:space:]]*and[[:space:]]*//; s/[[:space:]]*$//')
if [ -n "$CLAUSE" ]; then
  EXTRACTED=$(jq -n --arg cwd "$PROJ" "[inputs|select(.type==\"assistant\" and ($CLAUSE))]|length" "$LOG" 2>/dev/null)
  [ "$EXTRACTED" = "1" ] && ok "SKILL.md 원문 절이 fixture 1건 매칭 (실 idiom 검증)" \
                         || ng "SKILL.md 원문 절 적용 결과 $EXTRACTED 건 (want 1)"
else
  ng "SKILL.md 에서 cwd 정규화 절 추출 실패"
fi

echo ""
echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ ALL TESTS PASSED"; exit 0; } || { echo "✗ SOME TESTS FAILED"; exit 1; }
