---
name: closing-local-scrape-pull-trigger
description: "서비스 마감 스크랩 '로컬 수동 실행' 풀 방식 원격 트리거 구조 + proxy PUBLIC_PATHS 함정"
metadata: 
  node_type: memory
  type: project
  originSessionId: fbde5872-232f-48f3-992e-704c796d6e5e
---

서비스 마감 스크랩은 회사 PC(residential IP)에서만 동작한다 — 웹/GitHub Actions는 데이터센터 IP라 Cloudflare 로그인 차단(#445, [[weekly-report-no-graph-copy]]와 무관). 웹에서 on-demand 실행하기 위해 **풀(pull) 방식 원격 트리거**를 구축(PR #549, 2026-06-17).

**구조**: 웹 "로컬 실행 요청" 버튼 → `closing_scrape_requests`(pending) 적재 → 회사 PC 폴러(`poll-local.ps1`, 작업 스케줄러 `OPS-Console-Closing-Poll` 5분 간격)가 `GET /api/closing/scrape-request`로 원자적 claim(→running) → `run-local.ps1` 실행 → `POST`로 완료 보고(done/failed). API 인증은 `CRON_SECRET`(Bearer), PC는 `.env.local`의 `OPS_CONSOLE_BASE_URL`+`CRON_SECRET` 사용. UI는 AutomationHub 테이블의 행(`LocalScrapeRequest`), 비admin은 알럿 게이트.

**함정 (PR #550)**: 새 CRON_SECRET 엔드포인트는 반드시 `src/proxy.ts`의 `PUBLIC_PATHS`에 추가해야 한다. 누락 시 세션 없는 호출(PC 폴러)이 인증 가드에 막혀 `/login` HTML(200)로 리다이렉트됨 → `Invoke-RestMethod`가 그걸 받아 `request:null`로 조용히 종료(에러 없음). 증상: 폴러가 출력 없이 즉시 종료 + 요청이 pending에 머묾. proxy matcher는 `/api`를 포함하므로 API도 가드 대상.

**Why:** ingest/run-log는 이미 PUBLIC_PATHS에 있었으나 신규 scrape-request만 빠뜨려 동일 클래스 버그 재발.
**How to apply:** CRON_SECRET/외부호출 엔드포인트 추가 시 PUBLIC_PATHS 등록을 체크리스트로. 검증은 prod에서 `fetch(.../api/...)`의 content-type이 application/json인지 확인(html이면 가드에 막힌 것). DB 스키마 변경은 [[supabase-migration-apply-before-merge]]대로 사용자 SQL Editor 적용 후 REST 검증.
