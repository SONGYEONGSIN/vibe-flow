# Brainstorm: security 강화 — OWASP 자동 hooks

## 의도
- **산출물**: PostToolUse Write/Edit 시 자동 OWASP 정적 lint hook (`core/hooks/security-lint.sh`). 변경 파일만 스캔, warn-only
- **사용자**: vibe coder, 코드 작성 직후 즉각 피드백 (commit/CI 전)
- **트리거**: ROADMAP 미완. 미루면 보안 위반이 commit/CI/PR까지 가서야 발견 → 피드백 루프 김
- **성공**: (a) Write/Edit 직후 < 200ms 응답, (b) 5+ OWASP 패턴 cover, (c) false positive < 5% (test/spec/templates 제외)

## 제약
- PostToolUse hook timeout 3000ms 한도, 목표 200ms
- 기존 hook (eslint-fix, prettier-format, pattern-check) 충돌 방지 — 별개 영역
- warn-only — vibe-flow hook 정책 (절대 차단 X)
- false positive: test/spec/markdown/lockfile/templates/ 제외
- stack-agnostic (정규식 기반)

## 대안 비교

| 항목 | A. 신규 hook | B. /security 자동 호출 | C. agent message-bus | D. eslint plugin | Z. do nothing |
|------|------------|--------------------|---------------------|----------------|--------------|
| 응답 | <200ms | 5~30s | 비동기 | <1s | n/a |
| stack | generic | generic | generic | JS/TS only | n/a |
| 위험 | false positive | hook 무거움 | 노이즈 | 의존 무거움 | 늦발견 |

## 추천 + 근거

**대안 A 채택.**

1. pattern-check.sh와 동일 패턴 (Write/Edit, warn-only, exit 0) — 학습 비용 ↓
2. grep 기반 ~200ms — 사용자 체감 X
3. stack-agnostic
4. 점진적 — 5 패턴부터 시작, 후속 보강
5. /security와 역할 분리 — hook은 즉각 정적, /security는 명시 deep scan

**기각 B**: full scan 백그라운드 무거움
**기각 C**: 메시지 비동기 → 즉각성 ↓
**기각 D**: JS/TS 한정 + eslint 의존, generic 충돌

## 시작 패턴 (5+ OWASP)
- A03 Injection: SQL string concat (`SELECT.*\+.*FROM`), `eval()` / `Function()`
- A07 XSS: `innerHTML\s*=`, `dangerouslySetInnerHTML`, `document.write`
- A02 Crypto/Secret: hardcoded `api[_-]?key|password|secret.*=.*["'][^"' ]{16,}`
- A01 Auth: hardcoded JWT secret (`jwt.*sign.*['"][^'"]{8,}`)
- A09 Logging: `console.log.*(password|token|secret)`

## 다음 단계
- HARD-GATE: 2~3 파일 (1-5 인라인)
- branch `feat/security-lint-hook`
- files: `core/hooks/security-lint.sh` (신규), `settings/settings.template.json` PostToolUse, `core/skills/security/SKILL.md` (hook 안내), README Hooks 24→25, ROADMAP [x]
