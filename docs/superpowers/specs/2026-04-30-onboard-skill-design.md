# /onboard 스킬 설계

vibe-flow 신규 + 기존 사용자 모두를 위한 단계 자가진단 + 다음 행동 추천 인터랙티브 스킬.

## 의도

**문제**: vibe-flow는 23 스킬 / 12 에이전트 / 5 extensions로 학습 곡선이 길다. 신규 사용자는 어디서 시작할지 모르고, 기존 사용자도 1개월 후 "다음 무엇을 배워야 하나?"를 직관으로 결정하기 어렵다. `docs/ONBOARDING.md`는 정적이라 사용자 현재 상태를 반영하지 못한다.

**해결**: `/onboard` 인터랙티브 스킬 — 사용자 데이터 기반 단계 자동 진단 → 단계별 맞춤 다음 행동 추천 (지금 / 이번 주 / 다음 단계).

**대상**:
1. 신규 사용자 (setup.sh 직후) — 첫 사이클 진입
2. 기존 사용자 (정기 점검) — 다음 학습 영역 발견

## 제약

- **데이터 우선**: vibe-flow의 자산(`events.jsonl`, `.vibe-flow.json`, `memory/`, `store.db`)을 활용. 자가보고는 데이터 부족 시 폴백.
- **신규 사용자 지원**: 데이터 0건이어도 자가보고로 진단 가능해야 함.
- **무거운 분석 금지**: jq 기반 단일 패스 분석. LLM 호출은 단계 분류 + 추천 생성에만.
- **재진단 가능**: 24h cache + `--refresh`로 강제 갱신.
- **명령 표면 최소**: 단일 명령 `/onboard`. `/onboard --refresh` 1개 옵션만.

## 설계

### 입력

```bash
/onboard            # 자동 결정 (24h cache 활용)
/onboard --refresh  # cache 무시 + 강제 재진단
```

### 단계 분류 (5단계)

| Stage | 명칭 | 시그널 | 설명 |
|-------|------|--------|------|
| 0 | 신규 | events 0건 또는 `.vibe-flow.json`만 존재, skills 디렉토리 비어 있음 | 첫 사이클 안 함 |
| 1 | 입문 | events 1~50, Core 스킬 1~5종 사용 | 첫 사이클 진행 중 |
| 2 | 핵심 익숙 | events 50~200, Core 스킬 6종 이상, `/commit` `/verify` 정기 사용 | 일상 사용 정착 |
| 3 | 확장 후보 | events 200+, Core 스킬 10종 이상 또는 `improvements.md` 존재 | extensions 시작 시기 |
| 4 | 자가 진화 | `extensions` 키 1개 이상 + (`/eval` 또는 `/retrospective` 1회+ events) | 메이커 모드 |

### 진단 입력 (우선순위)

1. **state 파일** (`.claude/.vibe-flow.json`)
   - 존재 여부 → Stage 0 vs 1+
   - `.extensions` 키 카운트 → Stage 4 후보 시그널
2. **events.jsonl** (`.claude/events.jsonl`)
   - 총 라인 수 → 사용 강도
   - skill 발생 분포 (jq aggregation) → 익숙한 스킬 카테고리
