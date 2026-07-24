---
name: mailbox-menu-todo
description: 고객응대 > 메일함 메뉴 — 구현 완료(PR #676~684). 운영 메모/주의점
metadata: 
  node_type: memory
  type: project
  originSessionId: ceb15623-4684-4e97-ba5e-95068e05b3f6
  modified: 2026-07-22T02:22:08.476Z
---

고객응대 > **메일함** 메뉴 구현 완료 (PR #676~#684, 2026-06 머지). Outlook 받은메일 확인 + AI 회신 초안 + 발송.

구조:
- 수집·초안 생성: `scripts/mailbox-ingest.mjs`. **초안 생성기는 `claude -p`** (PR #887, 2026-07-18 Ollama→claude 전환). team-briefing/dev-control과 동일 안전 호출: `execFileSync(CLAUDE_BIN, ["-p","--disallowedTools","Bash Edit Write NotebookEdit Task"], {cwd: os.tmpdir()})`. `CLAUDE_BIN` 기본 win32 `claude.cmd`/else `claude`, `MAILBOX_LLM_MODEL`은 model_used 라벨(기본 `claude`).
- **크론 호스트 = 이 Windows PC** (PR #893, 2026-07-22 이전). **핵심 gotcha: `claude -p` OAuth 구독은 로그인 사용자 세션에서만 유효** → Mac mini launchd/S4U 서비스 컨텍스트에선 인증 실패로 7/18~7/22 초안 0건이었음(수집은 정상, `automation_runs`엔 ok=true·초안0건으로 조용히 묻힘). 해결: `scripts/mailbox-ingest.cmd`(진입점) + `register-mailbox-ingest-task.ps1`로 작업스케줄러 `OPS-Console-Mailbox-Ingest`(10분, **InteractiveToken**) 등록. claude -p 쓰는 `OPS-DevControlAnalyze`와 동일 검증 모드. 로그 `scripts/logs/mailbox-ingest-<date>.log`(초안 실패도 stderr로 적재).
- **⚠️ Mac mini launchd 크론은 반드시 중지** — 두 곳 동시 실행 시 `last_synced_at` 레이스로 서로 새 메일을 놓쳐 초안 누락. (2026-07-22 시점 사용자에게 중지 요청함)
- 읽기 인프라: `src/lib/microsoft/mail-read.ts` (`Prefer: outlook.body-content-type="text"` 평문 수신).
- 발송/표시: `src/features/mailbox/` (actions/queries/schemas), 페이지 `src/app/dashboard/mailbox/`, list-variant `mailbox`.

라이브 검증 (2026-07-20, 이 Windows PC):
- `claude -p`(claude.cmd) 초안 경로 단건 실행 성공 (DB/Graph 미접촉 하네스). 질문형→마감일 미지어냄+"확인 후 안내", 안내(FYI)형→복창 없이 수신확인 위주. 초안당 ~19–29s. `buildDraftPrompt`/`assembleDraft`/`splitSentences`는 export 순수함수라 하네스에서 그대로 재사용 가능(`generateDraft`는 내부 함수).

광고성 필터 (2026-07-20, PR #891):
- 기존 필터(발신주소 토큰 + 대괄호 `[광고]`)는 CJ푸드빌(`cj.net`)·Tesla(`tesla.com`)처럼 자사도메인+대량발송플랫폼 메일을 못 잡음. 해결: `internetMessageHeaders`를 fetch에 추가하고 `hasBulkHeader(headers)` 신설 — `List-Unsubscribe`/`List-Id`·`Feedback-ID`·`Precedence:bulk`·`X-SG-*`(SendGrid=Tesla)·`X-MAIL_ID`/`X-SEND_TYPE`/`X-LIST_TABLE`·`X-Mailer:eMsSMTP`(한국 TMS=CJ) 등 1:1 메일엔 없는 헤더 감지. `shouldSkipMessage`에 headers 인자(하위호환).
- **한계**: 실사람 1:1 영업제안(예 `och3626@hecto.co.kr`)은 헤더 없어 통과(의도적). 막으려면 발신자 수동 blocklist.
- 저장분 정리: 새 필터 기준(헤더 재검증)으로 ys1114 저장 46→33건, 대량발송 13건 삭제. 서버에서 헤더 조회 불가 건은 안전 유지.

운영 주의 (2026-06-23 버그픽스):
- **본문 평문 변환 잔재**: 추적 비콘 `[http://…/dsn/…]`·`[cid:…]`·`<mailto:>` 가 본문에 노출됨 → `src/features/mailbox/clean-body.ts` `cleanMailBody()`로 display 정제(`_row-mapper`). bodyPreview는 깨끗.
- **AI 초안이 요약처럼**: 안내/공지(FYI)성 메일은 답할 용건이 없어 모델이 원문 복창 → `buildDraftPrompt()`에 "안내성이면 복창 말고 수신확인 위주" 분기 추가. 프롬프트 변경은 **다음 ingest 실행부터 반영**.

연계: [[ops-console-dev-workflow]]
