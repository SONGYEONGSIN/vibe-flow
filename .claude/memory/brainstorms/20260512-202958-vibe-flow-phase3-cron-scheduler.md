# Brainstorm: vibe-flow Phase 3 — cron scheduler + 다중 task 큐 (session-less 자율)

작성: 2026-05-12T20:29:58Z (filename에서 추출, retroactive F-A4 fix)

draft_status: 초안 — maker review 필요
출발점: `.claude/memory/brainstorms/20260504-103257-vibe-flow-v2-overnight-autonomous-build.md` Phase 2 섹션 + cycle 1-7 calibration 결과 + `feedback_auto_build_anytime` memory

## 의도

**무엇을**: `/auto-build` 자율 사이클을 **session-less**(사용자 Claude Code 세션 미 alive 상태)에서도 진행 가능하게 한다. (a) cron/schedule로 정기 trigger, (b) task 큐(다중 task 순차 처리), (c) 결과 누적 → dashboard 또는 jsonl로 추적.

**누가**: maker 본인 — Phase 2까지 session alive 필수였던 운영 한계 해소. memory `feedback_auto_build_anytime` 명시 "anytime 도구"라 야간 한정 프레임 회피, 사용자가 언제든 schedule 가능.

**왜 지금**: 7 cycle dogfooding(F1~F9 모두 resolved) + 짝 dogfooding 완주로 자율 사이클 인프라 안정성 확보. Phase 3는 운영 시간 확장의 마지막 게이트 (session 제약 제거).

**성공**: 
- cron 1회 firing → `/auto-build "<큐의 첫 task>"` 자동 trigger → 사이클 완주 → PR 생성, 사용자 Claude Code 세션 미 alive
- 큐에 N task 있으면 1 cycle 완료 후 다음 task 진입 (cycle 간 cap 별도)
- 결과 jsonl에 누적 → `/telemetry` 또는 별 view로 추적

## 제약

- **외부 의존 0 원칙**: vibe-flow는 self-contained. cron 메커니즘도 macOS launchd 또는 Claude Code 내장 schedule만 사용. 외부 CI(GitHub Actions cron)는 후순위.
- **session-less 진입점**: Claude Code 세션이 inactive일 때도 cron이 새 세션 spawn 가능해야. Claude Code의 `schedule` 또는 `CronCreate`가 이를 지원하는지 검증 필요.
- **token 비용 누적**: session-less 자동 진행은 사용자 통제 X. token cap 사이클당(현 200k) + 일일 cap이 안전 필수.
- **destructive op 차단 유지**: Phase 2의 safety hook이 cron-triggered 사이클에도 동일 활성.
- **multi-repo task**: F6 finding으로 단일 repo cycle만 자율. multi-repo는 짝 cycle 패턴(cycle 6→7)으로 분할 — 큐가 짝 의존성 표현 가능해야.
- **calibration sample 부족**: vote 1 sample (cycle 3, design 0.92 unanimous), 다른 카테고리(auth/perf/architecture) 미회수. Phase 3 cron 진입 전 추가 vote sample 회수 권장.

## 대안 비교

### A1. cron 메커니즘

| 옵션 | 외부 의존 | session-less spawn | 비용 | 통제 |
|------|---------|----------------|------|------|
| **A1.1 macOS launchd / Linux cron** | 0 (OS native) | ✓ (새 Claude Code 세션 launch) | 무료 | 사용자 직접 (plist/crontab edit) |
| A1.2 Claude Code `schedule` 슬래시 | 0 (Claude Code 내장) | ✓ (Anthropic 내부 cron) | 토큰만 | Claude Code UI |
| A1.3 GitHub Actions cron + remote agent | 외부 (GitHub) | ✓ (CI runner) | runner time | GitHub UI |

**추천 A1.2 (Claude Code schedule)** — 외부 의존 0 + UX 통합 + Anthropic 인프라. A1.1은 user-level만 (multi-machine X), A1.3은 외부 의존.

### A2. 큐 구조

| 옵션 | 표현 | 짝 의존 | 영속성 |
|------|------|---------|--------|
| **A2.1 .claude/memory/auto-build-queue.jsonl** | append-only 라인 | 명시(depends_on key) | 머신 local |
| A2.2 GitHub Issues + 자체 labels | issue 1개 = 1 task | issue link | repo 영속 |
| A2.3 dashboard UI + Supabase | 시각화 + CRUD | UI 관계 | 공유 |

**추천 A2.1 (jsonl)** — vibe-flow 일관 (events.jsonl 패턴). A2.2/A2.3는 외부 의존.

### A3. 큐 진입 트리거

| 옵션 | 동작 |
|------|------|
| **A3.1 cron firing 시 큐 첫 task 처리, 1 cycle 후 종료** | 보수적 — 사용자 review 후 다음 firing |
| A3.2 큐 비기 전까지 연쇄 처리 | 적극적 — 1 firing이 N cycle |
| A3.3 A1+A2 혼합 (max N cycle/firing) | 절충 |

**추천 A3.3 (절충, N=3)** — 1 firing이 큐의 3 task까지 연쇄. 토큰 비용 cap 가능. cycle 간 abort 시 즉시 종료.

### A4. 결과 누적

| 옵션 | 위치 |
|------|------|
| **A4.1 기존 `.claude/memory/auto-build-runs.jsonl` 확장 + 큐 metadata 추가** | source repo (이미 사용 중) |
| A4.2 dashboard `/morning` 페이지 신규 (v2 brainstorm Phase 3) | dashboard 짝 |
| A4.3 별 `/digest` 슬래시 스킬 | 명시적 view |

**추천 A4.1 + A4.2 분리** — A4.1 (data) 본 Phase 3 scope, A4.2 (dashboard view) 별 PR. /digest는 후속.

