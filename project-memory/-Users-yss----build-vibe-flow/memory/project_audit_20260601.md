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

- #80 (commit 8456c58) — P0 + P1 4건 cleanup
- #81 (commit 87c093c) — F-D2 R1 instrumentation tracker hook
- #82 (commit 0c8a459) — F-D2 R2 10 skill description 자연어 트리거 강화 (H3 해소)
- #83 (commit ad05aaa) — F-D2 R3 telemetry --source session 모드 (raw 호출 빈도 측정)

## Linked memories

- [[phase3-1-r10-functional-pass-f14-f15]] — Phase 3.1 cloud cycle 결과
- 이전 brainstorms는 `.claude/memory/brainstorms/` 17건 — 인덱스는 project-level MEMORY.md 참조
