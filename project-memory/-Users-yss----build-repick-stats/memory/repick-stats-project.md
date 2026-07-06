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

**성장 로드맵** (미착수): 계정(Clerk 등) → 관심지역 저장(Postgres) → 임계치 알림(Vercel Cron + Discord/이메일). T11 Vercel 배포는 사용자 로그인 필요로 보류.

R-ONE API 사용법·STATBL_ID·데이터 정규화는 코드(`src/lib/reb/`)와 `.claude/plans/repick-stats-mvp.md`에 있음. R-ONE 데이터는 **시간 오름차순 페이지네이션**(최근 데이터가 마지막 페이지)이라 전체 수집 후 캐싱하는 패턴 사용.
