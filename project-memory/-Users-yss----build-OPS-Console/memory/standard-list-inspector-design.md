---
name: standard-list-inspector-design
description: 기본 테이블 목록 + 인스펙터 표준 디자인 — 신규/전환 메뉴는 이 구성을 따른다
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 86163e16-5b15-41f6-b6a1-a31619f412ea
---

OPS-Console의 "기본 테이블 목록 디자인"은 dev-test 메뉴(#577~#581)에 적용한 표준 ListPattern + list-variant 인스펙터 구성이다. 신규 메뉴나 커스텀 UI 전환 시 반드시 이 구성을 따른다.

**목록 화면 (page.tsx)**:
- `ListPattern`(`_components/patterns/ListPattern.tsx`) 사용. services→`ListRow[]` 매핑.
- 검색/필터는 `controlsRow`에 — 루트 div `flex flex-wrap items-center gap-2 px-7 pt-3` (border/배너 배경 **금지**, ContactsControls와 동일). 필터는 searchParam 구동(`ListSearch`/`ListSelect` + router.push).
- 제목/건수 옆 스코프 칩: `inlineFilters={<ScopeChips total={total} mineLabel="내 X" />}` (전체/내 X, `?mine` 토글, 기본 mine=true → operator === 본인).
- 행 외 데이터는 `ListRow`에 임베드(data-request 패턴), 페이지네이션 `footer={<ListPagination/>}`.

**인스펙터 View (list-variants/<variant>/View.tsx)**:
- 표준 `Section`/`DefList`(`list-variants/shared`) 구성. 짧은 read-only는 DefList(2열), 긴 값/인터랙티브(URL 입력·폼·버튼)는 **DefList 밖 풀너비 블록**으로(88px term 칼럼에 넣으면 overflow).
- 행 제목/상태는 인스펙터 chrome이 렌더하므로 View에서 반복 금지.
- 주요 액션 버튼은 검정(`bg-ink text-cream`) 표준. 모달은 [[modal-shell-standard]] 사용.

**Why:** 메뉴마다 커스텀 UI가 제각각이라 사용자가 표준 통일을 지시. dev-test를 청사진(data-requests 패턴)으로 전환해 기준 확립.

**How to apply:** 신규/전환 메뉴는 커스텀 2-컬럼/박스 UI 금지 → 위 구성. variant 추가 비용: `list-variants/<v>` 폴더(View/Table/filters) + `registry.ts` 1줄 + `types.ts` Variant union 1줄. [[button-hover-black-rule]] 일관.
