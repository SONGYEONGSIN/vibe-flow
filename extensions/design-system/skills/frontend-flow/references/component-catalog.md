# 컴포넌트 카탈로그 (P2 선정 계약)

> shadcn/ui 블록을 계약으로 선정한다. 자유 창작 금지 — 이 표에서 고른다.
> 각 행의 `when_to_use`/`not_for`가 게이트 B에서 선정 근거로 감사된다.

| 블록 | when_to_use | not_for |
|---|---|---|
| button | 모든 액션 트리거 | 링크 네비게이션 (Link 사용) |
| card | 실제 elevation 위계가 필요할 때 | 단순 그룹핑 (border-t/divide-y 사용) |
| dialog | 모달 확인/폼 | 인라인 피드백 |
| table | 정형 데이터 행 | 카드형 컬렉션 |
| tabs | 동일 레벨 뷰 전환 | 순차 마법사 (Stepper 사용) |
| form | 검증 있는 입력 | 단일 검색창 |
| dropdown-menu | 액션 오버플로/컨텍스트 메뉴 | 폼 선택 (Select 사용) |
| sheet | 모바일 바텀시트/사이드 패널 | 데스크톱 주 네비게이션 |

## 선정 규칙

- **One family per project** — shadcn 계열 하나로 통일. Material/Carbon 등과 혼용 금지.
- **아이콘**: 한 패밀리(`@phosphor-icons/react` 권장), strokeWidth 전역 고정.
- **모션**: `motion/react`(구 framer-motion). 연속값은 `useMotionValue`, `useState` 금지.
- 예외 라우팅(데이터 집약→Carbon, 공공→GOV.UK)은 게이트 B에서 사용자 승인 후에만.
  **판정 규칙**(후보 제시 트리거): 참고사이트/DESIGN.md에서 표·대시보드가 화면의 과반이면 Carbon 후보, 정부기관 도메인(`.gov`/`.go.kr` 등)이거나 DESIGN.md `domain:`이 공공이면 GOV.UK 후보 — 두 경우 모두 게이트 B에서만 확정(자동 적용 금지).
