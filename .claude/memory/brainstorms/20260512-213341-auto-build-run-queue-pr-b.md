# Brainstorm: /auto-build run-queue wrapper (Phase 3.0 PR-B)

작성: 2026-05-12T21:33:41Z (filename에서 추출, retroactive F-A4 fix)

출발점: `.claude/memory/brainstorms/20260512-202958-vibe-flow-phase3-cron-scheduler.md` PR-B scope + PR-A merged 후 schema 확정 (`{id, task, created_ts, status, depends_on?}`).

## 의도

**무엇을**:
1. queue.sh에 `next` sub-command 추가 — `status=queued` 첫 entry의 id 출력 + `status_update running` 라인 append (pop + 잠금).
2. 신규 wrapper `core/skills/auto-build/scripts/run-queue.sh` — queue.sh next로 entry pop → /auto-build trigger (DRYRUN 모드 또는 실제) → 완료 시 `status_update done` (성공) 또는 `status_update aborted` (실패) 라인 append.
3. `AUTO_BUILD_QUEUE_MAX_CYCLES` env (기본 3) — 1 firing당 max cycle cap. 도달 시 종료.
4. cycle 간 abort 발생 시 즉시 종료 (다음 entry 진입 X).
5. `AUTO_BUILD_QUEUE_DRYRUN=1` 일 때 실제 /auto-build 호출 X, echo만 (smoke test 안전 격리).
6. SKILL.md "Queue 관리" 섹션에 run-queue 부분 추가.

