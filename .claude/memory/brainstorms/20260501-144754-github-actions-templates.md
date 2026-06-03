# Brainstorm: GitHub Actions templates

작성: 2026-05-01T14:47:54Z (filename에서 추출, retroactive F-A4 fix)

## 의도
- **산출물**: vibe-flow `templates/.github/workflows/`에 사용자 프로젝트용 GH Actions YAML
- **사용자**: vibe-flow 설치한 vibe coder, 자기 프로젝트 CI 셋업 시 복사 사용 (opt-in)
- **트리거**: ROADMAP 미완 항목, 1.4.0 안정화 후 자연스러운 후속. 미루면 사용자 각자 다른 CI 작성 → vibe-flow 패턴 분기
- **성공**: (a) 1~3개 핵심 워크플로우, (b) vibe-flow `/verify` `/security` 패턴 반영, (c) stack-agnostic 우선

## 제약
- GH Actions YAML, ubuntu-latest, 외부 액션 최소 (checkout/setup-node 만)
- vibe-flow 1.x skill 시그니처 안정성 가정
- `templates/` 명명 규칙 (`.template` suffix은 CLAUDE.md만, 나머지는 그대로 복사)
- setup.sh는 selective copy — opt-in 경로 안전

## 대안 비교

| 항목 | A. Generic 혼합 3개 | B. verify.yml 단일 | C. Next.js 풀세트 | Z. do nothing |
|------|-------------------|------------------|-----------------|--------------|
| 파일 수 | 3 | 1 | 5+ | 0 |
| 비용 | 1~2시간 | 1시간 | 4~6시간 | 0 |
| 위험 | stack 감지 일부 미커버 | 자기 스킬 사용자 미커버 | Non-Next.js 배제 | 패턴 분기 누적 |
| 가역성 | 높음 | 높음 | 중 | 높음 |

### 대안 A 상세
- `verify.yml` — generic (npm/yarn/pnpm 자동 감지, lint/typecheck/test)
- `eval-regression.yml` — `.claude/skills/**` 변경 시 SKILL.md/evals.json 구조 검증 (vibe-flow 자체 CI 패턴 계승)
- `security.yml` — npm audit + 옵션 OWASP grep 패턴

## 추천 + 근거

**대안 A 채택.**

1. vibe-flow 강점이 "다양한 stack 일반화" → 템플릿도 generic-first 일관
2. eval-regression 포함으로 "사용자 = 자기 스킬도 만드는 사람" 메이커 spec 격려
3. `/security` workflow는 1-shot 저비용 + 큰 가치
4. setup.sh 자동 복사 X — README에 manual copy 안내 (opt-in 안전, 부수효과 0)

**기각 B**: 메이커 본인 eval-regression 패턴을 사용자에게 안 주는 건 아쉬움. 자기 스킬 만들기 시작하면 즉시 필요.
**기각 C**: opinionated Next.js는 vibe-flow stack-agnostic 설계와 충돌. Next.js 영역은 design-system extension 등 별도.

## 다음 단계
- HARD-GATE: 3 파일 (1-5 인라인 등급) → 직접 구현
- 권장 다음 스킬: 직접 구현
- 구현: branch `feat/gh-actions-templates`, files: `templates/.github/workflows/{verify,eval-regression,security}.yml` + README usage 섹션 + ROADMAP [x]
