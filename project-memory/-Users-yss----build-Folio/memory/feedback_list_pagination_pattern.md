---
name: listpagination
description: src/components/common/ListPagination.tsx — 모든 list 도메인 (services / contracts / 향후 추가) 공유. ?page= URL 갱신 + prev/next 버튼 + 현재/총. 새 도메인 신설 시 별도 Pagination 컴포넌트 만들지 말 것
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8a18890a-c371-4590-bb5c-6cf1f23166ac
---

## 규칙

목록 페이지 하단 페이지네이션이 필요하면 **항상** `<ListPagination total={...} pageSize={...} />`를 import해서 사용.

**Why**: 사용자(2026-05-15) 명시 — "앞으로 목록 페이지 넘버링이 생기면 동일한 조건으로 적용하면 되". services PR-1.7에서 만든 `ServicesPagination`은 services-specific 코드가 0이었음. 별도 도메인마다 복제하면 DRY 위반 + maintenance 비용 증가.

**How to apply**:

```tsx
import { ListPagination } from "@/components/common/ListPagination";

// page.tsx에서 ListPattern footer prop으로 전달
<ListPattern
  ...
  footer={<ListPagination total={total} pageSize={30} />}
/>
```

- prop: `total` (전체 row 수, required) + `pageSize` (기본 30, optional)
- `total ≤ pageSize`면 자동 미노출
- URL `?page=N` 갱신 (router.push) — 첫 페이지면 query 제거
- SSR 호환: page.tsx에서 `Number(sp.page) || 1`로 받아 query 또는 client-side slice

**서버 vs 클라이언트 사이드 slice**:
- DB 도메인 (services): `listServices({ page, pageSize })` 서버 사이드 range
- SharePoint 도메인 (contracts): 시트 전체 fetch가 비용 동일 → `allRows.slice(start, start + PAGE_SIZE)` client-side

**금지**:
- 도메인별 *별도 Pagination 컴포넌트* 만들지 말 것 (services에서 ServicesPagination 만들고 hoist한 사례 있음 — 새 도메인 처음부터 ListPagination 사용)
- prev/next 버튼 디자인 임의 변경 X (일관성 — 다른 list 도메인과 동일)

## 관련

- 위치: `src/components/common/ListPagination.tsx`
- test: `src/components/common/__tests__/ListPagination.test.tsx` (5건)
- 사용처: `src/app/dashboard/services/page.tsx`, `src/app/dashboard/contracts/page.tsx`
