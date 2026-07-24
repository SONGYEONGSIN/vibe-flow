---
name: dev-control-analysis-pipeline
description: "개발 탭(원서제어 수집·AI 분석) 구조 — 원서GEN HTTP 수집 + claude -p 분석, PC cron 미등록 상태"
metadata: 
  node_type: memory
  type: project
  originSessionId: aaf4daf8-61a0-4fe6-b932-f91c6d930bbb
---

`/dashboard/dev-test?tab=dev` 개발 탭 (PR #870, 2026-07-15 머지). 서비스별 원서제어 JS(A=운영자/AU=개발자)를 수집·AI분석해 확인 피드백 제공.

- **수집**: `scripts/dev-control-analyze.mjs` — 원서GEN `Login.aspx` HTTP 폼 로그인(.env MOA_USERNAME/PASSWORD, ASP.NET VIEWSTATE) → `POST /_AU/Default.aspx/GetDevInfoByUnivServiceId {UnivServiceID, GenFlag:"W?"}` (GenFlag WA~WD 순회, `A` 단독은 500). js 파일만 FileContents 포함
- **분석**: 해시 비교 후 변경분만 `claude -p`(OAuth). 서브프로세스는 `--disallowedTools` + `cwd: os.tmpdir()` 격리 필수 — repo CWD로 실행하면 .claude 설정 상속해 git 명령 실행한 사례 있음
- **DB**: `dev_control_analyses` unique(service_id, **file_name**) — 한 GenFlag가 동일 kind 파일 복수 반환(라이브에서 발견). flags의 checked/note는 재분석 시 key 매칭 보존. 마이그레이션은 수동 적용(대시보드) — DB 직접 포트는 이 망에서 차단
- **이 PC(회사) 스케줄러 2개 등록됨**: `OPS-DevControlAnalyze`(매일 08:30 전체 수집) + `OPS-Console-DevControl-Poll`(5분 폴러 — 웹 '지금 분석' 요청 claim, PR #873). **집 맥은 원서GEN 접근 불가(connect timeout)** — 폴러는 반드시 회사 PC에
- exceljs처럼 d.ts 누락 대응: 없음. PR Follow-up Minor 6건은 #870 본문 참조

- **aspx/HTML 분석 확장은 보류(2026-07-16 사용자 스킵)**. 조사 확정 사실: ①`GetDevInfoByUnivServiceId`는 .aspx/.html의 FileContents를 항상 0자로 반환(내용은 js만) ②실제 접수 페이지 `https://nsdev.jinhakapply.com/Wonseo/{서비스ID}/4/{A|B|C}`는 단순 HTTP로는 3,532자 공통 셸(알림 레이어)만 반환 — 텍스트 "확인/취소"뿐, form/input 0개, 서비스가 달라도 동일 ③재개 시 entertest Selenium으로 렌더링 HTML 캡처가 유일 경로 (수집 시점·플래그 기준 질문에서 중단됨)

**Why:** 데이터 소스가 인증 필요한 내부 도구(원서GEN)라 서버(Vercel)가 아닌 이 PC에서 수집·분석 실행.
**How to apply:** 수집 로직 수정 시 실서비스 9998793으로 라이브 검증(분석→재실행 스킵 멱등 확인). [[supabase-migration-apply-before-merge]] [[drive-autonomously-local-selenium]]
