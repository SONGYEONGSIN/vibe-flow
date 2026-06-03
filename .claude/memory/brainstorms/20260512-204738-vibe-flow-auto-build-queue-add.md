# Brainstorm: /auto-build queue 슬래시 스킬 (Phase 3.0 PR-A)

작성: 2026-05-12T20:47:38Z (filename에서 추출, retroactive F-A4 fix)

출발점: `.claude/memory/brainstorms/20260512-202958-vibe-flow-phase3-cron-scheduler.md` 추천 A2.1 (jsonl) + PR-A scope 정의 (line 117).

## 의도

**무엇을**: `/auto-build` 스킬에 `queue <add|list|remove|clear>` sub-command 추가.
- `core/skills/auto-build/scripts/queue.sh` 신규 — bash CLI, 4 명령 분기
- 영속 store: `.claude/memory/auto-build-queue.jsonl` (append-only)
- entry payload: `{id, task, created_ts, status, depends_on?}`
  - `id`: ULID-like (timestamp + 4hex)
  - `task`: 자율 사이클에 전달할 4문항 task description
  - `created_ts`: ISO 8601 UTC
  - `status`: `queued | done | aborted`
  - `depends_on`: 선택 (prev entry `id`, 짝 cycle 의존성 표현)
- `core/skills/auto-build/SKILL.md`에 "Queue 관리" 섹션 추가 (호출 형태 + 예시)

