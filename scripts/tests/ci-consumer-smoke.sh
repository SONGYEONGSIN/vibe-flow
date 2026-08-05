#!/bin/bash
# ci-consumer-smoke.sh (audit R / F-R02·F-R03·F-R10) — CI 게이트의 **집행·소비 층** 배선.
# 실행: bash scripts/tests/ci-consumer-smoke.sh
#
# R17/R 의 실측: 게이트(워크플로·스크립트)는 강한데 그 결과를 받는 쪽이 없어
# main 이 10일간 RED 인 채 아무도 몰랐다(F-R03). 동시에 두 워크플로의
# pull_request 가 paths 필터를 갖고 있어, 이 상태로 required status check 을
# 걸면 해당 경로를 안 건드리는 PR 이 영원히 "Waiting for status" 로 막힌다(F-R02).
#
# 이 스모크는 그 두 축을 게이트한다:
#   (1) pull_request paths 필터 부재 — required check 지정이 안전하고,
#       F-K06/L11/M08/Q05/Q20 로 5회 반복된 "트리거 경로 누락" 계보가 종결된다
#   (2) push→main 실패가 issue 로 승격 — harness 안팎 모두가 읽는 자료구조
#   (3) /audit Phase 0 가 라운드 개시 전 main CI 를 확인 (소비자 측)

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VT="$REPO_ROOT/.github/workflows/validation-tests.yml"
ER="$REPO_ROOT/.github/workflows/eval-regression.yml"
AUDIT_SKILL="$REPO_ROOT/core/skills/audit/SKILL.md"

PASS=0; FAIL=0
ok() { echo "  ✓ $1"; PASS=$((PASS+1)); }
ng() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }

# pull_request: 블록(다음 최상위 트리거 키까지)만 잘라낸다.
pr_block() { awk '/^  pull_request:/{f=1;next} /^  [a-z_]+:/{f=0} f' "$1"; }

echo "=== C1: pull_request paths 필터 부재 (F-R02 — required check 데드락 차단) ==="
for wf in "$VT" "$ER"; do
  base=$(basename "$wf")
  if [ ! -f "$wf" ]; then ng "C1 $base 부재"; continue; fi
  if pr_block "$wf" | grep -qE '^\s+paths:'; then
    ng "C1 $base pull_request 에 paths 필터 잔존 — required check 지정 시 무관 PR 이 영구 대기"
  else
    ok "C1 $base pull_request paths 필터 없음"
  fi
done

echo "=== C2: push→main 실패가 issue 로 승격 (F-R03 — 소비자 부재 차단) ==="
for wf in "$VT" "$ER"; do
  base=$(basename "$wf")
  if [ ! -f "$wf" ]; then ng "C2 $base 부재"; continue; fi
  # 조건: failure() 게이트 + push 이벤트 한정 + gh issue create 호출
  if grep -q 'failure()' "$wf" && grep -q "github.event_name == 'push'" "$wf" \
     && grep -q 'gh issue create' "$wf"; then
    ok "C2 $base failure()+push 조건에서 gh issue create 배선"
  else
    ng "C2 $base main RED 알림 스텝 부재 (failure() / event_name push / gh issue create 중 누락)"
  fi
  # 중복 폭주 방지 — 같은 라벨의 열린 이슈가 있으면 새로 만들지 않는다
  if grep -q 'gh issue list' "$wf"; then
    ok "C2 $base 중복 이슈 가드(gh issue list) 존재"
  else
    ng "C2 $base 중복 가드 없음 — 매 push 마다 이슈 생성"
  fi
done

echo "=== C3: /audit Phase 0 가 main CI 를 확인 (F-R10 — 감사 진입 게이트) ==="
if [ ! -f "$AUDIT_SKILL" ]; then
  ng "C3 audit/SKILL.md 부재"
else
  phase0=$(awk '/^## Phase 0\./{f=1;next} /^## Phase 1\./{f=0} f' "$AUDIT_SKILL")
  if echo "$phase0" | grep -q 'gh run list --branch main'; then
    ok "C3 Phase 0 에 gh run list --branch main 확인 배선"
  else
    ng "C3 Phase 0 에 main CI 확인 없음 — RED 인 main 위에서 라운드가 개시된다"
  fi
fi

echo
echo "=== 결과 ==="
echo "  통과: $PASS / 실패: $FAIL"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
