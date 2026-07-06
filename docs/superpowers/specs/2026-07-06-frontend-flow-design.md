# `/frontend-flow` — 오케스트레이션 스킬 설계

- **작성일**: 2026-07-06
- **상태**: 설계 승인됨 (구현 계획 대기)
- **위치(예정)**: `extensions/design-system/skills/frontend-flow/`

## 1. 목적 (Conclusion First)

신규 프로젝트에서 **참고사이트 URL + `DESIGN.md`를 넘기면, 그 내용 기반으로 프론트엔드를 실제 제작(디자인 스킬 포함)까지 진행**하는 단일 오케스트레이션 스킬을 만든다.

핵심 통찰: 파이프라인의 상당 부분은 **이미 존재**한다(`/design-sync`, `/design-audit`, `frontend-design-specialist`, `rules/design.md`, `web-design-guidelines`). 따라서 `/frontend-flow`는 "전부 새로 만드는 것"이 아니라 **기존 자산을 지휘하면서 빠진 3가지를 얹는 얇은 오케스트레이터**로 정의한다:

1. **DESIGN.md 입력 병합** — 기존 `/vibe-design`은 URL 전용. "why(DESIGN.md) + what(사이트 HTML)" 병합 부재.
2. **디렉팅 게이트** — 모호한 결정 지점에서 사용자가 방향을 정하는 중간 승인.
3. **기계적 anti-slop pre-flight** — 주관적 "3초 테스트"를 이진 pass/fail 단언으로.

## 2. 결정 사항 (브레인스토밍 합의)

| 항목 | 결정 |
|---|---|
| 형태 | 새 오케스트레이션 스킬 `/frontend-flow` (에이전트 강화·부트스트랩 편입 대신) |
| 종착점 | 프론트엔드 실제 제작 (디자인 스킬 포함) |
| 기술 스택 | **기본 고정**(Next.js + Tailwind v4 + shadcn/ui + `design-tokens.ts`), 예외만 문맥 라우팅 |
| 기존 자산 | 가져올 수 있으면 재사용, 부족분만 신규 설계 |
| 디렉팅 | 모호한 지점은 게이트에서 사용자가 지시 (조용한 추측 금지) |
| 대상 | 신규 프로젝트 (`start-docs` 부트스트랩과 별개 흐름) |

## 3. 파이프라인 (P0–P5)

