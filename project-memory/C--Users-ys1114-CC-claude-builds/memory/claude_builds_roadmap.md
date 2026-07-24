---
name: claude-builds community-borrowing roadmap
description: claude-builds 개선 로드맵 — 커뮤니티 리서치 기반 우선순위 작업 큐, 완료/미완료 상태와 각 항목의 통합 지점
type: project
originSessionId: df22b198-a8b8-4136-a9e4-30356273a085
---
## 배경

2026-04-14 세션에서 VoltAgent/awesome-design-md 통합을 시작으로, 커뮤니티 GitHub 리서치를 통해 claude-builds에 도입할 4가지 패턴을 선별함. 1순위(SQLite)까지 완료 후 사용자가 다른 머신(집)에서 이어 작업 예정.

**Why:** 세션 간 연속성 유지를 위해 작업 큐를 기록. 다음 세션에서 "이어서 하자"고 할 때 즉시 맥락 복원 가능해야 함.

**How to apply:** 사용자가 claude-builds에서 "다음 단계" / "이어서" / "커뮤니티 N순위" 언급 시 이 메모리를 참조하여 해당 항목부터 진행. 각 항목의 통합 지점과 공수 추정이 포함되어 있음.

## 완료 현황 (origin/main까지 푸시 완료, 2026-04-14)

- ✅ **DESIGN.md 9섹션 포맷 지원** (`0871d9b`) — VoltAgent/Google Stitch 표준 통합, `agents/designer.md` + `rules/design.md`
- ✅ **README 정합성** (`cb29c77`) — 훅 수 15→18, Design System Enforcement 4중 레이어로 확장, awesome-design-md 링크
- ✅ **P1 정비** (`ab2b130`) — `_common.sh::truncate_log_file()` 함수화, `agents.json` 단일 소스, `validate.sh` 5단계 post-setup 검증
- ✅ **커뮤니티 1순위: SQLite Instinct Store** (`fb54ece`) — `scripts/store.js` + `query-instincts.sh` + better-sqlite3, dual-write 패턴 (JSON 유지 + SQLite 병행), 3개 훅 수정

## 미완료 작업 큐 (우선순위 순)

### 🟡 커뮤니티 2순위: Builder/Validator Pair Mode
- **출처**: disler/claude-code-hooks-mastery
- **핵심**: 모든 팀 작업이 **Builder(구현) + Validator(검증 전용)** 쌍으로 스폰. Validator는 Edit/Write 권한 없고 Read+Test만.
- **통합 지점**: `skills/orchestrate/` + `agents/` 하위. `team-orchestrator`에 `pair_mode: builder+validator` 플래그 추가
- **예상 공수**: 1일 (대규모 — orchestrate 스킬 구조 변경)
- **위험**: 기존 debate 패턴과의 경계 설정 필요

### 🟢 커뮤니티 3순위: Observability 스트림
- **출처**: disler/claude-code-hooks-multi-agent-observability
- **핵심**: 훅 이벤트를 JSONL로 localhost에 스트리밍 → `tail -f | jq`로 실시간 모니터링
- **통합 지점**: 기존 `session-log.sh` 또는 `metrics-collector.sh` 확장 (dual-write 형태). SQLite store.js에 `append-stream` 추가도 고려
- **예상 공수**: 반나절 (중규모)
- **효용**: `/orchestrate` 병렬 실행 시 stuck 에이전트 즉시 감지

### ⚠️ 커뮤니티 4순위: TDD-Enforcement PreToolUse Hook
- **출처**: obra/superpowers (Anthropic 마켓플레이스)
- **핵심**: 실패 테스트 없이 구현 코드 작성 시 **Edit 자체를 revert**하는 파괴적 훅
- **통합 지점**: `hooks/` 신규 훅 추가. PreToolUse 매처로 Write|Edit 감지 → 대응 `*.test.*` 파일 존재 + 실패 상태 확인
- **예상 공수**: 반나절~1일
- **주의**: 파괴적이라 처음엔 경고로 시작, 신뢰 쌓이면 차단으로 승격. `tdd-guide` 에이전트와 연동.

### 🔵 P2 전략 공백: 토큰/비용 예산 프레임워크
- **배경**: 감사 에이전트가 발견한 전략 공백. `/orchestrate`로 11개 에이전트 병렬 실행 시 무제한 과금 가능
- **통합 지점**: 새 `hooks/budget-guard.sh` + `.claude/budget.json` 설정 + `/metrics` 스킬에 비용 차트 추가
- **예상 공수**: 반나절
- **우선순위**: 커뮤니티 2~3순위보다 낮음 (실제 과금 사례 없을 때까지 대기)

## 다음 세션 복귀 절차

1. `git pull origin main` (다른 머신에서) — 최신 상태 동기화
2. 작업 선택: 2순위(Pair Mode) / 3순위(Observability) / 4순위(TDD) / P2(Budget)
3. 3순위부터 시작 권장 — SQLite store.js가 이미 있어 확장만 하면 됨, 작은 단위 테스트 가능

## 스모크 테스트 보존

SQLite 동작 확인됨 (로컬 `_smoketest/`에서 3개 이벤트 삽입 → summary/today/top-failures 모두 정상 반환). 재검증 필요 시:
```bash
cd <project> && bash .claude/scripts/query-instincts.sh summary
```
