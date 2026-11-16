# Project Memory

## OpsHub 프로젝트
- 경로: `/Users/yss/개발2/OpsHub`
- 내부운영관리시스템 대시보드
- Tech: Next.js 16 + shadcn/ui v4 + Tailwind CSS 4 + Recharts
- shadcn/ui v4는 Base UI 기반 → `asChild` 대신 `render` prop 사용
- 8개 메뉴: 오버뷰, 일정관리, 계약서관리, 서비스관리, 인수인계관리, 프로젝트관리, 계정설정, 관리자설정
- 라이트 테마 + 블루 액센트 + 다크 사이드바

## claude-builds 워크플로우 개선
- designer.md: 레퍼런스(URL/이미지) 감지 → design-sync 스킬 자동 선행 실행
- planner.md: 레퍼런스 확인 단계 추가
- design-sync SKILL.md: 에이전트 연동 섹션 추가 (호출 흐름 문서화)
- 흐름: 유저가 URL 제공 → planner 감지 → designer가 /design-sync --tokens-only 실행 → 토큰 기반 설계 → developer 구현

## 주의사항
- Next.js 16 + shadcn/ui v4: create-next-app에서 대문자 프로젝트명 불가 (npm 제한)
- claude-builds 템플릿 파일(templates/, hooks/ 등)은 tsconfig.json exclude에 추가 필요
- Figma Sites 등 JS 렌더링 사이트는 WebFetch로 분석 불가 → design-sync(Playwright) 사용