## 추천 + 근거

**추천: A1.2 + A2.1 + A3.3 + A4.1 통합**

### 핵심 설계

1. **새 슬래시 스킬 `/auto-build queue`**: `add <task>` / `list` / `remove <id>` / `clear` 명령. jsonl 영속.
2. **새 명령 `/auto-build run-queue`**: 큐 첫 task pop + `/auto-build "<task>"` 트리거. max 3 cycle (절충 A3.3).
3. **cron 등록**: Claude Code `schedule` 스킬로 cron expression 등록 — `/auto-build run-queue` 호출. 사용자 schedule 시점 선택 (anytime 도구 원칙).
4. **safety**: 기존 hooks(token/file/iter cap) 모두 활성. 큐 metadata에 priority/depends_on 추가.
5. **결과**: 사이클별 jsonl 라인에 `queue_position`, `cycle_in_firing` 추가. 후속 dashboard 통합.

### 근거

- **외부 의존 0**: A1.2(schedule)와 A4.1(기존 jsonl)이 vibe-flow self-contained 원칙 충족
- **anytime 원칙 충족**: schedule 스킬이 사용자 직접 cron expression 설정 — 야간 한정 X
- **scope brief**: 신규 슬래시 스킬 1 + 기존 orchestrator 확장 + jsonl schema 확장. 8-12 파일 추정 (brief)
- **calibration 보존**: 큐 metadata가 cycle별 token/iter/vote 누적 가능

### 기각 alternative

- **A1.1 (macOS launchd)**: multi-machine 사용자 setup 필요 + Claude Code 외부 spawn 보안 우려
- **A1.3 (GitHub Actions)**: 외부 의존 + secret 관리 복잡
- **A2.2/A2.3**: 외부 의존 (issue/Supabase)
- **A3.1 (1 firing 1 cycle)**: 보수적이나 task 많을 때 운영 비효율
- **A3.2 (큐 비기 전까지)**: 토큰 비용 제어 어려움

## 다음 단계

**hard_gate: brief** — 영향 파일 추정 8-12개:
- `core/skills/auto-build/SKILL.md` (queue / run-queue 명령 추가)
- `core/skills/auto-build/orchestrator.md` (run-queue 분기 + cycle 간 cap 명시)
- `core/skills/auto-build/scripts/queue.sh` (신규 — add/list/remove/clear)
- `core/skills/auto-build/scripts/run-log.sh` (queue metadata 키 추가)
- `core/hooks/auto-build-safety.sh` (firing 누적 cycle cap 추가)
- evals.json (queue 1-2 케이스)
- docs/superpowers/auto-build-queue.md (사용자 가이드)
- tests/auto-build-queue.test.sh (smoke)

**Phase 3.0 → 3.1 분할 권장**:
- **Phase 3.0** (본 brainstorm) — 큐 + run-queue 기본 (사용자 manual `/auto-build run-queue` 호출 가능)
- **Phase 3.1** — Claude Code schedule 스킬 통합 (cron 자동 firing). 별 brainstorm 후 진입.

이유: schedule 통합은 Claude Code 내부 cron 메커니즘 의존 — 사전에 schedule 스킬 동작 검증 필요. 큐 기능 자체는 schedule 없이도 가치 (manual run-queue).

### 후속 분기 (PR 시퀀스 권장)

1. **PR-A**: `/auto-build queue <add|list|remove|clear>` 슬래시 스킬 (queue.sh + SKILL.md)
2. **PR-B**: `/auto-build run-queue` 명령 (orchestrator + safety hook 확장)
3. **PR-C**: schedule 스킬 통합 (Phase 3.1)
4. **PR-D** (별 cycle): dashboard `/morning` 페이지 — A4.2

각 PR brief grade, 자율 사이클로 dogfooding 가능 (각 PR 자체가 inline/brief task).

### 검증 (Phase 3.0 완료 기준)

- `/auto-build queue add "<task>"` 1회 → `.claude/memory/auto-build-queue.jsonl`에 라인 append
- `/auto-build queue list` → 라인 표시
- `/auto-build run-queue` → 큐 첫 task pop + 자율 사이클 1회 진행 + PR 생성
- 사이클 종료 후 queue jsonl에서 처리 완료 표시 (status: done)

## 리스크

- **R1 cron firing 시 사용자 부재 abort 추적 부담**: cycle 5건 연속 abort 시 retrospective 자동 알림 (Phase 2 safety hook 정책 활용)
- **R2 token 비용 폭증**: cycle 간 token cap 100k(예) — 총 일일 비용 cap. Phase 3.1에서 cron 자동 firing 도입 시 더 엄격 cap 필요
- **R3 multi-repo task 큐 표현**: 짝 cycle을 큐에서 어떻게 명시? `depends_on: <prev_run_id>` 키로 표현 가능 (cycle 7이 cycle 6 PR 머지 대기). cron firing 시 PR merged 상태 polling 필요 — 후속 Phase
- **R4 schedule 스킬 미지원 시 Phase 3.1 abort**: schedule 스킬 동작 검증 후 Phase 3.1 진입. Phase 3.0 자체는 schedule 없이 가치
- **R5 vote calibration 부족**: 큐 진입한 task가 vote 발화 시 confidence 임계값 0.5/일치율 70%는 1 sample 기반. cron firing 자동화 전 sample 더 회수

## 결정 점

다음 maker decision (review 항목):

- [ ] A1.2 (Claude Code schedule) vs A1.1 (macOS launchd) — 외부 의존 vs 사용자 통제
- [ ] A3.3 cycle/firing cap N=3 적정?
- [ ] Phase 3.0 / 3.1 분할 vs 한 phase로 통합
- [ ] PR-D (dashboard /morning) scope 본 Phase 또는 별
