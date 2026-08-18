#!/bin/bash
# cloud-loop-prompt-smoke.sh (T3/PR-2) — AHE 폐루프 프롬프트 배선 무결성.
# 실행: bash scripts/tests/cloud-loop-prompt-smoke.sh
#
# 프롬프트는 자연어라 실행 단위 테스트가 불가 — 대신 (a)참조 스크립트 경로가 실존·실행가능
# (b)5 phase(health/verify/audit/enqueue/improve)가 모두 배선 (c)PR-only(auto-merge 금지)
# 명시를 게이트한다. broken path/누락 phase/auto-merge 유출 회귀를 차단.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROMPT="$REPO_ROOT/core/skills/auto-build/data/cloud-prompt-template.md"

PASS=0; FAIL=0
have() { if grep -qF "$2" "$PROMPT"; then echo "  ✓ $1"; PASS=$((PASS+1)); else echo "  ✗ $1 ('$2' 부재)"; FAIL=$((FAIL+1)); fi; }
# 스크립트는 프롬프트에서 `bash <path>` 로 호출 → 실행권한 불필요, 실존(-f)만 검증.
exe()  { if [ -f "$REPO_ROOT/$2" ]; then echo "  ✓ $1"; PASS=$((PASS+1)); else echo "  ✗ $1 ($2 부재)"; FAIL=$((FAIL+1)); fi; }

echo "Test L1: 프롬프트 파일 존재"
if [ -f "$PROMPT" ]; then echo "  ✓ L1.1 cloud-prompt-template.md 존재"; PASS=$((PASS+1)); else echo "  ✗ L1.1 부재"; FAIL=$((FAIL+1)); echo "PASS:$PASS FAIL:$FAIL"; exit 1; fi

echo "Test L2: 5 phase 배선"
have "L2.1 bootstrap cloud-init" "cloud-init.sh"
have "L2.2 HEALTH baseline"      "health-metric.sh"
have "L2.3 VERIFY pending-verify" "ledger.sh pending-verify"
# F-T09/F-V07: `git push --dry-run` 은 ref 를 갱신하지 않아 remote 의 pre-receive
# (브랜치 보호)가 돌지 않는다 — 보호 유무와 무관하게 항상 accept 로 보인다. 루프가
# 이 무효 계기로 F-S10 을 **거짓 refuted** 처리해 원장을 오염시킨 사고가 실재한다.
# 프롬프트(= 루프의 유일한 계약)에 금지가 박혀 있는지 게이트한다.
# 검색어는 선행 대시로 시작하면 안 된다 — grep 이 옵션으로 해석한다(이 케이스 작성 중 실측).
have "L2.3b VERIFY dry-run 금지 명시" "push --dry-run"
have "L2.4 VERIFY resolve"        "ledger.sh resolve"
have "L2.5 AUDIT"                 "/audit"
# F-T10: Phase 2 가 ledger append 후 MEMORY 인덱스를 갱신하지 않아 R17/R18/R19/R25
# 네 라운드가 연속 RED. 게이트(check-doc-counts:82)에만 있고 생산자 지시문에 없던 계약.
have "L2.5b AUDIT 후 MEMORY 갱신 지시" "라운드 요약 1줄을 반드시 추가"
have "L2.6 ENQUEUE"              "ledger.sh enqueue"
have "L2.7 IMPROVE run-cloud"     "run-cloud.sh"

echo "Test L3: 참조 스크립트 실존 + 실행가능"
exe "L3.1 cloud-init.sh"   "core/skills/auto-build/scripts/cloud-init.sh"
exe "L3.2 health-metric.sh" "core/skills/audit/scripts/health-metric.sh"
exe "L3.3 ledger.sh"        "core/skills/audit/scripts/ledger.sh"
exe "L3.4 run-cloud.sh"     "core/skills/auto-build/scripts/run-cloud.sh"
exe "L3.5 evolution-guard.sh" "core/hooks/evolution-guard.sh"

echo "Test L4: merge-gate 배선(T4) + default-safe + guard"
have "L4.1 Phase5 merge-gate.sh 배선" "merge-gate.sh"
have "L4.2 post-merge-verify.sh(auto-revert) 배선" "post-merge-verify.sh"
have "L4.3 default-safe AUTO_MERGE_TIER off 불변식" "AUTO_MERGE_TIER"
# 무조건(gate 미경유) merge 방지 — gh pr merge 가 라인 시작으로 있으면 안 됨
if grep -qE '^\s*gh pr merge' "$PROMPT"; then
  echo "  ✗ L4.4 무조건 'gh pr merge' 유출(gate 미경유)"; FAIL=$((FAIL+1))
else
  echo "  ✓ L4.4 무조건 merge 없음(반드시 merge-gate 경유)"; PASS=$((PASS+1))
fi
have "L4.5 AUTO_BUILD_MODE=1 (guard 활성)" "AUTO_BUILD_MODE=1"
have "L4.6 Phase6 self-update.sh 배선(T5)" "self-update.sh"
have "L4.7 self-update default-safe AUTO_RELEASE" "AUTO_RELEASE"
have "L4.8 Phase7 graduation tick 배선(T6)" "graduation.sh tick"
have "L4.9 breaker runbook 참조" "breaker-runbook"
have "L4.10 Phase8 capability-gate 배선(T7)" "capability-gate.sh"
have "L4.11 self-prune(grow/prune) 배선(T7)" "self-prune.sh"

