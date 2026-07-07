# Changelog

## [Unreleased]

## [2.3.2] - 2026-07-07 — anti-slop 색상 WARN 2종 (single-accent · low-saturation)

frontend-flow anti-slop에 색상 품질 검사를 추가. 색상 변환 헬퍼(`color-utils.js`) 신설.

### Added
- **single-accent WARN** — 유색 액센트(hex·oklch·tailwind)를 hue 30° 버킷화해 **색상 난립**(버킷 >3)이나 **near-duplicate 토큰 미추출**("한 파일에 미묘하게 다른 파랑 다섯", 한 버킷 raw >3)을 경고. tailwind shade는 토큰이라 제외.
- **low-saturation WARN** — 과포화 **네온 액센트**(hex HSL S≥90% 또는 oklch chroma≥0.25)를 경고. 정상 브랜드 채도(blue-600 S=83%)는 통과해 오탐 방지, tailwind는 curated 팔레트라 면제.
- **`color-utils.js`** — hex→HSL, oklch, tailwind 색상군→hue 파싱 헬퍼(순수 함수, 중성색 자동 제외).
- anti-slop 스모크 회귀 확장(35 → 46종): sprawl/near-dup/네온/브랜드블루-FP/oklch/tailwind면제/브랜드override.

### Changed
- 색상 WARN도 **브랜드 우선**: DESIGN.md에 명시된 색은 single-accent 버킷·low-saturation raw에서 양보.

## [2.3.1] - 2026-07-07 — anti-slop WARN 검사 정확도 패치

엣지케이스 배터리(26종)로 발견한 신규 WARN 2종의 오탐/미탐을 수정.

### Fixed
- **eyebrow-density 미탐(FN) 수정** — `uppercase`와 `tracking` 유틸이 별도 className으로 쪼개진 `cn()` 패턴에서 eyebrow를 놓치던 문제. 파일 단위 판정으로 재설계해 분리된 경우도 포착.
- **radius-system 오탐(FP) 수정** — 좌측 보더 '색상' 유틸(`border-l-zinc-200`)을 SaaS 카드 조합으로 오인하던 문제. 실제 보더 '폭' 유틸(`border-l`/`border-l-0/2/4/8`)만 매칭.
- **주석 오탐 제거** — 주석 속 em-dash·`<section>`·주석처리된 폰트명이 검사에 잡히던 문제. 스캔 전 블록/라인 주석 제거(URL `://`은 보존).

### Added
- anti-slop 스모크 회귀 테스트 확장(28 → 35종): eyebrow 분리, border-l 색상/폭 구분, 주석 스트립, URL 미오손상.

## [2.3.0] - 2026-07-07 — 접근성 audit + anti-slop 구조 검사 강화

### Added
- **정적 접근성 audit (P4)** — `/frontend-flow` 검증 단계에 **브라우저 없이도** 도는 4-차원 접근성 리뷰(대비/색상 · 시맨틱 HTML · 키보드/포커스 · 모션·폼)를 추가. Playwright가 설치돼 있지 않아도 접근성 게이트가 비지 않고, 고정 스택(shadcn/ui) 특성을 반영해 오탐을 줄인다.
- **anti-slop 구조 검사 2종** — 코너 반경 체계 일관성(`radius-system`)과 eyebrow 밀도(`eyebrow-density`)를 자동 점검. 빌드를 막지 않는 경고(WARN)로 보고해 "AI 템플릿 티 나는" 패턴을 제작 초기에 드러낸다.

### Changed
- anti-slop 검사 출력이 pass/fail 2단계에서 **pass/warn/fail 3단계**로 확장. warn은 빌드를 차단하지 않는 리뷰 신호로, 판단이 필요한 규칙(색상 조합·editorial-warm 등)은 에이전트 리뷰에 위임하는 경계를 명확히 했다.

## [2.2.0] - 2026-07-07 — frontend-flow 제작 오케스트레이션 스킬 + 내부 감사 R10

### Added
- **`/frontend-flow` 스킬** — 참고사이트 URL(또는 캡처 이미지)과 DESIGN.md를 넣으면 토큰 추출→정본화→기술선정→구현→검증까지 프론트엔드를 제작하는 오케스트레이션. 스택은 Next.js + Tailwind v4 + shadcn/ui 고정, 비싼 빌드 전 프로토타입으로 먼저 승인받는 게이트 구조. 기존 `/design-sync`·`/design-audit`·`frontend-design-specialist`를 지휘.

