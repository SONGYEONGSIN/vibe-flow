# Brainstorm: 캐릭터 시스템 확장

작성: 2026-05-04T07:42:53Z (filename에서 추출, retroactive F-A4 fix)

## 의도
- **산출물**: 캐릭터 시스템의 다음 진화 방향 1개 결정 + spec (다음 세션 즉시 구현 입력)
- **사용자**: vibe coder, 자기 작업의 시각/정서적 피드백을 깊게 받고 싶은 시점
- **트리거**: ROADMAP 마지막 큰 항목, 토대(12 캐릭터 + 이벤트 매핑 + Stage 어드저스터 UI) 안정화 완료. 미루면 캐릭터 시스템이 "정적 매핑 표시" 수준에서 멈춤
- **성공**: 결정점 3개 명확화 — (1) 우선순위 (2) 비용 (3) 다음 세션 진입 가능한 spec 형태

## 제약
- **픽셀 art 한계**: 단순 도트 그리드 → skin 변형 옵션 제한 (색상 swap, 작은 액세서리 정도)
- **dashboard 기존 코드**: `/characters` 페이지 + 12 컴포넌트 + reducer + useCharacterEngine 안정. 큰 리팩토링 부담
- **events.jsonl 데이터 자산**: 이번 세션 신규 이벤트 (perf_audit, security_lint, inbox_sent 등) + 누적 메이커 사용 패턴
- **vibe-flow 비침투 원칙**: dashboard는 events.jsonl 읽기 전용, 사용자 작업 흐름 차단 X

## 대안 비교

| 항목 | A. Stage 자동 진화 | B. 외형/이름 personalization | C. /pair 협업 애니메이션 | D. 작게 묶음 | Z. do nothing |
|------|-----------------|--------------------------|--------------------|------------|--------------|
| 핵심 | events.jsonl 카운트 → Stage 자동 | 설정 페이지 + localStorage | 두 캐릭터 walk-to + toggle | 3개 부분만 | 현 상태 유지 |
| 토대 활용 | 높음 (Stage 어드저스터 UI 활용) | 중 | 낮음 | 중 | n/a |
| 비용 | 중 (~3h, 1~2 PR) | 중 (~3h) | 큼 (~6h+, 위치 충돌) | 큼 (분산) | 0 |
| 위험 | 낮음 (Stage = derived data) | 중 (skin 옵션 제한) | 큼 (wander/idle 충돌) | 큼 (표면적) | 0 |
| 가치 | **메이커 진척감 + retrospective 루프** | cosmetic | 시각 임팩트 | 약함 | 0 |

## 추천 + 근거

**대안 A (Stage 자동 진화 — telemetry 기반) 채택.**

1. **토대 활용도 최대**: Stage 어드저스터 UI 이미 있음 (수동 → 자동 전환만), telemetry events.jsonl 이미 수집됨, dashboard SSE stream 동작 중
2. **vibe-flow 핵심 가치 일관**: "events.jsonl → 학습 → 시각" 루프 강화. 메이커 본인 사용 패턴이 캐릭터 진화로 보임 → retrospective/feedback 자연 연결
3. **Stage 의미 명확화 가능**: 0=신참 / 1=학습 중 / 2=숙련 / 3=고수 / 4=마스터. 카운트 임계값 + 시각 변화 (색상 진화, 후광 — 픽셀 가능 요소)
4. **다음 세션 즉시 진입 spec 명확**

**기각 B (외형/이름)**: 픽셀 art 변형 옵션 제한 → skin 가치 작음. 이름 입력만은 cosmetic. 메이커 진척과 무관.
**기각 C (/pair 협업)**: 동작 프리미티브 신규 + 두 캐릭터 위치 충돌 + 동기화 → 분량 큼. wander/idle/walk-to 시스템 충돌 위험. **B보다도 후순위**.
**기각 D (묶음)**: 각 항목 표면적, 결정점 분산 → 결국 다 어중간.

## 다음 세션 진입 spec

**구현 단위:**

1. **`stage-calculator.ts`** (신규) — `events.jsonl` 카운트 → 에이전트별 Stage (0-4)
   - 임계값 (조정 가능, JSON 별도 파일):
     - Stage 0: 0~9회
     - Stage 1: 10~49회
     - Stage 2: 50~199회
     - Stage 3: 200~499회
     - Stage 4: 500회+
   - 카운트 source: 에이전트별 매핑된 이벤트 type 합산
     - developer: commit_created, skill_invoked(commit/release)
     - planner: skill_invoked(plan/brainstorm/scaffold/onboard/finish)
     - qa: tool_result(qa)/verify_complete/skill_invoked(test/verify)
     - 등 (event-map.ts의 SKILL_TO_AGENT 역매핑)
2. **`useCharacterEngine` 확장** — 위 calculator를 reducer에 통합 (현 어드저스터 UI는 dev override로 유지, localStorage stage 우선 → 자동 stage fallback)
3. **캐릭터 시각 차이** — Stage별 후광 또는 색상 보정 (CSS box-shadow, filter:hue-rotate, opacity 등 — 픽셀 자체 변경 X, 비용 ↓)
4. **단위 테스트** — stage-calculator 임계값 + 누적 시뮬레이션 + 역매핑 검증

**HARD-GATE**: 6~8 파일 (간략 설계 등급) → 다음 세션 첫 작업: `/plan from-brainstorm <file>` 또는 직접 분해

**파일 영향도 (예상):**
- `src/app/characters/lib/stage-calculator.ts` (신규)
- `src/app/characters/lib/__tests__/stage-calculator.test.ts` (신규)
- `src/app/characters/data/stage-thresholds.json` (신규, 임계값)
- `src/app/characters/useCharacterEngine.ts` (수정)
- `src/app/characters/CharacterRoom.tsx` 또는 캐릭터 컴포넌트 (수정 — Stage prop 받아 시각 차이)
- `src/app/characters/data/agents.ts` 또는 별도 매핑 파일 (수정 — agent → event types 역매핑)

## 다음 단계

- spec 저장: `.claude/memory/brainstorms/20260504-074253-character-system-extension.md`
- 다음 세션 첫 작업: dashboard repo로 이동 후 `/plan from-brainstorm <file>` 또는 spec 인라인 설계로 직접 분해
- B (외형/이름) — 미정 후보로 ROADMAP 별도 보존, Stage 안정화 후 재평가 (사용자가 "내 캐릭터" 정 들이는 시점)
- C (/pair 애니메이션) — 장기 후보, 동작 프리미티브 일반화 후
