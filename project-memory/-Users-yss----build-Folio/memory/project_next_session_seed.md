---
name: 다음 세션 시드 — 2026-05-12 후속 (InspectorListBody refactor epic 머지 완료)
description: PR #75~#78 + hotfix #79 모두 머지. InspectorListBody 800줄 달성. ListPattern은 미손
type: project
originSessionId: 2026-05-12-inspector-refactor
---

## 종료 시점

2026-05-12 19:50 KST. main HEAD `15d6964` (PR #78). working tree clean, origin sync.

## 이번 세션 결과 — InspectorListBody refactor epic (Phase 1~4) 완료

브레인스토밍: `.claude/memory/brainstorms/20260512-170727-listpattern-inspector-refactor.md`
플랜: `.claude/plans/20260512-171323-listpattern-inspector-refactor.md` (status: completed_partial)

| Phase | Variant | PR | 결과 |
|-------|---------|-----|------|
| 1 | cohort (패턴 확립) | #75 머지 | InspectorListBody 2176 → 1735 |
| 2 | receivables | #76 머지 | 1735 → 1402 |
| 3 | ai-work | #77 머지 | 1402 → 1092 |
| 4 | team | #78 머지 | 1092 → **787** (-1389, **64% 감소**) |
| hotfix | ListPattern useState 패턴 | #79 머지 | React Compiler 룰 통과 |

신규 디렉토리: `src/app/dashboard/_components/inspector/list-variants/`
- `types.ts` — Variant union + ViewProps/EditFormProps 통일
- `registry.ts` — import-time static binding (RSC 호환)
- `shared.tsx` — Section/DefList/Divider
- `{cohort,receivables,ai-work,team}/{View,EditForm}.tsx`

테스트: 74 GREEN (45 phase1 + 11 receivables + 10 ai-work + 8 team)

## 머지 시 학습 (학습 패턴 추가)

1. **main CI 잠복 에러 우선 처리** — PR #74 머지부터 main CI red. ListPattern.tsx:513 useEffect+setState 위반. PR #75~#78 머지 차단 원인. hotfix PR (#79)로 main에 먼저 패치 후 4 PR이 자동 통과 가능 상태로
2. **React Compiler "Storing information from previous renders" 패턴** — `useEffect+setState(prop)` 대체. `useState(prop) + if (prev !== prop) { setPrev(prop); setState(prop); }`. useRef-in-render도 차단되므로 useState 비교만 안전
3. **Stacked PR sequential squash merge의 conflict cascade** — 각 stacked PR이 누적 phase 포함 → 첫 PR squash 후 나머지가 DIRTY 상태로. 각각 main 재머지 + `git checkout --ours <files>` + push + CI 재대기 패턴 반복. 4 PR 머지에 약 30분 (CI 시간 포함)
4. **`gh pr edit --base main`이 GraphQL Projects deprecation 에러로 silently 실패** — `gh api PATCH /repos/.../pulls/N -f base=main` 직접 호출이 우회로

## 미진 / 백로그 (다음 epic 후보)

- **ListPattern.tsx 1220줄** — 이번 세션 미손. 별도 epic 필요. inspector와 변경 영역 분리되어 별도 brainstorm/plan 권장
- **schedule/my-todo/post-feedback/post-notice variant** — InspectorListBody에 잔존. 800줄 상한은 충족이라 ROI 낮음. 부채성 follow-up
- **default variant + registry fallback** — Phase 8 미수행. 부채성 follow-up

## 운영 상태

- main HEAD `15d6964`
- 모든 PR (#75~#79) 머지, 미머지 0
- working tree clean
- lint clean (pre-existing _omit warning 11건만 — schema 테스트의 일회성 미사용 변수)

## 부채 (장기)

- ListPattern 1220줄 (변동 +3, hotfix로 약간 증가)
- /_global-error Next.js 16 빌드 실패 (main에서도 발생)
- 사이드바 mock 도메인 count hardcode 잔존 (DB 없는 도메인)
- receivables count hardcode 7건 (Excel 외부)
