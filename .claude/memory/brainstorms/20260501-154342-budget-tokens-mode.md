# Brainstorm: /budget token 추정 모드

작성: 2026-05-01T15:43:42Z (filename에서 추출, retroactive F-A4 fix)

## 의도
- **산출물**: `/budget --tokens` 옵션 — `~/.claude/projects/<slug>/*.jsonl` 파싱 → 모델별 token 합산 → 가격 곱셈 → 정확 USD
- **사용자**: vibe-flow 사용자, 정확 비용 필요 시점 (월말 정산, 비용 모니터링)
- **트리거**: ROADMAP 미완. 호출 카운트만으론 비용 추정 불가능 (스킬당 token 사용량 큰 차이)
- **성공**: (a) 모델별 input/output/cache 분리 합산, (b) 가격 1 파일 분리, (c) 기본 호출 카운트 모드 호환 유지

## 제약
- session-logs 위치 `${HOME}/.claude/projects/<slug>/*.jsonl`. 슬러그 = working dir 경로 변환 (macOS 기준)
- 프라이버시: 토큰 카운트만 사용, 프롬프트 내용 X
- 가격 정확도: Anthropic 가격 변동 → 별도 파일 분리해 업데이트 용이하게
- 코드베이스: `/budget` SKILL.md 수정, 가격 table은 신규 `pricing.json`

## 대안 비교

| 항목 | A. --tokens 추가 | B. /cost 분리 | C. primary 교체 | Z. do nothing |
|------|---------------|------------|-------------|--------------|
| 변경 | SKILL.md + pricing.json | 신규 스킬 | SKILL.md 큰 재작성 | 0 |
| 비용 | 1~2시간 | 2시간 | 3~4시간 | 0 |
| 위험 | 가격 stale | 스킬 혼동 | 기존 카운트 모드 잃음 | 비용 추정 불가 |
| 가역성 | 높음 | 중 | 낮음 | 높음 |

## 추천 + 근거

**대안 A 채택.**

1. 호출 카운트는 빠른 일일 추적, 토큰은 정밀 회계 — 분리 정당
2. pricing.json 별도 파일 → Anthropic 가격 변경 시 한 줄 PR
3. 호환성 100% (기본 그대로, --tokens opt-in)
4. ~30줄 jq + 모델 lookup → 작은 추가

**기각 B**: 사용자 인지 부담 (/budget vs /cost 분리). 같은 영역 분리하면 이해 비용 ↑
**기각 C**: 기본 mode 교체는 mental model 깸. Token 정확 비용은 보조 지표가 적절

## 다음 단계
- HARD-GATE: 2~3 파일 (1-5 인라인) → 직접 구현
- branch `feat/budget-tokens-mode`
- files: `core/skills/budget/SKILL.md`, `core/skills/budget/pricing.json`(신규), `core/skills/budget/evals/evals.json`, ROADMAP [x]
