---
name: project-autonomous-evolution-plan
description: 완전 자율 자기진화 하네스 7-PR plan (2026-07-24) — 다음 진입점 = T1/PR-0 rule 분리
metadata: 
  node_type: memory
  type: project
  originSessionId: 7575770d-0608-4f74-a9a4-6cef9cc38f2f
  modified: 2026-07-25T04:47:55.383Z
---

사용자 목표: 현 vibe-flow 하네스를 **완전 무인 자기진화**(자동 학습·문제수정·자기진화·자가업데이트 + **필요 스킬 자가 생성**)로. 2026-07-24 brainstorm→plan 완료.

**확정 결정 (사용자 명시 선택)**:
- 자율 경계 = **완전 무인 auto-merge 전체** (자기오염 리스크 수용 → auto-rollback+circuit breaker 필수)
- 케이던스 = **야간 cloud routine** (기존 R12 `trig_01RcUNYjHFh4t2k5UrKo75MB` KST 11:00 확장)
- 생성 트랙(스킬 자가생성) = **최상위 tier, 마지막 graduate** (eval+M밤 후). 승급순서 corrective저→구조→self-update→generative.

**설계 (대안 A — Guarded full-auto)**: 3 pillar = 불변 안전코어(denylist+PreToolUse guard) / post-merge auto-revert / circuit breaker(health regression 시 freeze). 핵심 불변식 = **pinned evaluator**(밤N이 밤N+1 감사로직 수정 불가). grow+prune 대칭(생성/은퇴).

**산출물**:
- brainstorm: `repo .claude/memory/brainstorms/20260723-212449-autonomous-self-evolution-closedloop.md`
- plan: `repo .claude/plans/20260724-063748-autonomous-self-evolution-closedloop.md` (7 step T1~T7 = PR-0~PR-6, HARD-GATE 전체)

**진행 상태 (2026-07-24)**: T1(discipline 분리)·T2(불변 안전코어 evolution-guard+denylist+health-metric)·T3(폐루프 프롬프트 5-phase) 구현 완료 → **PR #166 squash-merged to main (c707596)**. CI 2-leg(ubuntu+windows) green. 신규 smoke 3종(evolution-guard 11/health-metric 3/cloud-loop-prompt) + schedule-smoke S6.1 픽스. hooks 26→27, rules 8→9.

**폐루프 실 가동 확인 (2026-07-24)**: PR #166 머지 후 nightly routine `trig_01FZz2Na6WULE2ZSUU1cjKt4`(cron `0 21 * * *`, sonnet-5)이 실제로 firing — VERIFY 13건 반증→PR #170 머지, AUDIT round O/P 10건 발굴(F-O01~O05/F-P01~P05). **실 병목 발견**: Phase 4 IMPROVE가 cloud 런타임 gh CLI 부재로 abort.

**round O/P 10건 전건 fix·머지 완료 (2026-07-24, open=0)** — 3 PR:
- **PR #172 (a52f04d)** F-P02+F-O01: run-cloud.sh gh 조기 게이트 제거+P5 gh∥mcp 이연 / ledger append component·dimension 강제 + MEMORY round P 인덱스
- **PR #173 (1561d86)** 문서정합 5건 F-O02/O03/O04/P01/P04: MEMORY discipline·F-K03·R14 stale 정리 / orchestrator run-log 경로 / audit validate.sh baseline caveat
- **PR #174 (e9a45c1)** 코드+테스트 3건 F-O05/P03/P05: budget jq JQ_KEY idiom((key)==$t, audit 0→5) / cloud-init telemetry hook 배포 / ledger round 테스트 커버리지
전건 `fixed` — 다음 firing Phase1 VERIFY가 actual_delta 실측 반증 예정(폐루프 폐합). **caveat 유지**: F-P02의 mcp 대체는 cloud routine allowed_tools에 mcp__github 그랜트 필요할 수 있음(다음 firing 검증).

