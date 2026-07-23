# Brainstorm: 완전 자율 자기진화 하네스 — AHE 폐루프 배선

> 생성: 2026-07-23 12:24 UTC / 결정: 완전 무인(auto-merge 전체) + 야간 cloud routine

## 의도

- **산출물**: vibe-flow의 AHE 루프(evaluate→analyze→improve→verify)를 **사람 개입 0으로 매일 밤 자동 완주**하는 폐루프. 야간 cloud routine이 `pending-verify → /audit → enqueue → auto-build → CI-green auto-merge → self-update → health-check`를 1 라운드 돌린다. 신규 구축이 아니라 **이미 존재하는 5개 수동 크랭크 지점의 배선 + 3중 안전장치**.
- **산출물 확장 (능력 표면 진화)**: 루프가 **결함 수정(corrective)** 뿐 아니라 **능력 확장(generative)** 도 자율 수행 — telemetry가 입증한 반복 수동 패턴을 "capability-gap" finding으로 잡아 `skill-creator`로 신규 스킬을 스캐폴드→auto-build로 로직 채움→eval 게이트 통과→배선. **대칭**: 저사용 스킬은 은퇴 제안(self-pruning). 즉 하네스가 스스로 자라고(grow) 가지치기(prune)한다.
- **사용자**: 하네스 자신(cloud session). 사람은 아침에 dashboard/알림으로 밤새 진화 결과를 확인만 함. 대체 행동 = 현재의 손 크랭크(R1~R13처럼 매 라운드 직접 /audit).
- **왜 지금**: R1~R13을 손으로 돌려 3.0→4.15 달성했으나 (a)사람이 자는 동안 루프 정지 (b)매 라운드 사용자 시간 소모 (c)harness-evolution.md 자체가 "손으로 돌려온 것"이라 인정. Phase 3.1 cloud routine(R12)까지 조각은 다 있음 — 지금이 폐루프로 잇는 시점.
- **성공 기준** (측정 가능):
  1. 야간 routine 1회 firing이 사람 개입 없이 `verify→audit→fix→merge→self-update` 완주 (exit 0, PR 머지 ≥0건, ledger resolve ≥1건)
  2. **자기오염 0**: 오진 fix가 게이트/안전장치를 부수면 auto-revert가 같은 밤 내 되돌리고 circuit breaker가 발화 (health regression 시 auto-merge freeze)
  3. dimension 평균 점수가 라운드 간 비-감소 (4.15 유지 또는 상승) — 열화 없이 자율 진화 실증
  4. self-update: 머지 후 설치 플러그인 버전이 새 main과 동기 (drift 0)
  5. **생성 트랙**: capability-gap finding이 telemetry 반복 실측(≥N회)에서만 발화 + 생성 스킬이 eval(트리거 정확도) 통과 후 머지 + 저사용 스킬 은퇴 제안 작동 (grow/prune 양방향 실증). speculative 생성 0건.

## 제약

- **기술**:
  - vibe-flow는 **자기 자신의 rules/skills/agents/hooks를 다시 쓰는** 하네스 → auto-merge는 자기오염 런어웨이 리스크(오진 fix가 안전장치를 무력화 → 오염된 하네스가 자신을 감사 → 열화 누적). 사용자 선택 preview가 "auto-rollback + circuit breaker 반드시 필요" 명시.
  - cloud routine은 Anthropic cloud 실행(1h 최소 간격, prompt-based) — 로컬 cron 아님(project_phase3_1_r4 참조). 기존 R12 trig_01RcUNYjHFh4t2k5UrKo75MB 확장.
  - CI 2-leg(validation-tests + eval-regression)가 유일 머지 게이트 — auto-merge는 CI green을 필수 전제로.
- **비즈니스**: cloud session 비용(라운드당 token). 야간 1회 cap이 비용 예측성 확보. auto-build token/file/iter cap(200k/19/30) 이미 존재.
- **코드베이스**: 7-component observability + validate.sh/sync-drift.sh(core↔.claude 정합) 이미 존재. 신규 안전장치는 이 정합 게이트 통과해야. HARD-GATE: 20+ 파일/구조 변경 → **전체 설계(Planner 필수)**.
- **생성 트랙 특유 제약 (Simplicity-First 긴장)**: vibe-flow 자신의 규칙(`donts.md` Surgical, `karpathy-principles.md` §2 Simplicity First — "요청 안 한 것 만들지 마라")이 speculative 능력 확장을 금함. 자율 스킬 생성은 이 원칙과 정면 충돌 리스크 → 생성은 (a)강한 증거 바(telemetry 반복 N회 실측) (b)신규 eval 게이트(트리거 정확도 + 동작) (c)dedup(기존 스킬 의미 중복 차단, F-D3 collision 교훈) (d)skill-budget(라운드당 순증 cap) 4중 방어 없이는 금지. `skill-creator`는 eval/benchmark 지원 보유 → 트리거 정확도 자동 측정 가능.

## 대안 비교

