---
name: design-chrome-warm-white
description: 크롬 웜 화이트 디자인 리뉴얼 — #844 + 후속 #846까지 전부 머지 완료 (2026-07-12)
metadata: 
  node_type: memory
  type: project
  originSessionId: 3ee273c8-5592-48e5-9771-fdf637d1ed84
---

2026-07-12 사이드바/콘텐츠 배경 색 리뉴얼. **PR #844 squash 머지 완료** (main `78756db`).

**확정된 구성**:
- 상단 크롬 바(chrome-snow)·사이드바·브레드크럼/탭 밴드 = 웜 화이트 `#fffdf7` 통일
- 콘텐츠 본문 = paper `#fbf7f0` (크롬이 가장 밝고 본문이 반 단계 눌리는 3층 레이어링)
- 사이드바 유저카드 = `bg-situation-bg` + `border-line`(ink 검정 보더)
- 운영부 달력·주요업무 달력·프로젝트/간트 표 = `bg-cream`/`bg-washi-raised` → `bg-situation-bg`(#fdfdfb, 운영리포트 카드와 동일). 간트 헤더(모서리 셀·월 밴드)는 `bg-washi-raised`라 1차 교체에서 누락됐다가 머지 직전 수정
- `design-tokens.test.ts`가 sidebar/chromeSnow 값을 단언 — 색 바꾸면 이 테스트도 함께 갱신해야 CI 통과

**Why:** 사용자가 여러 방향을 실제 화면에 입혀 비교한 끝의 선택. 기각된 방향 — 다크 계열(Sumi/Espresso/Charcoal/Deep Teal/Soft Charcoal 전부), 웜그레이(greige), 중성 스노우 전체 테마(#f5f5f4 계열), 미드톤 그레이. "노란기 싫다"는 피드백도 있었으나 최종은 웜 화이트 크롬으로 회귀.

**How to apply:**
- 색 변경 시 주의: CrumbBar는 `bg-sidebar` 토큰(사이드바와 자동 동기), 활성 탭은 `bg-paper`(본문과 연결), CrumbBar 테스트가 `bg-sidebar`를 단언. design-tokens.ts(sidebar/chromeSnow)와 globals.css 양쪽 동기화 필수
- 색 후보 비교용 아트팩트(스와치 라이브 프리뷰) 재사용 가능: https://claude.ai/code/artifact/143c1541-5ffd-4f80-a518-e7ab75d0743b
- ~~잔여 후속: washi-raised 크림기~~ → **PR #846 머지 완료** (main `6f34f3d`, 2026-07-12): `--washi-raised` 토큰 `#f4eddd`→`#f5f2ec` 재정의(마크업 무변경 일괄 반영) + 선택 상태 표준을 vermilion 틴트(`bg-vermilion/10 text-vermilion`)로 전역 통일(목록 선택 행 27파일·사이드바 활성 메뉴), 매뉴얼 행 호버는 `hover:bg-washi-raised` 표준화. 메일 HTML/PDF 내장 색·인스펙터 토글·SchoolContactPicker는 의도적 제외
- ~~"오늘 할일" 영역 미처리~~ → **종결 (2026-07-12)**: "오늘 할 일" = 사이드바 my-todo 메뉴. 페이지 구성요소(주간 달력=주요업무 달력·프로젝트/간트 표)가 #844에서 이미 situation-bg 처리됐고 #846이 나머지 washi-raised를 커버 — 코드명이 "주요업무"라 당시 못 찾았을 뿐 같은 작업에서 커버됨. 사용자도 이미 변경된 것으로 확인
