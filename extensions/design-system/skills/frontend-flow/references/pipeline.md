# /frontend-flow 파이프라인 상세 (P0–P5)

> 각 단계의 입력·출력·게이트·실패처리. 오케스트레이터(SKILL.md)가 이 문서를 따라 실행한다.
> 재사용 스킬: P1 = `/design-sync`, P4 = `/design-audit` + `anti-slop-check.js`.

## P0 Intake

- **입력**: 참고사이트 URL (0~n, 선택) + DESIGN.md 경로 (선택). 최소 1개 필수.
- **동작**: `bash extensions/design-system/skills/frontend-flow/scripts/preflight-deps.sh`(루트 기준 풀 경로)로 의존성 fail-closed 체크. 입력 모드 감지(URL/이미지/로컬). 신규 빌드 vs 리스킨(기존 앱 개편) 판별.
- **실패처리**: 의존성 없으면 설치법 출력 후 **중단** (거짓 점수 방지).

## P1 Analyze

- **입력**: P0가 감지한 입력.
- **동작**: 사이트는 `/design-sync`로 토큰 역추출(고정 스키마 8종 요소 × 21종 CSS 속성). DESIGN.md는 9섹션 파싱. `why(DESIGN.md 의도) + what(사이트 HTML 사실)` 병합 → 루트 DESIGN.md 정본(`references/designmd-format.md` 스키마).
- **출력**: 루트 `DESIGN.md` 정본 + `preview.html` + `preview-dark.html`.
- **실패처리**: 추출 실패 시 부분 토큰 보존, 동적 사이트면 "불완전" 명시.

## Gate A (조건부)

- 사이트 토큰 ↔ DESIGN.md **충돌 항목**이 있을 때만 발동. 충돌 항목별로 사용자가 선택.

## P2 Research/Select

- **동작**: `references/component-catalog.md` 계약에서 컴포넌트 선정(자유 창작 금지). 3회 이상 반복 패턴은 `components/common/` 추출 후보로 표시, core vs site-specific 분리. 필요한 플러그인/API/앱쉘/폰트/아이콘/모션 라이브러리 선정.
- **출력**: `frontend-plan.md` (선정 근거 포함). 예외 라우팅 조건이면 대안 UI 라이브러리 제안.
- **실패처리**: 카탈로그 매칭 0이어도 core 컴포넌트로 진행(정상).

## Gate B (메인 디렉팅, 항상)

- `prototype.html` + 정본 DESIGN.md(MASTER) + `frontend-plan.md` + **'조용히 바꾸면 안 되는 것'**(라우트·nav 라벨·폼 필드·로고·법적 문구) 승인.
- 모든 모호한 결정을 `AskUserQuestion`으로 여기서 처리. 조용한 추측 금지.
- 비싼 P3 빌드 **전에** 정적 프로토타입으로 먼저 승인 → 토큰 낭비 방지.

## P3 Build

- **동작**: `frontend-design-specialist` 에이전트로 앱쉘 + 핵심 컴포넌트 + 대표 화면 구현. 토큰만 사용(`design-lint.sh` 훅이 하드코딩 색상 실시간 차단). 다화면이면 stitch-loop 바톤 방식으로 정본 토큰을 매 화면 프롬프트에 강제 주입 → 화면 간 일관성 보장.
- **실패처리**: 일부 화면 실패 시 성공분 보존 + 실패 목록 보고.

## P4 Verify

- **동작**: `/design-audit`(oklch 인식 색상 커버리지) + `/design-sync` 싱크율 pre/post(모드별 목표 URL 95% / 이미지 85~90%) + `node extensions/design-system/skills/frontend-flow/scripts/anti-slop-check.js <src> <DESIGN.md>`(루트 기준 풀 경로, `references/anti-slop-preflight.md`). 실제 브라우저 a11y(Playwright 접근성 트리)는 도구 있으면 실행, 없으면 graceful skip.
- **출력**: `events.jsonl` 텔레메트리(sync_rate_initial/final/target). skip 된 검사는 `status:skipped`로 기록(≠pass) — skip을 성공으로 오기록 금지.
- **실패처리**: 도구 없으면 graceful skip + 건너뛴 검사 명시. 단 **측정된 게이트가 하나도 없으면**(전부 skip) Gate C를 fail-closed 처리 — 거짓 점수 방지.

## Gate C (리뷰, 스킵 가능)

- pre-flight 리포트 + 싱크율 점수 + a11y 결과 리뷰. fail 항목 수정 후 재실행.

## P5 Learn (신규)

- ≥90% 성공 시 `learned/{site-hash}/`에 토큰·매핑 저장 → 유사 사이트 웜스타트.
