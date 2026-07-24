---
name: select-listselect
description: src/components/common/ListSelect.tsx — SettingsPattern 디자인(border + bg-transparent + px-3 py-2 + focus:border-vermilion) 기반 표준. 모든 list 도메인(services / contracts / 향후) 공유
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8a18890a-c371-4590-bb5c-6cf1f23166ac
---

## 규칙

목록 페이지에서 필터 select가 필요하면 **항상** `<ListSelect value={...} onChange={...} options={...} placeholder={...} ariaLabel={...} />`를 import해서 사용.

**Why**: 사용자(2026-05-15) 명시 — "서비스 메뉴에 검색 옆에 셀렉트 디자인도 시스템 설정에 있는 셀렉트 디자인 처럼 적용. 앞으로 요청한 디자인이 표준 디자인". `rounded-md border-faint bg-cream` 같은 ad-hoc 디자인은 시각 일관성 깨짐.

**디자인 명세** (SettingsPattern 기준):
- `border border-line bg-transparent px-3 py-2 text-sm text-ink`
- `outline-none focus:border-vermilion` (focus 시 vermilion red border)
- rounded 없음 (각진 모서리)
- height: text-sm + py-2

**How to apply**:

```tsx
"use client";
import { ListSelect } from "@/components/common/ListSelect";

<ListSelect
  value={universityType}
  onChange={(v) => navigate({ universityType: v || null })}
  options={UNIVERSITY_TYPE_OPTIONS}     // readonly string[] — value === label
  placeholder="대학구분 전체"             // 빈 옵션 라벨 (optional)
  ariaLabel="대학구분 필터"
/>
```

- options: `readonly string[]` (value === label). 더 복잡한 매핑이 필요하면 별도 prop 확장 후속
- placeholder: 빈 옵션 라벨 (`<option value="">대학구분 전체</option>`). 미지정 시 빈 옵션 미노출
- onChange: 새 값을 인자로 받음. URL push 또는 state 갱신은 부모 책임

**금지**:
- 도메인별 *별도 select 스타일* 만들지 말 것 (services에서 `rounded-md border-faint bg-cream` 잘못 만든 사례를 본 PR에서 정정)
- `rounded` 임의 추가 X (SettingsPattern 디자인은 각진 모서리)
- focus border 다른 색상으로 변경 X (`focus:border-vermilion` 유지)

**향후 적용**:
- SettingsPattern.tsx의 inline select도 ListSelect로 리팩토링 가능 (현재 디자인 동일이라 functional 변경 0)
- contracts 도메인에 향후 시트/상태 필터 추가 시 ListSelect 사용
- 검색·셀렉트 묶음은 검색 input(ListSearch) + select(ListSelect)로 일관 적용

## 관련

- 위치: `src/components/common/ListSelect.tsx`
- test: `src/components/common/__tests__/ListSelect.test.tsx` (3건)
- 사용처: `src/app/dashboard/services/ServicesControls.tsx`
- 디자인 기준: `src/app/dashboard/_components/patterns/SettingsPattern.tsx` select
- 관련 표준: [[feedback_list_search_design]] (ListSearch — 검색 input 표준), [[feedback_list_pagination_pattern]] (ListPagination — 페이지네이션 표준)
