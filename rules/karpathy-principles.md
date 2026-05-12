# Karpathy 4 원칙 — LLM 코딩 함정 회피

Andrej Karpathy가 공개한 LLM 코딩의 흔한 함정 관찰에서 도출된 4 원칙. 본 파일은 4 원칙을 명시하고, **각 원칙이 vibe-flow의 어느 rules/skills와 매핑되는지** cross-link한다.

원본 메시지: *"best instruction files get shorter at the top and more specific at the leaves"* — CLAUDE.md를 거대하게 만들지 말고, 작업 원칙을 짧고 specific하게 leaves(다른 rules 파일)로 분리하라.

---

## 1. Think Before Coding

> "State your assumptions explicitly. If uncertain, ask."

**원칙**:
- 구현 전 가정을 명시한다
- 모호하면 침묵하지 말고 stop & ask
- 여러 해석이 가능하면 모두 제시
- 혼란을 숨기지 말고 표면화

**vibe-flow 적용**:
- `rules/conventions.md` "설계 선행 원칙" — 4문항 체크리스트(무엇/왜/영향/검증)
- `skills/brainstorm/SKILL.md` — `/brainstorm` 스킬이 4문항 강제. 모호하면 사용자에게 확인 후 진행
- `skills/auto-build/SKILL.md` "호출 형태" — task description 4문항(무엇을/누가/왜 지금/성공) 필수, 누락 시 P1 abort

**Anti-pattern** (Karpathy 인용): *"models make wrong assumptions on your behalf and just run along with them without checking. They don't manage their confusion, don't seek clarifications."*

---

## 2. Simplicity First

> "Minimum code that solves the problem. Nothing speculative."

**원칙**:
- 요청된 것만 구현
- 일회용 코드에 추상화 추가 X
- 요청 안 한 설정 가능성 X
- 불가능 상황의 오류 처리 X
- 복잡해지면 단순하게 다시 쓰기

**vibe-flow 적용**:
- `rules/donts.md` "패턴 — 폴백 로직 금지" — graceful degradation, backwards-compatibility shim 작성 X
- System prompt: *"Don't add features, refactor, or introduce abstractions beyond what the task requires"* + *"Don't add error handling, fallbacks, or validation for scenarios that can't happen"*
- `rules/conventions.md` "기존 스타일 일관성" — 본인 취향과 다르더라도 기존 스타일 유지, drive-by 변경 X

**Anti-pattern**: *"agents love to build flexible, reusable, 'future-proof' systems, even when you just need a small fix... implement a bloated construction over 1000 lines when 100 would do."*

---

## 3. Surgical Changes

> "Touch only what you must. Clean up only your own mess."

**원칙**:
- 기존 코드 무분별하게 개선 X
- 작동하는 코드는 리팩토링 X
- 기존 스타일 따르기
- 본인 변경으로 인한 미사용만 제거

**vibe-flow 적용** (가장 강한 매핑):
- `rules/donts.md` "Surgical Change (작업 범위)" 섹션 — 무관한 dead code 발견 시 언급만 / 본인 변경의 orphan만 정리 / 인접 코드 "개선" 금지
- `rules/git.md` HARD-GATE 등급 — 변경 파일 수 1~5/6~19/20+ 등급별 설계 강도. **scope creep 방지 게이트**
- System prompt: *"NEVER modify files not mentioned in the task. NEVER change formatting or style in untouched files"*

**Anti-pattern**: *"models still sometimes change/remove comments and code they don't sufficiently understand as side effects, even if orthogonal to the task."*

---

## 4. Goal-Driven Execution

> "Define success criteria. Loop until verified."

**원칙**:
- 검증 가능한 목표로 변환
- 다단계 작업은 계획 수립
- 각 단계 확인 항목 명시
- 명확한 성공 기준으로 독립 실행

**vibe-flow 적용**:
- `rules/conventions.md` "최소 설계 체크리스트" 4번 — "검증: 변경 후 어떻게 확인할 것인가"
- `skills/auto-build/SKILL.md` 호출 형태 4문항의 "성공" 필드 필수
- `skills/verify/SKILL.md` — `/verify` 스킬이 lint/typecheck/test/E2E 순차 실행으로 성공 기준 자동 검증
- `rules/tdd.md` RED-GREEN-REFACTOR — RED 단계가 곧 성공 기준 정의

---

## CLAUDE.md.template 디자인 정합성

vibe-flow는 영상의 메시지("CLAUDE.md를 거대하게 만들지 마라")와 일치하는 디자인:

- `CLAUDE.md.template` = **프로젝트 메타** (tech stack / structure / commands) 만
- `core/rules/*.md` = **작업 원칙** (conventions / donts / git / tdd / debugging / design / **karpathy-principles**) 분리
- `core/skills/*.md` = **트리거 기반** (사용 시점에만 활성)

→ CLAUDE.md가 leaves로 분리돼 단일 파일 비대 회피.

---

## 출처

- [Andrej Karpathy](https://x.com/karpathy) — LLM 코딩 함정 관찰
- [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills) — 4 원칙 65줄 CLAUDE.md (GitHub 10만 스타)
- [Yanli Liu — "The 4 Lines Every CLAUDE.md Needs"](https://levelup.gitconnected.com/the-4-lines-every-claude-md-needs-2717a46866f6) (Level Up Coding, 2026-04)
- 실뱃개발자 (@sv.developer) YouTube — "안드레 카파시가 알려준 CLAUDE.md의 비밀"