### Fixed
- **내부 감사 R10 — frontend-flow 13개 결함 수정**: 스킬 스크립트가 문서 그대로 실행하면 경로를 못 찾아 게이트가 항상 실패하던 P0 버그, anti-slop 검사가 빈 소스·금지문 오해석·tailwind 검정 클래스를 놓쳐 조용히 통과하던 거짓 통과 3종, 신규 스크립트가 CI 검사 트리거에서 빠지던 사각지대, 그리고 종합 제작 스킬과 단발 컴포넌트 에이전트의 발동 경계 모호성을 교정.
- **문서 카운트 현행화** — README의 hook 수(29→26) 등 잔여 stale 수치 정정, 아키텍처 다이어그램 자동 재생성.

### Changed
- 감사 ledger R10 폐루프 — finding 13건을 `fixed`로 전이해 다음 라운드가 예측 효과를 실측 반증하도록 대기 상태로 둠(decision-observability).

## [2.1.0] - 2026-07-04 — AHE `/audit` 자기 진화 루프 + R6~R9 감사 하드닝

### Added
- **`/audit` 스킬 — 관찰성 기반 harness 자기 진화 (AHE)**: 내부 감사를 실행 가능한 계약으로. dimension 에이전트 병렬 분석 → 4-필드 finding(증거·원인·수정·예측효과) → decision-observability ledger(예측 vs 실측 반증). 2 라운드 연속 자립 운영으로 자기 인프라 결함까지 스스로 적발·수정.
- **`core/rules/harness-evolution.md`** — AHE doctrine (evaluate→analyze→improve, 7-component observability, ledger lifecycle 불변식).
- **`.claude/memory/audit-ledger.jsonl`** — finding 폐루프 추적(append→enqueue→mark-fixed→pending-verify→resolve). mkdir 원자 락(macOS 포팅) / base-10 번호 / 빈문자열 가드 / 4-커맨드 동시성 완비.
- **CI `validation-tests.yml`** — 검증·계측 툴링 회귀를 PR 단계에서 차단.

### Fixed
- **사용량 텔레메트리 집계 복원** — 잠복 결함으로 Top5/Total 이 줄곧 빈 값이던 것을 교정(events-source 첫 정상 측정).
- **drift 검증 강화** — core-only 신규 파일이 조용히 통과하던 비대칭, agents.json/규칙/스킬 커버리지, hook·유틸 경계 정확화.
- **계측 정확도** — 존재하지 않는 슬래시명(phantom) 기록 차단, plan 완료 이벤트, 도구 실패 오분류 축소.
- **매니페스트/문서 정확도** — 플러그인 skills=45 / hooks=26, 프로젝트 메모리 현행화.

### Changed
- 내부 감사 R6~R9 완주 (평균 점수 3.0 → 4.37, 35 PR). ad-hoc 감사 → `/audit` 스킬 상시 운영으로 전환.

## [2.0.0] - 2026-06-06 — marketplace publish + audit closure + adoption infra

vibe-flow 가 **plugin marketplace 1줄 install 가능** 한 상태로 도달. 누적 audit cycle R1~R5 4.53/5 + Karpathy 4 원칙 + Context Engineering 5번째 원칙까지 완성. 외부 채택 friction 완전 0.

### 추가 — 채택 인프라

