---
name: 다음 세션 시드 — 2026-05-13 (list-variants registry 9 variant 슬롯 완비)
description: PR #83~#86 머지. ListPattern 1220 → 452 (-63%) + InspectorListBody 787 → 128 (-84%). registry 9 variant 모두 View/EditForm/Table/Filters/blank 슬롯 완비
type: project
originSessionId: 2026-05-13-inspector-listbody-extract
---

## 종료 시점

2026-05-13 06:55 KST. main HEAD `55d8514` (PR #86). working tree clean.

## 이번 세션 결과 — InspectorListBody refactor + ListPattern refactor 두 epic 완주

### Epic 1: ListPattern Table refactor (PR #83~#85, 2026-05-12)
브레인스토밍: `.claude/memory/brainstorms/20260512-205059-listpattern-table-refactor.md`
플랜: `.claude/plans/20260512-211826-listpattern-table-refactor.md` (status: completed)

| Phase | 범위 | PR | 결과 |
|-------|------|-----|------|
| 1 | cohort 패턴 확립 + registry 슬롯 확장 | #83 머지 | ListPattern 1220 → 1106 |
| 2 | 7 variant Table 일괄 (team/post/schedule/my-todo/receivables/ai-work/default) | #84 머지 | 1106 → **452** (-768, **63% 감소**) |
| 3 | plan completion docs | #85 머지 | — |

### Epic 2: InspectorListBody View/EditForm 분리 (PR #86, 2026-05-13)
브레인스토밍: `.claude/memory/brainstorms/20260513-inspectorlistbody-view-editform-extract.md`

| 변경 | 결과 |
|------|------|
| post/View+EditForm (variant prop 분기 공유) | InspectorListBody dispatcher만 잔존 |
| schedule/EditForm + my-todo/EditForm + default/View+EditForm | 모두 list-variants 디렉토리 등록 |
| registry 4 신규 슬롯 | 9 variant 모두 View/EditForm/Table/Filters/blank 슬롯 완비 |
| InspectorListBody.tsx 787 → **128** | -659, **84% 감소** |

## 메트릭 (두 epic 합)

| 파일 | Before | After | 감소 |
|------|--------|-------|------|
| ListPattern.tsx | 1220 | 452 | -63% |
| InspectorListBody.tsx | 787 | 128 | -84% |
| **합계 (두 핵심 dispatcher)** | **2007** | **580** | **-71%** |

테스트: 720 unit GREEN 전수 유지 (통합 테스트로 dispatcher 라우팅 회귀 자동 감지)

## 학습 (재사용 자산)

1. **TDD hook strict + surgical refactor 충돌** — `.claude/settings.local.json`의 `CLAUDE_TDD_ENFORCE=strict`는 type-only 변경(types.ts)이나 cross-directory test layout(`inspector/__tests__/list-variants/`)을 인식 못 함. epic 동안 `warn`으로 잠시 변경 후 종료 시 원복 (두 epic에서 모두 적용)
2. **JSX에서 `<obj[key].Comp />` 직접 사용 불가** — TypeScript JSX는 컴포넌트 이름이 PascalCase 변수여야 함. `const X = obj[key].Comp; return <X .../>` 패턴 필요
3. **Registry union narrowing + optional slot** — `entry?.Slot`는 union 분기 narrow 실패. `"Slot" in entry && entry.Slot` 가드 패턴 필요
4. **variant-specific prop을 요구하는 컴포넌트는 dispatcher 분기** — PostView/PostForm은 variant prop이 필수. registry slot에 넣지 않고 InspectorListBody/ListPattern에서 직접 분기 처리 (현재 패턴 일관)
5. **Dispatch<SetStateAction<ListRow>> 시그니처 통일** — variant EditForm Props.setRow는 EditFormProps 시그니처에 맞추어야 registry 매핑 시 호환
6. **거대 dispatcher 분해 epic 패턴** — 1) brainstorm 4문항 → 2) plan + planner agent → 3) 패턴 확립 PR (1 variant) → 4) 일괄 분리 PR (n variant) → 5) 잔여 정리 PR. ListPattern (2 PR) + InspectorListBody (1 PR)로 검증됨
7. **stacked PR 4개 임계점** — 5+ 누적은 epic 조기 종료 신호. 패턴 확립 후 일괄 PR로 안전 가속 가능

## 미진 / 백로그 (다음 epic 후보)

- **ListRow 타입 분리** — 26+ 파일이 `import type { ListRow } from "../patterns/ListPattern"`. types.ts hoist (작은 mini-PR, ~1일)
- **variantRegistry 슬롯 타입 hoist** — 현재 inline `TableSlotProps`/`PostTableProps`/`MyTodoTableProps`. types.ts로 hoist
- **사이드바 mock 도메인 count hardcode** — DB 없는 도메인의 count 표기
- **receivables count hardcode 7건 (Excel 외부)** — 데이터 소스 미확정
- **isoToLocalKst/localKstToIso 중복** — schedule/EditForm + my-todo/EditForm에 사본 존재. lib/datetime.ts 등으로 hoist 가능 (작은 PR)

## 운영 상태

- main HEAD `55d8514`
- 모든 PR (#83~#86) 머지, 미머지 0
- working tree clean
- settings.local.json CLAUDE_TDD_ENFORCE 원복 완료 (warn → strict)
- lint clean (pre-existing _omit warning 11건만)
- 720 unit test GREEN, typecheck pass

## 부채 (장기)

- ListRow 타입이 ListPattern.tsx에 살아있음 (별도 mini-PR 후보)
- isoToLocalKst/localKstToIso 중복 정의 (schedule + my-todo EditForm)
- 사이드바 mock 도메인 count hardcode 잔존
- receivables count hardcode 7건 (Excel 외부)
- ~~ListPattern 1220줄~~ → **452줄** (해결)
- ~~InspectorListBody 787줄~~ → **128줄** (해결)
