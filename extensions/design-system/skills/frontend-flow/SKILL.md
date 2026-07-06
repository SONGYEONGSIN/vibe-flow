---
name: frontend-flow
description: 참고사이트 URL과 DESIGN.md를 입력하면 토큰 추출→정본화→기술선정→구현→검증까지 프론트엔드를 제작한다. 사용법 /frontend-flow <URL|--from-image 경로> [--design DESIGN.md]
effort: high
---

참고사이트 + DESIGN.md를 받아 기존 디자인 스킬을 지휘해 프론트엔드를 제작한다.
스택은 Next.js + Tailwind v4 + shadcn/ui 고정(예외만 문맥 라우팅).

## 사전 요구사항 (P0, fail-closed)

`bash scripts/preflight-deps.sh` — 의존성 누락 시 즉시 종료.

## 파이프라인

단계별 상세(입출력·게이트·실패처리)는 `references/pipeline.md`를 로드해 따른다.

- **P1 Analyze** — 참고사이트는 `/design-sync`로 토큰 역추출, DESIGN.md는 9섹션 파싱.
  병합해 루트 `DESIGN.md` 정본 생성 (`references/designmd-format.md` 스키마). 충돌 시 **게이트 A**.
- **P2 Research/Select** — `references/component-catalog.md` 계약에서 컴포넌트 선정, `frontend-plan.md` 작성.
- **게이트 B (메인 디렉팅)** — `prototype.html` + 정본 DESIGN.md + 기술선정안 승인. 모호점은 `AskUserQuestion`. 빌드 전에 프로토타입으로 먼저 승인.
- **P3 Build** — `frontend-design-specialist` 에이전트로 구현. 토큰만 사용(`design-lint` 훅). 다화면은 stitch-loop 바톤으로 토큰 강제 주입.
- **P4 Verify** — `/design-audit`(색상 커버리지) + `node scripts/anti-slop-check.js <src> <DESIGN.md>`
  (`references/anti-slop-preflight.md`). 실패 항목 수정. **게이트 C**.
- **P5 Learn** — ≥90% 성공 시 `learned/` 캐시.

## 브랜드 우선 원칙

추출된 브랜드 토큰이 anti-slop 기본 금지값을 이긴다 (`Inter`·순수 검정 등 명시 시 양보).
자세한 규칙은 `core/rules/design.md` §브랜드 우선 원칙 참조.

## 범위 밖

백엔드 구현, 배포/CI, 비-프론트 초기화, 카피라이팅.
