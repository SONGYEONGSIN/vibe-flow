---
plan_id: 20260512-213500-auto-build-run-queue-pr-b
status: completed
created: 2026-05-12T12:35:00Z
hard_gate: brief
source: brainstorm:.claude/memory/brainstorms/20260512-213341-auto-build-run-queue-pr-b.md
---

# Plan: /auto-build run-queue wrapper (Phase 3.0 PR-B)

## 단계

### T1 — queue.sh `next` sub-command + smoke Test 6 (RED→GREEN)
- 상태: pending
- 산출물:
  - queue.sh: `next` sub-command — `status=queued` 첫 entry id stdout + `status_update running` 라인 append + lockdir 보호
  - queue-tests.sh Test 6: add 2 → next 1 → 첫 entry running + 라인 추가 확인
- DoD:
  - RED: next 미구현
  - GREEN: `queue.sh next` → id 출력 + jsonl에 running 라인 1줄 append + smoke PASS
  - 빈 queue에서 next → empty stdout + exit 0

### T2 — queue.sh `status-update` helper + run-queue.sh DRYRUN 기본 흐름 + Test 7 (RED→GREEN)
- 상태: pending
- 산출물:
  - queue.sh: `status-update <id> <new_status>` helper sub-command — 단일 status_update 라인 append (run-queue가 직접 호출)
  - run-queue.sh 신규: DRYRUN 분기 + queue.sh next로 1 entry pop + DRYRUN echo → status-update done
  - queue-tests.sh Test 7: add 1 → run-queue.sh DRYRUN=1 → list --all에서 done 표시
- DoD:
  - RED: run-queue.sh / status-update 미구현
  - GREEN: 1 entry 처리 후 done 마킹 + smoke PASS

### T3 — max cycle cap + abort 즉시 종료 + Test 8/9 (RED→GREEN)
- 상태: pending
- 산출물:
  - run-queue.sh: `AUTO_BUILD_QUEUE_MAX_CYCLES` env 처리 (기본 3) + while loop COUNT
  - run-queue.sh: `AUTO_BUILD_QUEUE_DRYRUN_FAIL=1` 시 status-update aborted + break
  - queue-tests.sh Test 8: add 4 → run-queue MAX=3 → 3 done + 1 queued 잔존
  - queue-tests.sh Test 9: add 2 → DRYRUN_FAIL=1로 첫 cycle abort → 종료, 2번째 queued 잔존
- DoD:
  - RED: cap / abort 로직 미구현
  - GREEN: 두 케이스 모두 PASS

### T4 — SKILL.md run-queue 섹션 + evals.json 2 케이스
- 상태: pending
- 산출물:
  - SKILL.md "Queue 관리" 섹션에 run-queue 부분 추가 (호출 형태 + env table + 예시)
  - evals.json: queue-next-running / run-queue-dryrun-done 2 케이스
- DoD:
  - SKILL.md grep "run-queue" hit + DRYRUN 예시 1
  - evals.json valid JSON + cases.length == 18

## 검증 (P4)

```bash
bash -n core/skills/auto-build/scripts/queue.sh
bash -n core/skills/auto-build/scripts/run-queue.sh
bash scripts/tests/queue-tests.sh         # Test 1-5 회귀 0 + Test 6-9 신규 PASS
bash scripts/eval-regression-check.sh     # 18 cases (16+2) valid
```

## 종료 기준 (P5)

- 7 파일 commit (queue.sh, run-queue.sh, queue-tests.sh, SKILL.md, evals.json, brainstorm, plan)
- branch `feat/sleep-20260512T123341Z-vibe-flow-auto-build-run-queue`
- PR title: `feat(auto-build): run-queue wrapper (Phase 3.0 PR-B)`
- PR body: Summary + Test plan + DRYRUN 격리 정책 명시