**누가**: maker 본인 — Phase 3 brainstorm PR-B. PR-A (PR #61, merged f38d299) 후속.

**왜 지금**: schedule(PR-C, Phase 3.1) 진입 전 manual run-queue 동작 검증 필요. PR-A 머지 직후 schema 확정 상태가 wrapper 구축에 안전한 시점.

**성공**:
- smoke 4 케이스 PASS:
  - (a) `queue.sh next`: queued entry id stdout + `status_update running` 라인 append + 없으면 empty stdout + exit 0
  - (b) `run-queue.sh` DRYRUN=1: 1 entry add 후 1 cycle 실행 → `status_update done` 라인 append + `list --all`에서 done 표시
  - (c) max 3 cycle cap: 4 entry add 후 run-queue → 3 cycle만 진행, 1 entry queued 잔존
  - (d) cycle 간 abort: dryrun에서 의도적 fail (`AUTO_BUILD_QUEUE_DRYRUN_FAIL=1` env) 주입 시 즉시 종료, 다음 entry queued 잔존
- `bash -n core/skills/auto-build/scripts/run-queue.sh` PASS
- `bash scripts/tests/queue-tests.sh` Test 1-5 회귀 0 + Test 6-9 신규 PASS
- `bash scripts/eval-regression-check.sh` PASS

## 제약

- **재귀 회피**: run-queue.sh가 실제 `/auto-build`를 trigger하는 것은 본 PR 범위 외 — DRYRUN=1 모드로만 검증. 실 trigger는 Phase 3.1 schedule 통합 시 사용자 manual 호출로만.
- **append-only schema 일관**: PR-A의 `{op:"status_update", id, new_status, ts}` 라인 패턴 동일 사용. 신규 status는 `running`/`done`/`aborted` 3개만.
- **scope brief**: 신규 wrapper 1 + queue.sh 확장 + 신규 smoke 4 + SKILL.md 섹션 추가 = ~5 파일 (brief grade).
- **PR-A status enum 호환**: queued|done|aborted에 running 추가 → 4 enum. PR-A의 list fold 로직 영향 없음 (else . skip이 forward-compat 보장).
- **취소 정책**: `running` 상태 entry는 list 기본에서 숨김 (queued만 표시). `--all`로 확인 가능.
- **순환 의존 회피**: queue.sh가 run-queue.sh 호출 X. run-queue.sh만 queue.sh 호출.

## 대안 비교

### A1. next 명령 동작

| 옵션 | pop 시점 | 재진입 안전 |
|------|---------|------------|
| **A1.1 next 호출 시 즉시 running 마킹 (atomic pop)** | next 시점 | ✓ — 다음 next는 다른 entry 반환 |
| A1.2 next는 id만 반환, running 마킹은 run-queue.sh가 별도 | run-queue.sh 시점 | △ — race 가능 |
| A1.3 별 lock 메커니즘 도입 | next + lock | 복잡도↑ |

**추천 A1.1** — atomicity 자연, lockdir 활용해 multi-process 안전.

### A2. run-queue 실패 정책

| 옵션 | abort 시점 | 동작 |
|------|-----------|------|
| **A2.1 cycle 간 abort 시 즉시 종료** | abort 발생 직후 | 사용자 review 신호 명확 |
| A2.2 abort 후 다음 entry 진행 | 모든 entry 또는 cap 도달 | 자동 복구 시도 — 단 비효율 |
| A2.3 abort 후 N회 재시도 | 동일 entry 재시도 | 동일 task 반복 — 누적 비용 |

**추천 A2.1** — Phase 3 brainstorm 명시. abort 신호는 maker review 가치 큼.

### A3. DRYRUN 모드 표현

| 옵션 | smoke 적용 |
|------|-----------|
| **A3.1 env `AUTO_BUILD_QUEUE_DRYRUN=1` 시 echo만** | 안전 격리, 실 사이클 영향 0 |
| A3.2 별 wrapper `run-queue-dryrun.sh` | 코드 중복 |
| A3.3 CLI flag `--dryrun` | env 일관성 ↓ (다른 env 패턴과 불일치) |

**추천 A3.1** — vibe-flow의 다른 env(`AUTO_BUILD_MODE`, `QUEUE_STORE`)와 일관.

## 추천 + 근거

**추천: A1.1 + A2.1 + A3.1 통합**

### run-queue.sh 구조

```bash
# pseudo
MAX=$AUTO_BUILD_QUEUE_MAX_CYCLES  # default 3
COUNT=0
while [ $COUNT -lt $MAX ]; do
  ID=$(bash queue.sh next)  # running 마킹 + id 반환
  [ -z "$ID" ] && break      # 큐 비어 있음
  TASK=$(jq ... QUEUE_STORE)  # entry의 task 본문 lookup

  # /auto-build trigger
  if [ "$AUTO_BUILD_QUEUE_DRYRUN" = "1" ]; then
    if [ "$AUTO_BUILD_QUEUE_DRYRUN_FAIL" = "1" ]; then
      RESULT=aborted
    else
      RESULT=done
    fi
  else
    # 실 trigger — Phase 3.1에서 schedule 호출 시 활성
    # 본 PR-B에선 echo만 (실 사용은 schedule + cron)
    RESULT=done  # placeholder
  fi

  bash queue.sh status-update "$ID" "$RESULT"  # 또는 직접 jsonl append

  # abort 시 즉시 종료
  [ "$RESULT" = "aborted" ] && break

  COUNT=$((COUNT+1))
done
```

### 근거

- **PR-A schema 호환**: running enum 추가만, list fold/status_update 라인 패턴 동일
- **재귀 회피**: DRYRUN으로 안전. 실 trigger는 Phase 3.1 schedule scope
- **scope brief**: ~5-6 파일
- **append-only 보존**: 모든 상태 변경은 jsonl 라인 추가

### 기각 alternative

- **A1.2 (id만 반환)**: race condition 가능. atomicity 손실
- **A1.3 (별 lock)**: queue.sh의 lockdir로 충분
- **A2.2 (자동 복구)**: 토큰 비용 + 의도 불명확
- **A2.3 (재시도)**: 동일 task 반복 — 누적 비용

## 다음 단계

`hard_gate: brief` — 영향 파일 추정 5~6개:

| 파일 | 변경 |
|------|------|
| `core/skills/auto-build/scripts/queue.sh` | `next` sub-command 추가 (~25 lines) + `status-update` helper sub-command (~10 lines, run-queue가 직접 호출용) |
| `core/skills/auto-build/scripts/run-queue.sh` | **신규** — 위 pseudo 구현 (~60 lines) |
| `scripts/tests/queue-tests.sh` | Test 6 (next) + Test 7 (run-queue dryrun done) + Test 8 (max cycle cap) + Test 9 (abort 즉시 종료) |
| `core/skills/auto-build/SKILL.md` | "Queue 관리" 섹션에 run-queue 부분 + DRYRUN 예시 + env table |
| `core/skills/auto-build/evals/evals.json` | queue-next / run-queue-dryrun 케이스 2 추가 |

### Plan steps (P2 brief grade로 진입)

- T1: queue.sh `next` sub-command + smoke Test 6 — RED → GREEN
- T2: queue.sh `status-update` helper sub-command + run-queue.sh DRYRUN 기본 흐름 + Test 7 — RED → GREEN
- T3: max cycle cap (MAX env) + abort 즉시 종료 + Test 8/9 — RED → GREEN
- T4: SKILL.md 섹션 추가 + evals.json 2 케이스

### 검증 (P4)

```bash
bash -n core/skills/auto-build/scripts/queue.sh
bash -n core/skills/auto-build/scripts/run-queue.sh
bash scripts/tests/queue-tests.sh        # Test 1-9 (기존 5 + 신규 4) ALL PASS
bash scripts/eval-regression-check.sh    # 16+2=18 cases JSON valid
```

## 리스크

- **R1 next 명령 race condition**: queue.sh lock이 atomicity 보장. lockdir + PID stale 검사 (PR-A의 fix 활용)
- **R2 DRYRUN env 누락 시 실 /auto-build 호출**: smoke test가 `unset AUTO_BUILD_QUEUE_DRYRUN` 시 실 trigger 발동 위험. 본 PR-B의 run-queue.sh는 **DRYRUN=1 미설정 시 echo only + warning**으로 처리 (실 trigger는 Phase 3.1에서 추가). 사용자 실수 시 무한 재귀 방지가 우선.
- **R3 running 상태 잔존**: cycle 도중 SIGKILL 시 entry가 running으로 영구 고착. 회수 메커니즘은 본 PR-B 범위 외 — `queue.sh remove <id>` 수동 회수 (`SKILL.md`에 명시). Phase 3.1에 자동 회수 timer 추가.
- **R4 max_cycles 0 또는 음수 입력**: env 검증 — 음수/0이면 기본 3으로 fallback (Karpathy Simplicity First — 사용자가 의도적으로 1 firing 비활성 원하면 schedule 자체를 끄는 게 맞음).