### 대안 A: Guarded full-auto on main (main 직행 + 3중 안전장치 + 단계적 신뢰 구축)
- 핵심: 야간 routine이 main에 직접 auto-merge하되 3 pillar로 감쌈 — ①**불변 안전코어**(denylist: auto-build-safety/command-guard/circuit-breaker/validate.sh/merge-gate/denylist 자신 — auto-loop이 절대 수정 불가, PreToolUse hook 집행) ②**post-merge auto-revert**(머지 직후 fresh checkout validate.sh+CI, 실패 시 `git revert` 자동+알림) ③**circuit breaker**(rolling harness-health = CI pass% + dimension avg + gate 무결성 checksum; baseline 대비 regression 시 auto-merge OFF + human-gate 복귀 + 알림). 롤아웃 단계적: auto-merge OFF(PR-only, health baseline 수집)→low-risk tier 개방→M 클린 밤 후 full.
- 비용: 중(신규 hook 1 + 스크립트 3~4 + routine 확장 + self-update). fix가 **같은 밤 main 도달** → self-update 즉시.
- 위험: auto-revert 발동 전 **짧은 노출 창**(bad merge가 잠시 main에 존재). 안전코어 denylist가 뚫리면 무력화 → denylist를 안전코어에 포함해 차단.
- 가역성: 높음(revert + circuit breaker + 단계 롤백). 안전코어는 사람만 수정.
- 학습 효과: 실제 main 데이터로 harness-health metric 검증, 자기오염 방어 실전 관찰.

### 대안 B: Shadow/canary evolution (evolve 브랜치 격리 + 프로모션 게이트)
- 핵심: 야간 루프가 main이 아닌 장수 `evolve/main` 브랜치에서 진화. 거기서 self-fix 누적 + 전체 test/dimension suite 연속 실행. **K일 연속 green + 점수 개선** 시에만 evolve→main auto-promote. main은 안정 릴리즈 채널, self-update는 promoted main에서. 오진 fix는 evolve만 오염, 절대 promote 안 됨.
- 비용: 고(브랜치 프로모션 머신 + evolve 상시 CI + 이중 채널 관리).
- 위험: fix가 main 도달까지 K밤 지연 → 자율성 체감 저하. 프로모션 게이트 로직 자체 오염 시? → 게이트를 main-side pinned 스크립트로 실행해 차단.
- 가역성: 최고(main 무오염 보장, evolve 폐기 가능).
- 학습 효과: 캐너리 관찰 데이터, 하지만 지연으로 라운드 피드백 느림.

### 대안 Z (do nothing)
- 지금 안 하면: 손 크랭크 유지(R1~R13 방식). 3.0→4.15는 달성했으나 사람 시간 계속 소모 + 야간 정지 + "완전 자동화" 사용자 목표 미달.
- 우회책: 반자동 `/evolve` 1-명령 단축(온디맨드)으로 부분 완화 가능 — 하지만 "무인"은 아님.

## 추천 + 근거

**추천: 대안 A (Guarded full-auto on main, 단계적 롤아웃)**

**선택 근거**:
1. 사용자 결정(완전 무인 + 야간 cloud)에 정합 — fix가 **같은 밤 main 도달 → self-update 즉시** 작동. B는 K밤 지연으로 "무인"의 체감을 깎음.
2. 3 pillar가 사용자 preview가 요구한 "auto-rollback(=post-merge revert) + circuit breaker"를 **직접 구현**. 특히 **불변 안전코어 denylist**가 핵심 불변식 — 하네스가 자신의 안전장치를 수정하는 런어웨이를 원천 차단(대안 B도 이 invariant 없으면 evolve 게이트가 자기오염됨).
3. 기존 자산의 **증분 확장**(R12 routine, ledger.sh, run-queue.sh, auto-build vote, CI 2-leg) — B의 브랜치 프로모션 머신은 신규 인프라 부담 큼.
4. **단계적 신뢰 구축**(OFF→low-risk→full)이 day-1 full-auto의 위험을 데이터로 상환 — "empirical trust before autonomy".

**핵심 불변식 (A·B 공통, 절대 양보 불가)**:
- **Pinned evaluator**: 밤 N+1의 audit/verify는 밤 N이 수정할 수 없는 안전코어 로직으로 실행 → 오염이 평가자를 매수해 bad fix를 승인하는 cascade 차단.
- **안전코어 불변**: circuit-breaker/revert/denylist/safety-hook/validate.sh는 auto-loop 수정 금지.

**기각된 대안 B**: 지연(K밤)이 사용자의 "무인 즉시 진화" 의도와 상충. **단, A의 짧은 노출 창(auto-revert 전 bad merge가 main에 잠깐 존재)이 실전에서 위험하다고 판명되면 B(캐너리)로 전환할 가치** — 특히 구조적/안전-인접 변경은 A에서도 canary 경유하도록 하이브리드 가능.

### 생성 트랙 — capability-gap (corrective와 분리된 별도 파이프라인)

결함 수정과 **다른 evidence·gate·tier**를 갖는다:

