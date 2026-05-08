# Spec: `commit_pushed` 이벤트 짝 추가 — 첫 `/auto-build` dogfooding

- **plan_id (예정)**: 2026-05-09-commit-pushed-event-pairing
- **목적**: vibe-flow Phase 2 머지 후 첫 실 task `/auto-build` dogfooding의 입력 task 정의
- **선행 메모리**: `~/.claude/projects/.../memory/project_auto_build_runtime_limit.md`, `~/.claude/projects/.../memory/feedback_auto_build_anytime.md`, `~/.claude/projects/.../memory/project_vibe_flow_pairing.md`

---

## 1. 배경

`/auto-build` Phase 2(Ralph loop + persona vote) 머지 완료(PR #39, #40). 그러나 머지 evals(53 케이스 PASS:7)는 합성 검증으로, 실제 사이클 데이터(token / iter / vote 행동)는 미수집. 4 calibration 입력 회수가 Phase 3(`CronCreate` 정기 스케줄) 진입 결정의 선결 조건.

**dogfooding 작업 형태**: 1 cycle = 1 repo(Phase 2 SKILL.md 스킵 조건 — multi-repo). 짝 task가 필요하면 2 cycle 순차. 본 spec은 vibe-flow → dashboard 짝 패턴(memory `project_vibe_flow_pairing.md`)을 첫 dogfooding task로 채택.

**왜 작은 task로 시작?**: 첫 cycle은 "사이클이 끝까지 도는가"를 우선 검증. Ralph 분할 + vote 발화는 이후 dogfooding에서 별 입력으로 검증.

---

## 2. Task 정의

### Task A — vibe-flow (1차 cycle)

`commit_pushed` 신규 이벤트 타입을 events.jsonl에 기록한다.

| 항목 | 정의 |
|------|------|
| **이벤트 type** | `commit_pushed` |
| **payload 필드** | `type`, `ts` (ISO 8601), `branch`, `subject` (커밋 메시지 첫 줄, 80자 truncate) |
| **emit 시점** | 사용자가 `git commit` 성공 시 1 라인 append. 정확한 emit 위치(Claude Code Stop hook / git post-commit hook / `/commit` 스킬 내부 등)는 auto-build brainstorm 단계가 결정 |
| **/telemetry 매핑** | `core/skills/telemetry/SKILL.md` line 65 영역의 type→label 매핑 표에 `commit_pushed` 행 추가. label 한국어 ("커밋" 등) |
| **NFC 정규화** | branch / subject 한글 포함 시 NFC 정규화 (memory `feedback_macos_nfd_nfc.md` — `python3 -c "import unicodedata; print(unicodedata.normalize('NFC', s))"` 또는 동등) |

### Task B — vibe-flow-dashboard (vibe-flow PR 머지 후 2차 cycle)

`commit_pushed` 이벤트를 dashboard event-map에 매핑한다.

| 항목 | 정의 |
|------|------|
| **event-map.ts** | `if (type === "commit_pushed") return [{ agent: "developer", action: "typing", dialogueKey: "commit" }]` 형태의 새 분기 |
| **dialogue-pool.json** | `developer` 에이전트에 신규 dialogueKey `commit` — 예: `["커밋!", "⚡ 한 줄", "진행 중"]` (정확한 dialogue는 auto-build brainstorm이 결정) |
| **단위 테스트** | `event-map.test.ts`에 commit_pushed 분기 1 케이스 추가 (mapEvent({type:"commit_pushed", ...}) → developer typing 매칭) |

---

## 3. 합격 기준

### Task A 머지 후
- 임의 git commit 1회 → `.claude/events.jsonl`에 `commit_pushed` 라인 append됨
- `/telemetry` 실행 시 출력의 label 매핑 표에 `commit_pushed` 표시 (카운트 ≥1)
- `bash -n` / `jq empty` 모든 신규 sh / json 통과
- eval-regression CI PASS

### Task B 머지 후
- vibe-flow의 `commit_pushed` 이벤트가 dashboard에 도착(파일 동기화 또는 mock fixture)했을 때 — developer 캐릭터 `typing` 액션 + `commit` dialogue 표시
- vitest event-map.test.ts 신규 케이스 PASS, 기존 케이스 회귀 0
- TypeScript 타입 에러 0 (`commit` dialogueKey가 dialogue-pool.json에 실재)

---

## 4. Out of Scope

- 다중 task 큐 / 다중 repo 1 cycle 처리 — Phase 3
- vote 발화 task — 본 dogfooding 의도적으로 회피(첫 cycle은 변수 최소)
- past commits 일괄 백필 — 신규 이벤트는 신규 commit부터 누적, 과거 무시
- Phase 1 plan 형식의 사이클 분할 정의 — auto-build orchestrator가 스스로 결정
- dashboard 양방향 통신 / 실시간 push — 기존 파일 polling 패턴 유지
- 한국어 외 언어 dialogue — 추후

---

## 5. `/auto-build` 입력 문자열

### 1차 cycle (vibe-flow에서 trigger)

```
/auto-build "vibe-flow .claude/events.jsonl에 commit_pushed 신규 이벤트 타입 추가. payload는 type/ts/branch/subject 4 필드, ts는 ISO 8601, subject는 80자 truncate, 한글 NFC 정규화. git commit 성공 시마다 1 라인 append. emit 위치(Stop hook / git post-commit / /commit 스킬 내부)는 brainstorm 단계가 결정. core/skills/telemetry/SKILL.md의 type→label 매핑 표에도 commit_pushed 추가."
```

### 2차 cycle (vibe-flow PR 머지 후 dashboard에서 trigger)

```
/auto-build "vibe-flow-dashboard event-map.ts에 commit_pushed 핸들러 추가. developer 에이전트 typing 액션 + 새 dialogueKey commit 매핑. dialogue-pool.json의 developer 섹션에 commit dialogue 어레이 신규(3 개). event-map.test.ts에 commit_pushed 분기 1 케이스. vibe-flow PR (commit_pushed 이벤트 추가) 머지 후 짝 PR로 진행."
```

---

## 6. 4 Calibration 입력 회수 계획

각 cycle 종료 후 다음 데이터 수집:

| 입력 | 회수 위치 | 본 task 예상값 |
|------|----------|--------------|
| token cap 200k 적정성 | `/budget --tokens` 또는 jsonl `cumulative_tokens` | 작은 task — 30~80k 예상 |
| max_iter 30 cap 적정성 | `.claude/memory/auto-build-runs.jsonl`의 max `iteration` | 1-2 iter 예상 |
| vote confidence 분포 | jsonl `vote_triggered` 이벤트의 confidence 필드 | 본 task vote 발화 예상 0 (변수 회피) |
| persona 일치율 | jsonl vote 결정 vs moderator 채택 비교 | 동일, 데이터 0 |

**1차 cycle 단독으로는 token/iter calibration 입력만 수집됨**. vote calibration은 후속 dogfooding task(예: 디자인 결정 포함 task)에서 수집.

---

## 7. 리스크

- **R1 emit 위치 다중 후보 → vote 발화**: brainstorm 단계가 design 카테고리로 vote dispatch 가능. 첫 cycle 변수 늘어남. **완화** — task 입력에 후보 3개 명시, brainstorm은 trade-off 비교만 하고 단일 선택. confidence ≥0.5 시 vote 자동 결정.
- **R2 events.jsonl 폭증**: commit 빈도가 매일 N→1000+로 늘 수 있음. **완화** — 본 task는 emit만, /telemetry 검색 성능은 별 작업. 폭증 발견 시 후속 PR로 jsonl 압축/회전.
- **R3 dashboard 짝 PR 의존성**: 1차 머지 전 2차 시작 X. **완화** — 본 spec에 명시, dogfooding 시점에 maker 본인 강제.
- **R4 NFC 누락**: 한글 commit subject가 macOS git에서 NFD로 들어올 수 있음. **완화** — task 입력에 NFC 명시, brainstorm 단계가 인지.
- **R5 단발 cycle 실패 시 calibration 데이터 손실**: abort 시 jsonl `exit_reason` 명시되므로 데이터 0 아님. **완화** — abort branch 보존(safety hook 정책), morning review에서 calibration 회수.

---

## 8. 후속

- 4 calibration 입력 수집 후 본 spec 끝에 `## Calibration 결과` 섹션 추가 (별 PR)
- vote calibration 미수집은 후속 dogfooding task(예: design 결정 포함)에서 수집
- 본 task 결과 가지고 Phase 3 brainstorm 진입 — `.claude/memory/brainstorms/20260504-103257-vibe-flow-v2-overnight-autonomous-build.md` Phase 3 섹션이 출발점
