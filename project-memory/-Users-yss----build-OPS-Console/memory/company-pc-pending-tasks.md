---
name: company-pc-pending-tasks
description: 회사 PC에서만 할 수 있는 미완 작업 — 배포는 끝났고 그 PC 조치만 남은 것들
metadata: 
  node_type: memory
  type: project
  originSessionId: d4e408f0-fbc3-4552-ad3e-5eb1ff9b999a
  modified: 2026-08-30T05:10:14.085Z
---

배포는 끝났는데 **회사 PC(YS1114V1)에서 해야 끝나는** 작업 목록. 서버는 이미 받을 준비가 돼 있고, 그 PC가 갱신되기 전까지는 값이 `null`로 남을 뿐 화면은 깨지지 않는다.

## 1. 어시스턴트 폴러 갱신 — 토큰·비용 (2026-08-30 시점 미완)

`scripts/assistant/serve-local.mjs`가 바뀌었다(PR #1137). 그 PC에서 `git pull` + 폴러 재시작을 해야 토큰·비용이 쌓이기 시작한다.

- **왜 필요한가**: 폴러가 Agent SDK의 `result` 메시지에서 `usage`·`total_cost_usd`·`num_turns`를 **원래 받고 있었는데 버리고 있었다**(`m.result`만 꺼냄). 그래서 전 78개 테이블에 토큰 컬럼이 하나도 없었다.
- **서버 쪽은 완료**: `assistant_requests`에 `input_tokens`/`output_tokens`/`cache_read_tokens`/`cost_usd`/`model`/`num_turns` 컬럼 + 인덱스 적용됨. 라우트가 숫자만 걸러 저장한다(안 보내면 `null` — 0으로 채우면 공짜로 돈 것처럼 보인다).
- **확인 방법**: 갱신 후 어시스턴트에 질문 하나 → `assistant_requests` 최근 행에 토큰이 찍히는지. 갱신 전에는 전부 "토큰 없음"이다.
- 절차 문서: `docs/assistant-poller-setup.md`

## 2. 원서GEN 분석 1회 실행 — 세팅 변경 이력 (2026-08-30 시점 미완)

`scripts/dev-control-analyze.mjs` 가 바뀌었다(PR #1144). 그 PC에서 개발·테스트 탭의 분석을 **한 번 실행**해야 세팅 변경 이력이 쌓이기 시작한다. **원서GEN 은 회사망 밖에서 TCP 차단이라 자택에서 못 돌린다.**

- **왜 필요한가**: 스크립트가 파일 해시로 세팅 변경을 **원래 감지하고 있었는데** `dev_control_analyses` 가 upsert 라 최신 상태만 남고 사건이 매번 덮여 사라졌다. 이제 `dev_control_setting_changes` 에 append 한다.
- **서버 쪽은 완료**: 테이블 + RLS 적용, 기존 157행을 `prev_code_hash=null`(첫 관측)로 시드. 성과 aggregator `dev-control-changes` 등록됨.
- **확인 방법**: 실행 후 `select count(*) from dev_control_setting_changes where prev_code_hash is not null` 이 0 보다 커지는지. **지금은 전원 0 건이 정상** — 비어 보인다고 고장 난 게 아니다.

## 3. 메일함 수집 작업 재등록 — 야간 정지 (2026-08-30 시점 미완)

`scripts/register-mailbox-ingest-task.ps1` 이 바뀌었다(PR #1146). 그 PC에서 **다시 한 번 돌려야** 스케줄이 바뀐다 — 레포 머지만으로는 Windows 작업 스케줄러가 안 바뀐다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/register-mailbox-ingest-task.ps1
```

- **왜 필요한가**: 10분 간격 **24시간**이라 하루 144회 돌았고, 실측(8/23~29) 1,000회 중 실제 수집은 51회(5.1%). **00~08시·20~23시 504회는 7일 내내 전부 빈손**이었다. 08~20시로 좁혀 약 73회가 된다.
- **메일은 안 놓친다**: 수집이 `last_synced_at` 델타라 아침 첫 실행이 밀린 것을 가져온다.
- `-Force` 라 기존 작업(`OPS-Console-Mailbox-Ingest`)을 덮어쓴다.
- **확인 방법**: 다음날 `automation_runs` 의 `mailbox-ingest` 가 144 → 약 73으로 줄었는지 + 일일 보고가 `ok` 로 뜨는지(거짓 `stale` 이 아니어야 한다).

> cadence 는 `hourly`(임계 3h) 그대로 두는 게 맞다. 야간 공백 12h 가 임계보다 커도, 판정이 **'오늘 실행 기록'을 먼저 보기** 때문에 11:00 보고 시점엔 이미 정상이다. 늘리면(daily 48h) 회사 PC 가 꺼진 하루를 놓친다. `digest-night-window.test.ts` 가 이 두 계약을 지킨다.

## 참고 — 회사 PC 폴러는 6개다

`assistant` / `postal-extract` / `ratio-audit` / `closing-scrape` / `entertest` / `dev-control`. 전부 같은 PC(`YS1114V1`)에서 돌고 `poller_heartbeats`에 각자 심박을 남긴다. 이번 변경은 `assistant` 하나만 해당한다.

심박의 `machine` 값이 `ys1114v1`(node, `hostname()`)과 `YS1114V1`(PowerShell, `$env:COMPUTERNAME`)로 **대소문자가 섞여 있다** — 지금은 PC가 한 대라 무해하지만 두 대가 되면 같은 PC를 둘로 셀 수 있다. `poller_heartbeats` PK가 `poller_id` 단독이라 **PC가 둘이 되면 서로 덮어쓰는** 문제와 함께 정리해야 한다.

**Why:** 서버 배포만으로는 끝나지 않는 작업이 있고, 잊으면 "기능은 나갔는데 데이터가 안 쌓인다"가 조용히 계속된다. **How to apply:** 회사 PC 앞에 앉았을 때 이 목록을 확인하고, 처리한 항목은 이 파일에서 지운다.
