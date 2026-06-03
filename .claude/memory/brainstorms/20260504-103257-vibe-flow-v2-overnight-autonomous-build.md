# Brainstorm: vibe-flow v2 — 다음 가치 축 (overnight 자율 빌드 워크플로우 포함)

작성: 2026-05-04T10:32:57Z (filename에서 추출, retroactive F-A4 fix)

## 의도

- **산출물**: vibe-flow v2 사이클의 가치 축 1개 결정 + 다음 세션 즉시 plan 진입 가능한 spec. 사용자 명시 후보: overnight 자율 빌드 워크플로우 (영상 *GStack + GSD + Superpowers Workflow* 패턴).
- **사용자**: 메이커 본인 (vibe coder). 시나리오 — 잠자기 전 task 1개 큐잉 → `/sleep-build` 시작 → 깨어나서 morning report + 12 캐릭터 야간 활동 흔적 확인 → working PR review/merge. 대체 행동: 깨어있는 시간에 직접 1~2 PR씩 진행 (현재 방식).
- **트리거**: v1 사이클 actionable 큐 모두 완결 (1.5.0 + dashboard #10 머지). 메이커가 "다음에 뭘 하지?" 단계. 영상 트렌드(GSD/gstack/Superpowers 결합)가 2026 표준화. 미루면 vibe-flow가 "수동 사이클 강화" 단계에서 정체.
- **성공 기준**:
  - week 1: maker가 sleep 전 task 1개 큐잉 → 깨어나서 working PR 1개 확보 (실패 사이클 포함 비율 측정)
  - events.jsonl에 `sleep_build_*` 이벤트 누적, dashboard에 morning digest 표시
  - 자율 사이클 비용/안전 가시화 — token 비용, 실패 rollback, scope 이탈 감지

## 제약

- **기술**: Claude Code 자율 실행은 `/loop` dynamic mode + `ScheduleWakeup` + `CronCreate`로 self-pacing 가능. /gsd auto는 GSD-2 외부 TS 앱이 agent session 제어 — 우리는 슬래시 스킬 + hook 조합으로 동등 가능. dashboard 짝 운영 시 morning digest = dashboard 신규 영역.
- **비즈니스**: maker 본인 작업, no deadline. 토큰 비용 — `/budget --tokens`로 야간 cap 강제 필수. 외부 의존 0가 vibe-flow 일관 정체성.
- **코드베이스**: 자율화는 신규 슬래시 스킬 + 안전 hook 추가. 기존 12 에이전트/캐릭터/telemetry/예산 토대 재사용도 100%. branch 격리 + morning review로 maker 통제권 보존.

## 대안 비교

| 항목 | A. `/sleep-build` 자체 구현 | B. gstack/GSD 외부 채택 | C. 자가 진화 루프 강화 | D. 외부 공유성 축 | Z. do nothing |
|------|--------------------------|----------------------|--------------------|----------------|--------------|
| 핵심 | vibe-flow 자체 자율 오케스트레이터 신규 | 23역할/`gsd auto` adapter | telemetry → 자동 패턴 추출 → 스킬 제안 | "자율 빌드 스타터킷" 포지셔닝 + 마케팅 | v1 plateau 유지 |
| 비용 | 큼 (~6h, 3 PR — phase 분할 가능) | 중 (~3~4h) | 중 (~4h) | 큼 (~5~6h) | 0 |
| 위험 | scope drift, token 폭주 (가드로 완화) | vibe-flow 정체성 흐려짐 + 외부 의존 | 자동 제안 quality | 메이커 즐거움 결 다름 | 동력 손실 |
| 가역성 | 매 사이클 branch 격리 + maker review → 가역 | adapter 제거로 가역 | 제안만 제출 → 매우 가역 | 자료 폐기 가능 | n/a |
| 토대 활용 | **100%** (loop/schedule/12 agent/character/telemetry/budget) | 낮음 (외부가 본체) | 중 (telemetry/agent) | 낮음 | n/a |
| 차별 가치 | **12 캐릭터 야간 진화 + Stage 자동 누적** — maker 정서적 즐거움 ↑ | 외부 결합기 위치 — 흥미 작음 | 메타 layer 깊어짐 | reach 확장 | 0 |
| 정체성 | **maker 정체성 일치** | 손상 | 일치 | 결이 다름 | 유지 |

## 추천 + 근거

**대안 A (`/sleep-build` 자체 구현) 채택 — Phase 분할로 작게 시작.**

1. **maker 정체성 일치**: vibe-flow는 "자기 도구 maker가 짠 자기 도구"다. 자율 빌드를 외부(B) 채택하면 vibe-flow가 통합기로 격하됨. 자체 구현이 메이커의 즐거움 결과 정합.
2. **토대 100% 활용**: `/loop` dynamic + `ScheduleWakeup` + 12 에이전트 + Stage 자동 진화 + dashboard SSE + telemetry + budget — 모두 이미 있음. 신규 진입점은 `/sleep-build` 1개와 안전 hook 1개.
3. **차별 가치 (vibe-flow만의 것)**: 12 캐릭터 + Stage 자동 진화 + 야간 활동 = "자고 일어나니 캐릭터가 밤새 진화"라는 정서적 경험. GSD 채택(B)으로는 못 만든다. character system은 v1의 정서 토대였고 v2 자율 사이클에서 시각 piece가 된다.
4. **비용 분할 가능**: Phase 1 = 단일 task one-shot 자율 (1~2h, ~5~7 파일). Phase 1 후 멈춰도 가치 검증 완료. Phase 2/3는 검증 결과 기반 단계 진입.

**기각 B (gstack/GSD 외부 채택)**: vibe-flow 정체성 손상 + 외부 의존 + 캐릭터/12 에이전트 레버리지 감소. **B 전환 가치 시점**: maker 본인 코드보다 결과물 안정성이 절대 우선이 되는 시점 — 현재 X.
**기각 C (자가 진화 루프)**: 매력적이나 사용자 명시 의도(overnight 자율 빌드)와 결이 다름. **C는 A의 sub-feature로 흡수**: overnight 사이클 결과를 retrospective agent가 학습하여 다음 사이클 개선 제안. A Phase 4로 자연 편입.
**기각 D (외부 공유)**: 자율 빌드 본체 없이 마케팅 자료부터 만드는 건 순서 거꾸로. v3 후보로 보존 (자율 빌드 운영 데이터 누적 후).
**기각 Z**: maker 동력 손실 + v1 plateau 정체.

## 다음 세션 진입 spec

### v2 가치 축

**축**: "vibe-flow는 maker가 깨어있는 시간을 늘려주지 않고, **maker가 자는 시간을 가치로 만든다**" — 야간 자율 사이클로 maker 사이클 ×N 증폭.

### Phase 1 — `/sleep-build "<task>"` MVP (가장 작은 가치)

단일 task → brainstorm → plan → TDD → commit → PR 자동 사이클. /loop dynamic + ScheduleWakeup으로 self-pace.

**구현 단위 예상**:
- `core/skills/sleep-build/SKILL.md` (신규) — 슬래시 스킬 진입점
- `core/skills/sleep-build/orchestrator.md` 또는 `.sh` (신규) — /brainstorm → /plan → 구현(TDD) → /verify → /commit → /finish 시퀀스 + 실패 시 자가 복구 분기
- `core/hooks/sleep-build-safety.sh` (신규, PreToolUse) — budget cap, file count cap (HARD-GATE 등급), destructive op 차단, branch 격리 강제
- `.claude/memory/sleep-build-runs.jsonl` (신규) — 사이클 이력 (maker가 가장 먼저 보는 morning digest 소스)
- 기존 활용: `/budget --tokens`, character agents (developer/qa/planner), `/loop` dynamic, ScheduleWakeup, `/finish`

**안전 가드 (Phase 1 필수)**:
- branch 자동 격리 (`feat/sleep-<timestamp>-<slug>`) — main 직접 변경 0
- destructive op 차단 (`rm -rf`, `git reset --hard`, `git push --force`, `--no-verify` 등) — security-lint hook 확장
- token budget cap (예: 사이클당 100k input + 30k output 초과 시 abort)
- file count cap (HARD-GATE 등급 — 20+ 파일 변경 사이클은 자율 차단)
- 실패 시 abort → 사이클 로그 + 부분 진행 commit 보존, branch는 남김 (사용자 morning review)

**HARD-GATE**: Phase 1 = 5~7 파일 = **간략 설계 등급** → 다음 세션 첫 작업 `/plan from-brainstorm 20260504-103257-vibe-flow-v2-overnight-autonomous-build.md`

### Phase 2 — task 큐 + 스케줄 (검증 후 진입)

- `/sleep-build queue add "<task>"`, `/sleep-build queue list`
- `CronCreate`로 정기 야간 실행 (예: 매일 23:00 큐 처리 시작)
- 다중 task 사이클 (1 task 완료 → 다음 task 진입)

### Phase 3 — morning digest (dashboard 짝)

- vibe-flow-dashboard `/morning` 신규 페이지
- 야간 사이클 결과 timeline + 12 캐릭터 야간 활동 stage 진화 시각화
- 사이클별 PR 링크 + 실패 사유 + token 비용
- character system Stage 자동 진화 카운트에 sleep_build_* 이벤트 가중치 (선택)

### Phase 4 — 자가 진화 (대안 C 흡수)

- retrospective agent가 사이클 로그 학습 → 다음 사이클의 brainstorm/plan 개선 제안
- skill-creator 자동 호출 후보 식별 (반복 패턴 → 새 스킬 제안)
- maker 승인 후 머지 → vibe-flow 자체가 dogfooding으로 진화

## 다음 단계

- spec 저장: `.claude/memory/brainstorms/20260504-103257-vibe-flow-v2-overnight-autonomous-build.md`
- 다음 세션 첫 작업: `/plan from-brainstorm 20260504-103257-vibe-flow-v2-overnight-autonomous-build.md` (Phase 1 한정)
- **Phase 1 plan**: `.claude/plans/20260504-194208-vibe-flow-sleep-build-phase1.md` (T1~T10, 간략 등급, branch `feat/sleep-build-phase1`)
- ROADMAP에 v2 축 추가: "Phase 5 — 자율 사이클 (maker가 자는 시간을 가치로)"
- B (외부 채택) — 안정성 절대 우선 시점에 재평가 (Phase 1 운영 데이터 누적 후)
- C (자가 진화) — Phase 4로 흡수, 별도 큐 X
- D (외부 공유) — Phase 3 운영 데이터 누적 후 v3 후보로 부상
