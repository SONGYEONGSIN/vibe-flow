# vibe-flow ROADMAP

내부 감사 결과 + 커뮤니티 리서치 + 메이커 비전 기반 작업 큐.

**머신 간 동기화**: Claude Code 메모리는 로컬 저장이라 회사↔집 공유가 안 됨.
이 파일이 진행 상황의 **단일 진실의 원천(single source of truth)**.

---

## 완료

### Phase 0 — claude-builds 시기 (1.0.0 이전)

#### 디자인 시스템
- [x] DESIGN.md 9섹션 포맷 지원 (VoltAgent/Google Stitch)
- [x] 디자인 토큰 / 하드코딩 색상 / 다크 모드 분리 규칙
- [x] /design-sync 7/5/6단계 워크플로우 (URL/이미지/HTML)
- [x] /design-audit + design-lint 훅 (oklch 포함)

#### 인프라
- [x] _common.sh DRY화, agents.json 단일 소스, validate.sh 5단계
- [x] settings 매처 통합 (PostToolUse 9→5, Stop 3→1)

#### 커뮤니티 출처 통합
- [x] SQLite Instinct Store (affaan-m/everything-claude-code)
- [x] 실시간 관측 스트림 (disler/claude-code-hooks-multi-agent-observability)
- [x] TDD 강제화 (obra/superpowers)
- [x] Pair Mode + Validator (disler/claude-code-hooks-mastery)
- [x] Hermes Agent 5 패턴 (NousResearch/hermes-agent)
  - Error Classifier (13-class)
  - Context Compressor (12KB 예산)
  - Memory Context Fencing
  - Smart Model Routing
  - Self-Evolution Loop (5 게이트 + A/B 비교)
- [x] Release skill (Shpigford/chops)
- [x] Karpathy 4 원칙 체리피킹 (forrestchang/andrej-karpathy-skills)

#### 4 process skills 도입
- [x] /brainstorm — 의도 탐색
- [x] /plan — 멀티스텝 추적
- [x] /finish — 의사결정 트리
- [x] /receive-review — 리뷰 비판적 수용

### Phase 1 — vibe-flow 리브랜드 + 경량화 (1.1.0)

- [x] **Repo rename**: claude-builds → vibe-flow
- [x] **Core/Extensions 분리**: 14 스킬 core / 9 스킬 extensions / 모든 hook core
- [x] **setup.sh CLI**: --extensions, --all, --list, --info, --remove, --check
- [x] **State 파일** (.vibe-flow.json) 도입
- [x] **마이그레이션 자동 감지** (시그니처 추론)
- [x] **validate.sh 10 stages** (state + reconciliation 추가)
- [x] **README 재구성**: 725 → ~120줄
- [x] **docs/ 분리**: REFERENCE / ARCHITECTURE / MIGRATION / ONBOARDING
- [x] **글로벌 심볼릭 갱신** (Core only) — vibe-flow 1.1.0 머지 시 완료
- [x] **CHANGELOG 1.1.0** breaking notice + 호환 명시 — vibe-flow 1.1.0 머지 시 완료

---

## 미완 (우선순위 순)

### 🟢 Phase 2 — UX 개선 (다음 후보)

