---
name: assistant-chat-launcher
description: "어시스턴트 = 우하단 고정 채팅 런처(메뉴 아님) + 표준 인스펙터 패널. LLM은 Claude가 아니라 Gemini 2.5-flash"
metadata:
  node_type: memory
  type: project
  originSessionId: ec85b534-6819-4191-82d9-815a5d99874c
  modified: 2026-08-15T16:43:07.773Z
---

어시스턴트는 **메뉴 페이지가 아니라 우하단 고정 채팅 런처**다 (사용자가 참고 이미지를 보고 지시, 2026-08-15). 클릭하면 **표준 InspectorPanel**이 열린다 — 별도 채팅 UI를 만들지 않고 기존 인스펙터를 재사용했다(#980·#981).

**2026-08-18 기준 기본 모드는 Claude다** (아래 Gemini 서술은 '빠른 답변' 토글 쪽 경로).

| 모드 | 실행 위치 | 보는 것 | 지연 |
|---|---|---|---|
| Claude · 지식망 읽기 (기본) | **회사 PC 구독 + Agent SDK** | 볼트 마크다운 직접 Read + 일정 조회 도구 | 30~40초 |
| 빠른 답변 | Vercel (Gemini 2.5-flash) | Supabase 인덱스 검색 요약 | 즉답 |

큐 `assistant_requests` ← 웹(`/api/assistant/claude`, 세션) / 폴러(`/api/assistant/claude/claim`, CRON_SECRET). 폴러는 `scripts/assistant/serve-local.mjs` 상주 2초. **판단(프롬프트·근거추출)은 전부 서버**라 프롬프트 수정 시 회사 PC를 안 만진다. 셋업은 `docs/assistant-poller-setup.md`.

**자동 대체는 일부러 안 한다** — 조용히 Gemini로 넘기면 회사 PC가 며칠 죽어도 모른다. 15초간 claim이 없으면 화면에 "회사 PC가 응답하지 않습니다".

**폴러가 지금 어디서 도는지가 운영 리스크다** — 2026-08-18 현재 **개발자 맥**. 회사 PC 이전은 사용자가 출근해서 진행 예정.

**(과거) LLM은 Claude가 아니라 Gemini다** — `/api/assistant/ask` → `lib/ai/gemini.ts`, 모델 `gemini-2.5-flash`(env `GEMINI_MODEL`로 교체 가능), 키는 `GEMINI_API_KEY`(Vercel Production에 79일 전 등록 = 실운영). 코드베이스에 Anthropic 호출은 없다.
어시스턴트 자체가 **79일 전 Gemini로 만들어진 기존 기능**이고, 2026-08-15~16에 내가 바꾼 건 껍데기(런처·패널)와 입력(화면 컨텍스트·지식망 검색)뿐 — **호출부는 안 건드렸다**. 사용자는 2026-08-16에 이 사실을 듣고 놀랐다. 앞으로 "어시스턴트가 답한다"고 쓸 때 **어느 모델인지 먼저 밝힐 것**.
사용자가 고른 방향은 **Claude 구독 + Agent SDK(회사 PC, ratio-audit 폴러 방식)** 였지만 **아직 구현 안 됐다**. 지금 화면에서 답하는 건 Gemini다 — "Claude가 답한다"고 말하면 틀린다.
(Agent SDK는 harness만 제공하고 배포는 자기 몫이라 Vercel 서버리스에서 구독 인증으로 못 돌린다. 그래서 회사 PC 폴러 경로가 나왔다.)

**검색 도메인 7개**: `knowledge`(업무 지식망) + 사고·인수인계·AI TIP·백업·연락처·서비스. 지식망을 **결과 맨 앞**에 두고 시스템 프롬프트에도 우선 규칙을 적었다 — 사람이 쓰고 owner가 책임지는 문서이고 나머지는 운영 데이터의 파편이기 때문.

**도메인 추가 시 4곳을 같이 고쳐야 한다** (하나라도 빠지면 조용히 반쪽이 된다):
1. `features/assistant/search.ts` — `SourceDomain` + `searchXxx` + `searchAllDomains`의 `Promise.all`
2. `/api/assistant/ask/route.ts` **시스템 프롬프트의 도메인 목록** — 여기 없으면 모델이 그 근거를 안 쓴다
3. `AssistantClient.tsx`의 `DOMAIN_LABEL` / `DOMAIN_TONE`
4. `AssistantClient.tsx`가 **자체 정의한 `Source` 타입** — `search.ts`가 server-only라 client가 import 못 해 같은 모양을 두 번 적는다. typecheck가 잡아주긴 한다

관련: [[claude-agent-sdk-hardening]] — SDK 호스팅 함정 4가지(격리·상한). [[knowledge-vault-project]] — 이 화면이 그 프로젝트의 (c) 단계다. [[standard-list-inspector-design]] · [[modal-shell-standard]]
