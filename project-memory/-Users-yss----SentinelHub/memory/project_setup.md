---
name: SentinelHub 프로젝트 초기 셋업
description: Next.js 14 + Tailwind CSS 4 + Stitch 디자인 기반 내부운영관리시스템 셋업 완료 내역
type: project
---

SentinelHub 내부운영관리시스템 웹앱 프로젝트 초기 셋업 완료 (2026-03-26)

**Why:** Stitch에서 디자인한 퍼블 HTML 코드를 Next.js App Router 프로젝트로 전환하여 실제 운영 시스템 구축

**How to apply:**
- Next.js 14.2.x + React 18 + Tailwind CSS 4 스택
- Next.js 16은 `useContext` 빌드 에러 발생, 14.x 사용
- `NODE_ENV=development` 상태에서 `next build` 시 에러 발생 → `NODE_ENV=production next build`로 스크립트 설정
- 빌드 시 `--turbopack` 플래그는 Next.js 14에서 미지원
- Stitch 참고 파일(sentinelhub_1~16, aegis_grid_v2)은 .gitignore에 추가, 삭제 금지
- 디자인 토큰: Tailwind CSS 4의 `@theme inline` 디렉티브로 설정 (globals.css)
- 폰트: Pretendard + Material Symbols Outlined (CSS @import로 로딩)
- framer-motion v11 설치됨 (빌드 호환 확인 완료)
