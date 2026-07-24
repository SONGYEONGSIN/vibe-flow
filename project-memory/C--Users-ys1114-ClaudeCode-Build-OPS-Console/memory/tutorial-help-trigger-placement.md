---
name: tutorial-help-trigger-placement
description: 튜토리얼/도움말 재생 트리거는 플로팅 버튼 금지 — 상단바 ChromeRight에 배치
metadata: 
  node_type: memory
  type: project
  originSessionId: 0855094f-fa90-44db-b266-6e786a26cff7
---

대시보드 튜토리얼('가이드'/'도움말') 재생 버튼은 **우하단 고정 플로팅 버튼으로 만들지 않는다**. 상단바 우측 `ChromeRight`(타이머/벨/유저 옆)에 배치한다.

**Why:** PR #318(`fix(tutorial): 우하단 고정 '도움말' 플로팅 버튼 제거`)이 플로팅 버튼을 "화면 내용과 겹쳐 보임" 이유로 제거했다. 재도입은 그 결정을 역행한다. (메뉴별 튜토리얼 PR1 설계 시 플로팅으로 계획했다가 이 이력 때문에 ChromeRight로 변경함.)

**How to apply:**
- `TutorialGuideButton`은 `ChromeRight`에 둔다. `sections`는 `layout.tsx → Chrome → ChromeRight → 버튼` 경로로 전달.
- `TutorialTour`는 effect 전용(return null) 유지 — 첫 방문 INTRO 자동 실행만. driver.js 실행은 공유 `run-tour.ts`의 `runTour()` 사용.
- 메뉴별 상세 튜토리얼 **완료**(#324 인프라 + #325 그룹보정·26메뉴 콘텐츠·UX, 모두 머지). plan `.claude/plans/20260604-102625-menu-tutorial.md`(completed). 콘텐츠 사전은 `tutorial-menu-copy.ts`(slug별), 누락/미구현 slug는 빌더가 skip(폴백 금지). 가이드 동작: 상단바 '가이드' 클릭 → 메뉴 개요 스텝에서 `router.push`로 그 메뉴 이동 → 인터랙션·버튼(설명 `<br>` 줄바꿈) 안내. 팝업은 `globals.css` `.ops-tour-popover`. vault·meetings 등 미구현 메뉴는 페이지 생기면 사전에 slug 추가하면 자동 합류. [[ops-console-dev-workflow]]