| 축 | corrective (결함 수정) | **generative (스킬 생성)** |
|----|----------------------|--------------------------|
| finding 유형 | defect (evidence=file:line) | **capability-gap** (evidence=telemetry 반복 N회 + 미커버 증명) |
| trigger | /audit dimension | telemetry 반복 패턴 탐지 + error 클래스 반복 |
| 생성 도구 | Edit(기존 파일) | **skill-creator 스캐폴드 → auto-build 로직 채움** |
| 검증 | /verify + CI | /verify + CI + **skill-creator eval(트리거 정확도/variance) + dedup + skill-budget** |
| auto-merge tier | 저위험은 early 개방 | **최상위 — 가장 마지막에 graduate** (mis-trigger·sprawl·Simplicity 긴장) |

**anti-sprawl 4중 방어** (생성 특유):
1. **evidence bar** — telemetry가 동일 수동 패턴 ≥N회 실측해야 후보 (speculative 생성 금지)
2. **dedup gate** — 기존 45 스킬과 의미 중복 시 abort (신규 대신 기존 스킬 확장 제안)
3. **eval gate** — 생성 스킬은 skill-creator eval로 트리거 정확도 + 동작 실증 후에만 머지
4. **skill-budget** — 라운드당 순증 스킬 수 cap (runaway 생성 backstop)

**대칭 — self-pruning**: 생성 스킬이 M 라운드 후 telemetry near-zero면 루프가 **은퇴 PR** 제안 → 능력 표면이 양방향(grow/prune)으로 진화. Karpathy §5(context 큐레이션 — 노이즈 제거)와 정합.

## 다음 단계

- **저장됨**: `.claude/memory/brainstorms/20260723-212449-autonomous-self-evolution-closedloop.md`
- **HARD-GATE**: 20+ 파일 + 구조/안전/인증-등급 변경 → **전체 설계 (Planner 필수)**
- **권장**: `/plan from-brainstorm <이 파일>` → planner 에이전트 전체 분석 → **PR 분할** 제안 (예):
  - **PR-1 안전코어 기반**: 불변 denylist(`.claude/evolution-protected`) + PreToolUse 집행 hook + circuit-breaker health metric 스크립트 (auto-merge는 아직 OFF)
  - **PR-2 폐루프 배선**: 야간 routine 확장(pending-verify→/audit→enqueue→run-queue→auto-build→/verify), PR-only 모드로 health baseline 수집
  - **PR-3 auto-merge + auto-revert**: CI-green + tier + 안전코어-untouched 게이트 → `gh pr merge --auto`, post-merge fresh-CI + auto `git revert`
  - **PR-4 self-update**: 머지 후 `/release` 버전 bump + 플러그인 재동기 + drift 검증
  - **PR-5 graduation**: 확정된 승급 순서 — ①corrective 저위험(ledger/docs/telemetry/memory) → ②corrective 구조적(rules/hooks/gates/agents) → ③self-update → ④generative(스킬 생성). 각 tier는 M밤 클린 데이터 후 다음 tier 개방. + circuit-breaker 발화/리셋 runbook
  - **PR-6 생성 트랙**: capability-gap finding 유형(telemetry 반복 탐지) + skill-creator 스캐폴드 배선 + eval/dedup/skill-budget 4중 게이트 + self-pruning 은퇴 제안. **최상위 tier — 다른 트랙 graduate 후 마지막 개방.**
- **선행 정리 (PR-0 필수)**: F-K03 재판정 완료(2026-07-23) → **REFUTED** (ledger resolve 반영). 메커니즘 확정: `.claude/rules/` 자동스캔 + **frontmatter path-scoping** — git/debugging/harness-evolution/karpathy(frontmatter無)=글로벌 상시로드, conventions/donts/tdd/design(`paths: src/**`)=코드편집 시 조건로드(설계된 동작). 명예규칙 아님, ENOENT 증거 거짓. 제안 fix(CLAUDE.md @import 8) 기각 — TS규칙을 bash편집에 강제로드 = context-engineering(Karpathy §5) 위반.
  - **그러나 자율진화 직결 실이슈 (R14 candidate finding)**: `donts.md`가 **일반 discipline**(Surgical Change :34-39 / 완료기준 "no /verify=no done" :48-57 / 합리화방지 테이블 :59-77)을 **TS-특화 규칙과 한 파일**에 묶어 `paths: src/**` 스코프. path-scoping은 파일 단위라 일반 규칙이 src/** 게이트를 상속 → **하네스가 자기 자신(.sh/.md/rules)을 수정할 때 일반 discipline이 dormant**. 자율 루프가 이 상태로 self-modify하면 Surgical·완료기준이 컨텍스트 밖.
  - **PR-0 (교정된 스코프)**: `donts.md`/`conventions.md`에서 **일반 discipline 섹션을 frontmatter 없는 글로벌 rule로 분리** (예: `discipline.md`), TS-특화(any/console.log/useEffect/보안)만 path-scoped 유지. 반증 = 분리 후 harness .sh 편집 세션에서 Surgical/완료기준이 컨텍스트에 존재. auto-modification 활성화의 전제조건.
