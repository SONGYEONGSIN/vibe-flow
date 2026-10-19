---
name: Skill discipline in claude-builds projects
description: claude-builds 셋업이 깔린 프로젝트에서는 룰 자동 주입에만 의지하지 말고 superpowers 스킬을 명시 호출해야 함. 빌드를 셋업한 목적 그 자체.
type: feedback
originSessionId: fa4d7468-5d81-4499-b474-305dc529d2ce
---
claude-builds(`.claude/{agents,skills,hooks,rules,scripts,memory,messages}`)가 셋업된 프로젝트에서는 work를 단순 코드 작성으로 진행하지 말고 다음을 명시 호출한다:

- `superpowers:brainstorming` — 새 기능/페이지/컴포넌트 신규 도입 전 (mockup이 명세 역할이면 스킵 가능)
- `superpowers:writing-plans` — 6+ 파일 변경, 다세션 작업, 의존성 단계 2+ (HARD-GATE 충족 시)
- `superpowers:test-driven-development` — runtime 로직 (UI 토글, 드로어, 메뉴 등도 포함). "스타일 전용 변경" 예외는 좁게 해석
- `superpowers:verification-before-completion` — "완료" 직전 무조건. tsc/lint/build만으로는 부족 (브라우저 콘솔, 시각, 인터랙션까지)
- `superpowers:requesting-code-review` — 매 스텝/배치 끝마다, 자체 PR 생성 전, merge 전. `superpowers:code-reviewer` 서브에이전트 dispatch
- `superpowers:systematic-debugging` — 모든 버그/실패에. 찍어맞추기 금지

**Why:** 사용자(송영석)가 명시 피드백 — *"그냥 진행하면 안되.. 해당 빌드를 사용하는 이유가 있는데"* (2026-04-26 세션). claude-builds 셋업의 ROI는 도구를 *실제로* 활용할 때 발생. 룰 자동 주입(파일 Write 시 system reminder)을 따르는 건 **필요조건**이지만 **충분조건이 아님**. 스킬 자체가 정의한 "1% 가능성이라도 있으면 호출하라"를 무시하면 빌드가 무용지물.

**How to apply:**
- 세션 시작 시 `/Users/yss/개발/build/<project>/.claude/skills/` 와 `/Users/yss/개발/build/<project>/.claude/agents/` 목록 확인. 무엇이 들어와있는지 안다.
- 작업 분류 시점에 매핑: 새 기능 → brainstorming. 멀티파일 → plan. runtime 로직 → TDD. 완료 직전 → verification. 스텝 끝 → review.
- 룰 자동 주입(rules/{conventions,donts,design,tdd}.md)은 **이미 따르고 있는 기준**으로 간주하고, 그 위에 스킬 호출을 얹는다.
- Folio처럼 mockup이 이미 완성된 프로젝트라도 `requesting-code-review` + `verification-before-completion`은 절대 스킵 금지. 코드 양/위험도가 작아 보여도.
- 스킬 호출은 *내가 부담하는 것*이 아니라 *사용자가 셋업하면서 의도한 것*이다.
