---
plan_id: 20260724-063748-autonomous-self-evolution-closedloop
status: in_progress
created: 2026-07-23T21:37:48Z
hard_gate: full
source: .claude/memory/brainstorms/20260723-212449-autonomous-self-evolution-closedloop.md
---

# Plan: 완전 자율 자기진화 하네스 — AHE 폐루프 배선

## Goal

vibe-flow의 AHE 루프(evaluate→analyze→improve→verify)를 **사람 개입 0으로 매일 밤 자동 완주**하는 폐루프로 만든다. 야간 cloud routine(기존 R12 확장)이 `pending-verify → /audit → enqueue → auto-build → CI-green auto-merge → self-update → health-check`를 1 라운드 돌린다. corrective(결함수정)뿐 아니라 generative(스킬 생성)도 자율 수행하되, 3중 안전장치(불변 안전코어 / auto-revert / circuit breaker)로 자기오염 런어웨이를 차단한다.

## Approach

**대안 A — Guarded full-auto on main (단계적 롤아웃)**. main 직행 auto-merge하되 3 pillar로 감싸고, auto-merge OFF부터 시작해 health baseline 데이터로 신뢰를 쌓은 뒤 tier별로 승급한다. 핵심 불변식: **pinned evaluator**(밤 N이 밤 N+1의 감사/검증 로직을 수정 불가) + 안전코어 불변(denylist). 기존 자산(R12 routine, ledger.sh, run-queue.sh, auto-build vote, CI 2-leg)의 증분 확장이지 신규 구축이 아니다.

## Out of Scope

- 대안 B(shadow/canary 전체) — 지연(K밤)이 무인 즉시진화 의도와 상충. 단 구조/안전-인접 변경은 A에서도 canary 경유 하이브리드로 부분 채택(T4 리스크 완화).
- 로컬 cron — cloud routine은 Anthropic cloud 실행(1h 최소 간격). 로컬 스케줄러 신설 안 함.
- 모델 변경 — harness(rules/skills/agents/hooks)만 진화. 모델 고정(AHE 원칙).
- CI 게이트 자체 재설계 — 기존 2-leg(validation-tests + eval-regression)를 유일 머지 게이트로 재사용.

## 영향 파일

| 파일 | 변경 유형 | PR | 비고 |
|------|----------|-----|------|
| `core/rules/discipline.md` | 신규 | PR-0 | frontmatter無 글로벌 rule. sync-drift.sh 자동 glob |
| `core/rules/donts.md` | 수정 | PR-0 | 일반섹션 이동, TS-특화만 잔류 |
| `core/rules/conventions.md` | 수정 | PR-0 | 동일 처리 |
| `core/rules/karpathy-principles.md` | 수정 | PR-0 | §2/§3 donts 참조 갱신 |
| `.claude/evolution-protected` | 신규 | PR-1 | 안전코어 denylist (자신 포함) |
| `core/hooks/evolution-guard.sh` | 신규 | PR-1 | PreToolUse 집행 hook |
| `core/skills/audit/scripts/health-metric.sh` | 신규 | PR-1 | CI%+dim avg+checksum |
| `core/skills/auto-build/scripts/cloud-init.sh` | 수정 | PR-1 | evolution-guard wire |
| R12 cloud routine (`trig_01RcUNYjHFh4t2k5UrKo75MB`) | 수정 | PR-2/3/4 | prompt 확장 |
| `core/skills/auto-build/scripts/run-queue.sh` | 수정 | PR-2 | 폐루프 체인 |
| `core/skills/audit/scripts/ledger.sh` | 수정 | PR-2 | enqueue 배선 |
| `core/skills/audit/scripts/merge-gate.sh` | 신규 | PR-3 | tier+안전코어-untouched 게이트 |
| `core/skills/audit/scripts/post-merge-verify.sh` | 신규 | PR-3 | fresh-CI + auto revert |
| `core/skills/release/SKILL.md` | 수정 | PR-4 | 버전 bump + 재동기 |
| tier-config + breaker-runbook(docs) | 신규 | PR-5 | 승급순서 + runbook |
| capability-gap finding형 + skill-creator 배선 + eval/dedup/budget 게이트 | 신규 | PR-6 | 생성 트랙 |

## 단계

