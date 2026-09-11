---
name: company-pc-pending-tasks
description: 회사 PC에서만 할 수 있는 미완 작업 — 배포는 끝났고 그 PC 조치만 남은 것들
metadata: 
  node_type: memory
  type: project
  originSessionId: d4e408f0-fbc3-4552-ad3e-5eb1ff9b999a
  modified: 2026-08-30T05:10:14.085Z
---

배포는 끝났는데 **회사 PC(YS1114V1)에서 해야 끝나는** 작업 목록. 서버는 이미 받을 준비가 돼 있고, 그 PC가 갱신되기 전까지는 값이 안 쌓이거나 기능이 꺼진 채 돌 뿐 화면은 안 깨진다.

## 1. 원서GEN 분석 1회 — 세팅 변경 이력 (2026-08-30 배포, 미완)

`scripts/dev-control-analyze.mjs` 가 바뀌었다(PR #1144). 그 PC에서 개발·테스트 탭의 분석을 **한 번 실행**해야 세팅 변경 이력이 쌓이기 시작한다. **원서GEN 은 회사망 밖에서 TCP 차단이라 자택에서 못 돌린다.**

- **왜 필요한가**: 스크립트가 파일 해시로 세팅 변경을 **원래 감지하고 있었는데** `dev_control_analyses` 가 upsert 라 최신 상태만 남고 사건이 매번 덮여 사라졌다. 이제 `dev_control_setting_changes` 에 append 한다.
- **확인**: `select count(*) from dev_control_setting_changes where prev_code_hash is not null` > 0. **2026-09-03 기준 0건** — 아직 안 돌았다. 시드 157행은 전부 첫 관측(`prev_code_hash=null`)이라 성과에서 빠진다.
- 성과 aggregator `dev-control-changes` 가 이 값을 센다.

## 2. SMS 웹훅 env 이름 바꾸기 — 이중화 켜기 (2026-09-03 배포, 미완)

`.env.local` 에 `MAKE_SMS_CODE_URL` 이 **같은 이름으로 두 줄** 들어가 있다. 백업 쪽 이름을 `_2` 로 고쳐야 이중화가 켜진다(PR #1161).

```
MAKE_SMS_CODE_URL=https://hook.eu2.make.com/2sksi…
MAKE_SMS_CODE_URL_2=https://hook.eu2.make.com/enfpm…   ← 이름에 _2
```

- **왜**: make 계정이 둘이고 같은 문자함을 두 경로로 읽는다(무료 한도 대비). 같은 이름 두 줄이면 백업이 백업이 아니라 유일한 값이 되고, 더 나쁘게는 **읽는 쪽마다 다른 줄을 집는다** — 파이썬 dotenv 는 마지막 줄, PowerShell `Get-DotEnv` 는 첫 줄.
- **안 고쳐도 돈다** — 다만 이중화가 꺼진 채 주 웹훅 하나로만 간다.
- `.env.local` 은 gitignore 라 레포에서 못 고친다. 그 PC에서 직접 + `git pull`.
- 적용 범위: 마감 스크래핑 · 경쟁률 점검 · 정산 탐색(셋 다 `scrape.py` 를 쓴다).

> **웹훅을 섞으면 안 된다** — baseline 을 A 에서 읽고 폴링을 B 에서 하면 만료된 코드를 새 코드로 오인한다(2026-08-06 사고와 같은 형태). `pick_baseline` 이 고른 URL 을 함께 돌려주고 흐름 내내 그것만 쓴다.

## 완료된 것 (참고 — 다시 안 해도 된다)

- **어시스턴트 폴러 갱신** ✅ (2026-08-31 확인) — 토큰·비용이 들어오고 있다. 2026-09-03 기준 19건. 입력 10~18인데 **캐시 읽기가 9만~24만** — 캐시를 따로 센 게 옳았다(합쳤으면 왜 비싼지 전혀 안 보인다).
- **메일함 야간 정지 재등록** ✅ (2026-08-31 확인) — 하루 144회 → **9/2 실측 71회**(08~20시), 마지막 실행이 20:00 정각. `hourly` cadence 를 안 건드린 게 맞았다 — 미실행 판정이 '오늘 실행'을 먼저 봐서 오탐이 없다.
- **맥미니 mailbox-ingest 크론 중지** ✅ (2026-07-22) — `~/Library/LaunchAgents/com.opsconsole.mailbox-ingest.plist.disabled-20260722`. `launchctl list`·`crontab -l` 둘 다 비어 있고, 실행 수가 한 대분인 것으로도 확인된다.

## 참고 — 회사 PC 폴러는 6개다

`assistant` / `postal-extract` / `ratio-audit` / `closing-scrape` / `entertest` / `dev-control`. 전부 같은 PC(`YS1114V1`)에서 돌고 `poller_heartbeats`에 각자 심박을 남긴다.

심박의 `machine` 값이 `ys1114v1`(node, `hostname()`)과 `YS1114V1`(PowerShell, `$env:COMPUTERNAME`)로 **대소문자가 섞여 있다** — 지금은 PC가 한 대라 무해하지만 두 대가 되면 같은 PC를 둘로 셀 수 있다. `poller_heartbeats` PK가 `poller_id` 단독이라 **PC가 둘이 되면 서로 덮어쓰는** 문제와 함께 정리해야 한다.

**Why:** 서버 배포만으로는 끝나지 않는 작업이 있고, 잊으면 "기능은 나갔는데 데이터가 안 쌓인다"가 조용히 계속된다. **How to apply:** 회사 PC 앞에 앉았을 때 이 목록을 확인하고, 처리한 항목은 완료 섹션으로 옮긴다. 완료 판정은 **실측**으로 한다(카운트 쿼리·실행 수) — "했다고 기억함"으로 지우면 다시 헤맨다.
