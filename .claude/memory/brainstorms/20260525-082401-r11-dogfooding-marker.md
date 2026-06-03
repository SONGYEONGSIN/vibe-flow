# Brainstorm: R11 dogfooding marker (cloud cycle 세 번째 실 task)

작성: 2026-05-25T08:24:01Z (filename에서 추출, retroactive F-A4 fix)

## 의도

- **무엇을**: `core/skills/auto-build/SKILL.md` 말미에 `## R11 dogfooding marker` H2 섹션 1개 추가 (본문 1줄)
- **누가**: cloud remote agent (cron firing 자율 사이클)
- **왜 지금**: R11 dogfooding — F14/F15 (PR #77)에서 추가한 신규 관찰 로그 형식 (safety hook PASS stderr, orchestrator P3a/P3b 진입 stderr)이 cloud session에서 정상 출력되는지 검증 완료 표시
- **성공**: SKILL.md에 `## R11 dogfooding marker` 섹션이 말미에 추가되고 PR 생성 완료

## 제약

- 수정 파일은 `core/skills/auto-build/SKILL.md` 단 1개
- 기존 내용 수정 금지 — 말미에 append
- 빈 줄 1줄로 앞뒤 분리
- PR 제목: `docs(auto-build): R11 dogfooding marker`

## 대안 비교

| 방안 | 삽입 위치 | 장단점 |
|------|-----------|--------|
| A: 말미 append | R10 marker 바로 아래 (현재 파일 끝) | 시간순 일관성 유지, 가장 자연스러움 |
| B: R10 marker 이전 | 파일 중간 삽입 | 시간순 역행, 불필요한 diff 범위 |

## 추천 + 근거

**방안 A** — 말미 append. R9 → R10 → R11 시간순 배치가 dogfooding 이력 추적에 자연스럽고 diff 최소화.

## 다음 단계

hard_gate: inline (영향 파일 1개)
