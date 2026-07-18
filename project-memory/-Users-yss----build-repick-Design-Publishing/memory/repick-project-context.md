---
name: repick-project-context
description: repick-Design Publishing 프로젝트의 목적·구조·표준 근거 — 디자인 HTML을 개발 퍼블 표준 패키지로 변환하는 본부 내부 도구
metadata: 
  node_type: memory
  type: project
  originSessionId: d53e5702-a78a-49f4-a377-4ab53ba2f8a0
---

repick-Design Publishing = 운영자(사용자)의 본부에서 타 본부 퍼블 의뢰를 없애기 위한 내부 도구.
디자이너/운영자의 자기완결 HTML을 업로드하면 개발 퍼블 표준 패키지(SCSS 구조 + 컴파일 CSS + REPORT.md)로 변환한다.

핵심 배경 (2026-07-17 구축):
- 과거 운영자가 바이브 코딩 HTML을 개발자에게 전달했다가 "CSS가 맞지 않아 별도 퍼블 필요" 반려됨.
  원인은 스타일 내용이 아니라 **파일 구조** — 개발 파이프라인은 scss 파셜→css 컴파일 구조(Live Sass Compiler)를 기대.
- 표준의 근거는 `reference/dev-output/ApplyModify/` (진학어플라이 계열 실물) — 추출 명세는 `docs/PUB-STANDARDS.md`.
  snake_case + `_com{N}` 컴포넌트, :root 토큰 ~60종, `@include medium`(1023px), PC/모바일 이중 마크업, jQuery 1.12.4.
- `reference/` 3종: dev-output(정답)/designer-output(입력 샘플, kebab-case라 표준과 멂)/operator-output(반려 사례).
- 변환 엔진: `lib/standards.ts`(사전) + `lib/convert.ts`(css-tree 필터링 + hex→토큰 + sass 컴파일).
  표준 컴포넌트 재정의는 제거해 _common.scss에 위임, 사전에 없는 클래스는 "신규 컴포넌트"로 리포트 분리.
- 주의: devDependency typescript는 **5.x 고정** (7.0.2 네이티브 프리뷰는 Next 16 빌드를 깨뜨림 — 실제 발생).
- 다음 마일스톤: docs/PUB-STANDARDS.md 개발자 검수 → 실제 수정 건 1건을 시스템 경유로 처리(수용 판정이 MVP 성공 기준).
