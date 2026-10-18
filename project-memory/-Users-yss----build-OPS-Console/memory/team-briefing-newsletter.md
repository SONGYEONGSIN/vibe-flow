---
name: team-briefing-newsletter
description: "팀 브리핑 스티비풍 뉴스레터(#884 배포) — 맥 launchd 등록·Vercel cron 제거·샘플 삭제 잔여, 사진 연동 후속"
metadata: 
  node_type: memory
  type: project
  originSessionId: f36d7cf4-c643-43d5-b578-895e5c934acb
---

팀 보고 브리핑을 스티비풍 뉴스레터로 개편 — **PR #884 머지·프로덕션 배포 완료** (2026-07-17, main `872f735`).

**아키텍처**: 금 10:00 상시 맥 launchd(`scripts/team-briefing/publish-local.mjs`) → `GET /api/team-briefing/draft`(서버 집계: 계약·차주일정·마감·AI·근속기념일) → **claude -p 스토리**(캐치 제목+4섹션 이야기, 실패 시 수치 요약 폴백) → `POST /api/team-briefing/publish`(`team_briefings` 발행 + Teams 티저). 게스트 페이지 `/r/briefing/[token]`, 스킨은 스티비 클론 전용 `nl-*` 토큰(#68BAE2 하늘 액센트·파스텔 박스·13px 라운드 — 다른 화면 사용 금지). registry `team-briefing` 잡은 수동/폴백(스토리 없음).

**잔여 운영 단계 (이 맥)**:
1. `.env.local`에 `OPS_CONSOLE_BASE_URL=<프로덕션 URL>` 추가
2. `cp scripts/team-briefing/com.opsconsole.team-briefing.plist ~/Library/LaunchAgents/ && launchctl load ...` (금 10:00)
3. **기존 Vercel/cron-job.org의 금 10:00 team-briefing 스케줄 제거** — 안 하면 중복 발행
4. **샘플 발행분 삭제**(share_token `sampley4xiqouq`, issue_no 0) — 첫 실발행 전 필수, 안 지우면 첫 호가 #2 (호수는 count+1)

**★ '운영부 마법사' 리디자인 (#885, 2026-07-17 배포)**: 제호 '운영부 마법사'+#001(3자리)+큰 제목+페이지 전체 라인 / 카드 nl-ivory 단일색(pink 토큰 삭제) / 이모지→커스텀 SVG 8종(NewsletterIcons.tsx) / 생일 코너(operators.birth_date, upcomingBirthdays) / 프롬프트에 운영부 컨텍스트(원서접수·PIMS 주업무).

**사진 파이프라인 (⚠️ 공개 레포 주의)**: 직원 사진은 레포 커밋 금지 — `public/newsletter/`(gitignore된 임시 보관함)에 넣고 `node scripts/team-briefing/upload-assets.mjs`(sips 리사이즈+Storage 'newsletter' 공개 버킷 업로드+파일명→captions.json). draft API가 **최근 7일 YYYYMMDD 폴더**를 자동 수집(커버+앨범 6장+영상 2개). 첫 배치 `20260717/` 13장+영상 1개 업로드됨.

**Why:** claude -p는 Vercel 실행 불가(구독 OAuth·CLI) → 발행 주체를 맥 launchd로 이전([[mailbox-feature]] 패턴). 드라이런 실측: claude가 "마감 20일이 연차와 겹침" 같은 교차 통찰 포함 — 품질 검증됨.

**How to apply:** 수동 발행 `node scripts/team-briefing/publish-local.mjs [--dry]`. claude 호출은 dev-control과 동일 안전장치(도구 전면 차단 + cwd=tmpdir) 필수. 스토리 스키마 변경 시 `scripts/team-briefing/story-lib.mjs` + `BriefingStory` 타입 + 파서 테스트 동시 수정.
