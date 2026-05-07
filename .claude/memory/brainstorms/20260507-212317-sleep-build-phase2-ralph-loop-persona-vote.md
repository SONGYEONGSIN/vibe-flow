# Brainstorm: sleep-build Phase 2 — Ralph loop + persona voting

## 의도

- **산출물**: Phase 1 단발 사이클을 **multi-iteration Ralph loop**로 확장 + **ambiguity 발생 시 vibe-flow 24 agent 중 관련 persona 자동 dispatch + moderator 중재**로 결정 → maker 추가 입력 없이 진정한 무인 사이클. 한 task로 PR 1+개 생성하는 본격 SaaS 빌드 가능.
- **사용자**: vibe-flow maker. 시나리오 — 잠자기 전 task 큐잉 (예: "vibe-ops에 인증 통합 + 5 페이지 stub 추가") → `/sleep-build` 진입 → Ralph loop가 N iteration 자율 수행 → ambiguity (디자인/구현 결정) 발생 시 designer + ux-researcher + frontend-design-specialist 등 자동 vote → moderator 결정 주입 → 사이클 계속 → 깨어나서 PR 1+개 받음. 대체 행동 — 깨어 있는 시간에 ambiguity마다 사용자 응답 (현재 Phase 1 abort 정책).
- **트리거**: Phase 1의 `abort-on-ambiguity` 정책이 SaaS 본격 빌드 (디자인 결정, 20+ 파일) 진입 자체를 차단. 영상 *GStack + GSD + Superpowers Workflow*의 핵심 패턴 (Build Loop + persona vote)이 vibe-flow의 기존 토대(`/loop`, `Agent` tool, 24 agents, `moderator`)로 자체 구현 가능. 미루면 vibe-flow는 "단발 작은 task만 가능한 자율"에 머물고, 영상의 진짜 무인 사이클 가치 못 받음.
- **성공 기준**:
  - week 1: 작은 task 1개 ("vibe-ops에 작은 helper 1개 추가") dogfooding — Ralph 1~3 iteration 안에 PR 1개 + vote 1회 이상 발화 (디자인 결정)
  - week 2: 본격 task 1개 ("vibe-ops 인증 페이지 5개 stub") — Ralph 5~15 iter, PR 분할 (각 file_cap 안), vote 5회+
  - 사이클당 token 200k 이내 / max 30 iteration / abort 시 명시적 exit_reason 기록
  - vote 결정 사후 검토 — maker가 morning review에서 vote 결과 일치율 70%+

## 제약

- **기술**: `/loop` dynamic + `ScheduleWakeup` self-pace 검증됨 (이전 세션). `Agent` tool로 vibe-flow 24 agent dispatch 가능. `moderator` agent 이미 존재. PR 자동 분할은 git branch + 단계별 commit + 마지막 push로 단순화. session 활성 유지 한계는 그대로 (Phase 3 cron 진입 전).
- **비즈니스**: maker 1인, deadline 없음. token 비용 — 사이클당 200k cap (Phase 1의 130k 대비 ~50% 상향). vote 1회당 3~5 persona × 평균 1k token = 3~5k 추가 → 30 vote 시 ~150k. 안전한 cap.
- **코드베이스**: Phase 1 인프라 그대로 유지. orchestrator.md만 확장 (P3 안에 ambiguity vote 분기 + 외부 Ralph loop wrapper 추가). safety hook 유지 (destructive 차단 그대로, cap 상향만). vibe-flow ↔ dashboard 짝 운영 — `sleep_build_*` 이벤트에 `vote_triggered` / `iteration_complete` 추가, dashboard 매핑 짝 PR 후속.

## 대안 비교

| 항목 | A. Phase 2 본격 (Ralph + vote) | B. 단계 분할 (2.1 vote → 2.2 Ralph) | C. gstack 외부 채택 | D. Phase 1.5 cap만 상향 | Z. do nothing |
|------|-----------------------------|----------------------------------|------------------|----------------------|--------------|
| 핵심 | Ralph loop + vote 동시 머지 | vote 먼저 검증 → Ralph 별도 PR | 23역할 외부 패키지 + adapter | file_cap 19→50, abort 정책 일부 완화 | Phase 1 한계 유지 |
| 비용 | 큼 (~6h, 6 파일, 간략 등급) | 중 (~3h × 2회 = 6h, PR 2개) | 중 (~4h, 외부 의존) | 작음 (~1h, 1 파일) | 0 |
| 위험 | vote 결정 품질 미검증 / token 폭증 | 2.1만으론 가치 작음 (단발 안에서 vote 1회 거의 안 일어남) | vibe-flow 정체성 손상 (이전 brainstorm 기각 사유) | 큰 task abort 폭주 — 본질 미해결 | 동력 손실 |
| 가역성 | branch + iter commit + cap → 매우 가역 | PR 2개로 더 안전 | adapter 제거 | 1줄 revert | n/a |
| 토대 활용 | **100%** (/loop, Agent, 24 agent, moderator) | 100% | 낮음 (외부가 본체) | 100% (cap만) | n/a |
| 가치 | **진정한 무인 사이클** | 동일 가치 (시간 더 김) | 외부 결합기 격하 | 일부 task만 가능 | 0 |
| dogfooding 적합성 | 첫 사이클 = 작은 task로 검증 가능 | 2.1+2.2 각각 dogfooding 필요 (2배) | 외부 의존 검증 시간 | 가치 작아 dogfooding 불필요 | n/a |

