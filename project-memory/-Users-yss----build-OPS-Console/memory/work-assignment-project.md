---
name: work-assignment-project
description: "업무배정 — 총괄장 엑셀을 DB 원장으로. 설계 PR1~PR9 거의 닫힘, 실제로 막혔던 곳과 그 이유"
metadata: 
  node_type: memory
  type: project
  originSessionId: d4e408f0-fbc3-4552-ad3e-5eb1ff9b999a
  modified: 2026-09-21T22:35:38.467Z
---

총괄장 시트(사람이 쓰던 엑셀)를 **DB 원장(`assignments`)으로** 옮기고, 3월 연간 배정을
에이전트가 제안 → 관리자가 승인하는 구조. 설계: `docs/superpowers/specs/2026-09-12-work-assignment-design.md`
(990줄, rev 3). 화면은 **관리 > 업무배정**(`/dashboard/work-assignment`, admin only).

## 진행 (2026-09-22)

PR1~PR8 완료(#1189~#1214). PR9(문서)는 #1211. 원장 **1,858행 / 299 대학**.

**남은 것**: `assignSingle` 배선 누락(단건 지름길이 안 물려 전부 에이전트를 탄다) ·
E2E 0건 · 신규배정 탭 UI(0건이라 못 봄) · 배정현황 '진행 상세' 아코디언 15개가 표 아래
전부 깔림(인스펙터로 갈 물건).

## 실제로 막혔던 곳 — 둘 다 코드가 아니라 **데이터와 조회**였다

**① 연차 그룹이 비어 있으면 제안이 0건이다.** `operators.tenure_group` 은 **사람이
넣는 값**인데 15명 전원 빈칸이었다. `gate.ts:143` 이 `if (!prev?.tenure_group) reject(G3)`
라 **모든 제안이 G3 에서 탈락**한다. 코드는 다 됐는데 기능이 죽어 있었다.
→ 채운 뒤 제안 24건 · 이동 12건이 실제로 나왔다.

**② 반려하면 그 학년도가 영영 닫혔다** (#1212). `hasAnnualBatch` 가 `status` 를 안 보고
`academic_year`+`kind` 만 봐서, 반려된 배치가 남으면 `[실행]` 이 매번 skip 했다.
설계는 *"반려가 기본 선택지"* 라고 여러 번 말하는데 그 기본을 고르면 끝이었다.

> **DB 제약이 처음부터 옳았다** — `assignment_proposal_batches_pending_annual_key` 가
> **pending 에만** 걸린 partial unique다. 제약은 "pending 이 둘이면 안 된다" 고 말하는데
> 조회만 "어떤 상태든 막는다" 고 했다. **조회를 제약에 맞춘 것**이지 새 규칙이 아니다.
> 이 형태(제약 ↔ 조회 불일치)는 다른 곳에서도 볼 만하다.

## 손대면 안 되는 것 셋

- **3월배정 탭을 `ListPattern` 으로 옮기지 마라.** 적용·반려의 **결정 단위가 배치**고,
  행별로 펴면 `G4` 가 막으려던 수시/정시 분할이 화면에서 되살아난다
  (`ProposalDecision.tsx:15-17` 이 행별 적용을 의도적으로 뺐다). 표는 고쳐도 구조는 그대로.
- **시트 재가져오기를 만들지 마라.** 이관 버튼은 PR3 이 만들어 **1회 쓰고** PR4 가 걷었다.
  자연키 upsert 라 클릭 한 번이 앱 편집을 전부 시트 값으로 되돌리고, 그 덮어씀이
  `assignment_changes` 에 **정당한 변경으로 남아 사고와 구분이 안 된다.** 지금 원장에
  쓰는 경로는 둘뿐 — 인스펙터 수동 편집, 제안 승인.
- **백업자를 배정으로 세지 마라.** 원장에 없다(`parse.ts:118` 이 명시적으로 가른다) —
  공백 때 대신 볼 사람이지 배정이 아니다.

## 내보내기 (PR8, #1213)

확정 원장 → 총괄장의 **`(앱) 배정확정`** 시트. 사람이 쓰는 `02~08` 은 안 건드린다.
**수동 트리거만** (자동이면 열어 둔 파일이 불시에 바뀐다). 설계 §7 의 열 구성표가
실측으로 **세 군데 틀려** rev 3 으로 고쳤다 — PIMS 는 `FULL 환충`(개발 0건) · 원서접수는
5칸(백업자 없음) · 학년도는 원장에 있는 것만(2026 빈 열 20칸은 거짓말).

⚠️ **`ASSIGNMENT_EXPORT_DRY_RUN` 이 Vercel Production 에 없으면 첫 실행이 곧 실쓰기다.**

## 판정은 회사 PC 폴러가 한다

`scripts/assignments/propose-local.mjs`. **Moa·볼트를 안 써서 집에서도 돌릴 수 있다**
(다른 폴러들과 다른 점 — 등록 스크립트만 PowerShell이라 맥은 수동 실행). claim 이
**원자적**(`.eq("status","pending")` 을 update 조건에 같이 검) 이라 두 곳에서 켜도 안 부딪힌다.

**Claude CLI 로그인이 만료되면 판정이 통째로 선다** — 2026-09-21 에 3번 중 2번이
`Anthropic profile login expired` 로 죽었다. 그리고 그 알림이 **안 갔다**:
`failure-notify.ts:20` 이 `!previous || previous.ok` 라 **직전도 실패면 억제**하는데,
직전 실패는 원인이 다른 건(admin 클라이언트 버그)이었다. 새 장애가 옛 장애에 가렸다.

관련: [[closing-automation]] · [[company-pc-pending-tasks]] · [[standard-list-inspector-design]] · [[local-test-baseline]]
