---
name: vibe-flow-internal-audit-20260601
description: vibe-flow 내부 감사 3 dimension (컨텍스트 관리/아키텍처/dogfooding) 결과 — 21 finding 발굴. 평균 3.0/5. PR
metadata: 
  node_type: memory
  type: project
  originSessionId: ee15f3be-28d2-4532-8760-4ef7258e28a5
---

2026-06-01 vibe-flow 자체 점검. 3 agent 병렬 위임으로 D1/D2/D3 dimension 분석 + 통합 보고. 4 finding은 PR #80(commit 8456c58)로 즉시 해소, 13건은 별 PR 분할 예정.

**Why**: vibe-flow는 41 skills + 22 agents + 7 rules + 25 hooks 통합 시스템이 견고한지 확인. 특히 우리가 추가한 Karpathy 5번째 원칙(Context Engineering, PR #76)이 실제로 적용되고 있는지.

## Dimension별 점수

| Dim | 점수 | 핵심 |
|-----|------|------|
| D1 컨텍스트 관리 | 2.8/5 | MEMORY.md 미존재, tee 자기 위반, leaves dead ref |
| D2 아키텍처/구조 | 3.8/5 | 4-layer 견고, 일부 도메인 (security/test/planner/performance) 책임 흐려짐 |
| D3 dogfooding gap | 2.5/5 | **44 skill 중 38 + 22 agent 전체 사용 0회** |
| **평균** | **3.0/5** | 의도 명확 / 실 운영 약함 |

## 21 Finding — 우선순위 매트릭스

### 🔴 P0 (해소됨, PR #80)
- **F-A1** — `.claude/memory/MEMORY.md` 미존재, skill 4개+ broken refs

### 🟠 P1 (high — 부분 해소)
- **F-A2** ✅ — performance-checker `tee` 3건 (PR #80)
- **F-A3** ⏳ — `templates/CLAUDE.md.template:70` 존재하지 않는 `patterns.md` 참조
- **F-B1** ✅ — security 도메인 2+2 중복 (PR #80, description 재정의)
- **F-B2** ⏳ — `git-post-commit.sh` 동기화 이탈 (`.git/hooks/` vs `.claude/hooks/` 메커니즘 차이 문서화 부재)
- **F-D1** ✅ — cloud-init/persona-vote/run-log 227줄 test 0 (PR #80, 46 case)
- **F-D2** ⏳ — **44 skill + 22 agent 사용 0회** (가장 큰 미해결 — 근본 원인 조사 필요)
- **F-D3** ⏳ — plan_created 8 vs plan_completed 1 추적 폐기

### 🟡 P2 (정리, 별 PR)
- F-A4 — brainstorms/에 task-plan 성격 오분류 (R10/R11 marker)
- F-A5 — subagent 위임 prompt에 context-budget 명세 없음
- F-A6 — brainstorm retention 미정의
- F-A7 — events.jsonl `tool_failure` 상세 없음
- F-A8 — `memory_sync_triggered` 동일 ts 중복 emit
- F-B3 — `performance-checker` vs `perf-audit` 경계 흐림
- F-B4 — `test` + `qa` + `test-writer` 3중 트리거 중복
- F-B5 — `planner` vs `project-planner` agent 경계 모호
- F-B6 — `message-bus.sh` 위치 문서화 부재
- F-B7 — `site-auditor`가 존재하지 않는 agent 호출
- F-D4 — review_pr 최근 17 PR 중 0회 self-review

## 정상 항목 (Top 6)

- ✅ 순환 의존 0건 (rules → skills 단방향)
- ✅ Hook wire 완전성 (25개 등록 hook 모두 실재)
- ✅ CLAUDE.md.template 74줄 — Karpathy "shorter at top" 완전 준수
- ✅ brainstorm 17개 H2 헤더 표준 100% 준수
- ✅ HARD-GATE 등급 대체로 준수 (최근 25 commit 인라인 60%)
- ✅ donts 금지 패턴(console.log/any/@ts-ignore) 위반 0건
- ✅ dogfooding cycle 진화 견인 작동 (F10→PR#74, F14/F15→PR#77, F16→PR#79)

## 핵심 패러독스 (F-D2) — Phase 2 정정 (2026-06-01)

원래 결론 "22 agent 전체 0회"는 **instrumentation gap 때문에 부정확**. session-logs 43MB 분석 결과:

| 측정 | events.jsonl | session-logs 실 | gap |
|------|-------------|----------------|-----|
| Skill tool call | 7 | **41** | 83% |
| Agent dispatch | 0 (type 부재) | **52** | 100% |

**실제**: 13 agent 사용 52건 (general-purpose 25 / code-reviewer 8 / planner 4 / 그 외), 9 agent 진짜 0회. 13/44 skill만 사용, 31 skill 진짜 0회. User prompt 76% 자연어.

**가설 판정 (Phase 2)**:
- H1 instrumentation gap — **강** ✅ (PR #81 R1로 해소: `tool-invocation-tracker.sh`)
- H2 real low usage — **중** (gap 보정해도 13/44 skill만)
- H3 description weak — **강** (자연어 76%인데 brainstorm/plan/auto-build 외 trigger 거의 없음)

→ **본질은 H1 + H3 동시 성립**. 70% gap = instrumentation, 30% = description specificity.

## How to apply (다음 세션 진입점)

### F-D2 R1 완료 (PR #81 commit 87c093c) — 2026-06-01
- `tool-invocation-tracker.sh` PostToolUse hook 신설 (Skill/Agent/Task track)
- 20/20 smoke PASS, 이제부터 events.jsonl에 자동 trigger + Agent 호출 누적

### F-D2 R2 완료 (PR #82 commit 0c8a459) — 2026-06-01
- 10 skill description 한국어 자연어 트리거 강화 (Batch A git/PR + B 테스트 + C 메타)
- gap 진단: 31 미사용 중 22건 description 약점, 6건 도메인 좁아 자연 저빈도
- 양호 유지: 도메인 좁은 6 skill + 이미 trigger 강한 3 skill = 미수정 9건

### 옵션 A — F-D2 R3 (telemetry 데이터 소스 전환)
`telemetry` skill 데이터 소스를 `~/.claude/projects/<project>/*.jsonl`로 전환. 자체 hook 유지비 제거. ~45분.

### 옵션 B — F-D2 R2 후속 (남은 12 미사용 skill description audit)
배치 A/B/C 외 12건: agent-browser, b2b-landing, budget, deploy-safety-guard, dependency-manager(양호 유지 권장이라 skip), inbox, menu, onboard, orchestrate, receive-review, retro, status, sync-claude-md, sync-workflow, telemetry, webapp-testing — 일부는 P2 수준이라 ROI 낮음.

### 옵션 C — 다른 P1 — F-A3 patterns.md dead ref + F-A4 brainstorm 재분류
소규모. ~20분.

### 옵션 D — F-B2 git-post-commit 문서화
`core/hooks/README.md` 신설. ~15분.

### 옵션 E — R12 cloud cycle 실패 root cause (Phase 3.1/4 잔여)
F16 PR #79 효과가 cloud에 미적용 — cloud session log 확인 필요.

### 검증 — R1/R2 효과 측정
PR #81 + #82 적용 후 며칠 데이터 누적되면 events.jsonl에서 자동 trigger 빈도 + 새 description 효과 정량 확인 가능 (telemetry skill 호출).

**권장 순서**: A (R3 telemetry 전환) → C/D 소규모 → 검증 → E.

## 머지된 PR (audit 관련)

### Round 1 (2026-06-01) — 4 PR
- #80 (commit 8456c58) — P0 + P1 4건 cleanup (F-A1/F-A2/F-B1/F-D1)
- #81 (commit 87c093c) — F-D2 R1 instrumentation tracker hook
- #82 (commit 0c8a459) — F-D2 R2 10 skill description 자연어 트리거 강화 (H3 해소)
- #83 (commit ad05aaa) — F-D2 R3 telemetry --source session 모드

### Round 2 (2026-06-02 ~ 06-03) — 4 PR
- #84 (commit f378c28) — F-A3 (patterns.md placeholder) + F-B8 (validate.sh 28 hooks) + F-D3 R1 (5 plan completed) 3건 P1 해소
- #85 (commit b502a64) — F-B6 security agent 2개 라우팅 명시 분리 (D2 정체 해소)
- #86 (commit 6590678) — F-A4 (15 brainstorm timestamp) + F-A10 (subagent context-budget) + F-B2 (core/hooks/README.md) + F-D3 R2 (brainstorm vs brainstorming 명명) 4건 P2 묶음
- #87 (commit b787b6f) — F-B4 (test 3-way) + F-B5 (planner 2-way) 도메인 라우팅 description 명시 (D2 완주)

### Round 3 (2026-06-04 ~ 06-05) — 재감사 + sync + 잔여 P2/P3 3건 (4 PR)
- 3 dimension 점수: D1 4.0→4.5 / D2 3.8→4.0 / D3 3.5→4.0 / 평균 **3.77→4.17 (+0.40)**
- 핵심 신규 finding F-C1 (3 dim 공통): `core/` ↔ `.claude/` sync drift — 22 파일 미동기화
- #88 (commit 26f5655) — F-C1 sync 자동 탐지 추가 + local 일괄 sync
- #89 (commit dc65ae6) — F-D3 R3-1 dangling plan 3건 닫기 (#58/#61/#62 retroactive)
- #90 (commit c676004) — F-D3 R3-3 tool_failure 오분류 (path/filename substring 차단)
- #91 (commit f648b33) — F-D3 R3-4 cloud cycles observability (cycles-report.sh)

### Round 3 종료 (2026-06-05) — 잔여 0
audit round 3 P2/P3 3건 모두 해소. 다음 round 후보 finding 2건 신규 surface:
- **F-A11** (P1) — `.claude/settings.json` + `.claude/settings.local.json` 양쪽에 같은 hook 중복 등록되어 모든 hook 2회 fire. `events.jsonl` 의 tool_failure 가 모두 중복으로 들어가는 원인. settings.local.json 은 gitignored 라 본 머신 한정. fix: 두 파일 중 하나만 hooks 보유하도록 정리 (또는 sync 자동화).
- **F-D5** (P2) — R12 routine (`trig_01RcUNYjHFh4t2k5UrKo75MB`) 미발화 의심 — queue entry `20260526T002254Z-65fe` 10일째 queued 상태로 stuck. cycles-report.sh 가 자동 surface. /schedule list 로 routine 상태 점검 필요.

### Round 4 (2026-06-05) — 재감사 + 신규 finding 해소 (2 PR)

3 dimension fresh-context agent 병렬 위임으로 Round 3 baseline 대비 점수 변화 측정.

| Dimension | R3 | R4 | Δ | 핵심 |
|-----------|----|----|---|------|
| D1 컨텍스트 | 4.5 | 4.0 | **-0.5** | F-C1 검증이 rules/ + scripts/ 미커버 발견 → 메타 결함 노출 (Karpathy §5 룰이 .claude/ 에 stale 한 상태) |
| D2 아키텍처 | 4.0 | 4.2 | **+0.2** | 도메인 라우팅 견고 유지, F-A11 hook 중복 발견 |
| D3 dogfooding | 4.0 | 4.0 | **±0** | TDD smoke 247 케이스 역대 최고, F-D6 false alarm 으로 상쇄 |
| **평균** | **4.17** | **4.07** | **-0.10** |

**머지 PR**:
- #92 (commit c5fc586) — F-D1-R4-1 + F-D1-R4-2 sync drift 검증 범위 확장 (rules + scripts + hooks). 5종 drift 일괄 sync. validate.sh 31 pass → 36 pass.
- #93 (commit e0c2658) — F-A11 settings hook 중복 fire 차단. settings.local.json hooks 블록 제거 + validate.sh 재발 감지 check 추가.

**F-D6 결과 (false positive)**: D3 agent 가 "tool-invocation-tracker Skill matcher 0건 누적" 으로 P1 finding 보고. 라이브 검증 결과 `/status` 스킬 호출 시 `skill_invoked_auto` event 정상 emit (`ts:2026-06-04T17:21:13Z`). 0건의 진짜 원인은 사용자 행동 패턴 — audit-driven 14일 sessions 가 Bash/Read/Edit/Agent 위주라 Skill tool 직접 호출이 거의 없었음. 슬래시 명령은 `skill_invoked` 채널 (UserPromptSubmit) 로 별도 추적됨. **코드 수정 불필요**.

### F-A12 해소 (2026-06-05) — PR #94 (commit 0fa216a)

근본 원인 차단: `cloud-init.sh` 가 `settings.local.json` 에 hooks 존재 시 settings.json install skip. cloud session (fresh clone) 은 settings.local.json 부재라 정상 진행. FORCE=1 override 유지. 테스트 25/25 PASS (C6 4 + C7 3 신규).

### F-D5 진단 (2026-06-05) — 완전 해소 + 신규 finding 2개 surface

`/schedule list` (RemoteTrigger API) 결과 R12 routine (`trig_01RcUNYjHFh4t2k5UrKo75MB`) 실제로는 fire 했음 (`ended_reason: run_once_fired`, `last_fired_at: 2026-05-26T02:00:08Z`). "routine 미발화"가 아니라 "routine fire → cloud cycle silent fail" 이 진짜 finding.

**R13 재무장 후 진정한 원인 확정**: R13 routine (`trig_01DZKFt39UPhZX9zRK4yaku1`) 2026-06-05T14:39:15Z fire → cloud cycle 완전 작동 (cloud-init.sh + orchestrator P0~P5 + PR #95 자동 생성). PR #95 brainstorm 에서 cloud agent 본인이 R12 silent fail 원인 직접 진단:

> "run-cloud.sh가 gh CLI 부재 시 실 cycle 미활성 분기로 entry queued 복구"

**F-D5 = gh CLI 부재 + run-cloud.sh 정책 불일치 (entry queued 복구 vs aborted 마킹)** — 즉 routine 자체나 cloud-init 문제가 아니라 cloud env의 gh CLI 가용성 + run-cloud 분기 처리 버그.

### F-A13 (PR #96, commit 1c48c33) — 신규 + 즉시 해소

PR #95 (R12 cycle) 머지 직후 surface. `cloud-init.sh` 가 cloud session 에서 `.claude/settings.json` 생성. 같은 디렉토리의 settings.local.json/template.json 은 이미 gitignored 인데 settings.json 만 누락. 결과: 매 cycle PR 마다 settings.json 276줄 noise + user-machine state 유출 위험. fix: `.gitignore` 추가 + `git rm --cached`.

### F-D7 해소 (PR #97, commit add0614, 2026-06-06)

조사 결과 F-D7 실 원인은 gh-absent 정책 불일치가 아니라 **PR-C2 stub 미정리**. run-cloud.sh:66-74 가 R8 dogfooding (2026-05-23 PR #71) 후 정리 예정이었으나 14일째 잔존 — entry 를 `running` → `queued` 복구하고 exit 1. R12 silent fail 의 근본 원인.

해결: stub 제거 + agent hand-off 명시 (run-cloud.sh 책임 = entry pop + running 마킹; cloud agent 책임 = orchestrator P0~P5 + PR 생성 + status-update). stderr 단계별 지시. SKILL.md:245 정책 갱신. smoke test C4 4 케이스 신규 (총 12/12 PASS).

R8/R9/R10/R11/R13 은 cloud agent 가 stub exit 무시하고 manual orchestration 으로 성공했음 — agent 해석 robustness 에 의존. 본 fix 로 향후 cycle 결정적 작동.

### F-D5 완전 종료

R13 cycle PR #95 + F-D7 fix PR #97 로 F-D5 root cause 완전 차단. 향후 routine fire → cycle 완주 → marker PR 결정적.

### audit round 4 마감 (2026-06-06) — PR #98 (commit 14f546e)

`core/skills/test/SKILL.md:9` 중복 effort 키 1줄 삭제. audit round 4 잔여 0건.

### Round 5 (2026-06-06) — 측정 + fix 1 PR

R4 measurement 후 6 PR (#92-#98) 적용 효과 정량 측정. fresh-context 3 agent 위임.

| Dim | R4 | R5 측정 | R5 #99 후 예상 |
|-----|----|----|------|
| D1 | 4.0 | **4.5** (+0.5) | 4.5 유지 |
| D2 | 4.2 | **4.4** (+0.2) | ~4.6 (F-E1/E2 해소) |
| D3 | 4.0 | **4.5** (+0.5) | 4.5 유지 |
| **평균** | **4.07** | **4.47** | **~4.53** |

핵심 진전: D3 self-evolving closed-loop (R13 cloud cycle 본인이 silent fail brainstorm 진단 → PR #95/#96/#97 자동 closed-loop) 입증. D2 +0.2 미달은 신규 F-E1 메타 drift 발견 때문.

PR #99 (commit fb1940a) — F-E1/E2/D8 3건 묶음 fix:
- F-E1 (P2) orchestrator.md 37줄 drift sync
- F-E2 (P3) validate.sh F-C1 에 skill-doc loop 추가 (비-SKILL.md 검증 범위 확장)
- F-D8 (P3) hook drift loop missing 케이스 대칭 fix + git-post-commit.sh 명시 skip

R5 잔여: F-D9 (P3) cycles-report --all over-count.

### 통합 종료 — audit round 1 ~ 5 (2026-06-01 ~ 06-06)

본 audit cycle 동안 **19 PR 머지 (#80-#98)**. 발견 finding 총 14건, 모두 처리 (해소 12 / false positive 1 / closed by chain 1). 

**점수 진화**:
- Round 1 (06-01): 3.0/5 — 시작점
- Round 2 (06-02~03): 3.77 (+0.77) — 4 PR
- Round 3 (06-04~05): 4.17 (+0.40) — 4 PR + 잔여 3건 모두 해소
- Round 4 (06-05~06): 4.07 측정 (-0.10 메타 결함 노출) → fix 후 ~4.27 예상 — 7 PR
- **누적 예상 +1.27**

**핵심 진화** (각 round 1 줄):
- R1: P0 + P1 4건 cleanup (MEMORY 운영, tee 제거, security 라우팅, TDD smoke)
- R2: 잔여 P1 3건 + P2 묶음 (validate 28 hooks, plan close, test/planner 도메인 명시)
- R3: 마지막 P2 3건 (dangling plan close, tool_failure 오분류, cycles-report)
- R4: 메타 결함 fix (F-C1 검증 범위 확장, hook 중복 fire 완전 봉쇄 (증상 → 근본), F-D5 silent fail 진짜 원인 (run-cloud stub) 해소)

### Round 4 예상 회복 (PR #92/#93 적용 후 재측정 시)

본 PR 들 적용 후 D1 finding 2건 해소 + F-A11 해소되었으므로:
- D1 ~4.5 회복 (drift 검증 완전)
- D2 ~4.3 (F-A11 해소)
- D3 ~4.0 유지 (F-D6 false alarm 명확화)
- 평균 **~4.27 (+0.20 vs Round 3 4.17)** 예상

## 최종 점수 (Round 3)

| Dimension | Round 1 | Round 2 | Round 3 |
|-----------|---------|---------|---------|
| D1 컨텍스트 | 2.8 | 4.0 | **4.5** (+1.7 누적) |
| D2 아키텍처 | 3.8 | 3.8 | **4.0** (+0.2 누적) |
| D3 dogfooding | 2.5 | 3.5 | **4.0** (+1.5 누적) |
| **평균** | 3.0 | 3.77 | **4.17 (+1.17 누적)** |

## Round 2 점수 변화 (재감사 결과)

| Dimension | 1회차 | 2회차 | Δ |
|-----------|------|------|---|
| D1 컨텍스트 관리 | 2.8 | **4.0** | **+1.2** ⬆️ |
| D2 아키텍처/구조 | 3.8 | 3.8 | 0 (해소 +1 vs 신규 -1) |
| D3 dogfooding gap | 2.5 | **3.5** | **+1.0** ⬆️ |
| **평균** | **3.0** | **3.77** | **+0.77** |

### D1 +1.2 핵심
- Karpathy 5번 적용 2→4 (tee 제거 + donts 룰 정착)
- 메모리 운영 2→4 (MEMORY.md 71줄 + 2계층 분리)

### D2 정체 (0)
- 해소: F-B1 (security 3-layer), F-B3 (performance-checker 차별화) +1.0
- 신규: F-B8 (validate.sh 누락, 자기 모순) -0.5, F-B6 (security agent 2 중복 유지) -0.5
- → PR #84로 F-B8 해소했으므로 round 3 측정 시 D2 ~4.3 예상

### D3 +1.0 핵심
- TDD Iron Law 회복 (smoke test 5→8)
- session-logs 분석으로 "22 agent 0회" 결론 정정 → 실은 13 agent 52건
- agent_invoked event 라이브 캡처 4건 (hook 작동 확인)
- 단 plan_completed 8:1 → PR #84로 6:8 (이전 7:1→8:1 악화에서 회복)

## Round 6 (2026-06-10) — 재감사 + PR-1 머지 진행

R5 종료(06-06, v2.0.0 #106) 후 ~4일 누적. 3 dimension fresh-context 병렬 위임 (general-purpose D1 / architecture-reviewer D2 / general-purpose D3 — retrospective agent 가 보고 없이 종료해 재위임).

| Dim | R5 | R6 | Δ | 핵심 |
|-----|----|----|---|------|
| D1 컨텍스트 | 4.5 | 4.5 | ±0 | 인프라 무결, project `.claude/memory/MEMORY.md` 만 06-01 동결 stale |
| D2 아키텍처 | 4.4 | 4.5 | +0.1 | 라우팅/hook 견고, **validate.sh drift 무력화 노출** |
| D3 dogfooding | 4.5 | 4.3 | -0.2 | cloud cycle 정상, telemetry poisoning 2건 신규 |
| **평균** | **~4.47** | **~4.43** | **-0.04** | R4 처럼 **메타-검증 결함** 노출 라운드 |

**Round 6 finding (de-conflict + 통합 넘버링)**:
- 🟠 P2 — **F-F1** (validate.sh:133 `dirname "$0"` → 문서 경로 `bash .claude/validate.sh` 시 drift 블록 silent skip, R3~R5 sync 검증 무력화) / **F-F2** (skill-tracker.sh:15 awk garbage skill 명 telemetry 오염) / **F-D9** (cycles-report.sh:19 squash+원본 중복 카운트, R5 잔여) / **F-F3** (project MEMORY.md 06-01 동결 — "Phase 3.1/4 active" 인데 실제 #80~#99+v2.0.0 완료)
- 🟡 P3 — **F-F4** (agents.json 10/22 등록, validate [5/10] 12 orphan 미검증) / **F-F5** (MEMORY.md dead ref 2건: audits/ 미존재, brainstorm 파일 부재) / **F-F6** (tool_failure 노이즈 sandbox git not found)
- **기각**: F-F7 (scripts/tests 0 커버) = false positive, 14 test 파일 실재

**PR-1 머지 진행 (PR #108, 브랜치 fix/audit-r6-instrumentation-accuracy)** — F-F1+F-F2+F-D9 계측/검증 정확도 trio. TDD RED→GREEN, smoke test 신규 2 (skill-tracker/validate-drift) + cycles-report Case 4. 5 suite 51 assertion 0 fail. 소스(core/+root validate.sh)만 커밋 (.claude/ 는 gitignore 런타임 미러).

**PR-2 머지 진행 (PR #109, 브랜치 fix/audit-r6-cleanup, main 독립 분기)** — P3 정리 묶음 F-F3+F-F4+F-F5:
- F-F3: project `.claude/memory/MEMORY.md` 06-01 동결 → Phase 3.1/4 종료 + v2.0.0 + R1~R6 인덱스로 현행화 (71→61줄).
- F-F4 **(D2 agent 프레이밍 교정)**: agents.json 은 message-bus/inbox 참여자 레지스트리(curated 10개, inbox 디렉토리도 10개)라 "22개 등록"은 message-bus 동작 바꾸는 비-surgical 변경 → **기각**. 대신 진짜 불일치만 fix: inbox/SKILL.md "12"→"10" (3곳) + message-bus.sh 폴백의 유령 agent(grader/skill-reviewer) 제거 + validator 추가 → agents.json 과 정확히 일치.
- F-F5: MEMORY.md dead ref 2건 (audits/ 미존재 + brainstorm 파일명 auto-build→sleep-build 오타).
- **F-F6 (P3 tool_failure 노이즈) 보류** — sandbox `git not found`로 코드 버그 아님, fix 대상 아님.

**Round 6 마감 상태**: P2 trio(PR #108) + P3 cleanup(PR #109) 2 PR 로 finding 전부 처리 (해소 6 / 기각 2: F-F7 false positive + agents.json 22등록 / 보류 1: F-F6). 두 PR 머지 시 R6 종결.

## Round 7 (2026-06-23) — D4 메타-검증 dimension 신설 + 4 PR (#110~#113, 머지 완료)

> 4 PR 전부 머지(2026-06-23). #110 신규 CI(validation-tests.yml)가 첫 실행에서 비-CI-safe 기존 테스트 2종 surface(skill-tracker가 .claude 미러 참조 / run-cloud C3 gh-absent 비포팅) → core/ 경로 교정 + CI-SKIP 마커로 해소 후 green 머지. F-G11(metrics-collector)만 별도 트랙 잔여.

R6 종결(#108/#109 머지) 후 ~13일. 기존 3 dimension + **D4(메타-검증 인프라 "감사 도구를 감사") 신설** 4 agent 병렬 위임. 각 agent에 file:line 증거 + 자가 반증 강제(F-D6/F-F7 false positive 교훈).

| Dim | R6 | R7 | Δ | 핵심 |
|-----|----|----|---|------|
| D1 컨텍스트 | 4.5 | 4.3 | -0.2 | template dead command refs, MEMORY.md stale 회귀 |
| D2 아키텍처 | 4.5 | 4.3 | -0.2 | validate 비대칭, agent-routing ghost refs |
| D3 dogfooding | 4.3 | 4.3 | ±0 | 계측 견고, plan_completed 미계측 부채 |
| **3-dim 평균** | **4.43** | **4.30** | **-0.13** | R4/R6 이어 3연속 메타-결함 노출 라운드 |
| D4 메타-검증 (신규) | — | 3.6 | — | 검증 도구 false-PASS 경로 잔존 |

**R7 테마**: drift 탐지·계측 도구가 구조적 맹점/거짓 신호를 가짐. D4 신설 적중 — 최고 가치 finding 다수가 메타-검증 결함. 교차검증: D2·D4가 독립적으로 F-G01 동일 발견 + /tmp 재현.

**12 Finding (F-G 시리즈)**:
- 🔴 P1: F-G01 validate.sh agents/skills/rules drift 루프 missing-dst 비대칭(core-only 신규 파일 silent-PASS, F-D8 fix 절반만 적용)
- 🟠 P2: F-G02 validate.sh CI 미실행 / F-G03 agents.json drift 미탐지 / F-G04 telemetry events-source(**from_entries idiom 깨짐 — COUNTS 항상 빈 객체로 Top5/Total 무력화** + noise 오염 + 계측 타입 누락) / F-G05 template dead command refs(/metrics·/retrospective·/design-audit = 확장 전용) / F-G06 project MEMORY.md stale(F-F3 회귀) / F-G07 agent-routing ghost refs 8종 / F-G08 plan_completed 미계측 부채
- 🟡 P3: F-G09 tool_failure diagnostic noise / F-G10 cycles-report 변형 마커 over-count / F-G11 metrics-collector 10s window 교차오염 / F-G12 perf-audit 라우팅 누락
- false-positive 회피: D3가 R7 저활동을 tracker 고장으로 오진 안 함(13일 중 organic 2일 = 행동 패턴, F-D6 교훈)

**4 PR (머지 대기, TDD RED→GREEN)**:
- **#110** drift 게이트 강화 trio (F-G01 2-branch 통일 + F-G03 agents.json 양쪽 + F-G02 validation-tests.yml CI). validate-drift-missing-smoke RED 4/4→GREEN.
- **#111** telemetry/plan 계측 정확도 (F-G04 from_entries 교정+noise+가시화 / F-G08 plan_completed emit). telemetry-counts-smoke 7.
- **#112** 문서/상태 drift cleanup (F-G05 확장 표기 / F-G06 MEMORY 현행화 / F-G07 (plugin) 주석 / F-G12 perf-audit 행).
- **#113** P3 신호 품질 (F-G09 diagnostic gate / F-G10 마커 정규화). **F-G11 defer**(best-effort, 로그 file_path 재설계 필요).

**핵심 진전**: D4 신설로 events-source telemetry 가 from_entries 폴백으로 **줄곧 빈 집계**였던 잠복 결함(R6 F-F1 류) 발굴 → F-G04 교정으로 events-source 첫 정상 측정 가능. 검증 도구를 CI(#110)에 올려 silent 무력화 재발 차단.

**다음 진입점 = #110~#113 머지 후 → telemetry 효과 정량 재측정 + Round 8, 또는 character-system 신규 트랙. F-G11 별도 트랙 잔여.**

## AHE 정식화 (2026-06-23, #114/#115 머지)

R7 직후 "harness 자기진화" 1순위 goal 실행. 감사를 **실행 가능한 계약**으로 고정:
- `core/rules/harness-evolution.md` — AHE doctrine (evaluate→analyze→improve, 7-component observability, 4-필드 finding contract, decision-observability)
- `/audit` 스킬 — 루프 1 호출 실행 (dimension 병렬 → 4-필드 finding → 전역 단일 번호 → ledger)
- `ledger.sh` + `.claude/memory/audit-ledger.jsonl` — 폐루프: append(open)→enqueue(auto-build)→mark-fixed→pending-verify→resolve(verified/refuted). R7 F-G01~G12 seed.
- PR-1 #114(framework) + PR-2 #115(improve 자동화 enqueue + 폐루프). 근거 레포 china-qijizhifeng/agentic-harness-engineering.

## Round 8 (2026-07, `/audit` 첫 라이브 dogfooding) — 3 PR (#116~#118 머지 완료)

**AHE 스킬을 실제로 처음 실행.** Phase 0(R7 11건 verified 반증, 폐루프 첫 실작동) → 4 dimension 병렬 → 12 finding.

| Dim | R7 | R8 | Δ | 핵심 |
|-----|----|----|---|------|
| D1 | 4.3 | 4.4 | +0.1 | MEMORY stale + ledger lifecycle 노출 |
| D2 | 4.3 | 4.0 | -0.3 | plugin.json audit 누락 + ledger 상태머신 gap |
| D3 | 4.3 | 4.5 | +0.2 | **R7 telemetry fix 실데이터 작동 측정 확인** |
| D4 | 3.6 | 3.8 | +0.2 | 신규 인프라 대체로 정확, 동시성·경계 결함 |

**메타-패턴**: `/audit`이 자신이 방금 만든 AHE 인프라의 실 결함 발굴 + **Phase 3 실행 도중 자기 octal 버그(F-H12) 라이브 적발** + 내 superficial Phase 0(F-H07)까지 D1·D3 교차 self-적발. dogfooding의 궁극.

**12 Finding**: F-H01 plugin.json audit 누락 / F-H02 ledger append TOCTOU race / F-H03 빈문자열 vs null / F-H04 validate orphan 24/45 / F-H05 CI mktemp false-skip / F-H06 MEMORY stale / F-H07 ledger lifecycle 단락(내 실행 결함) / F-H08 mark-fixed 가드 / F-H09 audit 과잉권한 / F-H10 phantom skill telemetry / F-H11 diagnostic gate(defer) / F-H12 next_num octal(라이브 적발).

**3 PR**: #116 ledger.sh 견고성(H02/03/08/12, mkdir 락+octal) / #117 배포·검증 wire(H01/04/05) / #118 doc·telemetry(H06/07/09/10). 11 fixed + F-H11 deferred.

**다음 진입점 = R8 머지 후 누적 → Round 9 를 `/audit`로. R8 fix 들을 pending-verify→resolve 로 반증(decision-observability 2회차). F-H11 + F-G11 별도 트랙 잔여.**

## Linked memories

- [[phase3-1-r10-functional-pass-f14-f15]] — Phase 3.1 cloud cycle 결과
- 이전 brainstorms는 `.claude/memory/brainstorms/` 17건 — 인덱스는 project-level MEMORY.md 참조