**누가**: maker 본인 — vibe-flow Phase 3.0 자율 구현 (Phase 3 brainstorm PR #60의 PR-A).

**왜 지금**: Phase 3 brainstorm 4 결정 채택 후 후속 PR 시퀀스 첫 항목. session-less 자율의 큐 기반 인프라 우선 구축. PR-A는 큐 기능만 — run-queue는 PR-B로 분리되어 scope brief 유지.

**성공**:
1. `queue.sh add "<task>"` 1회 → `.claude/memory/auto-build-queue.jsonl`에 라인 1개 append
2. 해당 라인 `jq empty` 통과 (valid JSON)
3. `queue.sh list` → entry table (id/status/created_ts) 출력
4. `queue.sh remove <id>` → 해당 entry `status=aborted`로 마킹 (실제 삭제 X, append-only 원칙 유지)
5. `queue.sh clear` → 모든 `queued` entry `status=aborted`로 마킹
6. `bash -n core/skills/auto-build/scripts/queue.sh` PASS (syntax)
7. 신규 `scripts/tests/queue-tests.sh` 4 케이스 (add/list/remove/clear) ALL PASS
8. 기존 `bash scripts/eval-regression-check.sh` CI PASS (auto-build evals 회귀 0)

## 제약

- **append-only**: jsonl 라인 수정/삭제 금지. 상태 변경은 항상 신규 `status_update` 라인 append. `list`는 entry별 최신 status 라인을 fold하여 표시.
- **id 충돌 회피**: `created_ts`(초 단위) + `openssl rand -hex 2` 조합. 동일 초 발생 시 hex로 구분.
- **자율 사이클과 분리**: queue.sh는 큐 store CRUD만. run-queue (실제 사이클 trigger)는 PR-B scope. PR-A에선 manual `/auto-build "<큐 entry task>"` 호출만 가능.
- **NFC + 80자 truncate**: task 본문이 한글 포함 가능 → events.jsonl 패턴 일관 적용 (commit_pushed hook 참조).
- **race condition**: bash flock 사용 — multi-process 동시 add 시 jsonl 손상 방지. macOS는 `flock` 미기본 — `mkdir lockdir` 패턴 fallback.
- **scope brief 유지**: ~5 파일 (queue.sh, SKILL.md, tests, evals.json, smoke). orchestrator 변경 X (PR-B scope).

## 대안 비교

### A1. 영속 store 형식

| 옵션 | 표현 | append-only | jq 친화 |
|------|------|-------------|---------|
| **A1.1 jsonl (1 라인 1 entry)** | flat | ✓ | ✓ |
| A1.2 단일 json 배열 | nested | ✗ (재작성 필요) | ✓ |
| A1.3 SQLite | row | ✓ | △ (.dump 필요) |

**추천 A1.1** — Phase 3 brainstorm A2.1 추천 일관, events.jsonl/auto-build-runs.jsonl 동일 패턴, append-only 자연 충족.

### A2. 상태 변경 표현

| 옵션 | 의미 |
|------|------|
| **A2.1 신규 라인 append (event-sourcing)** | `{id, op: "status_update", new_status, ts}` 라인 추가. list 시 fold |
| A2.2 entry 라인 in-place 재작성 | append-only 위반 |
| A2.3 별 status jsonl 분리 | 2개 파일 동기화 부담 |

**추천 A2.1** — append-only 원칙 충족, replay/audit 가능, events.jsonl 패턴 일관.

### A3. id 생성 방식

| 옵션 | 충돌 | 정렬 |
|------|------|------|
| **A3.1 timestamp + 4hex (`20260512T204738Z-a1b2`)** | 거의 0 | 시간순 ✓ |
| A3.2 uuid v4 | 0 | 정렬 X |
| A3.3 increment counter | 0 (단일 머신) | ✓ |

**추천 A3.1** — auto-build run_id 동일 패턴, 시간 정렬 자연.

## 추천 + 근거

**추천: A1.1 + A2.1 + A3.1 통합**

queue.sh 4 sub-command 구조:

```bash
queue.sh add "<task>"        # 신규 entry append (status: queued)
queue.sh list [--all]        # status=queued entry 표 (--all로 done/aborted 포함)
queue.sh remove <id>         # status_update queued → aborted
queue.sh clear               # 모든 queued → aborted (bulk)
```

**근거**:
- Phase 3 brainstorm A2.1 추천 일관 (jsonl, depends_on key)
- append-only event-sourcing이 audit/replay 자연
- vibe-flow 기존 jsonl 패턴 (events / auto-build-runs / brainstorm metadata) 일관
- bash CLI는 외부 의존 0, smoke test/eval 쉬움
- scope brief: ~5 파일

**기각 alternative**:
- A1.2 (단일 json 배열): append-only 위반, race condition 위험
- A1.3 (SQLite): 외부 dep + jq 친화도 ↓
- A2.2 (in-place): append-only 위반
- A3.2/A3.3: 정렬/충돌 trade-off가 A3.1보다 열위

## 다음 단계

`hard_gate: brief` — 영향 파일 추정 5~6개:

| 파일 | 변경 |
|------|------|
| `core/skills/auto-build/scripts/queue.sh` | **신규** — bash CLI 4 sub-command + flock + NFC + 80자 truncate |
| `core/skills/auto-build/SKILL.md` | "Queue 관리" 섹션 추가 (호출 형태 + 4 명령 + 예시) |
| `scripts/tests/queue-tests.sh` | **신규** — 4 케이스 smoke (add/list/remove/clear) + jq empty 검증 |
| `evals/auto-build.json` (또는 evals.json) | queue add / list 케이스 추가 (2개) |
| `.gitignore` | `.claude/memory/auto-build-queue.jsonl` 패턴 추가 (런타임 생성) |
| `setup.sh` (선택) | `SELF_INSTALL_PATTERNS`에 queue.jsonl 추가 (자동 .gitignore) |

### 검증 (P4)

```bash
bash -n core/skills/auto-build/scripts/queue.sh                # syntax
bash scripts/tests/queue-tests.sh                              # 4 케이스 PASS
bash scripts/eval-regression-check.sh                          # CI 회귀 0
```

### Plan steps (P2 brief grade로 진입)

- T1: queue.sh 신규 (add 명령) + smoke test add 케이스 — RED → GREEN
- T2: queue.sh list 명령 + fold 로직 + smoke test list 케이스 — RED → GREEN
- T3: queue.sh remove + clear 명령 + smoke test 2 케이스 — RED → GREEN
- T4: SKILL.md "Queue 관리" 섹션 + evals.json 케이스 + .gitignore 패턴

## 리스크

- **R1 flock macOS 미지원**: mkdir lockdir 패턴 fallback (이미 P2/T1에서 처리). 검증 OS = macOS Darwin 25.3.0
- **R2 NFC 정규화 누락**: events.jsonl/git-post-commit.sh 패턴 그대로 차용 — `python3 -c "import unicodedata,sys; print(unicodedata.normalize('NFC', sys.argv[1]))"` 또는 perl 동일 (이미 hooks/git-post-commit.sh 패턴 검증됨)
- **R3 task 본문 80자 초과**: subject만 80자 truncate, body는 별 키 (commit_pushed 패턴). 단 queue task는 4문항 포맷 전체라 길이 ~500자 — 본 PR-A에선 80자 truncate 안 함 (4문항 전체 보존). 80자 제약은 commit_pushed 한정.
- **R4 PR-B run-queue와 schema 부정합**: PR-A에서 status enum 확정 (`queued|done|aborted`) — PR-B run-queue 시 추가 status (예: `running`) 필요 시 schema 확장. PR-A schema는 PR-B 진입 시 review.
