#!/bin/bash
set -u
# capability-gate.sh — 생성 트랙 pre-generation 방어 (T7/PR-6).
#
# 하네스가 **없는 능력(스킬)을 스스로 만드는** generative 트랙은 corrective(결함수정)와
# 리스크가 다르다(mis-trigger·sprawl·Simplicity-First 긴장). 신규 스킬 후보를
# skill-creator 로 스캐폴드하기 **전에** 3중 방어로 검증한다(anti-sprawl):
#   1. evidence bar — telemetry 반복 ≥N (speculative 생성 차단)
#   2. dedup       — 기존 스킬과 이름 중복(정확/부분) 차단 (F-D3 collision 교훈)
#   3. skill-budget— 라운드당 순증 스킬 수 cap (runaway 생성 backstop)
# 4번째 방어(eval: 트리거 정확도·동작 실증)는 skill-creator 런타임 — 통과 후 진입.
#
# 입력: $1=후보 스킬명  $2=설명
# env: CAP_EVIDENCE_COUNT(후보 빈도) / EVIDENCE_MIN(기본 3) /
#      SKILL_GEN_COUNT(이번 라운드 순증, 기본 0) / SKILL_BUDGET(기본 1)
# 출력: DECISION=<PASS|ABORT_EVIDENCE|ABORT_DEDUP|ABORT_BUDGET> REASON=..
# exit: 0(PASS) / 1(ABORT).

NAME="${1:-}"; DESC="${2:-}"
[ -z "$NAME" ] && { echo "usage: capability-gate.sh <name> <description>" >&2; exit 1; }
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

EVIDENCE="${CAP_EVIDENCE_COUNT:-0}"
EVIDENCE_MIN="${EVIDENCE_MIN:-3}"
GEN="${SKILL_GEN_COUNT:-0}"
BUDGET="${SKILL_BUDGET:-1}"

emit() { echo "DECISION=$1"; echo "REASON=$2"; [ "$1" = "PASS" ] && exit 0 || exit 1; }

# 1. evidence bar
if ! [ "$EVIDENCE" -ge "$EVIDENCE_MIN" ] 2>/dev/null; then
  emit "ABORT_EVIDENCE" "telemetry 반복 $EVIDENCE < 최소 $EVIDENCE_MIN — speculative 생성 차단(요청된 것만)"
fi

# 2. dedup (이름 정확/부분 중복 vs 기존 스킬)
for d in "$ROOT/core/skills"/*/ "$ROOT/extensions"/*/skills/*/ ; do
  [ -d "$d" ] || continue
  s=$(basename "$d")
  # 정확 일치 또는 부분 포함(어느 쪽이 다른 쪽을 포함) → 의미 중복 의심
  if [ "$NAME" = "$s" ] || case "$NAME" in *"$s"*) true ;; *) false ;; esac || case "$s" in *"$NAME"*) true ;; *) false ;; esac; then
    emit "ABORT_DEDUP" "기존 스킬 '$s' 과 이름 중복 — 신규 대신 기존 확장 검토(F-D3 collision)"
  fi
done

# 3. skill-budget (라운드 순증 cap)
if [ "$GEN" -ge "$BUDGET" ] 2>/dev/null; then
  emit "ABORT_BUDGET" "이번 라운드 순증 $GEN >= cap $BUDGET — runaway 생성 backstop"
fi

emit "PASS" "evidence $EVIDENCE>=$EVIDENCE_MIN, dedup ok, budget $GEN<$BUDGET — skill-creator+eval 진입 적격"
