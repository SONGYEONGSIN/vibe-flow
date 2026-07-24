---
name: closing-automation
description: "서비스 마감(closing) — Moa 스크래핑 자동화. Phase 1 머지 완료, Phase 2(스크래퍼) 미착수"
metadata: 
  node_type: memory
  type: project
  originSessionId: dfd926da-c463-45e5-9e83-49ed1a4fb0f3
---

Moa 서비스조회를 스크래핑해 마감 서비스를 OPS '서비스 마감'(slug=closing, 서비스사이클 그룹) 메뉴에 표시하는 자동화. 2026-06-07 Phase 1 머지.

**설계 문서**: `.claude/plans/20260607-moa-closing-scrape.md` (전제·결정 전부). brainstorm: `.claude/memory/brainstorms/20260607-132803-moa-closing-scrape.md`.

**확정 결정**
- 스케줄: 2주 격주 월요일 10:00 (anchor=2026-06-08, (today-anchor)%14==0). cron-job.org 주간 → workflow_dispatch → 격주 게이트.
- 검색 오픈일 = 학년도 동적 3/1 00:01~익년 2월말 23:59, 매년 +1 (윤년 처리). `features/closing/academic-year.ts`.
- "마감" = 작성마감 datetime < 스크래핑시각.
- **스크래핑 방식 = '엑셀저장' 버튼 다운로드 후 파싱** (HTML테이블/페이지네이션 X — SmileEDI 방식).
- closing 페이지 = **services variant 재사용**(읽기 전용). 별도 변형 안 만듦.
- 11컬럼: 서비스ID·대학명·지역·서비스명·대학구분·카테고리·운영자·개발자·작성시작·작성마감·단독여부 (+scraped_at).
- SMS 2FA: 로그인 제출→SMS(Tasker→make POST)→스크래퍼가 GET `MAKE_SMS_CODE_URL`(=https://hook.eu2.make.com/enfpm5qhyynjrfpy4lslc7o5wa7rnr1q, 응답=SMS본문)로 `[숫자]` 추출. **신선도=baseline-diff 폴링**(로그인 전 코드 저장→달라지면 새 코드, ~90초 타임아웃).

**Phase 1 (머지 완료, PR #424)**
- `closing_services` 테이블+RLS(select 전원/write service_role) — DB 적용·검증 완료(15컬럼).
- `features/closing/{schemas,queries,academic-year,biweekly-gate}.ts` (+테스트).
- `POST /api/closing/ingest` (Bearer CRON_SECRET + zod + 전체대체 delete-all+insert + 빈배열 거부).
- `/dashboard/closing` 페이지(services variant readOnly) + `_row-mapper.ts`. ListRow에 `scrapedAt` 추가.
- Vercel 재배포로 페이지 라이브(데이터는 Phase 2 전까지 빈 상태).

**Phase 2 (진행 중 — 트리거 잡 완결, 스크래퍼 스캐폴드, 선결 2건 대기)**
- **자동화 메뉴 등록 결정**: closing을 `/dashboard/automations`에 **트리거형 잡 `closing-scrape`**로 등록(SmileEDI와 반대 방향 = OPS가 GitHub dispatch). ✅ TDD 완결: `src/lib/github/dispatch-workflow.ts`(+테스트6) + `features/automations/jobs/closing-scrape.ts`(+테스트2) + registry 1줄. 격주 게이트는 스크래퍼만(run()은 순수 디스패처).
  - **하드 선결**: OPS에 GitHub PAT 필요 — Vercel env `GITHUB_DISPATCH_TOKEN`/`GITHUB_DISPATCH_REPO`(owner/repo)/`GITHUB_DISPATCH_WORKFLOW`(moa-closing-scrape.yml). cron-job.org를 GitHub직접→`/api/automations/run?jobId=closing-scrape` 경유로 재설정.
- `scripts/moa-closing/scrape.py`(+requirements/msoffcrypto) + `.github/workflows/moa-closing-scrape.yml` 작성. 격주게이트/학년도/SMS폴링/인제스트/필터는 TS 단일소스와 동치 검증 완료.
- **Moa DOM 라이브 디스커버리 완료**(Playwright 실로그인): 로그인 `#txtUserID/#txtPassWord/#txtSANum/#btnLogin`(이중용도), 캡차 `#secCaptcha`(실패시만 노출→abort), ServiceSearch `/Foundation/ServiceSearch`, 오픈일 `#txtOpenFromTime/#txtOpenToTime`(포맷 `YYYY-MM-DD HH:MM`), **⚠️운영자 `ddlManager` 기본=로그인운영자→''(전체)로 비워야 전건**, 엑셀저장=JS `GetUnivServiceListToExcel()`, **⚠️엑셀 암호화(CDFV2)→`MOA_EXCEL_PASSWORD`+msoffcrypto 복호**.
- **✅ 라이브 검증 완료(Playwright 실세션, 2026-06-07)** — 블로커 2건 해결:
  - **엑셀 복호 = `VelvetSweatshop`**(서버 생성 엑셀 표준 기본키, 비밀 아님 / 운영자 비번·akfls12!! 아님). 스크래퍼 기본값 내장 → MOA_EXCEL_PASSWORD 비워둠.
  - **SMS 웹훅 해결**: make 수정으로 GET이 최신 SMS 본문 반환. Moa 포맷 `[…] 인증번호는 [123456] 입니다` → 정규식 `\[(\d+)\]` 매치. 자동 2FA(수동입력0) 성공.
  - 엑셀 실제 **14컬럼**(plan11 + 접수구분/결제시작/결제마감) 중 11 매핑, **430건 파싱**(마감 279). 오픈일 포맷 `YYYY-MM-DD HH:MM`. ⚠️운영자 ddlManager 기본=로그인계정→''(전체) 비워야 전건.
- **✅ 완전 운영 (2026-06-07)**: PR #425 머지. prod 배포는 git auto-deploy 안 떠서 `npx vercel --prod`로 수동 배포. 모든 단계 완료·검증:
  - GH Secrets 5개(MOA_USERNAME/MOA_PASSWORD/MAKE_SMS_CODE_URL + CRON_SECRET/OPS_CONSOLE_BASE_URL).
  - Vercel prod env: `GITHUB_DISPATCH_TOKEN`/`GITHUB_DISPATCH_REPO=SONGYEONGSIN/OPS-Console`/`GITHUB_DISPATCH_WORKFLOW=moa-closing-scrape.yml` (npx vercel env add).
  - DB `automation_settings` closing-scrape enabled=true.
  - **end-to-end 검증**: cron-job.org test-run → 200 OK `{ok:true, 워크플로 트리거}`. PAT dispatch + 격주게이트(off주 SKIP) 라이브 확인.
- **첫 실제 스크래핑 = 6/8(월) 10:00** (anchor=실행주). 이후 격주(6/22, 7/6…). 그 전까지 closing 페이지 빈 상태.
- **재배포 주의**: Vercel git auto-deploy가 squash 머지에 안 떴음. env 변경/재배포 필요 시 `npx vercel --prod`(이미 인증·링크됨, 로컬 main 기준).
- **14컬럼 전부 적재**(사용자 결정): 기존 11 + 접수구분(admission_type)/결제시작(pay_start_at)/결제마감(pay_end_at). 마이그 `20260607e`(DB 적용완료, 18컬럼) + schemas+ingest+row-mapper+scrape.py 반영. 표시는 services variant 재사용이라 카테고리/작성마감만 노출(접수구분은 DB 저장만). cron 스케줄 `0 10 * * 1`(매주 월) 확인.
- 상세: plan `결정 업데이트 3·4·5`.

**Cloudflare 차단 + residential 검증 (2026-06-09)**
- GH Actions(데이터센터 IP)에서 Moa가 **Cloudflare "Just a moment"로 차단** → 모든 run 실패, closing_services 0건. undetected-chromedriver+xvfb(#438)로도 미통과(IP 평판 문제).
- **로컬(Mac, residential IP)에서 scrape.py 전 구간 성공 확인**: CF 통과 → 로그인 → 자동2FA(웹훅) → 검색 → 다운로드 → **285건 추출 → 실제 인제스트 완료(inserted:285, 84개대학)**. closing 페이지 라이브 표시(배포 불요, DB read).
- **로컬 실행 레시피**: Python 3.14는 distutils 없어 uc import 실패 → `pip install --user --break-system-packages "setuptools<81"` + env `SETUPTOOLS_USE_DISTUTILS=local`. 또 `CHROME_VERSION=148.x`(설치 Chrome 버전) 지정해야 uc 드라이버 매칭(미지정 시 SessionNotCreated). `HEADLESS_MODE=false`(headful)·`CLOSING_DRY_RUN`·`OPS_CONSOLE_BASE_URL=https://ops-console-psi.vercel.app`. env는 .env.local에서 source.
- **Moa 비번 변경**: `akfls55!!`→`akfls44!!`(2026-06-09). .env.local + GH Secret MOA_PASSWORD 동기화 완료.
- **남은 것**: 무인 격주 자동화 미해결. CI는 CF로 불가 → **셀프호스티드 러너(사무실 상시 PC) 또는 로컬 cron(residential IP)** 셋업 필요. 285건은 수동 1회 적재.

[[smileedi-automation]] (동일 GH Actions+cron-job.org 스크래핑 패턴 재사용)