**T4-T6 완료 (2026-07-25) — 자율 머신 전체 구축, default-safe OFF**:
- **T4 (#175 `0e388f2`)**: `merge-gate.sh`(safety-core>tier>CI, 14/14) + `post-merge-verify.sh`(health 실패→auto git revert, 8/8) + Phase 5.
- **T5 (#176 `4f4e718`)**: `self-update.sh`(비대화 semver, 12/12) + Phase 6. AUTO_RELEASE off 기본. 한계: 로컬 설치 재동기는 `claude plugin update` 몫.
- **T6 (#177 `32af06f`)**: `graduation.sh` 상태기계(off→docs→structural→generative, M=3밤 클린/tier) + circuit breaker(regressed→trip→off freeze, reset 사람만) + breaker runbook + Phase 7. merge-gate/self-update가 graduation-state 읽음. 13/13.

**★ 자율을 실제로 켜는 법**: main 상태는 **disarmed(off)** — auto-merge OFF. 운영자가 `bash core/skills/audit/scripts/graduation.sh arm` 명시 실행 → docs tier부터 3밤 클린마다 개방(docs→structural→generative). health regression 시 breaker가 off로 freeze. **arm 전엔 무조건 PR-only.**

**T7 완료 (2026-07-25, PR #178 `4d1ee64`) — plan status=completed, T1-T7 전건 done**: 생성 트랙 — `capability-gate.sh`(evidence/dedup/budget 3중 pre-gen, 7/7) + `self-prune.sh`(생성스킬 저사용 은퇴, 4/4) + eval(skill-creator 런타임 4번째) + Phase 8(graduation=generative 최상위 시만) + generated-skills registry.

**★★ plan 전체 완료 — 자율 자기진화 머신 전체 구축 (default-safe OFF)**. 7 자율 스크립트(core/skills/audit/scripts/): health-metric·merge-gate·post-merge-verify·self-update·graduation·capability-gate·self-prune. 전 파이프라인: HEALTH→VERIFY→AUDIT→ENQUEUE→IMPROVE→merge-gate→post-merge-verify→self-update→graduation-tick→generative. **켜는 법**: `graduation.sh arm`(운영자 명시) → docs→structural→generative 3밤 클린마다 개방, breaker 보호. **arm 전엔 PR-only.** 이번 세션 9 PR(#166/#172~#178 + F-P02/O01). 다음 진입점 = graduation arm(운영 결정) / nightly firing finding / 신규 요구.

**다음 세션 진입점 (2가지)**:
1. **런타임 활성화 (T3 firing-DoD)**: R12 routine 재등록(`schedule-register.sh`) → 새 폐루프 프롬프트 주입. **주의: 라이브 cloud 변경 + 다음 firing부터 야간 자율 audit→PR 시작(PR-only, 머지는 X). 사용자 명시 승인 필요** — 켜면 cloud 토큰 소비 + PR 자동 생성. T4(auto-merge) 아직 없음.
2. **T4 (PR-3) auto-merge + auto-revert**: merge-gate.sh(CI-green+tier+안전코어-untouched) + post-merge-verify.sh(fresh-CI→git revert). plan 파일 T4 참조. **최고 stakes** — 실제 자율 머지를 켜는 PR.

(T1 상세 서브태스크 이력은 plan 파일 T1 참조 — 완료됨)

**부수 성과 — F-K03 REFUTED** (ledger resolve 반영): "규칙이 명예규칙(never loaded)"은 오진. 실제 = `.claude/rules/` 자동스캔 + **frontmatter path-scoping**(paths:src/** → 코드편집 시 조건로드, frontmatter無 → 글로벌 상시로드). "8중 4 로드"는 버그 아닌 설계. 제안 fix(CLAUDE.md @import 8)는 context-engineering 위반이라 기각. 잔여 실이슈(일반 discipline이 src/** 스코프에 묶여 하네스 self-work서 dormant)가 곧 PR-0. 관련 [[project_audit_20260601]] (F-K03은 R11/K 발), [[project_phase3_1_complete]] (R12 routine).
