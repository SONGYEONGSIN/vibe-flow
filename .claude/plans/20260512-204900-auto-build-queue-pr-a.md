---
plan_id: 20260512-204900-auto-build-queue-pr-a
status: completed
created: 2026-05-12T11:49:00Z
hard_gate: brief
source: brainstorm:.claude/memory/brainstorms/20260512-204738-vibe-flow-auto-build-queue-add.md
---

# Plan: /auto-build queue 슬래시 스킬 (Phase 3.0 PR-A)

## 단계

### T1 — queue.sh add 명령 + smoke test add 케이스 (RED→GREEN)
- 상태: pending
- 산출물:
  - `core/skills/auto-build/scripts/queue.sh` 신규 — `add` sub-command 골격 + `case` 분기 4 명령
  - 영속 store helper: NFC 정규화 (perl 또는 python3), id 생성 (timestamp + 4hex), jsonl append (flock/mkdir-lock fallback)
  - `scripts/tests/queue-tests.sh` 신규 — test_add 케이스
- DoD:
  - RED: smoke test 실행 → add 미구현으로 FAIL
  - GREEN: `bash core/skills/auto-build/scripts/queue.sh add "<task>"` 1회 → `.claude/memory/auto-build-queue.jsonl`에 1 라인 append + `jq -e 'has("id") and has("task") and has("created_ts") and .status == "queued"'` PASS

### T2 — queue.sh list + fold 로직 + smoke test list 케이스 (RED→GREEN)
- 상태: pending
- 산출물:
  - `queue.sh` `list` sub-command — entry별 최신 status fold (status_update 라인 반영)
  - `queue-tests.sh` test_list 케이스 추가
- DoD:
  - RED: list 미구현
  - GREEN: `queue.sh list` → tab-separated `id | status | created_ts | task(80자 truncate)` 출력 + test_list PASS

### T3 — queue.sh remove + clear + smoke 2 케이스 (RED→GREEN)
- 상태: pending
- 산출물:
  - `queue.sh` `remove <id>` sub-command — `{op:"status_update", id, new_status:"aborted", ts}` 라인 append
  - `queue.sh` `clear` sub-command — 모든 `queued` entry에 대해 status_update aborted 일괄 append
  - `queue-tests.sh` test_remove + test_clear 케이스
- DoD:
  - RED: remove/clear 미구현
  - GREEN: 두 명령 후 list가 aborted 반영 + smoke 2 케이스 PASS

### T4 — SKILL.md + evals.json + .gitignore 통합
- 상태: pending
- 산출물:
  - `core/skills/auto-build/SKILL.md` "Queue 관리" 섹션 추가 (호출 형태 + 4 명령 + 예시)
  - evals 경로 확정 후 queue add / queue list 케이스 추가 (2개)
  - `.gitignore`에 `.claude/memory/auto-build-queue.jsonl` 패턴 추가
- DoD:
  - SKILL.md grep "queue" hit + 예시 1개 이상
  - eval-regression-check.sh PASS

## 검증 (P4)

```bash
bash -n core/skills/auto-build/scripts/queue.sh         # syntax
bash scripts/tests/queue-tests.sh                       # 4 케이스 PASS
bash scripts/eval-regression-check.sh                   # CI 회귀 0
```

## 종료 기준 (P5)

- queue.sh + tests + SKILL.md + evals + .gitignore 모두 커밋
- branch: `feat/sleep-20260512T114728Z-vibe-flow-auto-build-queue-add`
- PR title: `feat(auto-build): queue 슬래시 스킬 (Phase 3.0 PR-A)`
- PR body: Summary + Test plan + Phase 3 brainstorm 링크
