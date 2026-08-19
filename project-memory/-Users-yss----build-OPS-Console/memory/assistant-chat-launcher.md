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

**Claude 단일 경로다 (2026-08-19, #1025).** 토글로 있던 빠른 답변(Gemini)은 걷어냈다 — "Claude의 백업이 아니었다"가 이유. `lib/ai/gemini.ts`·`/api/assistant/ask` 모두 삭제됐다. 회사 PC가 꺼지면 어시스턴트도 멈춘다.

큐 `assistant_requests` ← 웹(`/api/assistant/claude`, 세션) / 폴러(`/api/assistant/claude/claim`, CRON_SECRET). 폴러는 `scripts/assistant/serve-local.mjs` 상주 2초. **판단(프롬프트·근거추출)은 전부 서버**라 프롬프트 수정 시 회사 PC를 안 만진다. 셋업은 `docs/assistant-poller-setup.md`.

**자동 대체는 일부러 안 한다** — 조용히 Gemini로 넘기면 회사 PC가 며칠 죽어도 모른다. 15초간 claim이 없으면 화면에 "회사 PC가 응답하지 않습니다".

**회사 PC 폴러에 밀린 변경이 쌓여 있다 (2026-08-19 기준)** — #1013·#1016(답 잘림)·#1020(로그 경로 이중)·#1021(실행 단계 표시)·#1022(폴링 조기 종료)·#1024(KST 시각). `serve-local.mjs`가 계속 바뀌므로 **회사 PC 갱신이 밀리면 새 기능이 안 붙는다.**

**폴러는 회사 PC로 이관 완료** (2026-08-18). 작업 스케줄러 `OPS-Console 어시스턴트 폴러`, 로그온 시 시작 + 죽으면 1분 뒤 재시작. 개발자 맥 폴러는 정지했다 — **두 곳에서 돌리지 않는다**(답이 두 번 가진 않지만 어느 PC가 답했는지 추적이 안 된다).

**작업 스케줄러는 코드를 따라가지 않는다** — 죽은 프로세스만 되살린다. `scripts/assistant/*`나 `package.json`이 바뀌면 회사 PC에서 `git pull → npm ci → Restart-ScheduledTask` 필요. 서버 쪽(`features/assistant`·`api/assistant`)만 바뀌었으면 배포로 끝. 실제로 폴러가 몇 시간 낡은 코드로 돌아 새 도구가 안 붙어 있었고, **에러가 안 나서 티가 안 났다**. 절차·증상표는 `docs/assistant-poller-setup.md` §4·§5.

로그는 회사 PC 레포 루트 `assistant-poller.log`(#1005). 작업 스케줄러로 돌면 콘솔이 없어 이게 유일한 확인 경로다.

**빠른 답변(토글 끔) 경로**는 `/api/assistant/ask` → `lib/ai/gemini.ts`, 모델 `gemini-2.5-flash`(env `GEMINI_MODEL`), 키 `GEMINI_API_KEY`. 이 어시스턴트는 원래 Gemini 전용이었고(2026-05경), Claude 경로는 2026-08-16~18에 얹었다 — 그래서 두 경로가 공존한다.

**검색 도메인 7개**: `knowledge`(업무 지식망) + 사고·인수인계·AI TIP·백업·연락처·서비스. 지식망을 **결과 맨 앞**에 두고 시스템 프롬프트에도 우선 규칙을 적었다 — 사람이 쓰고 owner가 책임지는 문서이고 나머지는 운영 데이터의 파편이기 때문.

**도메인 추가 시 4곳을 같이 고쳐야 한다** (하나라도 빠지면 조용히 반쪽이 된다):
1. `features/assistant/search.ts` — `SourceDomain` + `searchXxx` + `searchAllDomains`의 `Promise.all`
2. `/api/assistant/ask/route.ts` **시스템 프롬프트의 도메인 목록** — 여기 없으면 모델이 그 근거를 안 쓴다
3. `AssistantClient.tsx`의 `DOMAIN_LABEL` / `DOMAIN_TONE`
4. `AssistantClient.tsx`가 **자체 정의한 `Source` 타입** — `search.ts`가 server-only라 client가 import 못 해 같은 모양을 두 번 적는다. typecheck가 잡아주긴 한다

**이 계열 결함은 전부 조용했다** — 에러도 안 나고 답도 오는데 내용만 틀렸다. 2026-08-19에 셋을 잡았다:
- 연락처 검색이 `contact_phone`/`contact_email`을 **select에 안 넣어** "연락 수단을 알 수 없다"고 답했다(#1014). DB엔 343건 중 전화 205·이메일 261건이 있었다
- `m.result`만 담아 **답이 마지막 블록으로 잘렸다**(#1016)
- 앞서 인수인계·AI TIP 도메인은 **없는 컬럼을 조회**해 조용히 0건이었다(#1002)
→ `domain-selects.test.ts`가 두 방향(없는 컬럼 조회 / 있는 데이터 누락)을 다 본다. **새 도메인·필드를 붙일 때 여기부터 볼 것.**

관련: [[claude-agent-sdk-hardening]] — SDK 호스팅 함정 4가지(격리·상한). [[knowledge-vault-project]] — 이 화면이 그 프로젝트의 (c) 단계다. [[standard-list-inspector-design]] · [[modal-shell-standard]]
