---
name: browser-cannot-reach-local-dev
description: Chrome 확장 도구는 로컬 dev 서버에 못 닿지만 헤드리스 크롬(Lighthouse/Playwright)은 붙는다 — 시각 판단은 사람, 정량 검증은 자동화
metadata: 
  node_type: memory
  type: project
  originSessionId: 0ed66907-31fd-4a19-b052-0f2588b03f3b
  modified: 2026-08-01T02:58:55.775Z
---

이 프로젝트에서 Claude 측 브라우저 자동화(claude-in-chrome 확장)가 로컬 dev 서버에
도달하지 못한다. 2026-07-31 세션에서 여러 에이전트가 localhost·127.0.0.1·LAN IP 를
모두 시도했고 전부 실패했으나 외부 사이트 접속은 정상이었다.

**단, 헤드리스 크롬은 붙는다.** 2026-08-01 에 `npx lighthouse http://localhost:3500/cardnews`
로 접근성 감사가 정상 실행되는 것을 확인했다(92점, `color-contrast`·`label` 실패 검출).
`npx playwright` 도 사용 가능하다. 제약은 **확장 도구 한정**이지 브라우저 전반이 아니다 —
이걸 뭉뚱그려 기억했다가 Lighthouse 게이트를 설계에서 뺄 뻔했다.

**How to apply:** 검증을 셋으로 나눈다. 서버 렌더는 `curl`(라우트 상태 코드·기대 문자열).
접근성·대비·폭 오버플로 같은 **정량 항목은 Lighthouse/Playwright 로 자동화**한다.
확장 도구가 필요한 인터랙션·시각 판단(드래그, 파일 드롭, 캡처 결과물의 미감)만
**사람 확인 항목으로 분리해 넘긴다.**
에이전트에게 "못 한 것을 했다고 쓰지 마라" 를 지시에 넣으면 정직하게 구분해 보고한다.

**Why:** 이 제약을 모르면 에이전트가 검증했다고 착각하거나, 브라우저 접속을 반복
시도하다 시간을 태운다. 실제로 렌더 계층 결함 9건을 전부 코드 정독과 산술로만 잡아냈고,
폴더 드롭이 아예 동작하지 않는 결함은 최종 리뷰의 DOM API 추론으로만 발견됐다.

`npm run build` 도 오래 걸려 에이전트 워치독이 무진행으로 판단하는 일이 잦다 —
`npm run build > /tmp/x.log 2>&1; echo "exit=$?"` 로 리다이렉트하게 지시할 것.