### T1: PR-0 — 일반 discipline 분리 (하네스 self-modify 시 상시로드)
- **상태**: done
- **파일**: `+core/rules/discipline.md`, `~donts.md`, `~conventions.md`, `~karpathy-principles.md`, `~harness-evolution.md`, `~audit/SKILL.md`, `~runner.md`, `~README.md`
- **변경**: 일반 discipline(Surgical/완료기준/합리화/컨텍스트보호/설계선행)을 path-scope에서 떼어 frontmatter無 글로벌 rule로. TS-특화(any/console.log/useEffect/보안)만 `paths: src/**` 잔류
- **DoD**: `.sh` 편집 세션에서 discipline 규칙이 컨텍스트 로드 확인 + `bash core/scripts/sync-drift.sh --check` exit0
- **서브태스크**: t0.1(donts 일반섹션 라인확정 34-39/41-46/48-57/59-77) → t0.2(discipline.md 생성) → t0.3(donts 이동분 삭제) → t0.4(conventions 처리) → t0.5(karpathy 참조갱신) → t0.6(sync-drift 실행) → t0.7(validate+drift check)
- **리스크**: 이동 중 규칙 누락 → 원문 라인 diff 보존으로 완화
- **완료일**: 2026-07-24
- **노트**: F-K03 refuted 후 교정된 스코프 (CLAUDE.md @import 아님 — context-engineering 위반 회피). 검증: discipline.md frontmatter無(글로벌) + donts/conventions는 TS-특화만 + dangling ref 0 + check-doc-counts rules=9 + sync-drift --check no drift + validate.sh exit0. 크로스ref는 계획(4파일)보다 3파일 더 갱신(harness-evolution/audit-SKILL/runner)해 dangling 방지 — 여전히 간략 등급.

### T2: PR-1 — 불변 안전코어
- **상태**: done
- **파일**: `+.claude/evolution-protected`, `+core/hooks/evolution-guard.sh`, `+core/skills/audit/scripts/health-metric.sh`, `+scripts/tests/evolution-guard-smoke.sh`, `+scripts/tests/health-metric-smoke.sh`, `~settings/settings.template.json`, `~cloud-init.sh`, `~cloud-init-smoke.sh`, `~validation-tests.yml`, `~README.md`, `~plugin.json`, `~marketplace.json`
- **변경**: denylist(안전코어 파일 목록, 자신+guard+health+미래 T4 forward-protect) + PreToolUse hook(evolution-guard)이 AUTO_BUILD_MODE=1 시 denylist 편집(Edit/Write/Bash벡터) 차단, 사람은 허용 + health metric(CI%/ledger health/safety-core checksum) 3지표. auto-merge는 아직 OFF
- **DoD**: denylist 파일 편집 시도 → hook exit≠0 재현; `health-metric.sh` 3값 출력
- **의존**: T1 · **HARD-GATE**: 전체
- **리스크**: denylist 자기미포함 우회 → denylist에 자신+guard+health 포함으로 완화
- **완료일**: 2026-07-24
- **노트**: TDD RED(11 fail)→GREEN(11 pass). 검증: evolution-guard smoke 11/11(사람통과/자율차단/비보호통과/fail-closed/Bash벡터/basename), health-metric smoke 3/3, cloud-init smoke 26/26, check-doc-counts hooks 27 일관, validate 훅27+동기화, drift 0, CI EXPECTED_SMOKE 28→30 일치, settings JSON valid. **미결(후속)**: 로컬 /auto-build 활성화는 local settings.json에 evolution-guard 미등록(gitignored) → setup.sh 재실행 필요. 단 로컬 인터랙티브는 AUTO_BUILD_MODE 미설정이라 inert. cloud 야간 루프는 cloud-init가 settings.template.json 설치로 활성.

### T3: PR-2 — 폐루프 배선 (PR-only 모드)
- **상태**: done (firing-DoD 종결 2026-07-24)
- **파일**: `~core/skills/auto-build/data/cloud-prompt-template.md`(폐루프 5-phase 재작성), `+scripts/tests/cloud-loop-prompt-smoke.sh`, `~validation-tests.yml`(EXPECTED_SMOKE 30→31)
- **변경**: 야간 routine 프롬프트를 bootstrap→HEALTH→VERIFY(pending-verify+resolve)→AUDIT(/audit)→ENQUEUE→IMPROVE(run-cloud, PR-only)로 배선. `AUTO_BUILD_MODE=1`로 evolution-guard 활성. auto-merge 절대 금지 명시. 기존 스크립트(ledger pending-verify/resolve/enqueue, health-metric, run-cloud) 재사용 — 신규 스크립트 0 (surgical, planner의 run-queue/ledger 수정 추정보다 좁음)
- **DoD**: 1 firing exit0 + PR≥0건 생성 + ledger resolve≥1건 (auto-merge 없음)
- **의존**: T2 · **HARD-GATE**: 전체
- **리스크**: 체인 무한루프 → auto-build iter30/token200k cap 재사용
- **완료일**: 2026-07-24 (wiring + firing 종결)
- **노트**: cloud-loop-prompt smoke ALL PASS(5-phase 배선+참조 실존+PR-only 검증), drift/doc-counts/validate green. **firing-DoD 종결(2026-07-24T06:57Z)**: nightly routine `trig_01FZz2Na6WULE2ZSUU1cjKt4`(cron `0 21 * * *`, sonnet-5, env_01Lzz…) 등록 후 `RemoteTrigger run` 으로 1회 test-fire. cloud agent 가 origin/main checkout → Phase 1 VERIFY 로 pending-verify 13건(F-M01~M10 + F-N01~N03) **전건 실측 반증(F-H07 준수, 배포상태 문자열 0건)** → **PR #170** 생성(ledger 단일 파일, auto-merge 안 함, 안전코어 미접촉) → 머지(e2e4828). DoD 3기준 전건 충족: exit0 / PR≥0(=1) / resolve≥1(=13). 사전 발굴 [[F-N02]](tool grant Agent/Task 누락 → Phase 2 AUDIT 사망)를 firing 전에 fix 하지 않았으면 Phase 2 가 죽었을 것. routine prompt 는 full-injection 대신 bootstrap-delegation(repo 템플릿 read-execute) — schedule-register.sh 설계와 다름, 재등록 시 주의.

