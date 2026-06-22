---
name: ops-news-feature
description: 운영부 뉴스(대학 뉴스 RSS 자동 수집) — PR
metadata: 
  node_type: memory
  type: project
  originSessionId: c638331c-95e2-4cb8-8774-151ddce704b8
---

사이드바 '개요' 그룹 **운영부 달력(slug schedule) 아래 운영부 뉴스(slug news)**. 대학 통폐합·폐교·정원감축 뉴스를 RSS로 자동 수집해 목록 표시. 기존 `insights-collect`(YouTube 수집) 자동화 패턴을 그대로 복제.

**문서**: `docs/superpowers/specs/2026-06-23-ops-news-design.md`, `docs/superpowers/plans/2026-06-23-ops-news.md`.

**구현 (PR #680, 브랜치 `feat/ops-news`, 7 Task TDD)**:
- 수집 잡 `src/features/automations/jobs/news-collect.ts` `runNewsCollect()` — `news-sources.ts`의 `NEWS_SOURCES`(구글 뉴스 RSS 키워드 5개: 통폐합·폐교·정원감축·글로컬대학·구조조정) 순회→fetch→`parseRssItems`(fast-xml-parser)→`mapRssItemsToNews`→`dedupeByLink`→admin upsert(onConflict link)→60일 cleanup. errors[] 누적. `registry.ts` 1줄 등록(id `news-collect`).
- 마이그 `20260623_news_table.sql`(link unique)+`_rls.sql`(insight_videos 복사). `src/features/news/{schemas,queries.ts}` `newsRowSchema`/`listNews()`. `/dashboard/news` 페이지 + `news` variant(View/Table, 원문링크 target=_blank, readOnly).
- 신규 의존성 `fast-xml-parser`(설치 완료).
- **GOTCHA**: 구글 뉴스 RSS `<source>`가 fast-xml-parser에서 `{ "#text", "@_url" }` 객체 또는 문자열로 파싱 → 양쪽 가드. cron route(`/api/automations/run?jobId=`)·이력(`automation_runs`)·수동실행 UI는 잡 등록만으로 자동 적용(무변경).

**★ 실운영 가동 완료(2026-06-23, PR #680 머지)**:
- DB 마이그 적용·검증 완료. 자동화 토글 ON 완료(`automation_settings` job_id=news-collect enabled=true — service_role upsert로 설정). 첫 수집 477건 적재(실데이터 검증, 출처 한국대학신문/네이트 등).
- cron-job.org 등록 완료: `POST /api/automations/run?jobId=news-collect` + `Authorization: Bearer CRON_SECRET`(기존 자동화 공유), **평일 06~18시 매시 `0 6-18 * * 1-5` Asia/Seoul**.
- 토글 저장소 = `automation_settings`(job_id+enabled) 테이블, `getJobEnabled` 기본 false. cron route는 enabled=false면 silent skip.

**후속(미반영)**: 키워드 칩 필터(ListPattern Filter union에 키워드 등록 필요 — 1차는 빈 필터/전체표시), 교육부·전문지 직접 RSS 피드 추가(NEWS_SOURCES placeholder), fetch timeout(AbortController), news_blocklist.

관련: [[standard-list-inspector-design]], [[db-migration-apply]].
