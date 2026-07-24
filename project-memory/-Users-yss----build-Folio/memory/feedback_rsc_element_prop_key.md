---
name: rsc-element-prop-key
description: Server Component에서 Client Component(ListPattern 등)에 ReactElement prop 전달 시 key 명시 필수. Next.js 16 + React 19에서 RSC payload가 element prop을 array로 직렬화하면서 key 검사 발동
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8a18890a-c371-4590-bb5c-6cf1f23166ac
---

Next.js 16 + React 19 환경에서 Server Component(`page.tsx`)가 Client Component(`ListPattern`)에 ReactElement prop을 전달하면, RSC payload 직렬화 단계에서 element들이 array로 인코딩되며 각 element에 `key`가 없으면 dev console에 다음 경고가 뜬다:

```
Each child in a list should have a unique "key" prop.
Check the render method of `ListPattern`. It was passed a child from ServicesPage.
```

**Why**: `<ListPattern header={...} inlineFilters={...} footer={...} />` 같은 prop 호출은 JSX 상 단일 element prop이지만, RSC payload에서 ClientComponent에 함께 묶여 전달되며 React 19가 dev mode에서 array key 검사를 한다. div wrap만으로는 해소되지 않는다 — 진짜 fix는 **element 자체에 key 부여**.

**How to apply** (list 도메인 신규/수정 시):
- `page.tsx`에서 ListPattern(또는 다른 Client Component)에 element prop으로 넘기는 모든 `header / inlineFilters / footer / customSection` 등에 `key="<domain>-<slot>"` 추가.
- `const header = (<div key="services-header">...)` 패턴.
- inline 호출도 `inlineFilters={<ScopeChips key="services-scope" ... />}` 처럼 key를 명시.
- Fragment(`<>...</>`)는 RSC 경계로 보내는 prop에서 회피 — div wrap + key.

**검증법**: 임시 e2e spec으로 `page.on("console")` 캡처. 추측 산탄총 디버깅 금지 — raw 메시지로 진단. (검증 시 사용한 spec은 진단 후 즉시 삭제하여 `e2e/` 오염 회피.)

**적용 완료** (commit 6a361da):
- services / contacts / contracts / backup / receivables `page.tsx` 5개

연관: [[feedback_layout_debugging]] (디버깅 워크플로 — 4단계 원칙 준수)
