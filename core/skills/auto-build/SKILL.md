---
name: auto-build
description: multi-iteration Ralph loop + persona vote 자율 사이클 — 사용자가 다른 작업 하는 동안 brainstorm → plan → 구현(TDD + ambiguity 시 24 agent 자동 vote) → /verify → /commit → /finish 까지 완주. branch 격리 + destructive op 차단 + token/file/iter cap으로 안전 보장. 사용법 /auto-build "<task description>"
effort: large
---

vibe-flow v2의 자율 워크플로우 — Phase 2 (Ralph loop + persona voting). 사용자는 task 1개를 명시하고 사이클 종료 후 working PR(또는 명시적 abort + 부분 진행 보존 branch)을 review 한다. 시간대 무관 — 점심시간/저녁/주말/잠자기 전 등 사용자가 다른 작업 하는 동안 자율 진행.

## 사용 시점

**필수**:
- task가 사이클(brainstorm → plan → 구현 → PR)로 닫힐 만큼 명확 (Ralph wrapper가 N iter PR 분할 처리)
- 사용자 추가 의사결정 없이 진행 가능한 명시 task (ambiguity는 24 agent persona vote가 자동 결정)

**스킵 (수동 사이클 권장)**:
- 모호한 의도 (vote 카테고리 매핑조차 안 되는 본질 결정)
- stacked PR / multi-repo 동시 변경 (Ralph wrapper가 단일 repo 가정)

> **Phase 2 변경**: "디자인 결정 포함" / "HARD-GATE 전체 등급" 스킵 조건 제거 — vote가 디자인 결정 자동 처리, Ralph wrapper가 file_cap 75% 도달 시 PR 분할 후 다음 iter 진입.

## 비교 — 4 자율 워크플로우

vibe-flow 환경에서 사용 가능한 자율 진행 방식 4종. 상황별 매칭:

| 방식 | 다음 턴 시작 조건 | 종료 조건 | 적용 케이스 |
|------|------|------|------|
| `/auto-build` (vibe-flow) | P1~P5 sequential 완주 | TDD + `/verify` 통과 후 commit/PR | full cycle (branch 격리 + persona vote + TDD discipline 필요) |
| `/goal <condition>` (Claude Code v2.1.139+) | 이전 턴 종료 | 평가자(기본 Haiku)가 condition 충족 판정 | 단순 1-shot 완수 조건 ("all tests pass", "lint clean") |
| `/loop [interval] <cmd>` (Claude Code built-in) | 시간 간격 경과 | 사용자 중지 or 모델 종료 판단 | 정기 polling (PR 머지 대기, deploy 상태 watch) |
| Phase 3 cron schedule | 사전 정의된 시각 | trigger 1회 후 종료 | 세션 독립 정기 실행 (야간 dogfooding, 매일 아침 triage) |

**선택 가이드**:
- TDD/branch 격리/persona vote가 필요한 full cycle인가? → `/auto-build`
- 평가 가능한 단일 condition으로 묶이는 작업인가? → `/goal`
- 시간 기반 반복인가? → `/loop` (세션 내) 또는 cron schedule (세션 독립)
- `/goal`은 평가자가 대화에 surface된 것만 판단 — 검증 출력을 conversation에 명시적으로 띄워야 함. 조건 최대 4,000자, session 1개 goal 한계
- `/auto-build` 내부 verify 단계에 `/goal` 채택은 ROI 낮음 (P1→P5 명시 흐름이 단일 condition으로 표현 어려움)

> `/goal` 공식 문서: https://code.claude.com/docs/en/goal

## 안전 계약

`/auto-build`는 자율 모드 진입 시 다음을 **반드시** 준수한다:

