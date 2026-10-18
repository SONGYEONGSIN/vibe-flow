---
name: 테이블 공통 패턴
description: 테이블 위에 개수 표시 형식과 간격을 contracts 기준으로 통일
type: feedback
---

테이블이 있는 페이지에서는 contracts 페이지 기준으로 통일한다.

**Why:** 메뉴별로 개수 표시 형식(N개, N건, N명, Badge)과 간격이 제각각이었음.

**How to apply:**
- 개수 표시: `총 <span className="font-medium text-foreground">{count}</span>건` + 페이지네이션 있으면 `(1-50 표시)` 추가
- 간격: `mb-2` (개수 표시와 테이블 사이)
- 테이블 래퍼: `<div className="rounded-md border bg-card overflow-hidden">`
- 테이블 헤더 행: `<TableRow className="bg-[#334155]">`
- 테이블 헤더 셀: `<TableHead className="text-white">` (+ font-medium은 TableHead 기본)
- native `<table>` 사용 시: `<tr className="bg-[#334155]">` + `<th className="text-white font-medium">`
- 단위는 항상 "건" 사용 (서비스, 계약, 인수인계, 사용자 모두)
