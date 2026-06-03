# Brainstorm: R10 dogfooding marker 추가

작성: 2026-05-25T03:01:50Z (filename에서 추출, retroactive F-A4 fix)

## 의도

- **무엇을**: `core/skills/auto-build/SKILL.md` 파일 말미에 R10 dogfooding marker H2 섹션 1개 추가
- **누가**: auto-build cloud cycle (cron-triggered remote agent)
- **왜 지금**: R10 dogfooding 사이클이 safety hook + vote 코드 path + orchestrator P0~P5 정상 통과를 검증하기 위한 두 번째 실 task
- **성공**: PR 머지 후 SKILL.md에 `## R10 dogfooding marker` 섹션이 기존 R9 마커 아래에 존재

## 제약

- 수정 대상: `core/skills/auto-build/SKILL.md` 단일 파일
- 다른 파일 절대 수정 금지
- 빈 줄 1줄로 앞뒤 분리
- PR 제목: `docs(auto-build): R10 dogfooding marker`

## 대안 비교

| 삽입 위치 | 장점 | 단점 |
|-----------|------|------|
| A. 파일 말미 (R9 아래) | 시간순 자연스러운 누적 | 없음 |
| B. R9 바로 위 | 역순 정렬 | 시간순 역행 — 혼란 |

## 추천 + 근거

**A 선택**: 파일 말미에 R9 바로 아래 삽입. R9 마커와 동일 패턴으로 시간순 누적. B는 시간순 역행으로 부자연스럽다.

## 다음 단계

- hard_gate: inline
- 영향 파일: 1개 (`core/skills/auto-build/SKILL.md`)
- 변경 규모: 4줄 추가 (빈줄 + H2 헤더 + 빈줄 + 본문)