1. **branch 자동 격리** — `feat/sleep-<timestamp>-<slug>` 신규 branch 생성 후 main 직접 수정 0. Ralph wrapper iter+1 시 새 branch base = 직전 iter tip (R3 stacked PR 사고 회피).
2. **destructive op 차단** — `core/hooks/auto-build-safety.sh` PreToolUse hook이 `AUTO_BUILD_MODE=1` 감지 시 활성. 차단 패턴: `rm -rf`, `git reset --hard`, `git push --force`, `--no-verify`, `chmod 777`, fork bomb 등
3. **token cap** — 사이클당 누적 token이 `AUTO_BUILD_TOKEN_CAP`(기본 200000) 초과 시 abort
4. **file count cap** — branch git diff 파일 수가 `AUTO_BUILD_FILE_CAP`(기본 19) 초과 시 abort. 단 Ralph wrapper가 75% 도달 시 P5 강제 push + 새 branch로 우회.
5. **max_iterations cap** — Ralph wrapper iter 카운트가 `AUTO_BUILD_MAX_ITERATIONS`(기본 30) 초과 시 abort `max_iterations_exceeded`
6. **실패 시 abort** — exit reason을 `.claude/memory/auto-build-runs.jsonl`에 명시 + branch 보존(폐기 X) → 사이클 종료 후 maker review

## 선행 조건 (P0가 자동 검증, 부재 시 즉시 abort)

- **배포 검증** (Phase 1.1, F1 완화):
  - `.claude/hooks/auto-build-safety.sh` 실행 권한 보유 — 미배포 시 abort `deployment_missing`
  - `.claude/skills/auto-build/scripts/run-log.sh` 실행 권한 보유
  - `.claude/skills/auto-build/orchestrator.md` 존재
- **검증 명세** (Phase 1.1, F5 완화):
  - `package.json`의 `scripts.test|build|lint|typecheck` 중 1개 이상 존재 (P4가 detect)
  - 또는 `/verify` 스킬 배포
  - 모두 부재 시 abort `verify_unspecified`
- **환경**:
  - 현재 working tree clean (커밋되지 않은 변경 없음)
  - `gh` 인증 완료 (PR 생성용)
  - `core/hooks/auto-build-safety.sh` 가 `settings.template.json`의 PreToolUse에 등록됨 (setup.sh 자동 처리)

## 절차 요약

자율 사이클은 다음 4-step으로 압축된다. 단계별 본체는 `core/skills/auto-build/orchestrator.md`에 정의됨 — 이 파일은 진입점만 다룬다.

1. **안전 계약 발효** — `AUTO_BUILD_MODE=1` export, branch 자동 생성, `run-log.sh start` 호출
2. **branch 격리** — `feat/sleep-<timestamp>-<slug>` checkout, working tree clean 확인
3. **orchestrator.md 시퀀스 진입** — P1(brainstorm) → P2(plan) → P3(TDD 구현) → P4(verify) → P5(commit + finish)
4. **종료 처리** — 성공/실패 무관 `run-log.sh done|abort` append, `AUTO_BUILD_MODE` unset, branch 보존

## 호출 형태

```bash
/auto-build "<task description>"
```

task description **4문항 필수** — orchestrator P1이 누락 시 즉시 abort `task_description_incomplete`:

- **무엇을**: 단일 산출물 명시
- **누가**: 사용자/대상 (예: maker 본인, 팀, 외부 사용자)
- **왜 지금**: task의 동기/맥락 (예: 회귀 fix, 성능 이슈, dogfooding calibration)
- **성공**: 검증 가능한 기준 (예: `npm test` 통과, PR 머지, 특정 metric)

### 예시

```
/auto-build "무엇을: extensions/X 디렉토리에 /Y-audit 스킬 추가 — OWASP 패턴 5개 검출 + audit 결과 jsonl 기록.
누가: maker 본인 — vibe-flow 보안 강화.
왜 지금: 최근 보안 리뷰에서 X 영역 검출 누락 발견.
성공: 5 OWASP 패턴 evals.json 케이스 추가 + bash scripts/eval-regression-check.sh PASS."
```

## 다음 스킬과의 연계

| 시점 | 스킬 |
|------|------|
| 사이클 시작 직전 | maker 본인 — task 명시화 + working tree clean |
| 사이클 진행 중 | `/brainstorm`, `/plan`, `/verify`, `/commit`, `/finish` (orchestrator가 자동 호출) |
| 사이클 종료 후 | maker 본인 — review (PR 머지 또는 abort branch 폐기) |
| 누적 데이터 분석 | `/telemetry` (auto_build_* 이벤트 추세), `/budget --tokens` (사이클당 비용) |

## 메시지 버스 알림 (선택적)

기본 정책: **알림 안 함** (자율 사이클 자체가 이미 jsonl 로그로 기록됨). 다음 좁은 케이스만:

