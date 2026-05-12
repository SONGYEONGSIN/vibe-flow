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

## 관련 파일

- `core/skills/auto-build/orchestrator.md` — Ralph wrapper + P0~P-end + P3 ambiguity 분기
- `core/skills/auto-build/scripts/persona-vote.sh` — vote dispatch 명령 + moderator 중재 helper (Phase 2 신규)
- `core/skills/auto-build/data/persona-mapping.json` — 카테고리(7) → persona 풀 매핑 (Phase 2 신규)
- `core/skills/auto-build/scripts/run-log.sh` — `.claude/memory/auto-build-runs.jsonl` append helper
- `core/hooks/auto-build-safety.sh` — PreToolUse 안전 hook (token/file/iter cap)
- `.claude/memory/auto-build-runs.jsonl` — 사이클 이력 (런타임 생성)
- `.claude/memory/brainstorms/20260504-103257-vibe-flow-v2-overnight-autonomous-build.md` — Phase 1 설계 근거
- `.claude/memory/brainstorms/20260507-212317-auto-build-phase2-ralph-loop-persona-vote.md` — Phase 2 설계 근거
- `.claude/plans/20260504-194208-vibe-flow-auto-build-phase1.md` — Phase 1 구현 plan
- `.claude/plans/20260507-213353-auto-build-phase2-ralph-vote.md` — Phase 2 구현 plan