- **`.claude-plugin/` manifest** (PR #105) — Claude Code marketplace publish. `/plugin marketplace add https://github.com/SONGYEONGSIN/vibe-flow` + `/plugin install vibe-flow` 1줄 install 가능. plugin v1.0.0 (44 skills + 22 agents 등록).
- **`LICENSE` MIT** (PR #100) — README 가 약속하던 라이선스 파일 실 추가 (지금까지 부재). 기업/OSS 채택의 전제조건.
- **`README.md` 영문** + **`README.ko.md` 한국어 보존** (PR #101) — 글로벌 채택 시작점. 양 파일 최상단 언어 스위처. stale 카운트 (skills 20→44, hooks 25→29, agents 12→22, extensions 11→7) 모두 현 상태로 정합.

### 추가 — 비용 최적화

- **4 agent opus → sonnet right-sizing** (PR #102) — `comparator` / `feedback` / `retrospective` / `validator` 의 model frontmatter 정정. 분포 Opus 13→9 / Sonnet 8→12 / Haiku 1. audit-heavy 세션 전체 30%+ 비용 절감 가능 (Sonnet ≈ Opus/5).

### 추가 — 가시성/UX

- **`session-review.sh` 학습 저장 proactive** (PR #103) — 기존 patterns.md age-based passive reminder → 세션 활동 패턴 자동 감지. 3 신호 (fix/refactor ≥ 2건 / distinct error_class ≥ 2종 / patterns.md ≥ 7일) 기반 targeted `/learn save` 제안. OMC `learner` 벤치마크 (0 dependency 단순 구현).
- **`core/scripts/sync-drift.sh`** (PR #104) — `setup.sh --upgrade` 대비 lightweight drift 정합. `--check` (dry-run, exit 1 if drift) / `--verbose` / apply 3 모드. agents + rules + skills 재귀 + hooks → `.claude/` 일괄 cp. `git-post-commit.sh` skip list 처리. smoke test 13/13 PASS.
- **`cycles-report.sh`** (PR #91) — auto-build cloud cycle observability. git log + queue + firings.jsonl 통합 view + stuck queued 탐지 (routine 미발화 신호). smoke test 8/8 PASS.

### 수정 — 내부 정합성 (audit cycle R1~R5 closure)

audit 5 round × 3 dimension (D1 컨텍스트 / D2 아키텍처 / D3 dogfooding) 완주. 점수 진화:

| Round | D1 | D2 | D3 | 평균 |
|-------|----|----|----|------|
| R1 (06-01) | 2.8 | 3.8 | 2.5 | 3.0 |
| R5 (06-06) | **4.5** | **4.4** | **4.5** | **4.47** |

20 PR 머지 (#80~#99) + R5 추가 (#102/#103/#104). 누적 +1.47.

핵심 finding 해소:

- **F-C1 sync drift** (PR #88) — `core/` ↔ `.claude/` runtime drift 자동 탐지. `validate.sh` F-C1 섹션 신설. R4 (PR #92) 와 R5 (PR #99) 에서 검증 범위 확장 (rules + skills/scripts + hooks + non-SKILL.md). 총 6 카테고리 모두 drift 0 보장.
- **F-A11 + F-A12 + F-A13 settings hook 중복 봉쇄** (PR #93/#94/#96) — `.claude/settings.json` + `.claude/settings.local.json` 양쪽 hook 등록 → 모든 hook 2회 fire 이슈. 증상 정화 + cloud-init.sh local-context 감지 + `.gitignore` 추가 = 3중 봉쇄.
- **F-D5 → F-D7 silent fail 근본 차단** (PR #97) — R12 cloud cycle silent fail 원인 = `run-cloud.sh` 의 PR-C2 stub (R8 dogfooding 후 미정리). stub 제거 + agent hand-off 명시. 향후 cycle 결정적 작동.
- **F-D3 R3-1/-3/-4** (PR #89/#90/#91) — dangling plan close + tool_failure substring 오분류 차단 + cloud cycles observability.
- **F-D1-R4 + F-E1/E2/D8** (PR #92/#99) — validate.sh F-C1 검증 범위 단계적 확장 (R4 rules + scripts + hooks → R5 skill 내 non-SKILL.md + hook drift loop 비대칭 fix).
- **F-D6 false positive 정정** — Skill instrumentation 가설 라이브 테스트로 기각 (`/status` 호출 시 `skill_invoked_auto` event 정상 emit 확인). 0건 누적은 사용자 행동 패턴 (audit-heavy 세션은 Skill tool 직접 호출 드묾).

### 추가 — R12/R13 cloud dogfooding cycle

- **R13 self-evolving closed-loop** (PR #95) — R13 cloud routine (`trig_01DZKFt39UPhZX9zRK4yaku1`) 2026-06-05T14:39:15Z fire → cloud cycle 완전 작동 → R12 dogfooding marker PR 자동 생성 → cloud agent 본인이 brainstorm 에서 R12 silent fail 원인 진단 → F-A13/F-D7 즉시 발굴 + 4시간 내 closed-loop 머지. self-evolving dogfooding 정합성 입증된 첫 사례.

### 변경 (Breaking)

이전 `[Unreleased]` 의 sleep-build → auto-build 전면 rename 등 v1.7~v1.9 미릴리즈 항목 일괄 v2.0.0 으로 통합. 아래 "이전 unreleased (v1.6.0 → v2.0.0 누적)" 섹션 참조.

### 이전 unreleased (v1.6.0 → v2.0.0 누적)

#### 추가
- **`setup.sh --clean` / `--clean-dry-run` 플래그** — target 프로젝트 `.claude/`에서 **source에 없는 obsolete hook/skill 자동 삭제**. rename 후 기존 sleep-build 같은 이전 이름 자산이 target에 남는 문제 해결.
  - 감지: `.claude/hooks/*.sh` 중 `core/hooks/`에 없는 것 + `.claude/skills/*/` 중 `core/skills/`에 없는 것
  - `--clean-dry-run` — 감지만, 삭제 X (사전 검토용)
  - `--clean` — 즉시 삭제 + install 단계 계속
  - `settings.local.json`의 stale hook 등록은 **수동 편집 안내만** (자동 갱신 X — 사용자 custom hook 보호)
  - 보호: source 출신만 삭제 (사용자 추가 custom hook/skill 보존 — `.claude/`에 있고 `core/`에도 있으면 건드림 X)

### 변경 (Breaking — 식별자 rename, 동작 변경 0)
- **`sleep-build` → `auto-build` 전면 rename** — Phase 2 도입(Ralph loop + persona vote)으로 "수면 중 자동 빌드" 초기 의미가 본질 변경 → 이름을 의미와 정합화.
  - 디렉토리: `core/skills/sleep-build/` → `core/skills/auto-build/`
  - hook: `sleep-build-safety.sh` → `auto-build-safety.sh`
  - env var: `SLEEP_BUILD_*` → `AUTO_BUILD_*` (MODE / TOKEN_CAP / FILE_CAP / MAX_ITERATIONS / RUN_ID)
  - jsonl event type: `sleep_build_*` → `auto_build_*` (start/done/abort) — **dashboard 짝 PR 필요**
  - jsonl 파일: `sleep-build-runs.jsonl` → `auto-build-runs.jsonl` (과거 데이터 마이그레이션 X)
  - settings.template.json hook 경로 + env (사용자 로컬 `.claude/settings.json`은 `bash setup.sh` 재실행 또는 수동 갱신 필요)
  - docs/superpowers/{plans,specs}/ 파일명 + 내용
  - 시스템 메모리 `project_sleep_build_runtime_limit.md` → `project_auto_build_runtime_limit.md`
  - 한국어 산문의 "sleep-build" 표기는 보존 (case-by-case 별 PR)

### 추가
- **`/auto-build` Phase 2 — Ralph loop + persona voting** — 단발 사이클을 multi-iteration Ralph wrapper로 확장 + ambiguity 발생 시 24 agent 풀에서 카테고리별 3~5명 자동 dispatch + moderator 중재로 무인 결정. 진정한 무인 사이클 (디자인 결정 포함, 본격 SaaS 빌드 가능).
  - 신규 `core/skills/auto-build/data/persona-mapping.json` — 카테고리 7개(design/auth/perf/architecture/ui/test/docs) → persona 풀 매핑
  - 신규 `core/skills/auto-build/scripts/persona-vote.sh` — vote dispatch 명령 stdout (orchestrator가 실 Agent tool 호출) + jsonl `vote_triggered` 이벤트
  - `orchestrator.md` 확장 — `## Ralph Loop Wrapper` 섹션 (iter 변수, 종료 조건 3, branch base = 직전 iter tip), P3 P3a/P3b 분기 (P3b: vote 호출 → moderator 중재 → 결정 주입)
  - `auto-build-safety.sh` cap 상향 — token 130k → 200k (vote 1회당 ~5k × 30 iter = 150k 여유), 신규 `AUTO_BUILD_MAX_ITERATIONS` 30 차단
  - `SKILL.md` 스킵 조건 완화 — "디자인 결정 포함" / "HARD-GATE 전체 등급" 제거 (vote가 자동 결정 / Ralph가 PR 분할)
  - `evals.json` 9 → 13 케이스 (Phase 2 vote/Ralph 4 신규), version 2.0.0
  - 설계 근거: `.claude/memory/brainstorms/20260507-212317-auto-build-phase2-ralph-loop-persona-vote.md`
  - 구현 plan: `.claude/plans/20260507-213353-auto-build-phase2-ralph-vote.md` (T1~T12)
- **외부 sync로 누적된 agents 12 + skills 23 import** — `core/agents/` 12 (api-architect, architecture-reviewer, devops-engineer, frontend-design-specialist, performance-optimizer, product-strategist, project-planner, security-specialist, supabase-db-specialist, technical-writer, test-writer, ux-researcher), `core/skills/` 23 (agent-browser, b2b-landing, codebase-analyzer, debate, dependency-manager, deploy-safety-guard, ebook-writing, error-path-analysis, idea, korean-privacy-terms, orchestrate, performance-checker, product-thinking, remotion-studio, retro, security-audit, seo-master, site-auditor, start-docs, sync-claude-md, sync-workflow, web-design-guidelines, webapp-testing). 156 파일, +36685.
- **`session-memory-sync.sh` Stop hook** — 세션 종료 시 `~/.claude/` 메모리를 `claude-memory` orphan branch에 background 자동 push. 머신 간(집↔회사) 동기화 자동화 — `sync-memory.sh push`를 수동 호출할 일 줄임.
  - rate limit 30분 (network 부하 방지) — `.claude/.last-memory-sync` 타임스탬프 추적
  - opt-out: `export VIBE_FLOW_AUTO_MEMORY_SYNC=0`
  - background `nohup ... &` 실행 — 사용자 다음 입력 차단 X
  - sync-memory.sh가 chmod +x 안 된 환경 대응(`-f` 검사)
  - events.jsonl `type=memory_sync_triggered` 1줄 기록
  - `<memory-context>` wrapper 안내 — 회사 머신은 `bash sync-memory.sh pull --force`로 받기

### 수정
- **`sync-memory.sh` chmod +x** — 실행 권한 누락 fix (이제 직접 호출 가능, 이전엔 `bash sync-memory.sh ...` 필수)

## [1.6.0] - 2026-05-05 — auto-build (자율 사이클) + character system 정리

vibe-flow v2 첫 사이클. **maker가 자는 시간을 가치로 만든다** — 야간 자율 사이클 토대 (`/auto-build`) + Phase 1.1 dogfooding 강화.

### 추가
- **`/auto-build` Phase 1.1 — orchestrator 강화 (#32, Closes #31)** — dogfooding 발견 4 design gap 해소.
  - F1 (high): P0.1 배포 fail-fast — hook + run-log + orchestrator.md 미배포 시 즉시 abort `deployment_missing`
  - F3 (high): P1 자율 spec 직접 작성 — `/brainstorm` 스킬 호출 X. orchestrator가 prepared 4문항 답변에서 5 H2 헤더 spec 합성. 합성 실패 시 abort
  - F4 (medium): P2 HARD-GATE 분기 — `inline` → P3 직행, `brief` → plan 생성, `full` → abort
  - F5 (medium): P4 project-aware verify — `/verify` 의존 X. `package.json scripts` (test/build/lint/typecheck) detect 후 실재 명세만 실행
  - evals.json +4 케이스 — 결정 트리 회귀 검증
- **`/auto-build "<task>"` Core 스킬 — Phase 1 MVP** — 단일 task one-shot 자율 사이클. brainstorm → plan → 구현(TDD) → /verify → /commit → /finish 까지 maker가 자는 동안 완주.
  - 진입점: `core/skills/auto-build/SKILL.md`. 본체 시퀀스: `orchestrator.md` (P0 전처리 → P1~P5 → P-end 후처리)
  - 안전 hook: `core/hooks/auto-build-safety.sh` (PreToolUse). `AUTO_BUILD_MODE=1` 일 때만 활성. destructive op 6+ 차단(`rm -rf`, `git reset --hard`, `git push --force`, `--no-verify`, `chmod 777`, fork bomb), token cap (`AUTO_BUILD_TOKEN_CAP` 기본 130k), file count cap (`AUTO_BUILD_FILE_CAP` 기본 19, HARD-GATE 20+ 자율 차단)
  - 사이클 이력: `.claude/memory/auto-build-runs.jsonl` (start/abort/done 이벤트, NFC 한글 경로 정규화)
  - eval: `core/skills/auto-build/evals/evals.json` 5 케이스 (orchestrator phase 헤더 / hook 차단 / hook 비활성 통과 / innocent 통과 / run-log append)
  - 설계 근거: `.claude/memory/brainstorms/20260504-103257-vibe-flow-v2-overnight-autonomous-build.md`
  - 구현 plan: `.claude/plans/20260504-194208-vibe-flow-auto-build-phase1.md` (T1~T10)
  - **Out of scope**: 다중 task 큐(Phase 2), CronCreate 야간 스케줄(Phase 2), dashboard `/morning`(Phase 3), retrospective 자가 진화(Phase 4)
- **GitHub Actions templates — `perf.yml` (#28)** — Lighthouse CI workflow. PR push 시 URL 1개 자동 측정 → comment 형태 결과. opt-in (manual copy from `templates/.github/workflows/`). 1.5.0의 verify/eval-regression/security 3종에 이어 4번째 템플릿.

### 호환
- ✓ 1.5.0 Core 20 + Extension 11 스킬 모두 유지 (Core 21 = 20 + /auto-build)
- ✓ Hook 25 → 26 (auto-build-safety.sh 추가)
- ✓ 자율 모드 토글은 `AUTO_BUILD_MODE=1` env로 격리 — 비-자율 작업에 영향 0
- 짝 운영 dashboard 1.1.0 ([dashboard CHANGELOG](https://github.com/SONGYEONGSIN/vibe-flow-dashboard/blob/main/CHANGELOG.md)) 와 auto_build_* 이벤트 형식 정합 (run-log.sh 출력 ↔ event-map.ts mapping)

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
