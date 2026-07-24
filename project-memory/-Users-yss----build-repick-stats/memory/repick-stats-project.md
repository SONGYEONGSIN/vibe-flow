---
name: repick-stats-project
description: repick 프로젝트의 목표·방향·아키텍처 (Phase 1 완료 상태)
metadata: 
  node_type: memory
  type: project
  originSessionId: c01fb6d5-b9fa-4361-8e54-26f5611ea0ef
---

repick = 아파트 **실거래가·시세 공개 서비스** (일반 대중 대상, Next.js 16 App Router + TS + Tailwind v4). 데이터: 국토교통부 실거래가 + 한국부동산원 R-ONE.

**히스토리**: 초기엔 '지역 비교 가격지수 대시보드 + 실거래가 탐색'(구버전, `../repick-stats-backup-20260707-205214`에 백업)으로 만들었으나, 2026-07-07 사용자가 **공개 서비스로 범위 재설정** + 처음부터 재구축. 키 2개(.env.local)와 전국 250 시군구 코드표(`src/data/lawdCodes.ts`)만 보존하고 클린 슬레이트로 재출발. vibe-flow 하네스 정식 설치(`.claude/` — agents/hooks/skills/rules), brainstorm→plan→TDD 워크플로우로 진행.

**로드맵** (4축, 순차): P1 실거래 딥다이브(✅) → P2 지역 비교 지수 대시보드 `/compare`(✅, reb 레이어) → P3 투자 스크리너 `/screener`(✅, 전세가율 A_2024_00072 + 전월세전환율 A_2024_00156) → **P4 계정+관심단지+알림(DB+인증+Cron, 미착수)**. 백로그: 실거래 랭킹·지도 히트맵·시세 카드 이미지. 커밋: chore(하네스)/feat P1/P2/P3 4개, 워킹트리 클린. 아직 미배포.

**Phase 1 아키텍처** (완료, `.claude/plans/repick-phase1.md`):
- 단지 URL `/apt/[aptSeq]` — aptSeq(단지 일련번호, 형식 `{lawd}-{serial}` 예 "11680-290")가 단지당 안정적 1:1(실API 검증). lawd는 aptSeq에서 파싱(`features/apt/slug.ts`).
- 지역 URL `/region/[lawd]` (시군구), 홈=지역검색 진입, `/search`.
- SEO: 지역 SSG 성격 + 단지 ISR(revalidate 12h) + `sitemap.ts`(250 지역) + `robots.ts` + generateMetadata(canonical) + 루트 OG(라틴).
- 데이터 레이어 `lib/molit/`(client 서버전용·UA·parseTagValue:false·동시성4 / aggregate / types), `features/{apt,region,search}`.
- 검색: 아파트 전역 인덱스 없음(시군구+월 API) → **지역 검색이 진입점**, 단지는 지역 페이지에서 필터.

**디자인 — "데이터 저널리즘"** (`DESIGN.md` 권위 소스, designer가 수립): 웜 아이보리 페이퍼(#faf8f4 계열, oklch hue 83) + 딥 잉크 + **피콕 틸 브랜드**(hue 200, 파랑/초록 배제 — 한국 부동산 상승=적/하락=청 관례와 무충돌). Pretendard(sans, CDN) × Newsreader(serif, 숫자 전용). 라이트 기본 + .dark. 보더-퍼스트(그림자 없음), 숫자 tabnum+우측정렬, base 14px. 토큰: `globals.css @theme` + `lib/design-tokens.ts`(chartColorVars·marketColors). 시장색 상승=text-up(적)/하락=text-down(청).

**국토부 실거래가 API 함정 3종** (`lib/molit/`에 반영): ①WAF가 비-브라우저 UA를 400 차단 → 브라우저 UA 필수. ②fast-xml-parser `parseTagValue:false` 필수(안 하면 resultCode "000"→0 오판). ③강원·전북은 특별자치도 신 법정동코드(51/52), 구코드(42/45)는 조용히 0건. 키는 `.env.local`: `REB_API_KEY`(R-ONE), `DATA_GO_KR_KEY`(국토부, data.go.kr). data.go.kr 개발계정 키는 발급 후 최대 1~2시간 전파 지연.

**미해결/후속**: 배포(Vercel, NEXT_PUBLIC_SITE_URL 설정 필요) · Pretendard self-host(현재 CDN) · 한글 단지명 OG(폰트 임베딩 필요) · 미커밋 상태.
