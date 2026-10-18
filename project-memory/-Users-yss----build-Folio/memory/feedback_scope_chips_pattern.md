---
name: chip-scopechips
description: "src/components/common/ScopeChips.tsx — \"전체 (N) | 내 X\" 토글. ?mine=true URL 갱신 + mutual exclusive. mineLabel prop으로 도메인 customize"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8a18890a-c371-4590-bb5c-6cf1f23166ac
---

## 규칙

목록 페이지에 *본인 담당* 필터 chip이 필요하면 **항상** `<ScopeChips total={...} mineLabel="내 X" />`를 import해서 사용.

**Why**: 사용자(2026-05-15) 명시 — "계약 메뉴에 전체 << 필터 옆에 '내 계약' 필터도 추가, 서비스 메뉴와 동일한 방식". 도메인별로 chip UI/URL 규칙 다르면 일관성 깨짐.

**Chip UI 명세**:
- "전체 (N) | 내 X" 두 chip — mutual exclusive
- active chip: `font-bold text-ink` + 하단 `bg-vermilion h-0.5` 인디케이터
- inactive chip: `text-muted hover:text-ink`
- URL `?mine=true` 갱신 (활성 시) / `?mine=` 제거 (비활성 시)
- chip 클릭 시 `?page=` 자동 제거 (페이지네이션 1로 reset)

**How to apply (page.tsx)**:

```tsx
import { ScopeChips } from "@/components/common/ScopeChips";

// 1. searchParams에 mine 추가
searchParams: Promise<{ ...; mine?: string }>;

// 2. mine 필터를 도메인 query에 전달 (server-side) 또는 client-side filter
const mineFilter = sp.mine === "true";

// services 예: query에 ownerMe/ownerEmail 전달 (DB side)
const filter = { ownerMe: mineFilter, ownerEmail: mineFilter ? me?.email : undefined };

// contracts 예: client-side filter (operator name 매칭)
const filteredRows = mineFilter && me?.displayName
  ? allRows.filter(r => r.operator === me.displayName)
  : allRows;

// 3. ListPattern inlineFilters에 ScopeChips 전달
<ListPattern
  ...
  inlineFilters={<ScopeChips total={filteredTotal} mineLabel="내 계약" />}
/>
```

**도메인별 "본인" 매칭 기준**:
- services: `operator_email === me.email OR developer_email === me.email` (DB 쿼리, ownerMe/ownerEmail filter)
- contracts: `operator === me.displayName` (Excel 운영자 컬럼 vs operator.name) — client-side
- 다른 도메인 신설 시: 어떤 필드가 *본인*을 의미하는지 명확히 + 일관 적용

**금지**:
- 도메인별 *별도 ScopeChips 컴포넌트* 만들지 말 것 (services에서 `ServicesScopeChips` 만든 사례를 본 PR에서 정정)
- mine 라벨 디자인 임의 변경 X (vermilion 인디케이터 + font-bold ink 유지)
- `?mine=` 대신 다른 query name 사용 X (전 도메인 통일)

## 관련

- 위치: `src/components/common/ScopeChips.tsx`
- test: `src/components/common/__tests__/ScopeChips.test.tsx` (4건)
- 사용처: `src/app/dashboard/services/page.tsx`, `src/app/dashboard/contracts/page.tsx`
- 관련 표준: [[feedback_list_search_design]] / [[feedback_list_select_design]] / [[feedback_list_pagination_pattern]] — common/ 목록 페이지 4종 세트 (검색/셀렉트/페이지/scope)