```
입력: 참고사이트 URL (0~n, 선택) + DESIGN.md 경로 (선택)   ※ 최소 1개 필수

P0. Intake
  · 의존성 fail-closed 프리플라이트 (없으면 설치법 출력 후 중단 — 거짓 점수 방지)
  · 입력 모드 감지: URL / 이미지 / 로컬
  · 모드 감지: 신규 빌드 vs 리스킨(기존 앱 개편)

P1. Analyze  [재사용: /design-sync]
  · 사이트 → 토큰 역추출 (고정 스키마: 8종 요소 × 21종 CSS 속성, 완전성 보장)
  · DESIGN.md → 9섹션 파싱
  · 병합: why(DESIGN.md 의도) + what(사이트 HTML 사실) → 루트 DESIGN.md '정본'
    (9섹션 + YAML 프론트매터 = 머신리더블 토큰)
  · 산출: preview.html + preview-dark.html (게이트 시각 확인용)
  · 충돌(사이트 토큰 ↔ DESIGN.md) 있으면 → 게이트 A 로 표시

── 게이트 A (조건부): 충돌 항목별 사용자 선택

P2. Research / Select
  · 컴포넌트 선정을 '계약'으로: shadcn 카탈로그에서 when_to_use / not_for 명시
  · 3회 이상 반복 패턴 자동 추출 후보(common/), core vs site-specific 분리
  · 필요한 플러그인/API/앱쉘/폰트/아이콘/모션 라이브러리 선정 리포트 → frontend-plan.md
  · 예외 라우팅 조건이면 대안 UI 라이브러리 제안

── ★ 게이트 B (메인 디렉팅, 항상):
     prototype.html + 정본 DESIGN.md(MASTER) + frontend-plan + '조용히 바꾸면 안 되는 것' 목록
     승인/수정/재지시. 모든 모호한 결정을 AskUserQuestion 으로 여기서 처리.
     ※ 비싼 P3 빌드 전에 정적 프로토타입으로 먼저 승인 → 토큰 낭비 방지.

P3. Build  [재사용: frontend-design-specialist]
  · 앱쉘 + 핵심 컴포넌트 + 대표 화면
  · 토큰만 사용 (design-lint.sh 훅이 하드코딩 색상 실시간 차단)
  · 다화면이면 stitch-loop 바톤 방식 — 바톤 파일이 정본 토큰을 매 화면 프롬프트에 강제 주입
    → 화면 간 디자인 일관성 보장

P4. Verify  [재사용: /design-audit + /design-sync + web-design-guidelines]
  · 색상 커버리지 (oklch 인식 하드코딩 스캔)
  · 싱크율 pre/post 수치 (pixelmatch) — 모드별 목표(URL 95% / 이미지 90%)
  · 기계적 anti-slop 단언 (전부 이진 pass/fail):
    accent==1, radius계==1, 레이아웃패밀리≥4/8, em-dash==0, 채도<80%,
    금지폰트 grep, eyebrow 밀도비 ≤ ceil(sectionCount/3), 순수 검정 금지
  · 실제 브라우저 a11y (Playwright 접근성 트리 — 렌더된 DOM 검사, 소스 아님)
  · events.jsonl 텔레메트리 (sync_rate_initial/final/target)

── 게이트 C (리뷰, 스킵 가능): pre-flight 리포트 + 싱크율 + a11y 결과, fail 수정 재실행

P5. Learn (신규)
  · ≥90% 성공 시 learned/{site-hash}/ 에 토큰·매핑 저장 → 유사 사이트 웜스타트
```

## 4. 재사용 vs 신규

### 재사용 (수정 없이 호출/의존)

| 자산 | 위치 | 역할 |
|---|---|---|
| `/design-sync` | `extensions/design-system/skills/design-sync` | P1 토큰 역추출 + P4 싱크율 |
| `/design-audit` | `extensions/design-system/skills/design-audit` | P4 색상 커버리지 |
| `frontend-design-specialist` | `core/agents` | P3 구현 |
| `designer` | `core/agents` | P2 컴포넌트 설계(선택) |
| `design-lint.sh` | `core/hooks` | P3 실시간 색상 차단 |
| `rules/design.md` | `core/rules` | 토큰·anti-slop 기본 규칙 |
| `web-design-guidelines` | `core/skills` | P4 접근성 100+ |
| 9섹션 DESIGN.md 포맷 | VoltAgent/awesome-design-md 표준 | P1 정본 스키마 |

### 패턴만 차용 (레포 밖 · 코드 복사 아님)

- `/vibe-design` — P0→P5 오케스트레이션 구조, prototype.html, 스택락 (이 레포엔 없는 별도 스킬)
- taste-skill §14 pre-flight / §11 audit / §12 block 계약 — 규칙 텍스트
- stitch-loop 바톤 — 다화면 토큰 일관성

### 신규 파일

```
extensions/design-system/skills/frontend-flow/
├── SKILL.md                     # 얇은 오케스트레이터 (P0~P5 지휘 + 게이트)
├── references/
│   ├── pipeline.md              # 단계별 입출력·게이트 상세
│   ├── designmd-format.md       # 9섹션+YAML 정본 DESIGN.md 스키마
│   ├── anti-slop-preflight.md   # P4 기계적 단언 (+ 브랜드토큰 우선 무효화 규칙)
│   └── component-catalog.md     # shadcn 블록 when_to_use / not_for 계약
├── scripts/
│   ├── preflight-deps.sh        # P0 의존성 fail-closed 체크
│   └── anti-slop-check.js       # P4 기계적 grep 단언
└── evals/evals.json             # 대표 브리프 회귀 테스트
```

