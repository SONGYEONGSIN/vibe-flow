---
name: open-notice-auto-mail
description: 개발·테스트 오픈안내 탭 — 오픈 시각 자동 발송. 실운영 상태와 발송 검증 기법
metadata: 
  node_type: memory
  type: project
  originSessionId: 4ea569fc-e7ea-487b-82be-155320ae53b4
  modified: 2026-08-22T08:53:58.054Z
---

`/dashboard/dev-test?tab=open-notice` — 담당 운영자가 토글을 켜두면 오픈 시각(`write_start_at`)에 대학 담당자에게 안내 메일이 나간다. 설계·규칙은 CLAUDE.md와 `docs/superpowers/specs/2026-08-22-open-notice-mail-design.md`에 있다. 여기엔 **문서에 없는 운영 상태와 검증 기법만** 적는다.

## 운영 상태 (2026-08-22 기준)

- PR #1082(기능) + #1083(경쟁률 선택·구분선 축소) 머지, 프로덕션 배포됨
- 마이그레이션 2개 운영 적용 완료 (RLS 실측 검증: anon select/insert 42501 차단, status check 23514)
- **프로덕션 `MAIL_DRY_RUN`은 꺼져 있다** — dispatch 응답 `dryRun: 0`으로 확인. 실제로 나간다
- cron-job.org에 `/api/open-notices/dispatch` 5분 주기 등록 완료, **실행 이력 200 확인**(사용자 확인). 자동 발송 경로가 끝에서 끝까지 살아 있다
- 실발송 1회 검증 완료 — Outlook에서 콜론 정렬·`└` 들여쓰기 정상

## 발송을 지금 검증하는 법 (오픈 시각을 안 기다리고)

토글은 예약만 걸어서, 오픈이 멀면 발송을 확인할 수 없다. **테스트 스크립트를 새로 만들지 마라** — 기존 `scripts/*-mail-test.mjs`들은 TS를 재구현(미러)하는 방식이라 정작 검증하고 싶은 `mail-html.ts`의 공백 보존을 증명하지 못한다.

대신 배포된 dispatch를 그대로 쓴다:

1. 실제 TS 모듈로 초안 생성 — 임시 vitest 파일에서 `buildDefaultOpenNoticeText()`를 부르고 결과를 JSON으로 `fs.writeFileSync`
2. `open_notice_sends`에 행 삽입 — `status='scheduled'`, `scheduled_at = now-60s`(즉시 만료), **`to_email`·`sender_email` 모두 본인**(`ys1114@jinhakapply.com`)
3. `curl -X POST -H "x-cron-secret: $CRON_SECRET" https://ops-console-psi.vercel.app/api/open-notices/dispatch`
4. 응답 `sent: 1` 확인 (`dryRun: 1`이면 발송 안 된 것)
5. **테스트 행 반드시 삭제** — 안 지우면 그 서비스에 '발송완료' 배지가 잘못 뜬다

손대는 건 시각과 수신자뿐이고 렌더링·발송은 전부 실제 경로다. `MAIL_DRY_RUN` 조작도 불필요.

## 알고 있어야 할 것

- **dispatch는 `automation_runs`에 안 남는다** → 자동화 일일 보고(11:00 Teams)의 미실행 감지에 안 잡힌다. 자료요청·백업요청도 같은 사각지대. cron 잡이 죽어도 아무도 안 알려준다
- **수동 발송 경로가 없다** — 토글뿐이라 cron이 멈추면 대체 수단이 없다
- 실데이터에 `write_end_at`이 1년 뒤로 적힌 건이 7개 있다(건국대·경상국립대 등). 초안이 종료 연도를 찍어 드러내게 해뒀다

관련: [[db-migration-apply]] · [[mail-cc-exclusion]] · [[ratio-setting-audit]]
