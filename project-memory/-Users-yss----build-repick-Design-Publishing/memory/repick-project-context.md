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

고도화 1차 완료 (2026-07-19, 브랜치 feat/learning-conversion-engine, 14커밋, 37/37 테스트):
= "완결적 변환 엔진(학습형)". 설계 docs/superpowers/specs/2026-07-19-*, 계획 docs/superpowers/plans/2026-07-19-*.
- 학습 매핑 루프: 미지 kebab클래스/이모지/골격을 제안→사용자 확정→standards/mappings.json 저장→다음부터 자동.
  lib/propose.ts(제안)+lib/mappings.ts(저장)+lib/convert.ts 2단계(applyMappings 자동적용→proposeUnknowns).
- 표준 사전 자동 도출: lib/standards.ts가 standards/scss/*를 파싱(토큰=regex, 컴포넌트=full∖base 컴파일 set-diff). "동기화=scss 교체".
- 미리보기(lib/preview.ts, iframe srcDoc), 이력(lib/history.ts, output/history.json), API /api/convert·confirm·history.
- vitest는 vitest.config.ts로 @/ alias 해석. api-flow 테스트는 mappings.json snapshot/restore로 self-heal.
- 승인된 후속(미구현): ①이력 재다운로드+output/<Feature>/ 디스크저장(MVP는 list-only) ②loadMappings plain-object 가드(다중사용자 B에서 필요) ③iconMap 치환 HTML 재파싱 견고화. 상세 .superpowers/sdd/progress.md.
- **아직 main 미머지, 개발자 수용 검증(1건) 미완** — 그게 최종 MVP 성공 기준.
- 다음 마일스톤: docs/PUB-STANDARDS.md 개발자 검수 → 실제 수정 건 1건을 시스템 경유로 처리(수용 판정이 성공 기준). 성공 시 B(역할 워크플로 공간) 착수.
