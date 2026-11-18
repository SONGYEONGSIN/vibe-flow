---
name: repick-project-context
description: repick-Design Publishing 프로젝트의 목적·구조·표준 근거 — 디자인 HTML을 개발 퍼블 표준 패키지로 변환하는 본부 내부 도구
metadata: 
  node_type: memory
  type: project
  originSessionId: d53e5702-a78a-49f4-a377-4ab53ba2f8a0
  modified: 2026-07-25T18:13:31.528Z
---

repick-Design Publishing = 운영자(사용자)의 본부에서 타 본부 퍼블 의뢰를 없애기 위한 내부 도구.
디자이너/운영자의 자기완결 HTML을 업로드하면 개발 퍼블 표준 패키지(SCSS 구조 + 컴파일 CSS + REPORT.md)로 변환한다.

핵심 배경 (2026-07-17 구축):
- 과거 운영자가 바이브 코딩 HTML을 개발자에게 전달했다가 "CSS가 맞지 않아 별도 퍼블 필요" 반려됨.
  원인은 스타일 내용이 아니라 **파일 구조** — 개발 파이프라인은 scss 파셜→css 컴파일 구조(Live Sass Compiler)를 기대.
- 표준의 근거는 `reference/dev-output/ApplyModify/` (진학어플라이 계열 실물) — 추출 명세는 `docs/PUB-STANDARDS.md`.
  snake_case + `_com{N}` 컴포넌트, :root 토큰 ~60종, `@include medium`(1023px), PC/모바일 이중 마크업, jQuery 1.12.4.
- `reference/` 3종: dev-output(정답)/designer-output(입력 샘플, kebab-case라 표준과 멂)/operator-output(반려 사례).
- 주의: devDependency typescript는 **5.x 고정** (7.0.2 네이티브 프리뷰는 Next 16 빌드를 깨뜨림 — 실제 발생).
- 이 저장소엔 **ESLint 설정도 lint 스크립트도 없다**. 검증 3종은 `npx tsc --noEmit` / `npm test` / `npm run build`.
- `vitest.config.ts`에 `environment` 미설정 → **node 환경, DOM 없음**. 그래서 `app/page.tsx` 같은 UI는
  컴포넌트 테스트가 아니라 빌드+정독으로 검증하는 것이 이 저장소의 확립된 관례다.
  jsdom+testing-library 도입은 **두 차례 검토 후 범위 밖으로 배제**(2026-07-25/26) — 다시 묻지 말 것.
  대신 UI 결함은 최종 전체 리뷰와 사람의 실물 확인이 잡는다. 실제로 이 갭으로 새어나간 결함이
  두 번 다 최종 리뷰에서 나왔다(도구 모드가 파이프라인 상태를 무음 파괴, 폴링 무한 재시도).
- `readFileSync`로 런타임에 읽는 자산(`standards/**`, `prompts/**`)은 `next.config.ts`의
  `outputFileTracingIncludes`에 **라우트별로** 등록해야 한다. 빠뜨려도 로컬 dev는 멀쩡하고 배포에서만 터진다.

진행 (2026-07-25 기준):
- 고도화 1차(학습형 변환 엔진) main 머지 완료. 이후 Figma MCP 연동으로 넘어갔다.
- 상위 설계 `docs/FIGMA-MCP-연동-설계.md` — 조각 1(업로드에 figma-output 소스, PR #10) 완료,
  조각 2(00 디자인작업 단계 + `claude -p` headless) PR #11. 수정 모드와 조각 3 나머지는 미착수.
- **개발자 수용 검증(실제 수정 건 1건을 시스템 경유로 처리)은 여전히 미완** — 그게 최종 MVP 성공 기준.

환경 함정 (저장소에 안 남는 사실, 보안 추론 시 반드시 고려):
- 이 저장소의 `.claude/settings.local.json`에 `"defaultMode": "bypassPermissions"`가 있다.
  전역 gitignore(`~/.config/git/ignore`)에 걸려 **커밋에 안 실리는 머신 로컬 설정**이다.
- 서버가 `cwd=리포루트`로 띄우는 헤드리스 `claude -p`가 이걸 **상속**한다 → Bash 포함 전체 도구가 열린다.
  `--allowedTools`로 좁혀도 이미 열린 권한을 빼지 못한다(이 환경 조합에서 실측 확인).
- 결과: 스펙의 "Bash 없음 / bypassPermissions 미사용" 보장은 **이 머신에서 사실이 아니다**.
  코드는 의도대로 짜여 있고 브랜치도 이 파일을 싣지 않으므로, 남이 받으면 의도대로 동작한다.
  헤드리스 실행의 권한을 논할 때 이 상속을 빼먹으면 잘못된 결론이 난다.
