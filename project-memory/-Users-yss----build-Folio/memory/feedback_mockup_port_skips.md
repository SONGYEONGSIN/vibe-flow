---
name: Mockup-driven port에서 brainstorm/plan 스킵 경계
description: 정적 HTML mockup이 명세 역할이면 brainstorm/plan 스킵 가능, 그러나 verification + review는 절대 스킵 금지. 사용자가 동의한 경계.
type: feedback
originSessionId: fa4d7468-5d81-4499-b474-305dc529d2ce
---
mockup이 이미 디자인/스코프/반응형까지 완성된 정적 HTML 형태로 존재할 때:

**스킵 가능:**
- `superpowers:brainstorming` — 의도/제약/대안 탐색은 mockup이 이미 답을 줌
- `superpowers:writing-plans` (design-ref에 plan.md 작성) — 스텝 분리는 자연스럽게 도출됨 (Foundation → Login → Dashboard 같은 패턴)

**스킵 금지 (절대):**
- `superpowers:verification-before-completion` — mockup 따랐다고 정확히 옮겨졌다는 보장 없음. tsc/lint/build는 정적이고, 인터랙션·시각·콘솔은 별도 검증 필요
- `superpowers:requesting-code-review` — `<div onClick>` → `<button>` 같은 mockup→React 시맨틱 갭, Tailwind v4 동적 클래스 보간 함정(`max-md:${stripe}` JIT 누락) 등은 리뷰가 잡아냄
- `superpowers:test-driven-development` — runtime 로직(드로어, 메뉴 토글, 아코디언) 부분은 적용. 순수 마크업만 예외

**Why:** 2026-04-26 세션 — Folio 스텝 1·2·3을 brainstorm/plan 스킵하고 진행해도 코드는 컴파일 통과. 그러나 `requesting-code-review` 호출 시 Critical 1건(C1: `max-md:${stripe}` 동적 클래스 보간 → Tailwind JIT 누락 → 모바일 띠 미렌더), Important 5건, Minor 12건 발견됨. 사용자가 빌드 셋업한 핵심 이유가 *"이런 걸 잡으라고"*. 코드가 굴러간다고 워크플로 스킵해도 된다는 뜻 아님.

**How to apply:**
- mockup-driven port에서 시작 시점부터 "verification + review는 한다"를 결심. brainstorm/plan은 ROI 평가 후 결정
- review에서 발견된 항목은 Critical → Important → Minor 순으로 즉시 처리. 한 번 미루면 다음 스텝으로 넘어감
- 매 스텝 끝마다(스텝 1→2, 2→3 사이) review 한 번씩 끼우기. Folio의 1·2 끝에 review를 안 끼웠던 게 3에서 누적 부담으로 돌아옴.
