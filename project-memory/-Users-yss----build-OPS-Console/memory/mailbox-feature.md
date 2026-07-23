---
name: mailbox-feature
description: "고객응대 메일함 기능 — Phase1 구현/PR 완료, Phase2(위임) 미착수 + 가동 전 운영 선행조건"
metadata: 
  node_type: memory
  type: project
  originSessionId: c638331c-95e2-4cb8-8774-151ddce704b8
---

고객응대 하위 **메일함**(slug `mailbox`). 운영자 Outlook 수신함을 DB 캐시로 준실시간 확인 + 로컬 LLM 회신 초안 + **본인(메일함 주인) 명의 발송**.

**확정 아키텍처 결정**:
- 초안 생성 = **로컬 claude -p** (PR #887, 2026-07-18 Ollama에서 전환). `scripts/mailbox-ingest.mjs`의 `generateDraft`가 `execFileSync(CLAUDE_BIN, ["-p","--disallowedTools","Bash Edit Write NotebookEdit Task"], {input:prompt, cwd:os.tmpdir()})` — team-briefing/dev-control과 동일 안전장치. `model_used` 라벨 기본값 `claude`(env `MAILBOX_LLM_MODEL`로 오버라이드 — .env.local에 남은 옛 qwen 값 있으면 삭제). Vercel(서버리스)는 claude CLI 못 돌리므로 **로컬 cron ingest 잡**이 Graph수신→DB→초안 전담(웹앱은 표시·승인·발송만). ⚠️ 메일함용 Ollama(`brew services`)는 더 이상 불필요.
- 인증 = Azure AD **Application 권한** `Mail.Read`(읽기)+`Mail.Send`(발송, 기존 sendMail 재사용). 운영자별 OAuth 위임 토큰 안 씀. Phase2 위임이 자연스러움.
- 발신 명의 = 항상 **메일함 주인**(고객이 A에게 보냈으면 A 명의), `sent_by_email`=실제 처리자 감사.

**문서**: `docs/superpowers/specs/2026-06-22-mailbox-feature-design.md`, `docs/superpowers/plans/2026-06-22-mailbox-phase1.md`.

**Phase 1 (PR #673 머지 완료, main `59f2106`)** — 8 Task TDD 완료. **DB 마이그도 프로덕션 Supabase 적용 완료**(3테이블+RLS+realtime publication 검증). 코드+DB 준비 끝.
마이그 3테이블(`mailbox_messages`/`mailbox_drafts`/`mailbox_settings`)+RLS+realtime / `src/features/mailbox/` schemas·queries·actions(`sendMailReply`·`setAutoDraftEnabled`) / `src/lib/microsoft/mail-read.ts` / ingest 잡 / 메뉴·`dashboard/mailbox/`·`list-variants/mailbox/`.
- **GOTCHA**: `mail-read.ts`는 `import "server-only"`라 `.mjs` ingest가 import 못 함 → ingest가 `fetchInbox` 자체 재구현(동일 인코딩 복제, 주석 교차참조). mail-read.ts는 현재 dead code(웹측 미사용)지만 spec-mandated·테스트 보유라 유지.
- **GOTCHA**: Graph OData `$filter`는 리터럴 `$`+`%20`+`encodeURIComponent` 필요. `URLSearchParams`는 `$`→`%24` 인코딩해서 깨짐(mail-read·ingest 양쪽 수정+회귀테스트).
- deferral: "다시 생성" 버튼 비활성(Phase1.5, 웹앱이 로컬 Ollama 직접 호출 불가), 준실시간=autoRefresh 폴링(realtime publication 등록만, 구독 UI 후속).

**★ 실운영 가동 완료(2026-06-23)**: PR #674(Phase1.5) 머지 + 아래 전부 완료.
- Phase1.5 추가분: ingest **재귀 폴더 수집**(받은편지함+모든 하위폴더, 순차+429백오프) / **외부 고객만 필터**(사내@jinhak·@jinhakapply·광고·전자결재시스템 = 수집·초안 모두 skip, .ac.kr/.or.kr 등 외부만) / 본문 **Prefer:text**(HTML태그 노출 방지) / 초안 **고정 틀**(안녕하세요+진학어플라이 {이름}입니다 + AI간결본문(문장별 줄바꿈 `splitSentences`) + 감사합니다) / **HTML 발송 + 운영자별 서명**(`src/lib/mail-signature.ts` `buildReplyHtml`/`buildHtmlSignature` — 2026-06-23 `src/features/mailbox/signature.ts`에서 lib로 공용 이동, data-requests 발송도 재사용. operators 테이블 팀·직책·내선 변수 + 4개 클릭링크 원서접수/진학닷컴/CATCH/JINHAKPRO, 발송 시 첨부 — 초안엔 서명 없음).
- **GOTCHA**: 마이그 직후 supabase-js(PostgREST)로 신규 컬럼 UPDATE 시 스키마 캐시 미리로드로 조용히 무시됨 → pg 직접 UPDATE로 우회. Graph 메일박스 동시성 ~4 → 폴더 fetch 순차+429 백오프 필수. Outlook 서명은 Graph로 못 읽음·API발송 자동첨부 안 됨 → operators 기반 동적 생성.
- **cron**: launchd `~/Library/LaunchAgents/com.opsconsole.mailbox-ingest.plist`(node `/usr/local/bin/node` `scripts/mailbox-ingest.mjs`, WorkingDirectory=프로젝트, StartInterval 600s, 로그 `~/Library/Logs/mailbox-ingest.log`). Ollama=`brew services` 상시. 현재 대상 메일함=ys1114@jinhakapply.com(자동초안 ON). MAIL_DRY_RUN은 미설정(=실발송) 상태 — 웹 발송 안전장치 필요 시 Vercel env에 설정.

**전체 운영자 확장 (PR #684 머지, 2026-06-23)**: 메일함 페이지 접근 시 `ensureMailboxSettings(myEmail)` 호출 → `mailbox_settings` insert-if-absent(`upsert` + `onConflict:owner_email` + `ignoreDuplicates:true`, 기존 토글 보존). 신규 등록 **자동초안 OFF 기본**(opt-in, 토글로 ON). ingest는 기존대로 `mailbox_settings` row 존재 운영자만 순회(스펙 §13)이므로, 메일함 연 운영자가 다음 cron부터 본인 외부고객 메일 자동 수집 대상이 됨. **단 cron ingest는 여전히 이 1대 Mac의 launchd에서만 돎** — 운영자가 늘면 Graph 호출량↑(순차+429백오프로 흡수). `ensureMailboxSettings`는 본인 메일함만(권한 게이트), `actions.test.ts` 2건 커버.

**★ Phase 2 위임 — 구현·머지 완료 (PR #693, 2026-06-24)**: SDD 6태스크 TDD + opus 최종리뷰. 스펙 `docs/superpowers/specs/2026-06-23-mailbox-delegation-design.md`, 계획 `docs/.../plans/2026-06-23-mailbox-delegation.md`.
- 테이블 `mailbox_delegations`(owner_email, grantee_email, granted_at, revoked_at, unique(owner,grantee)) + RLS(SELECT 전원/I·U·D service_role). 마이그 `20260623d`+`20260623e` **프로덕션 적용 완료**.
- `src/features/mailbox/delegation.ts`: `canAccessMailbox(viewer,owner)`(viewer===owner OR 활성위임 — 단일 권한게이트, 열람가드+발송가드 공용) + `isOwnerOrActiveDelegate`(순수) + `listMyDelegations`/`listMailboxesDelegatedTo`.
- `actions.ts`: `grantMailboxDelegation`/`revokeMailboxDelegation`(owner=me 고정, grant 시 operators 존재검증+B≠me, 재위임 upsert로 revoked_at 복구). `sendMailReply` 가드 `owner!==me` → `!canAccessMailbox(me,owner)`로 확장(발신 명의=주인 유지, sent_by_email=B).
- UI: `MailboxOwnerSwitcher`(`?owner=` 전환, 권한없으면 본인 폴백), `MailboxDelegationPanel`(ModalShell, **조직 운영자 셀렉트**로 위임 대상 선택 — listOperators active 중 본인·기위임자 제외 / 해제). 위임 버튼=검정 채움 "메일 위임". owner===myEmail일 때만 관리 노출. `ensureMailboxSettings`는 본인에만.

**★ 크론 머신 이전: Mac launchd → Windows 작업 스케줄러 (#893, 2026-07-22)**: claude -p 전환(#887) 후 **Mac mini launchd에서 초안 0건 실패**가 계속됨. 원인 = **claude -p 구독 OAuth는 로그인 사용자 세션에서만 유효**한데 launchd 컨텍스트엔 인증 세션이 없음(PATH 문제 아님 — PATH 넣어도 인증 실패. 인터랙티브 세션 스모크만 통과했던 착오). → **claude 인증된 회사 Windows PC로 이전**(dev-control 등 claude -p 예약작업 5종 이미 호스팅). `scripts/mailbox-ingest.cmd`(스케줄러 진입점) + `scripts/register-mailbox-ingest-task.ps1`(10분 간격, InteractiveToken). Windows에서 drafted=1·model=claude 검증됨. **이 Mac의 launchd `com.opsconsole.mailbox-ingest`는 언로드해야 함**(Windows와 이중 실행 시 last_synced_at 레이스로 메일 누락 위험). 언로드: `launchctl bootout gui/$(id -u)/com.opsconsole.mailbox-ingest` + plist 삭제/이동. → 교훈: **launchd/headless 컨텍스트는 claude -p 구독 OAuth 못 씀 = team-briefing도 동일 제약**(claude 쓰는 로컬 잡은 로그인 세션 있는 머신에서만).

관련: [[standard-list-inspector-design]], [[db-migration-apply]].