echo "Test L5: 툴 grant 가 템플릿 phase 요구 충족 (F-N02)"
# Phase 2 는 /audit 를 호출하고(L2.5 짝), /audit(audit/SKILL.md: allowed-tools ... Agent)은
# dimension agent 를 병렬 dispatch 한다. 따라서 routine 의 allowed_tools 는 Agent 를 포함해야
# firing 시 Phase 2 가 산다. 배선(prompt)과 권한(payload)이 다른 파일이라 한쪽만 갱신되는
# 회귀를 차단 — DRYRUN payload 의 실제 grant 를 뽑아 L2.5 와 대조한다.
REGISTER="$REPO_ROOT/core/skills/auto-build/scripts/schedule-register.sh"
# tr -d '\r': Windows jq.exe CRLF (F-N01 계열). grep -qx 매칭이 'Agent\r' 로 빗나가지 않게.
GRANT=$(SCHEDULE_REGISTER_DRYRUN=1 bash "$REGISTER" "0 21 * * *" 2>/dev/null \
  | jq -r '.body.job_config.ccr.session_context.allowed_tools[]' 2>/dev/null | tr -d '\r')
if grep -qF "/audit" "$PROMPT"; then
  if printf '%s\n' "$GRANT" | grep -qx "Agent"; then
    echo "  ✓ L5.1 allowed_tools 에 Agent (Phase 2 /audit dispatch 가능)"; PASS=$((PASS+1))
  else
    echo "  ✗ L5.1 allowed_tools 에 Agent 부재 — Phase 2 /audit 가 firing 시 툴 부재로 죽음"; FAIL=$((FAIL+1))
  fi
else
  echo "  - L5.1 skip (템플릿에 /audit 배선 없음 — 전제 불성립)"
fi

echo "Test L6: 프롬프트 산문 ↔ 구조 정합 (F-Q01/Q02/Q03)"
# 프롬프트는 자연어라 "Phase 를 추가했는데 상위 카운트 문장/역할 선언은 안 고침" 류 회귀를
# 어떤 게이트도 못 잡았다(F-Q02/Q03). 산문의 주장과 실제 구조를 기계 대조해 차단한다.

# L6.1 (F-Q02) 선언된 단계 수 == 실제 Phase 헤더 수
DECL=$(grep -oE '아래 [0-9]+단계' "$PROMPT" | head -1 | grep -oE '[0-9]+')
PHASES=$(grep -cE '^### Phase ' "$PROMPT")
if [ -n "$DECL" ] && [ "$DECL" = "$PHASES" ]; then
  echo "  ✓ L6.1 선언 단계수($DECL) == Phase 헤더수($PHASES)"; PASS=$((PASS+1))
else
  echo "  ✗ L6.1 선언 단계수($DECL) ≠ Phase 헤더수($PHASES) — 뒤쪽 Phase 가 실행에서 절단됨"; FAIL=$((FAIL+1))
fi

# L6.2 (F-Q03) 서두 역할 선언이 Phase 5 조건부 머지와 모순되지 않을 것
if grep -qF "auto-merge 절대 금지" "$PROMPT"; then
  echo "  ✗ L6.2 'auto-merge 절대 금지' 잔존 — Phase 5(merge-gate 조건부 머지)와 정면 충돌"; FAIL=$((FAIL+1))
else
  echo "  ✓ L6.2 서두에 무조건 auto-merge 금지 선언 없음"; PASS=$((PASS+1))
fi
if grep -qF "PR-3 scope" "$PROMPT"; then
  echo "  ✗ L6.3 'auto-merge 는 PR-3 scope' 잔존 — T4 머지 후 stale"; FAIL=$((FAIL+1))
else
  echo "  ✓ L6.3 auto-merge 를 미래 scope 로 미루는 문장 없음"; PASS=$((PASS+1))
fi

# L6.4 (F-Q01) Phase 7 이 graduation state 를 커밋할 것 — cloud checkout 은 ephemeral 이라
# 커밋 없으면 clean_nights 가 매 밤 0 으로 리셋돼 M 에 영원히 도달 못 한다(dead 상태기계).
P7=$(awk '/^### Phase 7 /,/^### Phase 8 /' "$PROMPT")
if printf '%s' "$P7" | grep -qF "graduation-state.json" && printf '%s' "$P7" | grep -qE 'git (commit|push)'; then
  echo "  ✓ L6.4 Phase 7 이 graduation-state.json 을 커밋(영속)"; PASS=$((PASS+1))
else
  echo "  ✗ L6.4 Phase 7 에 state 커밋 없음 — ephemeral checkout 에서 clean_nights 영구 0"; FAIL=$((FAIL+1))
fi

echo ""
echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ ALL TESTS PASSED"; exit 0; } || { echo "✗ SOME TESTS FAILED"; exit 1; }
