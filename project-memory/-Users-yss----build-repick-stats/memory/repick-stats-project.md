---
name: repick-stats-project
description: repick-stats 프로젝트의 목표·방향·성장 로드맵
metadata: 
  node_type: memory
  type: project
  originSessionId: c01fb6d5-b9fa-4361-8e54-26f5611ea0ef
---

repick-stats = 한국부동산원 R-ONE OpenAPI 기반 **지역 비교 아파트 가격 대시보드**. 사용자가 관심 지역을 골라(pick) 아파트 매매·전세 가격지수를 시계열로 겹쳐 비교.

**결정된 방향** (2026-07-04 brainstorm): "지역 비교 대시보드" 방향 + **실서비스 지향, 단 MVP부터 단계적**. 핵심 근거 — 실서비스의 심장은 R-ONE 데이터 정규화·캐싱 레이어이고 계정·알림도 그 위에 얹히므로, 그 레이어를 먼저 검증. 인증·DB·결제는 사용자 검증 후 증축 (조기 구축 금지).

**MVP 완료** (T1~T10): Next.js 16 App Router + TS + Tailwind + Recharts. Server Component + searchParams 아키텍처(useEffect fetch 금지 규칙 준수), R-ONE 키는 서버 전용(`lib/reb/client.ts` `import 'server-only'`)으로 은닉 — HTML·클라이언트 번들 미노출 검증 완료.

**2차 완료 — 실거래가 탭 추가** (2026-07-07): 국토교통부 아파트 매매 실거래가 API 통합. 앱은 이제 두 탭 — **가격지수**(R-ONE, 시/도 지수) + **실거래가**(국토부, 동·단지·면적·층·거래가). 시군구(전국 250개 코드표 `src/data/lawdCodes.ts`) 선택 → 법정동·단지 필터 → 요약/월별 시세차트/거래테이블. 데이터소스가 둘로 갈림: R-ONE는 구 단위 지수까지, 실거래가(효성동·특정 단지)는 국토부 API.

**국토부 실거래가 API 함정 3가지** (`src/lib/molit/`에 반영): ①WAF가 비-브라우저 User-Agent를 400 "Request Blocked"로 차단 → 브라우저 UA 헤더 필수. ②fast-xml-parser 기본값이 `<resultCode>000</resultCode>`을 숫자 0으로 변환 → `parseTagValue:false` 필수. ③강원·전북은 특별자치도 전환 후 신 법정동코드(51·52) 사용, 구코드(42·45)는 조용히 0건 반환. 키는 `.env.local` `DATA_GO_KR_KEY`(data.go.kr, R-ONE 키와 별개).

**성장 로드맵** (미착수): 계정(Clerk 등) → 관심지역 저장(Postgres) → 임계치 알림(Vercel Cron + Discord/이메일). Vercel 배포는 사용자 로그인 필요로 보류.

R-ONE API 사용법·STATBL_ID·데이터 정규화는 코드(`src/lib/reb/`)와 `.claude/plans/repick-stats-mvp.md`에 있음. R-ONE 데이터는 **시간 오름차순 페이지네이션**(최근 데이터가 마지막 페이지)이라 전체 수집 후 캐싱하는 패턴 사용.