### 기존 파일 최소 수정

- `rules/design.md` — 충돌 해소 1·2 반영(§6 참조): 브랜드 토큰 우선 무효화 조항 + 마케팅/앱-UI 스코프 구분
- `extensions/design-system/README.md` — `frontend-flow` 등록
- (선택) `start-docs` / `designer` — DESIGN.md 정본 경로 정렬(드리프트 해소)

## 5. 게이트 · 실패 처리 · 범위 밖

### 게이트

| 게이트 | 시점 | 승인/디렉팅 대상 | 발동 |
|---|---|---|---|
| A | P1 후 | 사이트 토큰 ↔ DESIGN.md 충돌 항목 | 충돌 시만 |
| **B** ★ | P2 후 | prototype.html + 정본 DESIGN.md + 기술선정안 + "조용히 바꾸면 안 되는 것" | 항상 |
| C | P4 후 | pre-flight + 싱크율 + a11y 리뷰, fail 재실행 | 항상(스킵 가능) |

### 단계별 실패 처리 (부분 실행도 산출물 보존)

- P0 의존성 없음 → 설치법 출력 후 중단 (거짓 점수 방지)
- P1 추출 실패 → 부분 토큰 보존, 동적사이트면 "불완전" 명시
- P2 카탈로그 매칭 0 → core 컴포넌트로 진행(정상)
- P3 일부 화면 실패 → 성공분 보존 + 실패 목록 보고
- P4 도구 없음(Playwright 등) → graceful skip + 건너뛴 검사 명시
- Ctrl-C → 모든 산출물 유지

### 범위 밖 (Non-goals)

- 백엔드/API 구현 (프론트만 — API는 "선정"까지)
- 배포·CI
- 비-프론트 프로젝트 초기화 (`start-docs` 영역)
- 콘텐츠 카피라이팅 (브리프/플레이스홀더 기반만)
- anti-slop 마케팅 규칙을 대시보드/데이터 UI에 강제 (스코프 분리)

## 6. 해결해야 할 충돌 (조사에서 발견)

1. **anti-slop 규칙은 추출된 브랜드 토큰에 양보** — taste-skill은 `Inter`·순수 검정·채도>80%를 금지하나, 참고사이트가 실제로 쓰면 정본 토큰이 이겨야 함. P4 lint는 "브랜드 토큰 존재 시 anti-slop 기본값 무효화"로 설계. 안 그러면 게이트가 충실한 클론을 거부.
2. **대시보드/데이터 UI 예외** — taste-skill 레이아웃 규칙(3카드 금지, hero 제약)은 마케팅 표면 전용. 앱쉘/대시보드엔 오발동 → anti-slop을 마케팅 표면에만 스코프.
3. **생성적 자율성 제거** — taste-skill은 에이전트가 자유롭게 미학을 추론하는 전제. 우리는 게이트에서 확정된 DESIGN.md대로 구현. taste의 규칙/pre-flight만 차용, "자유 추론" 프레이밍은 버림.

## 7. 스킬 아키텍처 원칙

SKILL.md는 얇게 유지하고 무거운 내용(9섹션 스키마, pre-flight 매트릭스, 블록 카탈로그)은 `references/`로 분리 — progressive-disclosure로 해당 단계에서만 로드해 토큰 절약. `evals/evals.json`으로 대표 브리프 회귀 테스트.

## 8. 조사 출처

- 로컬 스킬: `/vibe-design`, `/design-sync`, `/design-audit`, `stitch-loop`, `design-md`, `extract-design-system`, `ui-ux-pro-max`, `web-design-guidelines`
- GitHub: `Leonxlnx/taste-skill`(§11/§12/§14), `VoltAgent/awesome-design-md`(9섹션 정본), `vercel-labs/agent-skills`(규칙-as-files, validate/extract-tests)
- Anthropic 문서: Agent Skills best-practices(progressive disclosure, eval-driven), Playwright a11y 게이트
