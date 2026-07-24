---
name: input-listsearch
description: src/components/common/ListSearch.tsx — LogPattern 디자인(돋보기 SVG + border + bg-washi-raised) 기반 표준. 모든 list 도메인(services / contracts / 향후) 공유. 도메인별 별도 input 스타일 만들지 말 것
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8a18890a-c371-4590-bb5c-6cf1f23166ac
---

## 규칙

목록 페이지에서 검색 input이 필요하면 **항상** `<ListSearch value={...} onChange={...} placeholder={...} />`를 import해서 사용.

**Why**: 사용자(2026-05-15) 명시 — "서비스 메뉴에 검색 디자인을 업무 활동 로그에 있는 로그와 동일하게 적용. 앞으로 검색 디자인을 해당 디자인으로 적용". 도메인별로 디자인 다르면 시각 일관성 깨짐 + 운영부 학습 비용 증가.

**디자인 명세** (LogPattern 기준):
- container: `border border-line-soft bg-washi-raised px-3 py-2`
- 좌측 돋보기 SVG icon (`h-3.5 w-3.5 text-muted`)
- input: `border-none bg-transparent text-sm placeholder:text-faint`
- placeholder default: `"쿼리 입력…"` — 도메인별 override 가능
- **너비**: ListSearch 자체에 `flex flex-1 min-w-[240px]` 보유 → 부모 flex container 안에서 남은 공간 자동 차지. **className에 `max-w-*` 같은 너비 제한 두지 말 것**

**Layout 표준 (검색 + 셀렉트 한 줄 구성)**:

2페이지 이상 row가 노출되는 list 도메인은 다음 layout으로 통일:

```tsx
<div className="flex flex-wrap items-center gap-2 px-7 pt-3">
  <ListSearch value={q} onChange={setQ} placeholder="..." />
  <ListSelect ... />
  <ListSelect ... />
  {/* 필요 시 추가 select */}
</div>
```

- `flex flex-wrap items-center gap-2` parent
- ListSearch가 `flex-1`로 남은 공간 자동 차지 → 페이지 너비에 맞춤
- ListSelect 옆에 자동 배치 (한 줄). 좁은 화면에선 wrap
- `px-7 pt-3` (page padding 일관)

**How to apply**:

```tsx
"use client";
import { ListSearch } from "@/components/common/ListSearch";

<ListSearch
  value={q}
  onChange={setQ}
  placeholder="대학명·서비스명 검색"
  className="max-w-md"  // 도메인별 가로 제한 optional
/>
```

- controlled input — 부모가 `useState` + `useEffect` debounce + `router.push(?q=)` 처리
- props: value(required) / onChange(required) / placeholder(default "쿼리 입력…") / className(optional)

**금지**:
- 도메인별 *별도 search input 스타일* 만들지 말 것 (services에서 `rounded-md border-faint bg-cream` 잘못 만든 사례를 본 PR에서 정정)
- placeholder text 디자인 임의 변경 X (`text-faint` 유지 — 다른 list 도메인과 일관)
- 돋보기 icon 제거 X (시각 신호로 검색 input임을 명시)

**향후 적용**:
- LogPattern.tsx의 inline 검색 input도 ListSearch로 리팩토링 가능 (현재 디자인 동일이라 functional 변경 0, 코드 중복 제거 효과)
- contracts 도메인에도 향후 검색 추가 시 ListSearch 사용

## 관련

- 위치: `src/components/common/ListSearch.tsx`
- test: `src/components/common/__tests__/ListSearch.test.tsx` (4건)
- 사용처: `src/app/dashboard/services/ServicesControls.tsx`
- 디자인 기준: `src/app/dashboard/_components/patterns/LogPattern.tsx` 검색 input
