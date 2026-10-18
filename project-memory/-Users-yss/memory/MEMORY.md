# Memory

## 사용자 선호

- 디자인 참고 URL 제공 시 → Playwright로 CSS 추출 후 비교/적용 방식 선호
- `/design-sync` 스킬 생성됨 (AdminOps 프로젝트)
- 한국어 커뮤니케이션

## 디자인 싱크 패턴

디자인 URL → CSS 추출 → 비교 테이블 → 코드 수정 워크플로우:
1. Playwright `page.evaluate()`로 computed style 추출
2. Figma Sites는 뷰포트 스케일링 적용됨 → 보정 계수 필요 (보통 ×1.14)
3. 보정 계수 산정: 사이드바 메뉴 텍스트 실측값 vs 14px(text-sm) 비교
4. 검색/필터 요소는 별도 추출 필요 (input, select, button)
5. 임시 스크립트는 `scripts/` 폴더에 작성 후 완료 시 삭제