| 조건 | 수신자 | type / priority |
|------|--------|----------------|
| safety hook이 destructive op 차단 발생 | `security` | warn / high |
| token cap 초과 abort | 사용자 | warn / high |
| 5회 연속 사이클 실패 (retrospective 자동 감지) | `retrospective` | regression / medium |

## 규칙

- **사용자 합의 없이 main에 직접 변경 금지** — 항상 신규 branch
- **safety hook 미등록 환경에서는 즉시 abort** — `AUTO_BUILD_MODE` 활성 전 hook 존재 확인
- **사이클 도중 maker 추가 입력 요청 금지** — 모호하면 abort 우선 (`brainstorm` 4문항 추가 질문 시도 = abort 신호)
- **branch 자동 폐기 금지** — 실패 사이클도 branch는 사이클 종료 후 review 자료
- **token cap / file cap 초과는 silent skip 금지** — 반드시 jsonl `exit_reason` 명시
- **Phase 2: vote가 ambiguity 결정 자동화** — 단, vote 카테고리 매핑조차 안 되는 본질 결정은 abort `vote_low_confidence`
- **Phase 3 진입 전** — 다중 task 큐, cron 스케줄, dashboard 통합은 Phase 3 (CronCreate 통합)에서 다룸

## Queue 관리 (Phase 3.0 PR-A)

`/auto-build`는 큐 기반 다중 task 진행을 위해 영속 store(`.claude/memory/auto-build-queue.jsonl`)에 task entry를 적재한다. PR-A: CRUD(add/list/remove/clear). PR-B: `next`/`status-update` + `run-queue.sh` wrapper. schedule(cron) 통합은 PR-C (Phase 3.1).

### 호출

```bash
# CRUD (PR-A)
bash core/skills/auto-build/scripts/queue.sh add "<4문항 포맷 task>" [depends_on_id]
bash core/skills/auto-build/scripts/queue.sh list [--all]
bash core/skills/auto-build/scripts/queue.sh remove <id>
bash core/skills/auto-build/scripts/queue.sh clear

# run-queue (PR-B)
bash core/skills/auto-build/scripts/queue.sh next                       # queued 첫 entry pop + running 마킹
bash core/skills/auto-build/scripts/queue.sh status-update <id> <status># status_update 라인 append (run-queue 전용)
bash core/skills/auto-build/scripts/run-queue.sh                        # max N cycle 연쇄 처리
```

### 동작

- **append-only**: entry 추가/상태 변경 모두 jsonl 라인 append. in-place 수정 0.
- **entry payload**: `{id, task, created_ts, status, depends_on?}`. `id`는 `<UTC ISO 8601 (no sep)>-<4hex>`. `status`는 `queued | running | done | aborted`.
- **상태 변경**: `remove`/`clear`/`run-queue` 종료 시 별 라인 `{op:"status_update", id, new_status, ts}` append. `list`는 entry별 최신 status fold하여 표시.
- **lock**: `mkdir lockdir` 원자성 활용 + lockdir/pid의 `kill -0` 검사로 stale 자동 회수 (SIGKILL/전원차단 후 lockdir 잔존 시 자동 해제).
- **depends_on**: 짝 cycle 의존성 표현 (Phase 3.1 schedule에서 활성). PR-A/B는 schema 필드만 보장.

### run-queue env (PR-B + PR-C1)

| env | 기본 | 동작 |
|-----|------|------|
| `AUTO_BUILD_QUEUE_MAX_CYCLES` | 3 | 1 firing당 max cycle cap. 양의 정수 아니면 fallback 3 |
| `AUTO_BUILD_QUEUE_DRYRUN` | 0 | 1 시 echo만 (실 `/auto-build` 호출 안 함, smoke 안전 격리) |
| `AUTO_BUILD_QUEUE_DRYRUN_FAIL` | 0 | DRYRUN 중 의도적 abort (smoke test용) |
| `AUTO_BUILD_QUEUE_MAX_FIRINGS_PER_DAY` | 2 | 1일(UTC) max firing cap. 도달 시 즉시 exit 0. 양의 정수 아니면 fallback 2 (PR-C1) |
| `AUTO_BUILD_QUEUE_CRON_FIRING` | 0 | 1 시 cron 컨텍스트 진입 신호 — orchestrator가 사용자 부재 가정 (PR-C1) |
| `QUEUE_STORE` | `.claude/memory/auto-build-queue.jsonl` | jsonl 경로 (테스트 fixture override) |
| `QUEUE_LOCK_DIR` | `.claude/.queue.lock` | lockdir 경로 |
| `FIRINGS_STORE` | `.claude/memory/auto-build-firings.jsonl` | firings 영속화. 당일(UTC) 라인 grep -c로 cap 카운트 (PR-C1) |

