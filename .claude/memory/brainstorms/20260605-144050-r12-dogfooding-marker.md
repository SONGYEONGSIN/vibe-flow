# Brainstorm: R12 dogfooding marker 추가

## 의도
- **무엇을**: `core/skills/auto-build/SKILL.md` 말미에 `## R12 dogfooding marker` H2 섹션 1개 추가
- **누가**: auto-build 자율 에이전트 (R13 재무장 사이클)
- **왜 지금**: R12 cron firing (trig_01RcUNYjHFh4t2k5UrKo75MB, 2026-05-26) silent fail — PR 미생성 + queue 미업데이트. 원인: run-cloud.sh가 gh CLI 부재 시 실 cycle 미활성 분기로 entry queued 복구. R13에서 직접 P0~P5 실행으로 처리.
- **성공**: PR 머지 후 SKILL.md에 `## R12 dogfooding marker` 섹션 존재 확인

## 제약
- 수정 파일: `core/skills/auto-build/SKILL.md` 1개만
- 삽입 위치: 기존 ## R11 dogfooding marker 바로 아래 (말미)
- 빈 줄 1줄로 앞뒤 분리
- PR 제목: `docs(auto-build): R12 dogfooding marker`

## 대안 비교

| 대안 | 장점 | 단점 |
|------|------|------|
| 말미 append (추천) | 시간순 정렬 유지, 기존 R9~R11 패턴 일관 | 없음 |
| ## R11 앞 삽입 | 없음 | 역순, 기존 패턴 위반 |

## 추천 + 근거
- **말미 append** — R9, R10, R11이 모두 시간순 말미 추가 패턴. 일관성 유지.
- 기각: ## R11 앞 삽입 — 역순으로 기존 패턴 위반

## 다음 단계
hard_gate: inline (1개 파일, 4줄 변경)
