---
name: Folio = OPSROOM Next.js 포팅
description: Folio 프로젝트는 design-ref의 folio-login.html / folio-dashboard.html 정적 mockup을 Next.js 16 + Tailwind v4로 옮기는 작업. Nexus와 동일 패턴.
type: project
originSessionId: fa4d7468-5d81-4499-b474-305dc529d2ce
---
**Folio = "운영실 OPSROOM" 정적 HTML mockup → Next.js 포팅 프로젝트.**

- mockup 위치: `/Users/yss/개발/build/Folio/design-ref/folio-{login,dashboard}.html` — 이게 명세 그 자체. 이미 4-tier 반응형(≥1280, 1024-1279, 768-1023, 480-767, ≤479) 완성. 디자인 정체성: washi(종이) 베이스 + vermilion(낙관) 액센트 + Pretendard + 에디토리얼 톤.
- design-ref에 있는 `2026-04-25-dashboard5-mobile-refactor-{design,plan}.md`는 **mockup 자체를 만드는 과정의 산출물** — 이미 끝난 작업. Folio의 Next.js 포팅 plan은 별개로 존재하지 않음. (스텝 분리는 인라인으로 진행: 1=토큰, 2=로그인, 3=대시보드)
- Nexus(`/Users/yss/개발/build/Nexus/`)는 동일한 워크플로(mockup HTML → Next.js 16) 진행 중. 구현 순서 동일: Foundation(토큰) → Login → Dashboard. CLAUDE.md 구조도 1:1.

**Why:** 사용자가 *"에디토리얼 톤 사내 운영 관리 시스템"*이라고 정의 (CLAUDE.md). mockup의 톤(전통 한국 에디토리얼)이 핵심 차별화. 세 단계 분리는 사용자가 명시 동의한 진행 순서.

**How to apply:**
- mockup이 명세이므로 brainstorming 가치 낮음 (그러나 verification + review는 유지). 스코프/시각 결정은 mockup 따르되 React 시맨틱·a11y는 내가 개선해야 함 (`<div onClick>` → `<button>` 등).
- 빌드 산출물: `package.json`(name=folio), `src/app/{login,dashboard}/page.tsx`, `src/app/dashboard/_data.ts` + `_components/`, `src/lib/design-tokens.ts`, `src/app/globals.css`. Tailwind v4 `@theme inline`로 CSS 변수 → utility 매핑.
- 사용자가 design-ref에 새 mockup을 추가하면 그게 다음 단계. 임의 추측 금지.

**완료된 단계 (2026-04-26 세션):**
- 스텝 1 (디자인 토큰), 스텝 2 (로그인 UI), 스텝 3 (대시보드 UI + 27 e2e), 스텝 #3 (`/` 리디렉트), 스텝 #2 (Inspector 동적 데이터)
- 스텝 #1 (Supabase auth 연결): Nexus와 같은 Supabase 프로젝트 공유 (3개 키 `cp Nexus/.env.local Folio/.env.local`로 이전). `@supabase/ssr` + `zod` 의존성. `src/lib/supabase/{client,server,middleware}.ts` + `src/middleware.ts` + `src/features/auth/{schemas,actions,actions.test}.ts`. 로그인 폼은 `useActionState` + Server Action. Microsoft SSO 버튼은 disabled + "준비 중" 라벨 (Azure AD provider 미설정).
- 스텝 #2 (로그아웃 UI): `DropdownRow.action: 'signout'` 메타로 메뉴바 "파일 → 로그아웃" 항목을 `signOut()` Server Action에 연결. dropdown row 클릭 시 항상 닫힘.
- 미들웨어: `PUBLIC_PATHS=['/login']`, 인증된 사용자가 `/login` 접근 시 `/dashboard`로, 미인증 비공개 접근 시 `/login`으로 리디렉트
- E2E TEST_USER 패턴: `TEST_USER_EMAIL`/`TEST_USER_PASSWORD`(`.env.local`) 있으면 dashboard 시나리오 실 로그인 검증, 없으면 자동 skip (Nexus와 동일)

**남은 자연스러운 스텝:**
- TEST_USER_* 채우기 (사용자 작업) → dashboard e2e 32건 자동 활성화
- 시각 회귀(`/design-sync`) — orthogonal
- Microsoft SSO 실연결 (Supabase Azure AD provider 설정 필요)
- 로그아웃 UI (Sidebar의 footer 또는 menu의 "로그아웃" dropdown row 연결)
- DB 스키마 + RLS 정책 (Folio 도메인 — 서비스/장애/배치 등의 실 데이터)