### T4: PR-3 — auto-merge + auto-revert
- **상태**: pending
- **파일**: `+merge-gate.sh`, `+post-merge-verify.sh`, `~routine`
- **변경**: CI-green+tier+안전코어-untouched 통과 시 `gh pr merge --auto`; 실패 시 post-merge fresh-CI → 자동 `git revert`
- **DoD**: 안전코어 touch PR → merge-gate reject; bad merge 주입 → 같은 밤 revert 커밋 생성
- **의존**: T3 · **HARD-GATE**: 전체
- **리스크**: 노출창(revert 전 bad merge가 main에 존재) → post-merge fresh-CI 즉시 + breaker freeze; 구조/안전-인접 변경은 canary 경유 하이브리드
- **완료일**:
- **노트**:

### T5: PR-4 — self-update
- **상태**: pending
- **파일**: `~routine`, `~core/skills/release/SKILL.md`
- **변경**: 머지 후 `/release` 버전 bump + 플러그인 재동기 + drift 검증
- **DoD**: 설치 플러그인 버전 == main + `sync-drift.sh --check` exit0
- **의존**: T4 · **HARD-GATE**: 간략
- **리스크**: 부분 재동기 drift → `--check` 게이트로 완화
- **완료일**:
- **노트**:

### T6: PR-5 — graduation
- **상태**: pending
- **파일**: `+tier-config`, `+breaker-runbook(docs)`, `~merge-gate`
- **변경**: 승급순서(corrective저위험→corrective구조적→self-update→generative) + circuit-breaker 발화/리셋 runbook. 각 tier는 M밤 클린 후 다음 개방
- **DoD**: tier N 미승급 시 N+1 fix 머지 거부; breaker 발화 후 human-gate 복귀 재현
- **의존**: T4, T5 · **HARD-GATE**: 전체
- **리스크**: tier 오분류 → ledger component 매핑표로 완화
- **완료일**:
- **노트**:

### T7: PR-6 — 생성 트랙 (최상위 tier, 마지막 개방)
- **상태**: pending
- **파일**: `+capability-gap finding형`, `+skill-creator 배선`, `+eval/dedup/budget 게이트 3종`, `+self-pruning`
- **변경**: telemetry 반복 N회 실측 → skill-creator 스캐폴드 → auto-build 로직 → 4중게이트(eval/dedup/budget) → 배선; 저사용 스킬 은퇴 제안
- **DoD**: N회 미만 → 생성 abort; eval 통과만 머지; budget 초과 → abort; speculative 생성 0건
- **의존**: T6 · **HARD-GATE**: 전체
- **리스크**: sprawl → skill-budget cap + prune 대칭으로 완화
- **완료일**:
- **노트**: Simplicity-First 긴장 — evidence bar가 speculative 생성 차단

## 리스크

1. **자기오염(런어웨이)** — 오진 fix가 게이트/안전코어 무력화 → denylist + PreToolUse + **pinned evaluator**(밤N이 밤N+1 audit/verify 로직 수정 불가) + auto-revert. 안전코어는 사람만 수정.
2. **노출창** — revert 전 bad merge가 main에 잠깐 존재 → post-merge fresh-CI 즉시 + circuit breaker freeze; 구조/안전-인접 변경은 canary 경유(대안 B 부분채택).
3. **드리프트** — self-modify가 core↔.claude 갈라 거짓 신호 → 전 PR DoD에 `sync-drift.sh --check` exit0 강제(T1 신규 rule도 자동 glob됨).

## 진행 추적

| 시각 | 단계 | 상태 변경 | 비고 |
|------|------|----------|------|
| 2026-07-23T21:37:48Z | - | plan 생성 | brainstorm에서 분해, HARD-GATE 전체 |
| 2026-07-24T06:53:00Z | T1 | pending → done | discipline.md 분리, DoD 전건 exit0, dangling ref 0 |
| 2026-07-24T07:30:00Z | T2 | pending → done | 불변 안전코어(guard+denylist+health), TDD 11/11+3/3, 전 게이트 green |
| 2026-07-24T08:05:00Z | T3 | pending → wiring-done | 폐루프 프롬프트 5-phase, smoke green. firing-DoD는 post-merge 런타임 |
| 2026-07-24T06:57:41Z | T3 | wiring-done → done | routine 등록+test-fire, cloud Phase1 VERIFY 13건 반증 → PR #170 → 머지. DoD 3기준 전건 충족 |
