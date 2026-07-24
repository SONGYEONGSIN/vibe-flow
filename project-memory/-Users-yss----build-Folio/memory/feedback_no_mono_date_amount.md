---
name: no-mono-date-amount
description: "Folio UI에서 일자·금액 표시에 font-mono 사용 금지, 기본 폰트로 통일"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 2083d0e6-36f2-42d4-8e1d-57acd5de7922
---

Folio UI에서 **일자(날짜)와 금액 표시에는 `font-mono`를 쓰지 않는다.** 기본 폰트로 통일.

**Why:** 사용자가 list 테이블·인스펙터·실시간 현황 카드 전반에서 일자/금액만 monospace로 떠 다른 컬럼과 이질감이 든다고 반복 지적 (PR #144 청구금액 → #185 SimpleTable 우측정렬 → 본 정책화). 운영부 UI는 클래식 페이퍼 톤이라 mono가 튀어 보임.

**How to apply:**
- 새 컬럼/필드에서 날짜·금액 렌더 시 `font-mono` 붙이지 말 것 (기본 폰트)
- 우측 정렬이 필요하면 `text-right`만, `font-mono` 동반 금지
- 예외: 코드/ID/사번/service_id 같은 식별자성 값은 `font-mono` OK (가독성 목적) — 일자·금액만 한정
- 진행률 % 같은 수치 인디케이터는 사용자가 명시 안 했으므로 현행 유지

관련: [[feedback_list_search_design]] 등 공통 컴포넌트 디자인 통일 흐름의 연장.
