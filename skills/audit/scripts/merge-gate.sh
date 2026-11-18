#!/bin/bash
set -u
# merge-gate.sh — 자율 auto-merge 적격 판정 (T4/PR-3).
#
# 자율 루프가 생성한 PR 을 auto-merge 해도 되는지 결정한다. 3 관문(순서 중요):
#   1. 안전코어 touch  → REJECT_SAFETY_CORE (denylist 파일 변경은 절대 자율머지 X, 사람만)
#   2. tier graduation → HOLD_TIER (PR tier 가 현재 graduated tier 초과 시 사람 대기)
#   3. CI 상태         → HOLD_CI_FAILED / HOLD_CI_PENDING (CI green 아니면 대기)
#   통과 → AUTO_MERGE (exit 0). 그 외 전부 exit 1 (사람 대기/거부).
#
# **default-safe 불변식**: AUTO_MERGE_TIER 기본 "off" → 어떤 PR 도 AUTO_MERGE 안 됨.
#   T4 는 메커니즘만 짓고, tier 개방(graduation)은 T6 이 M밤 클린 데이터 후 수행.
#   즉 본 게이트가 머지돼도 라이브 자율머지는 켜지지 않는다.
#
# tier 순위: off(0) < docs(1) < structural(2) < generative(3) (graduation 순서).
#   docs      = 저위험(.claude/memory/**, docs/**, README/CHANGELOG)
#   structural= rules/hooks/gates/agents/scripts (denylist 제외)
#   generative= 신규 skill (T7 트랙, 최상위)
#
# 입력:
#   $1                = PR 번호 (실사용; gh 로 변경파일·CI 조회)
#   MERGE_GATE_FILES  = 변경파일 목록 override (테스트/오프라인)
#   MERGE_GATE_CI     = green|failed|pending override (테스트)
#   AUTO_MERGE_TIER   = off|docs|structural|generative (기본 off)
# 출력: stdout "DECISION=<...>\nREASON=<...>", exit 0(AUTO_MERGE)/1(그 외).

PR="${1:-}"
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
DENYLIST="$ROOT/.claude/evolution-protected"

emit() { echo "DECISION=$1"; echo "REASON=$2"; [ "$1" = "AUTO_MERGE" ] && exit 0 || exit 1; }

tier_level() {
  case "$1" in off) echo 0 ;; docs) echo 1 ;; structural) echo 2 ;; generative) echo 3 ;; *) echo 0 ;; esac
}

# ── 변경 파일 수집 ──
if [ -n "${MERGE_GATE_FILES:-}" ]; then
  FILES="$MERGE_GATE_FILES"
elif [ -n "$PR" ] && command -v gh >/dev/null 2>&1; then
  FILES=$(gh pr diff "$PR" --name-only 2>/dev/null)
else
  FILES=$(git diff --name-only origin/main...HEAD 2>/dev/null)
fi
[ -z "${FILES// /}" ] && emit "HOLD_NO_FILES" "변경 파일 0 — 판정 불가"

# ── 1. 안전코어 touch → REJECT ──
if [ -f "$DENYLIST" ]; then
  for f in $FILES; do
    fb=$(basename "$f")
    while IFS= read -r entry; do
      entry="${entry%%[$'\r']}"
      case "$entry" in ''|\#*) continue ;; esac
      if [ "$f" = "$entry" ] || [ "$fb" = "$(basename "$entry")" ]; then
        emit "REJECT_SAFETY_CORE" "안전코어 파일 변경($f) — 자율머지 불가, 사람 review 필수"
      fi
    done < "$DENYLIST"
  done
fi

# ── 2. tier 분류 (max) ──
PR_TIER="docs"; PR_LEVEL=1
for f in $FILES; do
  case "$f" in
    .claude/memory/*|docs/*|README.md|CHANGELOG.md) lvl=1; t="docs" ;;
    core/skills/*/SKILL.md|extensions/*/skills/*/SKILL.md) lvl=3; t="generative" ;;
    *) lvl=2; t="structural" ;;   # 기본 보수: rules/hooks/scripts/settings 등
  esac
  if [ "$lvl" -gt "$PR_LEVEL" ]; then PR_LEVEL=$lvl; PR_TIER="$t"; fi
done

# tier 소스: AUTO_MERGE_TIER env(테스트/수동 override) 우선, 없으면 graduation-state(T6).
GRAD="${AUTO_MERGE_TIER:-}"
if [ -z "$GRAD" ]; then
  GRADSH="$ROOT/core/skills/audit/scripts/graduation.sh"
  [ -f "$GRADSH" ] && GRAD=$(bash "$GRADSH" tier 2>/dev/null)
  GRAD="${GRAD:-off}"
fi
GRAD_LEVEL=$(tier_level "$GRAD")
if [ "$GRAD_LEVEL" -eq 0 ] || [ "$PR_LEVEL" -gt "$GRAD_LEVEL" ]; then
  emit "HOLD_TIER" "PR tier=$PR_TIER(레벨 $PR_LEVEL) > graduated=$GRAD(레벨 $GRAD_LEVEL) — 사람 대기"
fi

# ── 3. CI 상태 ──
# F-AT01: CI 상태는 **git 으로 알 수 없다** — 체크 상태는 API 전용이다. 변경 파일은
# `git diff origin/main...HEAD` 로 대체되지만(위) CI 는 대체 경로가 없다. 그런데
# cloud 세션에는 gh 가 없다(F-AI03 실측). 그 경우를 "미완료" 로 내면 **기다리면 풀릴
# 것처럼 보이지만 영원히 안 풀린다** — armed 상태에서 "곧 머지되겠지" 로 오해하면
# 자동화가 도는 줄 알고 방치된다. 조회 불가는 별도 판정으로 낸다(F-AH05 와 동형).
GH_BIN="${MERGE_GATE_GH_BIN:-gh}"
CI_SOURCE="unknown"
if [ -n "${MERGE_GATE_CI:-}" ]; then
  CI="$MERGE_GATE_CI"; CI_SOURCE="env"
elif [ -n "$PR" ] && command -v "$GH_BIN" >/dev/null 2>&1; then
  CI_SOURCE="api"
  states=$("$GH_BIN" pr checks "$PR" --json state -q '.[].state' 2>/dev/null)
  if echo "$states" | grep -qiE 'FAILURE|ERROR|CANCELLED|TIMED_OUT'; then CI="failed"
  elif echo "$states" | grep -qiE 'PENDING|IN_PROGRESS|QUEUED|EXPECTED'; then CI="pending"
  elif [ -n "$states" ]; then CI="green"; else CI="pending"; fi
else
  CI="unavailable"
fi
case "$CI" in
  green) : ;;
  failed) emit "HOLD_CI_FAILED" "CI 실패 — 자율머지 대기" ;;
  unavailable) emit "HOLD_CI_UNAVAILABLE" "CI 상태 조회 불가(gh 부재) — 대기해도 풀리지 않는다. 자율머지를 쓰려면 API 접근이 필요하다(F-AT01)" ;;
  *) emit "HOLD_CI_PENDING" "CI 미완료($CI) — 자율머지 대기" ;;
esac

emit "AUTO_MERGE" "tier=$PR_TIER graduated=$GRAD CI=green safety-core-untouched — 자율머지 적격"
