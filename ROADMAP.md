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

- [ ] **TUI 옵션** (vibe-flow-tui — 터미널 대시보드) — 미정. 메이커 사용 패턴 누적 후 결정.

### 🔵 Phase 4 — 거버넌스 + 확장

#### 메이커 도구화
- [x] telemetry 통합 (스킬별 사용 빈도 → 경량화 결정 데이터) — `/telemetry` 스킬
- [x] eval 자동 회귀 알림 (CI 통합) — `.github/workflows/eval-regression.yml`
- [x] 빌드 자체 메트릭 dashboard — README 배지 + `scripts/sync-readme-badges.sh`

#### 새 Extensions 후보
- [x] **i18n** — `/i18n-audit` 스킬 (라이브러리 무관 누락/미사용/불일치 검출)
- [x] **k8s** — `/k8s-audit` 스킬 (5 anti-pattern: resources / image:latest / securityContext / label-selector / Secret 평문)
- [ ] **mobile** — React Native / Flutter 보강 — **보류**, RN/Flutter 단일 스킬 일반화 어려움. 메이커 본인의 mobile 사용 데이터 누적 후 재평가 (또는 별도 extension `extensions/rn/` + `extensions/flutter/` 분리 검토).

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
