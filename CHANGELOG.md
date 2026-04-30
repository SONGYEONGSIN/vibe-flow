# Changelog

## [Unreleased]

## [1.2.0] - 2026-04-30 — Phase 2 + 4 + P5 (UX + 메이커 도구화)

### 추가

#### Phase 2 — UX 개선
- **`/onboard` 스킬** — 사용자 단계 자가진단(Stage 0 신규 ~ Stage 4 자가 진화) + 단계별 다음 행동 추천. 데이터 우선 (events.jsonl + .vibe-flow.json + memory/), 부족 시 자가보고 3 질문 폴백. 24h cache. (PR #2)
- **`/menu` 스킬** — 24 스킬 카테고리별 발견성 + events.jsonl 사용 분포 + onboard-state.json 기반 Stage 추천. 필터: `/menu core|extensions|<category>`. (PR #3)
- **`/inbox` 스킬** — 12 에이전트 inbox + broadcast + debates 통합 뷰. message-bus.sh CLI 호환 (read/archive 위임). 필터: `<agent>|--unread-only|--broadcast`. (PR #4)
- **Statusline 강화** — `scripts/statusline.sh` + `settings.template.json` `statusLine`. verify / 마지막 hook / 활성 plan 합성 (`✓v · 🔧✓ · 📋N/M`). `VIBE_FLOW_STATUSLINE=off|VERBOSE=1`. (PR #5)

#### P5 — 비용 예산
- **`/budget` 스킬 + `budget-warn` hook** — 호출 카운트 기반 (5 무거운 스킬). `.claude/budget.json` + `/budget set` + sparkline 추이. budget-warn Notification hook 80%+ 비차단 경고 (15분 디바운스). (PR #6)

#### Phase 4 — 메이커 도구화
- **`/telemetry` 스킬** — 본인 1 머신 30일 events.jsonl 분석. Top 5 + Active + Stale + 개선 후보 + 추세. 4 모드. (PR #7)
- **eval 회귀 CI** — `.github/workflows/eval-regression.yml` + `scripts/eval-regression-check.sh`. SKILL.md / agents.md / evals.json 구조 + agents.json 일치 자동 검증. LLM 호출 0. (PR #8)
- **README 배지 + 자동 갱신** — shields.io 배지 (CI / Core / Ext / Hooks / Agents / License) + `scripts/sync-readme-badges.sh` 카운트 갱신. (본 PR)

### 변경
- README 상단에 메트릭 배지 6개 추가
- Core 17 → 19 (`/onboard` `/menu` `/inbox` `/budget` `/telemetry`)
- Hooks 22 → 23 (`budget-warn.sh`)
- 신규 명령: `/onboard`, `/menu`, `/inbox`, `/budget`, `/telemetry`, statusLine 활성

### 호환
- ✓ 기존 17 Core + 9 Extension 스킬 모두 유지
- ✓ settings.local.json 호환 (statusLine + Notification 추가만)
- ✓ vibe-flow 1.1.0에서 `bash setup.sh`로 자동 마이그레이션

## [1.1.0] - 2026-04-30 — vibe-flow rename + Core/Extensions

### 변경 (Breaking — claude-builds 사용자에게)

- **Repo rename**: `claude-builds` → `vibe-flow`. GitHub auto-redirect 작동.
- **디렉토리 구조**: 평면 → `core/` + `extensions/<name>/` 두 단계.
- **setup.sh 기본 동작 변경**: 이전엔 모든 스킬 설치, 이제 Core 14만. `--all` 또는 `--extensions <name>`로 확장.
- **State 파일 도입**: `.claude/.vibe-flow.json` — 설치 추적/갱신/제거.

### 호환

- ✓ 모든 스킬 이름 그대로 (`/commit`, `/verify`, ...)
- ✓ settings.local.json 그대로 유효 (모든 hook 22개 core)
- ✓ 메모리 / 메트릭 / plans / messages 자동 보존
- ✓ 마이그레이션: `bash setup.sh` 한 번 실행으로 자동 (시그니처 디렉토리 추론)

### 추가

- `--list-extensions` / `--info <name>` / `--remove-extension <name>` / `--check`
- `--all` (Core + 5 extensions 모두)
- 마이그레이션 자동 감지 (시그니처 디렉토리 추론)
- validate.sh 10 stages (state 무결성 + state↔fs reconciliation 추가)
- `docs/REFERENCE.md` / `docs/ARCHITECTURE.md` / `docs/MIGRATION.md` / `docs/ONBOARDING.md` 신설
- `extensions/<name>/README.md` 5개 신설
- README 725 → ~120줄로 재구성

### 출처 (1.1.0 정식 매핑)

- Surgical change / Goal-driven: forrestchang/andrej-karpathy-skills
- TDD Iron Law: obra/superpowers
- Self-evolution + Memory fencing + Error classifier: NousResearch/hermes-agent
- Pair mode (Builder/Validator): disler/claude-code-hooks-mastery
- SQLite instinct store: affaan-m/everything-claude-code
- Observability stream: disler/claude-code-hooks-multi-agent-observability
- Release skill (semver + CHANGELOG): Shpigford/chops
- DESIGN.md 9섹션 포맷: VoltAgent/awesome-design-md

## [1.0.x] - claude-builds 시기 누적 (Unreleased에 누적된 항목)

### 추가 (claude-builds 시기 process skills)
- **`/brainstorm` 스킬** — 구현 전 의도/제약/대안 구조화 탐색. 4문항 의도 검증 + 제약 발견 + 최소 2개 대안 + do-nothing 옵션 + 추천/기각 근거. 결과는 `.claude/memory/brainstorms/`에 저장되어 다음 세션 인계 + retrospective 분석 입력. designer Phase 0가 디자인 한정이라면 /brainstorm은 도메인 무관 일반 의도 탐색. (Superpowers brainstorming 패턴 참조)
- **`/plan` 스킬** — 멀티스텝 작업의 계획을 `.claude/plans/`에 파일화하여 사용자 합의 + 단계별 추적. planner 에이전트로 영향 파일/단계 분해/리스크 분석, frontmatter status로 in_progress/completed/abandoned 라이프사이클 관리. brainstorm spec 헤더 계약(`## 의도 / ## 제약 / ## 추천 + 근거 / ## 다음 단계`)을 입력으로 받아 호환. 이탈은 silent 수정 금지 — `/plan revise`로 명시적 처리. (Superpowers writing-plans 패턴 참조)
- **`/finish` 스킬** — 작업 완료 시 머지/PR/cleanup 경로 자동 판정 + 의사결정 트리. 상태 점검(브랜치/미커밋/verify/활성 plan) → HARD-GATE 등급별 경로 안내(PR/direct push/release/cleanup). 미커밋·미통과·main 직접·pending step 등 결손 상태는 차단하고 해결 명령 명시. push/pr 자동 실행 안 함 — 결정만 자동화, 실행은 사용자 명령으로. (Superpowers finishing-a-development-branch 패턴 참조)
- **`/receive-review` 스킬** — 리뷰 피드백을 항목별로 분리 + 6 카테고리(bug/security/performance/architecture/style/preference) 분류 + 증거 기반 검증 후 accept/reject/clarify 명시 의사결정. performative agreement도 defensive rejection도 차단. 결과는 `.claude/memory/reviews/`에 저장 + events.jsonl 기록. 5 안티패턴(performative agreement / defensive rejection / scope creep agreement / preference vs principle 혼동 / silent ignore) 명시 차단. (Superpowers receiving-code-review 패턴 참조)

## [1.0.0] - 2026-04-16

첫 안정 릴리즈. 62 커밋의 누적 작업물.

### 에이전트 (12개)
- 12개 전문 에이전트 시스템: planner, designer, developer, qa, security, feedback, grader, comparator, validator, skill-reviewer, moderator, retrospective
- 파일 기반 메시지 버스로 에이전트 간 비동기 통신
- 구조화된 토론 시스템 (자동 트리거 + moderator 중재)

### 스킬 (19개)

| 카테고리 | 스킬 |
|---------|------|
| 개발 흐름 | `/commit`, `/pair`, `/scaffold`, `/worktree` |
| 검증 | `/verify`, `/test`, `/security`, `/review-pr` |
| 디자인 | `/design-sync` (URL/이미지/로컬 7단계), `/design-audit` |
| 분석 | `/feedback`, `/metrics`, `/status`, `/retrospective` |
| 학습 | `/learn`, `/discuss` |
| 품질 진화 | `/eval`, `/evolve` (Hermes Agent self-evolution 패턴) |
| 릴리즈 | `/release` (semver 자동 판단 + CHANGELOG 관리) |

### 훅 (22개)
- PreToolUse 파이프라인: command-guard, smart-guard, tdd-enforce
- PostToolUse 파이프라인: prettier, eslint, typecheck, test-runner, metrics, pattern-check, design-lint, debate-trigger, readme-sync
- 에러 분류: 13-class error classifier (Hermes Agent 패턴)
- 컨텍스트 압축: context-prune (도구 출력 1줄 요약, 12KB 예산)
- 모델 라우팅: model-suggest (events.jsonl 패턴 분석 → 비차단 제안)
- 세션 관리: session-review, session-log, uncommitted-warn

### 인프라
- SQLite instinct store (Migration v1-v3, 13개 사전 쿼리)
- Dual-write: JSON + SQLite + JSONL 3중 기록
- 실시간 관측 스트림 (watch-events.sh + events-tail.js)
- setup.sh 원클릭 설치 + validate.sh 5단계 검증
- 오케스트레이터: Claude Squad (tmux) + Agent Orchestrator (CI/CD) + 대안 도구 안내

### 규칙 (6개)
- conventions, tdd, git, design, donts, debugging
- Memory context fencing (Hermes Agent 패턴)
- $ARGUMENTS 검증 공통 규칙

### 출처
- SQLite Store: [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code)
- 관측 스트림: [disler/claude-code-hooks-multi-agent-observability](https://github.com/disler/claude-code-hooks-multi-agent-observability)
- TDD 강제화: [obra/superpowers](https://github.com/obra/superpowers)
- Pair Mode: [disler/claude-code-hooks-mastery](https://github.com/disler/claude-code-hooks-mastery)
- Error Classifier, Context Compressor, Memory Fencing, Model Routing, Self-Evolution: [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)
- Release Skill: [Shpigford/chops](https://github.com/Shpigford/chops)
