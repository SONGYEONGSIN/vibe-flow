---
name: modal-shell-standard
description: 모달 팝업은 공통 ModalShell 컴포넌트를 표준으로 사용 (검정 헤더 + boxed × + 푸터 슬롯)
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 86163e16-5b15-41f6-b6a1-a31619f412ea
---

OPS-Console의 모든 모달 팝업은 `src/components/common/ModalShell.tsx`를 표준으로 사용한다 (PR #557).

**표준 디자인** (대학연락처 일괄등록 모달 기준):
- 오버레이 `bg-ink/40` + 카드 `border border-line bg-paper`
- **검정 헤더** `bg-ink` — 타이틀(text-cream) + 우측 **boxed × 닫기**(`border border-line bg-paper` 정사각 버튼, aria-label "닫기")
- 본문(children, 스크롤) + 푸터(footer prop, 우측 정렬 액션) 슬롯
- Esc / 바깥 클릭 / × 로 닫힘
- 주요 액션 버튼은 **검정**(`border-ink bg-ink text-cream hover:bg-vermilion`), 건수 등은 버튼이 아닌 **본문에 별도 표시**

**Why:** 모달마다 디자인이 제각각이라 사용자가 통일을 요청. 공통 컴포넌트로 추출해 재사용을 강제하면 향후 자동 통일.

**How to apply:** 새 모달 작성 시 인라인 오버레이/카드 마크업 금지 — `ModalShell`에 title/onClose/children/footer/size(sm|md|lg) 전달. 적용 예: `BulkPasteContacts`, `HeadlineUrgentModal`(헤드라인·현황요약·핵심지표 팝업). 색 토큰은 [[button-hover-black-rule]]과 일관(hover 시 vermilion/ink).
