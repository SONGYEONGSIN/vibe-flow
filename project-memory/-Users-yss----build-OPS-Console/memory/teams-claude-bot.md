---
name: teams-claude-bot
description: "사내 Teams 그룹채팅 Claude 봇 — 코드는 ~/Downloads(git 아님), OPS-Console 어시스턴트 큐에 위임. 회사에서 할 6단계 남음"
metadata:
  node_type: memory
  type: project
  originSessionId: ec85b534-6819-4191-82d9-815a5d99874c
  modified: 2026-08-21T10:25:26.277Z
---

Teams 그룹채팅에서 `@봇` 으로 부르는 사내 봇. **코드가 `/Users/yss/Downloads/teamsclaudebot` 에 있고 git 저장소가 아니다** — 이 메모가 유일한 기록이다. Python + `microsoft-teams-apps` SDK.

## 봇은 스스로 생각하지 않는다

질문을 **OPS-Console 어시스턴트 큐**에 넣고 답만 받아온다(`LLM_BACKEND=ops` → `/api/assistant/bot`, PR #1051).

도구만 붙이지 않은 이유: **볼트는 회사 PC의 파일**이라 봇이 Azure 에 있으면 못 읽는다. 사내 규정을 물으면 "모른다"가 나오고, 같은 질문에 웹과 다른 답을 내는 두 번째 뇌가 된다 — [[assistant-chat-launcher]] 가 2026-08-19 에 걷어낸 바로 그 문제. 같은 큐에 넣으면 프롬프트·도구·볼트·빈틈 수집이 그대로 따라온다. 대가는 30~40초.

`subscription`·`api` 백엔드도 코드에 남아 있지만 **볼트를 못 읽는다.** 채팅방에서 느리다고 바꾸면 사내 지식을 잃는다.

## 인증

`CRON_SECRET` 으로 봇 서버를 인증하되 **요청자는 `operators.email` 에 있어야** 받는다(비밀키 하나로 사칭 불가). Teams UPN 을 그대로 쓴다. 조회도 이메일로 함께 걸러 id 추측으로 남의 답이 새지 않게 한다.

## 회사에서 할 일 — `NEXT-STEPS.md`

절차는 그 파일에 있다. 실측으로 확인한 것만 여기 남긴다:

- **① 앱 업로드 허용 ✅** — Teams 앱 관리에 `앱 업로드` 버튼 보이고 `어플라이봇/사용자 지정 앱` 이 이미 올라가 있다(실제 배포 이력)
- **③ 앱 등록 권한 ✅** — `+ 새 등록` 눌림
- **기존 앱 재사용 금지** — `moadata`(운영 중) · `운영부`(OPS-Console, Mail.Send 딸려옴) · `TeamsGpts(개별/통합)`·`매뉴얼봇`(**만료됨**)
- **`TeamsGpts`·`매뉴얼봇` 이 만료 상태**라는 게 곧 경고다 — 클라이언트 비밀은 만료되고, 만료되면 봇이 조용히 죽는다(`AADSTS7000215`)
- 남은 것: ② 구독 확인 → ③ 앱 등록 → ④ Azure Bot + Teams 채널 → ⑤ App Service + env → ⑥ 매니페스트 3곳(`id`/`botId`/`validDomains`) + zip

**`claude setup-token` 은 필요 없다** — ops 백엔드는 봇이 Claude 를 직접 안 부른다.

## 아이콘

`appPackage/color.png`(192×192, vermilion) · `outline.png`(32×32, **흰 선 + 투명** — Teams 규격상 단색만). 자동화 메일의 터미널 `>_` 마크와 같은 결. 원본 SVG 는 `icon-source.svg`.

**Why:** git 밖에 있어 잃어버리기 쉽고, "왜 도구를 안 붙였나"가 이 설계의 전부다. **How to apply:** 봇이 느리다고 백엔드를 바꾸자는 말이 나오면 볼트 문제를 먼저 짚는다. 회사 PC 폴러가 죽으면 봇도 답을 못 한다([[assistant-chat-launcher]]).

관련: [[assistant-chat-launcher]] · [[knowledge-vault-project]] · [[claude-agent-sdk-hardening]]
