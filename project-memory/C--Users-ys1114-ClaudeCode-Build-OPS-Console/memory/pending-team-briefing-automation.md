---
name: pending-team-briefing-automation
description: "팀 브리핑 — 스티비풍 뉴스레터+Teams 티저로 구현 완료. Windows 작업 등록됨(이 PC), Mac launchd 중지 집에서 대기"
metadata: 
  node_type: memory
  type: project
  originSessionId: 37cd345c-d0f9-451a-83c3-7447a4a90835
  modified: 2026-07-23T09:41:02.057Z
---

**⚠️ 아래는 2026-07-01 옛 설계(2섹션 계약현황+팀업무)이며 superseded.** 실제 구현은 **스티비풍 뉴스레터**(`/r/briefing/[token]`, claude -p 스토리 headline/intro/contracts/schedule/closing/ai) + **Teams 티저**로 개편됨(#849·#884~886). 발행기 `scripts/team-briefing/publish-local.mjs` (`--dry`=미발행 미리보기).

**현재 상태 (2026-07-23)**: 러너를 Mac→Windows 이전. **이 회사 PC에 Windows 작업 스케줄러 `OPS-Console-Team-Briefing` 등록 완료**(매주 금 10:00 KST, 로그온 시, `register-team-briefing-task.ps1`). `--dry` 검증 성공(claude 스토리 정상). 사유: claude -p 구독 OAuth는 로그인 세션에서만 유효 → Mac headless는 폴백만. **남은 것: 집 Mac mini의 `com.opsconsole.team-briefing` launchd 중지**(bootout + `~/Library/LaunchAgents`에서 plist 제거) — 안 하면 금10:00 중복(폴백) 발행. [[pending-macmini-mailbox-cron-stop]]과 동일 패턴. Vercel cron 없음, cron-job.org에 team-briefing 금10:00 있으면 제거.

---
(옛 설계 참고 — 미채택)

매주 금요일 Teams로 "팀 보고 브리핑"을 자동 발송하는 새 automations 잡. 2026-07-01 사용자와 섹션·주기 확정, 구현은 다음 세션으로 보류.

**확정 스코프**
- 발송 주기: **매주 금요일**
- 섹션 2개만 (추가 추천은 이번엔 미채택):
  1. **계약진행 현황** — `listContracts()`(SharePoint Excel, `src/features/contracts/queries.ts`). 5시트(`contractSheetEnum`: 4년제/전문대/초중고/대학원/기타)별로 `status`(계약진행현황="계약완료"/공란)·`serviceActive`(서비스여부="Y"/공란) 카운트. 시트별 × 계약완료/진행중.
  2. **팀업무 현황** — schedule `listScheduleEvents()`(7유형: shift/event/leave/training/application/pims/external_meeting, `src/features/schedule/queries.ts`) 이번주 카테고리별 + services 마감 임박(`write_start_at`). ⚠️ `listUpcomingForOperator(email, days)`는 **본인 담당만** — 팀 전체 마감 임박은 신규 team-wide 쿼리 또는 services를 write_start_at 범위로 직접 필터 필요.

**발송 인프라(준비됨)**
- `sendTeamsChatMessage({operatorEmail, chatId, html})` (`src/lib/microsoft/teams.ts`) — delegated token(`Chat.ReadWrite`), env `TEAMS_CHAT_ID`(그룹채팅) + 발송 명의 이메일. notice 공유가 이미 이 경로 사용.
- 등록: `src/features/automations/registry.ts` `AUTOMATION_JOBS` 배열 1객체 + `jobs/{id}.ts`에 `run{Job}(): Promise<AutomationRunResult>`. cron 진입점 `/api/automations/run?jobId=` (cron-job.org). 참고 구현 `jobs/notice-teams-share.ts`(멱등성 패턴).

**주의: 기존 `weekly-report-rollover` 잡과 구분** — 그건 사람이 쓰는 주간업무보고서 Teams 공유(발신 순환). 이 브리핑은 시스템이 뽑는 현황 스냅샷. 주기 겹치면 혼동 주의.

미채택(다음에 확장 후보): 미수채권(경과10일+)·인시던트(부서별)·인수인계 진행·백업요청 대기·메일함 회신필요. 관련 [[mailbox-menu-todo]].
