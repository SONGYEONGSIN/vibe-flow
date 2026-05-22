---
name: match-standard-ui
description: Folio 신규 UI는 기존 표준 컴포넌트/스타일을 그대로 재사용해야 한다 (rounded-md·iOS 스위치 등 새 스타일 도입 금지)
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 90fa3225-f069-423b-9fd5-1b1f1fc7bd0a
---

Folio에서 새 화면/컴포넌트를 만들 때는 **기존 표준 컴포넌트와 에디토리얼 디자인을 먼저 찾아 그대로 맞춘다.** 새 스타일을 즉흥 도입하지 말 것.

**Why:** 2026-05-22 자동화 실행(automations) 허브 구현 시, 표준을 확인하지 않고 카드 + `rounded-md` 버튼 + iOS형 슬라이드 스위치로 만들었다가 사용자가 4~5회 반복 수정 요청함. 이 프로젝트의 "기본 디자인 형식"은 다음이 표준:
- **각진 모서리**(sharp, radius 없음)가 기본 — 버튼/배지/토글. `rounded-md`는 과함. 예: my-todo priority 배지 `inline-block px-2 py-0.5 text-xs bg-vermilion text-cream`(radius 없음).
- **분절 토글** = `ScheduleViewToggle.tsx` 스타일 (`border border-line` 박스, active 세그 `bg-ink text-cream`, inactive `bg-transparent text-ink hover:text-vermilion`, `border-l border-line` 구분). iOS 슬라이드 스위치 X.
- **목록 페이지**는 테이블 위에 `<section className="p-7">` + `<h2 className="text-xl font-bold text-ink">제목</h2> · <span className="text-vermilion">N건</span>` 헤더 (ListPattern.tsx 참조).
- **버튼은 `cursor-pointer` 명시 필수** — Tailwind v4는 버튼 기본 커서가 pointer가 아님. 토글류엔 이미 붙어있음.
- 표준 액션 버튼 컬러는 vermilion(`border-vermilion bg-vermilion text-cream`), 본문/탭 active는 ink.

**How to apply:** 새 UI 착수 전 `grep`으로 유사 기존 컴포넌트(ScheduleViewToggle / ScopeChips / ListPattern / 도메인 Table.tsx / 공통 components)를 찾아 클래스를 그대로 차용. 디자인 토큰(ink/cream/muted/line/vermilion/vermilion-deep/faint)만 사용. 자세한 규칙은 [[no-mono-date-amount]] 등 다른 디자인 피드백과 함께 적용.
