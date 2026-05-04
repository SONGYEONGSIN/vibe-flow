---
name: sleep-build
description: 단일 task one-shot 자율 사이클 — maker가 자는 동안 brainstorm → plan → 구현(TDD) → /verify → /commit → /finish 까지 완주. branch 격리 + destructive op 차단 + token/file cap으로 안전 보장. 사용법 /sleep-build "<task description>"
effort: large
---

vibe-flow v2의 첫 자율 워크플로우. maker는 잠자기 전 task 1개를 명시하고, 깨어나서 working PR(또는 명시적 abort + 부분 진행 보존 branch)을 morning review 한다.

## 사용 시점

**필수**:
- task가 단일 사이클(brainstorm → plan → 구현 → PR)로 닫힐 만큼 명확
- HARD-GATE 간략 등급 이내(예상 6~19 파일)로 추정 가능
- 사용자 추가 의사결정 없이 진행 가능한 명시 task

**스킵 (수동 사이클 권장)**:
- 모호한 의도 (대안 비교가 필요한 단계)
- 디자인 결정 포함 (사용자 시각 검증 필수)
- HARD-GATE 전체 등급(20+ 파일) — file count cap이 중도 차단
- stacked PR / multi-repo 동시 변경

## 안전 계약

`/sleep-build`는 자율 모드 진입 시 다음을 **반드시** 준수한다:

1. **branch 자동 격리** — `feat/sleep-<timestamp>-<slug>` 신규 branch 생성 후 main 직접 수정 0
2. **destructive op 차단** — `core/hooks/sleep-build-safety.sh` PreToolUse hook이 `SLEEP_BUILD_MODE=1` 감지 시 활성. 차단 패턴: `rm -rf`, `git reset --hard`, `git push --force`, `--no-verify`, `chmod 777`, fork bomb 등
3. **token cap** — 사이클당 누적 token이 `SLEEP_BUILD_TOKEN_CAP`(기본 130000) 초과 시 abort
4. **file count cap** — branch git diff 파일 수가 `SLEEP_BUILD_FILE_CAP`(기본 19) 초과 시 abort (HARD-GATE 20+ 자율 차단)
5. **실패 시 abort** — exit reason을 `.claude/memory/sleep-build-runs.jsonl`에 명시 + branch 보존(폐기 X) → maker morning review

## 선행 조건

- `/brainstorm`, `/plan`, `/verify`, `/commit`, `/finish` 스킬 모두 사용 가능
- `core/hooks/sleep-build-safety.sh` 가 `settings.template.json`의 PreToolUse에 등록됨
- 현재 working tree clean (커밋되지 않은 변경 없음)
- `gh` 인증 완료 (PR 생성용)

## 절차 요약

자율 사이클은 다음 4-step으로 압축된다. 단계별 본체는 `core/skills/sleep-build/orchestrator.md`에 정의됨 — 이 파일은 진입점만 다룬다.

1. **안전 계약 발효** — `SLEEP_BUILD_MODE=1` export, branch 자동 생성, `run-log.sh start` 호출
2. **branch 격리** — `feat/sleep-<timestamp>-<slug>` checkout, working tree clean 확인
3. **orchestrator.md 시퀀스 진입** — P1(brainstorm) → P2(plan) → P3(TDD 구현) → P4(verify) → P5(commit + finish)
4. **종료 처리** — 성공/실패 무관 `run-log.sh done|abort` append, `SLEEP_BUILD_MODE` unset, branch 보존

## 호출 형태

```bash
/sleep-build "<task description>"
```

task description 가이드:
- 단일 산출물 명시 (예: "extensions/X 디렉토리에 /Y-audit 스킬 추가, OWASP 패턴 5개 검출")
- 4문항 답변 형식 권장 — `/brainstorm`이 추가 질문 없이 통과하도록 prepare:
  - 무엇을: ...
  - 누가: ...
  - 왜 지금: ...
  - 성공: ...

## 다음 스킬과의 연계

| 시점 | 스킬 |
|------|------|
| 사이클 시작 직전 | maker 본인 — task 명시화 + working tree clean |
| 사이클 진행 중 | `/brainstorm`, `/plan`, `/verify`, `/commit`, `/finish` (orchestrator가 자동 호출) |
| 사이클 종료 후 | maker 본인 — morning review (PR 머지 또는 abort branch 폐기) |
| 누적 데이터 분석 | `/telemetry` (sleep_build_* 이벤트 추세), `/budget --tokens` (사이클당 비용) |

## 메시지 버스 알림 (선택적)

기본 정책: **알림 안 함** (자율 사이클 자체가 이미 jsonl 로그로 기록됨). 다음 좁은 케이스만:

| 조건 | 수신자 | type / priority |
|------|--------|----------------|
| safety hook이 destructive op 차단 발생 | `security` | warn / high |
| token cap 초과 abort | 사용자 | warn / high |
| 5회 연속 사이클 실패 (retrospective 자동 감지) | `retrospective` | regression / medium |

## 규칙

- **사용자 합의 없이 main에 직접 변경 금지** — 항상 신규 branch
- **safety hook 미등록 환경에서는 즉시 abort** — `SLEEP_BUILD_MODE` 활성 전 hook 존재 확인
- **사이클 도중 maker 추가 입력 요청 금지** — 모호하면 abort 우선 (`brainstorm` 4문항 추가 질문 시도 = abort 신호)
- **branch 자동 폐기 금지** — 실패 사이클도 branch는 morning review 자료
- **token cap / file cap 초과는 silent skip 금지** — 반드시 jsonl `exit_reason` 명시
- **Phase 1 한정** — 다중 task 큐, cron 스케줄, dashboard 통합은 Phase 2/3에서 다룸

## 관련 파일

- `core/skills/sleep-build/orchestrator.md` — 자율 사이클 5 phase 시퀀스 본체
- `core/skills/sleep-build/scripts/run-log.sh` — `.claude/memory/sleep-build-runs.jsonl` append helper
- `core/hooks/sleep-build-safety.sh` — PreToolUse 안전 hook
- `.claude/memory/sleep-build-runs.jsonl` — 사이클 이력 (런타임 생성)
- `.claude/memory/brainstorms/20260504-103257-vibe-flow-v2-overnight-autonomous-build.md` — 설계 근거
- `.claude/plans/20260504-194208-vibe-flow-sleep-build-phase1.md` — 구현 plan
