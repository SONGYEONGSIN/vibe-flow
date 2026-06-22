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
- 초안 생성 = **로컬 Ollama**(상시 Mac, 한국어 모델 기본 `exaone3.5:7.8b`). 비용 0 + 고객 메일 사내 보관. Vercel(서버리스)는 LLM 못 돌리므로 **로컬 cron ingest 잡**(`scripts/mailbox-ingest.mjs`)이 Graph수신→DB→초안 전담. 웹앱은 DB만 표시·승인·발송.
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

**Phase 2 (미착수)**: `mailbox_delegations` 테이블 + `canAccessMailbox(viewer,owner)` + 위임 설정 UI + `[내 메일함 ▼]` 전환. 발송 가드를 `owner_email !== me.email` 단일 지점에 격리해 둠(확장점). 발신은 주인 명의 유지.

관련: [[standard-list-inspector-design]], [[db-migration-apply]].