### 정책

- **cycle 간 abort 즉시 종료**: cycle N이 abort 시 cycle N+1 진입 X. maker review 신호 명확.
- **실 trigger는 Phase 3.1**: PR-B의 `run-queue.sh`는 DRYRUN=1 모드 권장. DRYRUN=0 + 실 trigger는 PR-C schedule 통합 후 활성.
- **running 잔존 회수**: cycle 도중 SIGKILL 시 entry가 running 고착. 수동 `queue.sh remove <id>` 또는 PR-C2 자동 회수.
- **firings cap (PR-C1)**: 1일 max firing 도달 시 즉시 exit 0 (cron 환경에서 token 비용 폭증 차단). cap은 UTC 기준 — 자정 reset.
- **CRON_FIRING 분기 (PR-C1)**: `AUTO_BUILD_QUEUE_CRON_FIRING=1` 시 orchestrator가 사용자 부재 가정 — vote confidence < 0.7 시 즉시 abort.

## Schedule 등록 (PR-C1.1 cloud-native)

cron-triggered cloud remote agent 자동 firing을 위한 helper. `RemoteTrigger` create API payload JSON 생성 → 사용자 manual paste 또는 `/schedule` 슬래시로 등록.

> **R4 발견 (PR #67 dogfooding)**: `schedule` 스킬 = Anthropic cloud remote agent (local cron 가정 무효). `bash run-queue.sh` 직접 호출 불가 — cloud agent가 git clone 후 `/auto-build run-cloud` 슬래시(PR-C2 scope) 진입.

### 사용법

```bash
# DRYRUN — payload JSON stdout, 실 등록 안 함 (smoke 안전 격리)
SCHEDULE_REGISTER_DRYRUN=1 bash core/skills/auto-build/scripts/schedule-register.sh "0 */6 * * *"
# stderr: would register: 0 */6 * * *
# stdout: {"action":"create","body":{"schedule":{"cron":"0 */6 * * *"},"prompt":"...","repo_url":"...","branch":"main"}}

# 1회용 모드 (run_once_at)
RUN_ONCE_AT="2026-05-24T03:00:00Z" SCHEDULE_REGISTER_DRYRUN=1 \
  bash core/skills/auto-build/scripts/schedule-register.sh --once
# stdout: {"action":"create","body":{"schedule":{"run_once_at":"2026-05-24T03:00:00Z"},...}}

# 실 등록 (사용자 manual)
bash core/skills/auto-build/scripts/schedule-register.sh "0 */6 * * *"
# stderr: Manual step required — Claude Code /schedule 슬래시 또는 https://claude.ai/code/routines 에 payload paste
# stdout: <payload JSON>
```

### 정책

- **cron 1h 최소 간격 강제 (R4 발견)**: RemoteTrigger API가 sub-hour 거부. minute 필드는 단일 정수 0-59만 허용 (`*/30`, `*/5`, `0,30` 모두 reject). 1h+ 보장 cron만 통과
- **prompt 템플릿 placeholder 치환**: `core/skills/auto-build/data/cloud-prompt-template.md` 읽어 `{{REPO_URL}}`, `{{BRANCH}}` 치환 후 payload `body.prompt`에 주입
- **실 등록은 사용자 manual**: 자동 호출 X (보안/비용 보호) — DRYRUN=0이어도 stdout JSON + stderr 안내만 출력
- **legacy `would register:` 라인 stderr 분리**: stdout은 순수 JSON (jq 파이프 안전)
- **R6 cron 부재 abort 누적**: 5건 연속 abort 시 Phase 2 retrospective hook 자동 알림 (신규 hook X)
- **MAX_FIRINGS_PER_DAY (local 한정, PR-C1)**: cloud firing은 cron freq 자체로 cap (1일 N firing). firings.jsonl은 local manual `run-queue.sh` 한정 (cloud 환경 무효)

### env

| env | 기본 | 동작 |
|-----|------|------|
| `SCHEDULE_REGISTER_DRYRUN` | 0 | 1 시 stdout JSON만 + stderr 안내, 실 호출 X |
| `REPO_URL` | `git remote get-url origin` | cloud agent가 clone할 git URL |
| `BRANCH` | `main` | cloud agent가 checkout할 branch |
| `RUN_ONCE_AT` | (none) | `--once` 모드에서 RFC 3339 UTC 필수 (예: `2026-05-24T03:00:00Z`) |

## Cloud 실행 (PR-C2)

cloud remote agent 진입점 `run-cloud.sh` — 1 firing = 1 task = 1 cycle = 1 PR 정책.

```bash
# DRYRUN (smoke 안전 격리) — mock PR URL + status_update done
AUTO_BUILD_QUEUE_DRYRUN=1 bash core/skills/auto-build/scripts/run-cloud.sh
# stdout: https://github.com/SONGYEONGSIN/vibe-flow/pull/MOCK-<entry-id>
# stderr: run-cloud: processing entry ... / cycle done (DRYRUN)

# 실 cycle (DRYRUN=0) — PR-C3 R8 dogfooding 후 완전 활성
bash core/skills/auto-build/scripts/run-cloud.sh
# gh CLI 부재 시 exit 2 + entry aborted
```

### 동작

1. `queue.sh next`로 queued 첫 entry pop (running 마킹)
2. 큐 비어있으면 stderr "queue empty" + exit 0
3. **DRYRUN=1**: mock PR URL stdout + `status-update done`
4. **DRYRUN=0**: gh CLI 검증 → 실 `/auto-build` cycle (PR-C3 R8 후) → `gh pr create` → `status-update done|aborted`

### 정책

- **1 firing = 1 task = 1 cycle = 1 PR**: `AUTO_BUILD_QUEUE_MAX_CYCLES` 무시 (cron freq 자체 cap, A4.1)
- **gh CLI 부재 시 abort**: cloud env는 gh 필수. entry `aborted` 마킹 + exit 2
- **cloud session 가정**: `AUTO_BUILD_QUEUE_CRON_FIRING=1` 자동 set (prompt 템플릿 명시)
- **PR-C3 dogfooding 대기**: 실 `/auto-build` dispatch는 R8 결과 후 활성. 현 PR-C2는 entry `queued` 복구 + exit 1 (소실 회피)

### env

| env | 기본 | 동작 |
|-----|------|------|
| `AUTO_BUILD_QUEUE_DRYRUN` | 0 | 1 시 mock PR URL + status_update done (smoke 안전) |
| `QUEUE_STORE` / `QUEUE_LOCK_DIR` | (queue.sh와 동일) | 테스트 fixture override 가능 |

## Cloud Safety + Queue Git (PR-C3)

cloud remote agent가 queue.jsonl을 읽고 cycle 결과를 push할 수 있도록 git-committed 전환. safety hook cloud 호환은 R8 dogfooding으로 사후 검증.

### queue.jsonl git-committed 전환

```bash
# 사용자 또는 cloud agent가 queue 변경 후 자동 commit/push
QUEUE_COMMIT_DRYRUN=1 bash core/skills/auto-build/scripts/queue-commit.sh
# stderr: would commit & push: .claude/memory/auto-build-queue.jsonl (current branch)

# 실 commit + push
bash core/skills/auto-build/scripts/queue-commit.sh
# 변경 없으면 skip, queue.jsonl만 add (drive-by 회피)
```

### 정책

- **queue.jsonl만 commit** — `git add <single-file>` 의미로 drive-by 회피 (Surgical Changes)
- **single-writer 가정** — cloud agent 동시 2 firing 금지 (`RemoteTrigger` 1 routine 1 cron). 동시 push 충돌은 future PR-C5 scope
- **변경 없으면 skip** — git diff cached 비교 후 commit 회피 (idempotent)
- **branch 미명시** — 현 HEAD 사용. cloud는 main만 push 가정

### R8 dogfooding 안내 (PR-C3 머지 후 manual cycle)

머지 후 다음 단계로 R8 dogfooding 진행 — vote/safety hook이 cloud session에서 동작 검증:

1. `RUN_ONCE_AT="<+1시간 UTC>" SCHEDULE_REGISTER_DRYRUN=0 bash schedule-register.sh --once` → payload JSON stdout
2. 사용자가 https://claude.ai/code/routines 에 manual paste 또는 `/schedule` 슬래시 사용
3. 1시간 후 cloud agent firing → `run-cloud.sh` 호출 → 결과 PR open 또는 entry aborted 마킹
4. 결과 분석:
   - **R8 성공 (A3.1)**: safety hook 정상 동작, vote 정상 dispatch → 다음 PR-C4 진입
   - **R8 실패 (A3.3 fallback)**: orchestrator에 vote confidence floor 1.0 강제 코드 활성 별 PR 필요

### env

| env | 기본 | 동작 |
|-----|------|------|
| `QUEUE_COMMIT_DRYRUN` | 0 | 1 시 stderr echo만 (smoke 안전 격리) |
| `QUEUE_STORE` | `.claude/memory/auto-build-queue.jsonl` | queue 경로 (테스트 fixture override) |

## 결과 통보 (PR-C4)

cloud cycle 완주 후 사용자 통보 — 기본 채널 = PR open (gh notification email). 옵션으로 Discord/Slack webhook.

```bash
# DRYRUN (smoke 안전)
NOTIFY_PR_DRYRUN=1 bash core/skills/auto-build/scripts/notify-pr.sh \
  "https://github.com/SONGYEONGSIN/vibe-flow/pull/123" 30000
# stdout: would notify: https://github.com/.../pull/123 (cost=30000)

# 실 통보 (PR open만 — webhook unset)
bash core/skills/auto-build/scripts/notify-pr.sh "$PR_URL" "$COST_TOKENS"
# stdout: $PR_URL (run-cloud.sh가 cycle 결과로 사용)

# 옵션 webhook (Discord/Slack)
NOTIFY_WEBHOOK_URL="https://discord.../webhook/abc" \
  bash core/skills/auto-build/scripts/notify-pr.sh "$PR_URL" "$COST_TOKENS"
# stderr: notify: webhook POSTed → https://discord...
```

### 정책

- **기본 채널 = PR open**: gh notification이 사용자 email 발화 — 추가 액션 X
- **R10 cost threshold**: 1 firing token cost > 50000 시 stderr warning (회피 cap은 cron freq + budget skill 책임, notify는 알림만)
- **webhook은 명시적 opt-in**: `NOTIFY_WEBHOOK_URL` env 미설정 시 webhook 채널 활성 X
- **단일 webhook URL**: multi-channel orchestration은 본 PR scope 외

### env

| env | 기본 | 동작 |
|-----|------|------|
| `NOTIFY_PR_DRYRUN` | 0 | 1 시 stdout echo만 + 실 webhook POST 안 함 |
| `NOTIFY_WEBHOOK_URL` | (unset) | set 시 webhook POST (Discord/Slack 호환) |
| `NOTIFY_COST_THRESHOLD` | 50000 | R10 warning 임계값 (token) |

### 예시

```bash
# 큐 적재
bash core/skills/auto-build/scripts/queue.sh add "$(cat <<'EOF'
무엇을: ...
누가: ...
왜 지금: ...
성공: ...
EOF
)"
# queued: 20260512T204900Z-a1b2

# 큐 확인
bash core/skills/auto-build/scripts/queue.sh list
# 20260512T204900Z-a1b2  queued  2026-05-12T20:49:00Z  무엇을: ...

# 큐 비우기
bash core/skills/auto-build/scripts/queue.sh clear

# run-queue DRYRUN (PR-B)
AUTO_BUILD_QUEUE_DRYRUN=1 bash core/skills/auto-build/scripts/run-queue.sh
# run-queue: cycle 1/3 — entry 20260512T204900Z-a1b2
# run-queue: cycle 1 done (DRYRUN)
```

### 검증

```bash
bash scripts/tests/queue-tests.sh     # 10 케이스 (CRUD + stale lock + next + run-queue + cap + abort + DRYRUN=0 보존) ALL PASS
bash scripts/tests/schedule-smoke.sh  # 4 케이스 (cron validation + firings cap + CRON_FIRING 분기, PR-C1) ALL PASS
```

## 관련 파일

- `core/skills/auto-build/orchestrator.md` — Ralph wrapper + P0~P-end + P3 ambiguity 분기
- `core/skills/auto-build/scripts/persona-vote.sh` — vote dispatch 명령 + moderator 중재 helper (Phase 2 신규)
- `core/skills/auto-build/data/persona-mapping.json` — 카테고리(7) → persona 풀 매핑 (Phase 2 신규)
- `core/skills/auto-build/scripts/run-log.sh` — `.claude/memory/auto-build-runs.jsonl` append helper
- `core/skills/auto-build/scripts/queue.sh` — 다중 task 큐 CRUD + next/status-update (Phase 3.0 PR-A/B)
- `core/skills/auto-build/scripts/run-queue.sh` — queue 첫 task pop + 사이클 trigger wrapper (Phase 3.0 PR-B + 3.1 PR-C1 firings cap)
- `core/skills/auto-build/scripts/schedule-register.sh` — RemoteTrigger create payload JSON wrapper (Phase 3.1 PR-C1.1 — cloud-native)
- `core/skills/auto-build/scripts/run-cloud.sh` — cloud remote agent 진입점 (Phase 3.1 PR-C2)
- `core/skills/auto-build/scripts/queue-commit.sh` — queue.jsonl 자동 git commit/push helper (Phase 3.1 PR-C3)
- `core/skills/auto-build/scripts/notify-pr.sh` — cycle 완주 통보 helper + R10 cost warning (Phase 3.1 PR-C4)
- `scripts/tests/notify-pr-smoke.sh` — notify-pr.sh smoke 3 케이스 (Phase 3.1 PR-C4)
- `core/skills/auto-build/data/cloud-prompt-template.md` — cloud remote agent prompt 템플릿 (PR-C1.1)
- `.claude/memory/auto-build-queue.jsonl` — task 큐 (PR-C3 git-committed, append-only)
- `scripts/tests/run-cloud-smoke.sh` — run-cloud.sh smoke 3 케이스 (Phase 3.1 PR-C2)
- `scripts/tests/queue-commit-smoke.sh` — queue-commit.sh smoke 2 케이스 (Phase 3.1 PR-C3)
- `.claude/memory/auto-build-queue.jsonl` — 큐 store (append-only, 런타임 생성)
- `.claude/memory/auto-build-firings.jsonl` — firings 영속화 (Phase 3.1 PR-C1, 당일 cap 카운트)
- `scripts/tests/queue-tests.sh` — queue.sh + run-queue.sh smoke 10 케이스
- `scripts/tests/schedule-smoke.sh` — schedule-register.sh + run-queue firings smoke 4 케이스 (Phase 3.1 PR-C1)
- `core/hooks/auto-build-safety.sh` — PreToolUse 안전 hook (token/file/iter cap)
- `.claude/memory/auto-build-runs.jsonl` — 사이클 이력 (런타임 생성)
- `.claude/memory/brainstorms/20260504-103257-vibe-flow-v2-overnight-autonomous-build.md` — Phase 1 설계 근거
- `.claude/memory/brainstorms/20260507-212317-auto-build-phase2-ralph-loop-persona-vote.md` — Phase 2 설계 근거
- `.claude/plans/20260504-194208-vibe-flow-auto-build-phase1.md` — Phase 1 구현 plan
- `.claude/plans/20260507-213353-auto-build-phase2-ralph-vote.md` — Phase 2 구현 plan

## R9 dogfooding marker (cloud cycle 첫 실 task — 2026-05-24)

본 marker는 R9 dogfooding 사이클이 cloud session에서 정상 동작했음을 표시한다. PR 머지 후 R9 검증 완료.

## R10 dogfooding marker (cloud cycle 두 번째 실 task — 2026-05-25)

본 marker는 R10 dogfooding 사이클이 safety hook + vote 코드 path + orchestrator P0~P5 모두 정상 통과했음을 표시한다.

## R11 dogfooding marker (cloud cycle 세 번째 실 task — 2026-05-25)

본 marker는 R11 dogfooding 사이클로 F14/F15 (PR #77) 신규 로그 형식 — safety hook PASS stderr + orchestrator P3a/P3b 진입 stderr — 이 cloud session에서 정상 출력되는지 검증 완료를 표시한다.