#### 신규 스킬
- [x] `/onboard` — 인터랙티브 단계별 가이드 (실력 자가진단 + 추천) (PR #2)
- [x] `/menu` — 24 스킬 카테고리별 발견성 (실력별 추천)
- [x] `/inbox` — 12 에이전트 inbox 통합 뷰

#### Statusline 강화
- [x] hook live status 표시 (마지막 실행 결과)
- [x] 활성 plan 진행도 표시
- [x] verify 결과 표시 (✓/✗/⊘)

### 🟡 Phase 3 — UI 레이어

- [x] **vibe-flow-dashboard** (별도 repo) — https://github.com/SONGYEONGSIN/vibe-flow-dashboard
  - Next.js 16 + TypeScript 5 + Tailwind 4 + chokidar + SSE
  - 5 영역: events stream (라이브) / 활성 plan / inbox / 메트릭 / .claude 구조
  - `VIBE_FLOW_PROJECT` 환경변수로 vibe-flow 프로젝트 지정
  - localhost:9999 (PORT env로 변경 가능)
  - **Source 침범 0** — vibe-flow의 Layer 1/2 그대로, dashboard는 읽기 전용
  - Phase A scaffold + B MVP (SSE) + C-1~C-4 (4영역) 모두 완료

- [ ] **TUI 옵션** (vibe-flow-tui — 터미널 대시보드) — **미정**.
  - **재평가 트리거**: dashboard 사용 패턴 (events.jsonl `dashboard_*` 또는 사용자 피드백) 누적 후
  - **검토할 라이브러리**: ink (React for terminal) — Next.js 컴포넌트 일부 재사용 가능 / blessed (전통적) / charm.sh (Go, 별도 binary)
  - **데이터 소스**: dashboard와 동일 (`.claude/events.jsonl`, `plans/`, `messages/inbox/`, `memory/`, `.vibe-flow.json`)
  - **차별 가치**: 터미널 내장 (브라우저 미사용 / SSH 환경) — dashboard 보완재
  - **대안**: 단순 `tail -f` + `jq` 스크립트 (`scripts/watch-events.sh`)로 충분할 수도 — TUI 만들기 전 검토

### 🔵 Phase 4 — 거버넌스 + 확장

#### 메이커 도구화
- [x] telemetry 통합 (스킬별 사용 빈도 → 경량화 결정 데이터) — `/telemetry` 스킬
- [x] eval 자동 회귀 알림 (CI 통합) — `.github/workflows/eval-regression.yml`
- [x] 빌드 자체 메트릭 dashboard — README 배지 + `scripts/sync-readme-badges.sh`

#### 새 Extensions 후보
- [x] **i18n** — `/i18n-audit` 스킬 (라이브러리 무관 누락/미사용/불일치 검출)
- [x] **k8s** — `/k8s-audit` 스킬 (5 anti-pattern: resources / image:latest / securityContext / label-selector / Secret 평문)
- [ ] **mobile** — React Native / Flutter 보강 — **보류**.
  - **사유**: RN과 Flutter 생태계 완전히 다름 (JS/TS+native vs Dart/자체 렌더링). 단일 스킬 일반화 불가.
  - **재평가 트리거**: 메이커가 mobile 프로젝트 시작 + `/telemetry`에서 mobile 관련 events 누적
  - **분리안**: `extensions/rn/` (RN 전용) + `extensions/flutter/` (Flutter 전용) 별도 카테고리
  - **공통 영역만 가능 시**: package.json/pubspec.yaml 의존성 audit (취약 패키지 / outdated / unused) 1 스킬

#### v1.x 후속 후보 (우선순위 미정)

- [ ] **security 강화** — OWASP Top 10 자동 체크 hooks (`/security` 스킬 보강)
  - 현재 `/security` 단일 스킬만. PostToolUse hook으로 `Write/Edit` 시 자동 lint 추가 검토
  - 후보 검출: SQL injection, XSS, hardcoded secret, eval(), insecure deserialization

- [ ] **performance audit** — Lighthouse / Web Vitals 통합
  - `/perf-audit` 스킬 후보 — Next.js + Lighthouse CLI 자동 실행 + 결과 events에 push
  - 외부 의존: lighthouse, puppeteer (design-system extension과 유사 패턴)

- [ ] **GitHub Actions templates** — vibe-flow 자체 CI 템플릿 모음
  - 현재 `.github/workflows/eval-regression.yml` 1개만. 사용자 프로젝트용 템플릿 (`templates/.github/workflows/`) 추가 검토
  - 후보: vibe-flow-check.yml (validate.sh 자동), pr-summary.yml, security-scan.yml

- [ ] **`/inbox` 메시지 작성 스킬** — `/inbox send <agent> <subject> <body>` (현재 message-bus.sh CLI만 있음)

- [ ] **`/budget` token 추정 모드 (옵션)** — Claude Code session-logs/*.json에 cost 데이터 있으면 정확 비용 표시

- [ ] **`/telemetry` 기간 옵션** — `/telemetry --period 7|30|90` (현재 30일 고정)

- [x] **🎮 동적 캐릭터 시스템 (게임화)** — MVP 코드 인프라 완료 (`feat/dynamic-character-system`)
  - **spec**: `docs/superpowers/specs/2026-04-30-dynamic-character-system-design.md`
  - **plan**: `docs/superpowers/plans/2026-05-01-dynamic-character-system.md`
  - **구현**: vibe-flow-dashboard `/characters` 페이지 — 12 chibi 캐릭터 그리드, L2 wander + L3 event-driven 이동, 정적 대사 풀, Stage unlock, events.jsonl 반응. 게임 엔진 X (React/CSS).
  - **상태**: 18 tasks 완료, 29 단위 테스트 PASS. 코드는 production-ready, 픽셀 에셋은 placeholder(transparent PNG → mainColor fallback) — 실제 chibi 스프라이트는 별도 후속 작업.
  - **MVP 후속 후보** (spec 13절):
    - `dynamic-character-system-assets` — AI 픽셀 에셋 12종 생성/Aseprite 후처리
    - `dynamic-dialogue-llm` — LLM 동적 대사
    - `character-customization` — 사용자 이름/대사 커스텀
    - `vibe-flow-events-v2` — 의미적 이벤트 emit 추가 (commit_created, pair_started 등)
    - `character-roaming-phaser` — Phaser 자유 로밍
    - `character-leveling` — 레벨/뱃지

### 🔵 P5 전략 공백: 토큰/비용 예산 프레임워크 ✅ 완료

- **배경**: /pair / /discuss / 오케스트레이터 병렬 실행 시 무제한 과금 가능
- **구현**: `/budget` 스킬 + `budget-warn.sh` Notification hook + `.claude/budget.json`
- **방식**: 호출 카운트 기반 (token 정확 비용 X). 5 무거운 스킬 추적. 정보만 (차단 X).

---

## 작업 재개 절차 (머신 간)

```bash
# 1. 최신 상태 확보
cd ~/dev/vibe-flow && git pull origin main

# 2. ROADMAP 확인 → 다음 항목 선택
cat ROADMAP.md

# 3. 작업 시작 — Claude Code 세션에서:
#    "ROADMAP Phase 2 첫 항목 진행"
```

## 갱신 규칙

- 작업 **시작** 시: 해당 항목 앞에 "🚧 진행중" + 커밋
- 작업 **완료** 시: `[ ]` → `[x]`, 미완 → 완료 섹션 이동, 커밋 해시 추가
- 새 아이디어: "미완"에 우선순위와 함께 추가
- ROADMAP 갱신은 해당 작업 커밋과 함께 묶음
