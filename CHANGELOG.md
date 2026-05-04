# Changelog

## [Unreleased]

## [1.6.0] - 2026-05-05 — sleep-build (자율 사이클) + character system 정리

vibe-flow v2 첫 사이클. **maker가 자는 시간을 가치로 만든다** — 야간 자율 사이클 토대 (`/sleep-build`) + Phase 1.1 dogfooding 강화.

### 추가
- **`/sleep-build` Phase 1.1 — orchestrator 강화 (#32, Closes #31)** — dogfooding 발견 4 design gap 해소.
  - F1 (high): P0.1 배포 fail-fast — hook + run-log + orchestrator.md 미배포 시 즉시 abort `deployment_missing`
  - F3 (high): P1 자율 spec 직접 작성 — `/brainstorm` 스킬 호출 X. orchestrator가 prepared 4문항 답변에서 5 H2 헤더 spec 합성. 합성 실패 시 abort
  - F4 (medium): P2 HARD-GATE 분기 — `inline` → P3 직행, `brief` → plan 생성, `full` → abort
  - F5 (medium): P4 project-aware verify — `/verify` 의존 X. `package.json scripts` (test/build/lint/typecheck) detect 후 실재 명세만 실행
  - evals.json +4 케이스 — 결정 트리 회귀 검증
- **`/sleep-build "<task>"` Core 스킬 — Phase 1 MVP** — 단일 task one-shot 자율 사이클. brainstorm → plan → 구현(TDD) → /verify → /commit → /finish 까지 maker가 자는 동안 완주.
  - 진입점: `core/skills/sleep-build/SKILL.md`. 본체 시퀀스: `orchestrator.md` (P0 전처리 → P1~P5 → P-end 후처리)
  - 안전 hook: `core/hooks/sleep-build-safety.sh` (PreToolUse). `SLEEP_BUILD_MODE=1` 일 때만 활성. destructive op 6+ 차단(`rm -rf`, `git reset --hard`, `git push --force`, `--no-verify`, `chmod 777`, fork bomb), token cap (`SLEEP_BUILD_TOKEN_CAP` 기본 130k), file count cap (`SLEEP_BUILD_FILE_CAP` 기본 19, HARD-GATE 20+ 자율 차단)
  - 사이클 이력: `.claude/memory/sleep-build-runs.jsonl` (start/abort/done 이벤트, NFC 한글 경로 정규화)
  - eval: `core/skills/sleep-build/evals/evals.json` 5 케이스 (orchestrator phase 헤더 / hook 차단 / hook 비활성 통과 / innocent 통과 / run-log append)
  - 설계 근거: `.claude/memory/brainstorms/20260504-103257-vibe-flow-v2-overnight-autonomous-build.md`
  - 구현 plan: `.claude/plans/20260504-194208-vibe-flow-sleep-build-phase1.md` (T1~T10)
  - **Out of scope**: 다중 task 큐(Phase 2), CronCreate 야간 스케줄(Phase 2), dashboard `/morning`(Phase 3), retrospective 자가 진화(Phase 4)
- **GitHub Actions templates — `perf.yml` (#28)** — Lighthouse CI workflow. PR push 시 URL 1개 자동 측정 → comment 형태 결과. opt-in (manual copy from `templates/.github/workflows/`). 1.5.0의 verify/eval-regression/security 3종에 이어 4번째 템플릿.

### 호환
- ✓ 1.5.0 Core 20 + Extension 11 스킬 모두 유지 (Core 21 = 20 + /sleep-build)
- ✓ Hook 25 → 26 (sleep-build-safety.sh 추가)
- ✓ 자율 모드 토글은 `SLEEP_BUILD_MODE=1` env로 격리 — 비-자율 작업에 영향 0
- 짝 운영 dashboard 1.1.0 ([dashboard CHANGELOG](https://github.com/SONGYEONGSIN/vibe-flow-dashboard/blob/main/CHANGELOG.md)) 와 sleep_build_* 이벤트 형식 정합 (run-log.sh 출력 ↔ event-map.ts mapping)

## [1.5.0] - 2026-05-04 — bite-sized 스킬 + hook 일괄 보강

### 추가
- **`/perf-audit <url>` Core 스킬 (#26)** — Lighthouse CLI 래핑 (npx -y, 자동 다운로드). Performance score + 5 Web Vitals (FCP/LCP/CLS/TBT/Speed Index) 추출, pass/warn/fail verdict, `events.jsonl` `type=perf_audit` 이력. stack-agnostic (URL만 있으면 동작). on-demand only (~30s+).
- **`security-lint.sh` PostToolUse hook (#25)** — Write/Edit 직후 5+ OWASP 정적 패턴 (A01/A02/A03/A07/A09) grep. warn-only (차단 X), <200ms 응답. `pattern-check.sh`와 동일 형태로 일관. test/spec/templates/lockfile 등 false positive 회피.
- **`/inbox send <to> <subject> <body>` 모드 (#21)** — 사용자가 에이전트에게 메시지 발송. `--type info|alert|request|reply` / `--priority low|medium|high|critical` 옵션. 무효값 fallback. `message-bus.sh send` CLI 위임. 성공 시 `inbox_sent` 이벤트 push.
- **`/budget --tokens [--period 7|30|90]` 모드 (#24)** — Claude Code `~/.claude/projects/<slug>/*.jsonl` 파싱하여 모델별 정확 USD 비용. macOS NFD/NFC 한글 경로 정규화 (python3 fallback). pricing은 `core/skills/budget/data/pricing.json` 별도 파일 (가격 변경 시 한 줄 PR).
- **`/telemetry --period 7|30|90` 옵션 (#19)** — 기본 30일 분석 기간을 조정 가능. 모든 30일 하드코딩을 `$PERIOD_DAYS`로 치환. 무효값 (7/30/90 외) 경고 후 30일 fallback. JSON 출력 키 일반화 (`stale_30d` → `stale_period`).
- **GitHub Actions templates 3종 (#22)** — `templates/.github/workflows/`에 사용자 프로젝트용 CI 추가. **opt-in (manual copy)** — setup.sh 자동 복사 X.
  - `verify.yml` — npm/yarn/pnpm 자동 감지 + lint/typecheck/test (stack-agnostic)
  - `eval-regression.yml` — 사용자 자기 SKILL.md/agents.md/evals.json 구조 회귀 검증
  - `security.yml` — npm audit + secret 패턴 grep + OWASP 정적 (warn-only)
- **dashboard 신규 이벤트 매핑** ([dashboard #9](https://github.com/SONGYEONGSIN/vibe-flow-dashboard/pull/9)) — `inbox_sent` (수신자 jump) + `perf_audit` (verdict 분기) 캐릭터 액션 매핑.

### 변경
- **README**: Core 19 → 20, Hooks 24 → 25 (배지 + 텍스트 일관)
- **`docs/REFERENCE.md`**: 4 행 갱신 (perf-audit 신규, telemetry/inbox/budget 시그니처 확장)
- **eval-regression CI**: `templates/.github/workflows/**` path filter 추가, yq 설치 + Templates YAML 유효성 검증 단계 신규 (#23). 검증 6 → 7 항목.

### 호환
- ✓ 기존 19 Core + 11 Extension 스킬 모두 유지 (Core 20 = 19 + /perf-audit)
- ✓ 모든 신규 옵션은 backward compatible (기존 호출 그대로 동작)
- ✓ vibe-flow 1.4.0에서 자동 마이그레이션 (state 보존)

### 후속 후보
- `templates/.github/workflows/perf.yml` — `/perf-audit` CI 자동화 (별도 PR 후보)
- 🎮 캐릭터 풀 게임화 — 외형 설정 / `/pair` 협업 애니메이션 / Stage 진화 (별도 brainstorm)

## [1.4.0] - 2026-05-01 — Phase 3 UI + 동적 캐릭터 시스템 (게임화)

### 추가
- **Phase 3 UI 레이어 — vibe-flow-dashboard** ([repo](https://github.com/SONGYEONGSIN/vibe-flow-dashboard)) — 별도 Next.js 16 + TypeScript 5 + Tailwind 4 프로젝트. chokidar로 events.jsonl 실시간 tail, SSE로 브라우저 push. 5 영역 통합 대시보드: events stream / 활성 plan / inbox / 메트릭 / .claude 구조. `VIBE_FLOW_PROJECT` env로 vibe-flow 프로젝트 지정 (localhost:9999). **Source 침범 0** — vibe-flow Layer 1/2 그대로, dashboard는 읽기 전용.
- **동적 캐릭터 시스템 (vibe-flow-dashboard `/characters`)** — 12 에이전트 픽셀 룸 무대. events.jsonl 이벤트 → 매칭 캐릭터 점프/walk-to + 컨텍스트 대사. active/waiting zone 분리 + Activity Feed + Stage 어드저스터 UI (localStorage 미리보기). (dashboard PR #2/#7/#4/#8)
- **`skill_invoked` 이벤트 + hook** — `core/hooks/skill-tracker.sh` (UserPromptSubmit). 사용자가 prompt에 `/<skill>` 또는 `/<plugin>:<skill>` 입력 시 `.claude/events.jsonl`에 `{type:"skill_invoked", skill, ts}` push. dashboard `/characters`에서 40+ 스킬 → 12 에이전트 매핑 (planner/designer/developer/qa/security/validator/feedback/moderator/comparator/retrospective/grader/skill-reviewer) + 각 캐릭터 `skill_invoked` 컨텍스트 대사 풀 추가. 매칭 안 되는 스킬은 moderator fallback. 실패해도 exit 0 (기존 워크플로우 차단 X). (vibe-flow PR #17 + dashboard PR #6)

### 변경
- **ROADMAP 정리** — Phase 3 TUI / Phase 4 mobile 보류 사유 + 재평가 트리거 명확화. v1.x 후속 후보 6 항목 추가 (security / performance / GH Actions templates / inbox send / budget token mode / telemetry 기간 옵션).
- README Hooks 23 → 24

### 호환
- ✓ 기존 19 Core + 11 Extension 스킬 모두 유지
- ✓ vibe-flow 1.3.0에서 자동 마이그레이션 (state 보존)

## [1.3.0] - 2026-04-30 — Phase 4 새 Extensions (i18n + k8s)

### 추가
- **i18n Extension** — 6번째 extension 카테고리. `/i18n-audit` 스킬 — 번역 키 누락/미사용/locale 간 불일치 자동 검출. 라이브러리 무관 (next-intl, react-i18next, vue-i18n 등 5 패턴 정규식). 외부 의존 0 (jq + grep + comm). locale 자동 탐색 (messages/, public/locales/, locales/, src/i18n/). (PR #10)
- **k8s Extension** — 7번째 extension 카테고리. `/k8s-audit` 스킬 — Kubernetes manifest 5 anti-pattern 정적 검증 (resources 누락 / `image: :latest` / securityContext 미설정 / label-selector mismatch / Secret 평문). yq 가용 시 정확, 없으면 grep+awk fallback. manifest 자동 탐색 (k8s/, manifests/, deploy/, kustomize/, helm/templates/, .k8s/, deployment/). (PR #11)

### 변경
- README Extensions 6 → 7
- 신규 명령: `/i18n-audit`, `/k8s-audit`

### 호환
- ✓ 기존 19 Core + 9 Extension 스킬 모두 유지
- ✓ vibe-flow 1.2.0에서 자동 마이그레이션 (state 보존)

### 보류
- **mobile** Extension — RN/Flutter 단일 스킬 일반화 어려움. 메이커 본인의 mobile 사용 데이터 누적 후 재평가.

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