3. **memory/** 흔적
   - `improvements.md` 존재 → retrospective 1회+ 시그널 (Stage 3+)
   - `patterns.md` 라인 수 → /learn save 사용 빈도
4. **store.db** (가용 시)
   - commit_created / verify_complete 카운트 → 정기 사용 검증
   - 가용 안 되면 events.jsonl로 fallback

### 데이터 부족 시 폴백 (자가보고)

진단 시그널 부족(events <10 + state 없음)이면 3 질문 max:

```
1. vibe-flow 며칠 썼어요?
   a. 처음 / 1주 미만 / 1주~1개월 / 1개월+
2. 주로 쓰는 스킬은?
   a. 모름 / 1~2개 (commit, verify) / Core 6개+ / extensions까지
3. 다음 배우고 싶은 영역? (skip 가능)
   a. 기본 사이클 / 협업 / 디자인 / 메트릭/회고 / 자가 진화
```

### 출력 포맷

```
📍 현재 단계: Stage <N> — <명칭>
   근거: <events 카운트>, <Core 스킬 X종 사용>, [extensions: <list>]

🎯 지금 (오늘~3일): <스킬 1-2개 + 1줄 이유>
📅 이번 주: <스킬 1-2개 + 1줄 이유>
📆 다음 단계: Stage <N+1> 진입 — <조건 + 명령>

(필요 시) 명령:
  bash setup.sh --extensions <name>   # extension 활성화
  /<recommended-skill> "..."          # 다음 추천 사용 예시
```

### Stage별 추천 매핑

| Stage | 지금 (3일) | 이번 주 | 다음 단계 진입 조건 |
|-------|-----------|---------|---------------------|
| 0 | `/brainstorm "<주제>"` 한 번 | `/commit`, `/verify` 정기 사용 | events 50+ → Stage 1 |
| 1 | `/commit`, `/verify` 매일 | `/finish`, `/status` 도입 | Core 6 사용 → Stage 2 |
| 2 | `/test`, `/security` 정착 | `/scaffold`, `/worktree` | events 200+ 또는 retrospective 1회 → Stage 3 |
| 3 | `--extensions learning-loop` 활성화 | `/retrospective` 정기 | extensions + /eval/retrospective 사용 → Stage 4 |
| 4 | `--extensions meta-quality` (있으면 /eval) | `/evolve <skill>` 1회 시도 | (최종) — 메이커 활동 |

### 상태 저장

`.claude/memory/onboard-state.json`:
```json
{
  "last_diagnosed_at": "2026-04-30T07:00:00Z",
  "stage": 2,
  "stage_name": "핵심 익숙",
  "evidence": {
    "events_count": 137,
    "core_skills_used": 8,
    "extensions_active": []
  },
  "recommendations": {
    "now": ["/test", "/security"],
    "this_week": ["/scaffold"],
    "next_stage": "Stage 3"
  }
}
```

24h 이내 호출은 이 파일을 그대로 출력 (cache hit). `--refresh`로 무효화.

### Events 발생

`/onboard` 실행 시 `events.jsonl`에 1줄 append:
```json
{"type":"onboard","ts":"...","stage":2,"refresh":false}
```

retrospective 분석 입력으로 활용 (단계 변화 추적).

## 데이터 흐름

```
사용자: /onboard
   │
   ▼
1. cache check (.claude/memory/onboard-state.json)
   │ < 24h + !--refresh → cache 출력 + 종료
   │
   ▼ (cache miss 또는 --refresh)
2. 진단 시그널 수집 (jq + 파일 존재 체크)
   - state file
   - events.jsonl 라인 수 + skill 분포
   - improvements.md / patterns.md 존재
   - store.db (가용 시)
   │
   ▼
3. Stage 결정 (시그널 → 5단계 분류)
   │ 시그널 부족 → 자가보고 3질문
   │
   ▼
4. Stage별 추천 매핑 → 출력
   │
   ▼
5. .claude/memory/onboard-state.json 갱신
6. events.jsonl에 onboard 이벤트 append
```

## 구성 요소

### SKILL.md 구조

```
---
name: onboard
description: 사용자 단계 자가진단 + 다음 행동 추천. 신규~Stage 4 자동 분류.
model: claude-sonnet-4-6
---

# /onboard

## 트리거
- 사용자가 `/onboard` 또는 `/onboard --refresh` 입력

## 절차
1. cache check
2. 시그널 수집 (jq one-liners)
3. Stage 결정 + 부족 시 자가보고
4. Stage별 추천 출력
5. state 저장 + event append
```

### Evals (`evals/evals.json`)

5 evaluation cases:
1. 신규 (state 없음, events 없음) → Stage 0 + 자가보고 트리거
2. 50 events / Core 4 스킬 → Stage 1
3. 150 events / Core 8 스킬 / `/commit` 30회+ → Stage 2
4. 250 events / Core 12 스킬 / improvements.md 있음 → Stage 3
5. 250 events / extensions=[meta-quality] / /eval 5회 → Stage 4

각 case에 expected stage + expected 추천 (`/test`, `/scaffold` 등 정확 매칭).

## 의존

- **Core**: events.jsonl, memory/, store.db (선택)
- **외부**: jq (필수), node (store.db 폴백 시)
- **추가 hook 불필요**: 자체 SKILL.md 내부에서 모든 작업 처리

## 시나리오

### 시나리오 1 (신규 사용자, setup.sh 직후)

```
$ /onboard
📍 현재 단계: Stage 0 — 신규
   근거: events 0건, .vibe-flow.json만 존재

데이터가 부족합니다. 3 질문드릴게요:
> vibe-flow 며칠 썼어요?
1) 처음
2) 1주 미만
3) 1주~1개월
4) 1개월+

(사용자: 1)

🎯 지금 (오늘~3일):
  /brainstorm "<주제>" — 첫 의도 탐색 한 번
  → 결과 .claude/memory/brainstorms/<file>.md

📅 이번 주:
  /commit, /verify 매일 사용으로 자동 강제 익숙해지기

📆 다음 단계 (Stage 1 입문):
  events 50+ 누적 시 자동 진입
```

### 시나리오 2 (Stage 2 사용자, 데이터 기반)

```
$ /onboard
📍 현재 단계: Stage 2 — 핵심 익숙
   근거: 137 events / Core 스킬 8종 / commit 매일 사용

🎯 지금 (오늘~3일):
  /test src/<file>.ts — TDD strict 만나면 /test로 보완
  /security — 정기 OWASP 스캔 시작

📅 이번 주:
  /scaffold [domain] — 보일러플레이트 자동화
  /worktree create feat/<branch> — 격리 작업 시도

📆 다음 단계 (Stage 3 확장 후보):
  events 200+ 또는 첫 /retrospective 후 자동 진입
  미리 활성화: bash setup.sh --extensions learning-loop
```

### 시나리오 3 (Cache hit, 24h 내 재호출)

```
$ /onboard
(2시간 전 진단 결과 — --refresh로 강제 재진단 가능)

📍 현재 단계: Stage 2 — 핵심 익숙
[이전 출력 그대로]
```

## 비교: 기존 docs/ONBOARDING.md와의 차이

| 항목 | docs/ONBOARDING.md | /onboard |
|------|-------------------|----------|
| 형태 | 정적 문서 | 인터랙티브 스킬 |
| 단계 결정 | 사용자 자가 판단 | 데이터 자동 진단 + 폴백 |
| 추천 | 일반적 (모든 단계 1 페이지) | 사용자 단계 맞춤 |
| 재방문 | 매번 같은 내용 | 단계 변화 반영 |
| 메트릭 활용 | X | events.jsonl / state / memory |

`docs/ONBOARDING.md`는 README에서 링크되는 reference. `/onboard`는 daily/weekly 사용 도구.

## YAGNI

명시적 제외:
- **GUI/TUI 인터페이스** — 채팅 출력만 (Phase 3 dashboard에 위임)
- **자동 실행** — Notification 훅 트리거 안 함, 사용자 명시 호출만
- **다국어** — 한국어 출력만 (vibe-flow 전체 한국어 정책 일치)
- **상세 통계 대시보드** — `/metrics` 영역, 중복 회피
- **세션 추적** — 단순 timestamp만, 사용 패턴 분석은 retrospective 영역