## 추천 + 근거

**대안 A (Phase 2 본격 — Ralph + vote 동시) 채택.**

1. **분할 가치 작음**: B는 2.1(vote 만)에선 multi-iteration 없어 vote 발화 빈도 0~1회 → 검증 데이터 부족. Ralph + vote는 결합되어야 본질 가치 (vote가 ambiguity 해소 → 다음 iter 진행). 분할은 시간만 2배.
2. **토대 90% 재사용**: 신규 컴포넌트는 `persona-vote.sh` 1개 + orchestrator P3 분기 + cap 상향뿐. 영상의 Build Loop / GStack vote 패턴을 vibe-flow 자체 구현 (외부 의존 0).
3. **dogfooding-first 원칙 (memory 저장됨) 그대로 적용**: PR 머지 *후* 첫 사이클을 작은 task로 시작하여 vote 결정 품질 + iteration 비용 calibration. 분할(B) 없이도 dogfooding 가능.
4. **가역성 보장**: branch 격리 + iter별 commit (각 iter 끝에 mini-commit) + cap 완비 → 깨어나서 잘못된 사이클이면 `git reset` 1줄로 폐기 (단, safety hook이 `git reset --hard` 차단하니 maker가 수동).

**기각 B (단계 분할)**: 시간 2배, vote 단독 가치 작음, 결합이 본질.
**기각 C (gstack 외부)**: 이전 brainstorm(`20260504-103257-...`)에서 명시적 기각, 정체성 손상. 재론 X.
**기각 D (cap만 상향)**: 본질 — abort-on-ambiguity 정책 — 미해결. 큰 task에서 첫 ambiguity 발생 즉시 abort.
**기각 Z**: vibe-flow 동력 정체. SaaS 본격 빌드 영원히 수동 사이클.

## 다음 단계

### v2 가치 축 갱신

**기존 (Phase 1)**: "maker가 자는 시간을 가치로 만든다 — 단발 자율 사이클"
**Phase 2 진화**: "maker가 자는 시간을 가치로 만든다 — **persona가 결정하는** 무인 사이클"

### 구현 단위 (예상)

1. **`core/skills/sleep-build/scripts/persona-vote.sh`** (신규) — ambiguity 질문 입력 → 관련 persona 3~5명 자동 식별 (질문 카테고리 매핑) → `Agent` tool 병렬 dispatch → moderator agent 중재 → 결정 + 사유 stdout 출력
2. **`core/skills/sleep-build/orchestrator.md`** (수정) — P3에 ambiguity 감지 분기 추가 (P3a: 진행 가능 / P3b: persona-vote.sh 호출 → 결정 주입 → 진행). Ralph loop wrapper 시퀀스 추가 (외부 loop가 P0~P-end 1 사이클을 N번 반복, file_cap 도달 직전 PR push 후 새 branch로 다음 iter)
3. **`core/skills/sleep-build/SKILL.md`** (수정) — "스킵 (수동 사이클 권장)" 조건 완화: 디자인 결정 → vote로 자동 통과 표기, HARD-GATE 전체 등급 → Ralph loop가 PR 분할 처리 명시
4. **`core/hooks/sleep-build-safety.sh`** (수정) — `SLEEP_BUILD_TOKEN_CAP` 기본 130000 → 200000, `SLEEP_BUILD_FILE_CAP` 그대로 19 (PR 분할로 우회), 신규 `SLEEP_BUILD_MAX_ITERATIONS` 기본 30
5. **`core/skills/sleep-build/data/persona-mapping.json`** (신규) — 질문 카테고리 → persona 풀 매핑 (예: "design" → designer + ux-researcher + frontend-design-specialist; "auth" → security + api-architect + security-specialist; "performance" → performance-optimizer + qa + developer)
6. **`core/skills/sleep-build/evals/evals.json`** (수정) — +3 케이스: vote dispatch (mock), Ralph iter 1→2 진입, max_iterations 차단

총 6 파일 (신규 2 + 수정 4) — **HARD-GATE 간략 등급** → `/plan` 권장.

### 짝 dashboard 후속 (별도 PR)

- `sleep_build_iteration_complete`, `sleep_build_vote_triggered` 이벤트 추가
- 매핑: iteration_complete → developer jump (다음 사이클 진척감), vote_triggered → moderator clap + 관련 persona들 walk-to (시각 vote 모임)
- Phase 3 dashboard `/morning` 페이지에서 vote 결과 timeline 표시

### Phase 3 (보존)

- `CronCreate` 정기 야간 스케줄 — Ralph loop을 cron이 트리거 (진정한 set-and-forget)
- retrospective agent 자가 진화 — vote 결정 일치율 + iteration 비용 학습 후 다음 사이클 개선
- maker 첫 야간 실 운영 데이터 누적 후 진입

## 다음 단계 (이 brainstorm 기준)

- spec 저장: `.claude/memory/brainstorms/20260507-212317-sleep-build-phase2-ralph-loop-persona-vote.md`
- HARD-GATE 간략 등급 → 다음 작업 `/plan from-brainstorm 20260507-212317-sleep-build-phase2-ralph-loop-persona-vote.md`
- 첫 dogfooding task: vibe-ops 작은 helper 추가 (예: 시간 fmt utility 1개) — Ralph 1~3 iter, vote 1회 발화 시나리오 검증
