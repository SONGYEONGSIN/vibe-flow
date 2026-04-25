# Changelog

## [Unreleased]

### 추가
- **`/brainstorm` 스킬** — 구현 전 의도/제약/대안 구조화 탐색. 4문항 의도 검증 + 제약 발견 + 최소 2개 대안 + do-nothing 옵션 + 추천/기각 근거. 결과는 `.claude/memory/brainstorms/`에 저장되어 다음 세션 인계 + retrospective 분석 입력. designer Phase 0가 디자인 한정이라면 /brainstorm은 도메인 무관 일반 의도 탐색. (Superpowers brainstorming 패턴 참조)
- **`/plan` 스킬** — 멀티스텝 작업의 계획을 `.claude/plans/`에 파일화하여 사용자 합의 + 단계별 추적. planner 에이전트로 영향 파일/단계 분해/리스크 분석, frontmatter status로 in_progress/completed/abandoned 라이프사이클 관리. brainstorm spec 헤더 계약(`## 의도 / ## 제약 / ## 추천 + 근거 / ## 다음 단계`)을 입력으로 받아 호환. 이탈은 silent 수정 금지 — `/plan revise`로 명시적 처리. (Superpowers writing-plans 패턴 참조)
- **`/finish` 스킬** — 작업 완료 시 머지/PR/cleanup 경로 자동 판정 + 의사결정 트리. 상태 점검(브랜치/미커밋/verify/활성 plan) → HARD-GATE 등급별 경로 안내(PR/direct push/release/cleanup). 미커밋·미통과·main 직접·pending step 등 결손 상태는 차단하고 해결 명령 명시. push/pr 자동 실행 안 함 — 결정만 자동화, 실행은 사용자 명령으로. (Superpowers finishing-a-development-branch 패턴 참조)
- **`/receive-review` 스킬** — 리뷰 피드백을 항목별로 분리 + 6 카테고리(bug/security/performance/architecture/style/preference) 분류 + 증거 기반 검증 후 accept/reject/clarify 명시 의사결정. performative agreement도 defensive rejection도 차단. 결과는 `.claude/memory/reviews/`에 저장 + events.jsonl 기록. 5 안티패턴(performative agreement / defensive rejection / scope creep agreement / preference vs principle 혼동 / silent ignore) 명시 차단. (Superpowers receiving-code-review 패턴 참조)

## [1.0.0] - 2026-04-16

첫 안정 릴리즈. 62 커밋의 누적 작업물.

### 에이전트 (12개)
- 12개 전문 에이전트 시스템: planner, designer, developer, qa, security, feedback, grader, comparator, validator, skill-reviewer, moderator, retrospective
- 파일 기반 메시지 버스로 에이전트 간 비동기 통신
- 구조화된 토론 시스템 (자동 트리거 + moderator 중재)

### 스킬 (19개)

| 카테고리 | 스킬 |
|---------|------|
| 개발 흐름 | `/commit`, `/pair`, `/scaffold`, `/worktree` |
| 검증 | `/verify`, `/test`, `/security`, `/review-pr` |
| 디자인 | `/design-sync` (URL/이미지/로컬 7단계), `/design-audit` |
| 분석 | `/feedback`, `/metrics`, `/status`, `/retrospective` |
| 학습 | `/learn`, `/discuss` |
| 품질 진화 | `/eval`, `/evolve` (Hermes Agent self-evolution 패턴) |
| 릴리즈 | `/release` (semver 자동 판단 + CHANGELOG 관리) |

### 훅 (22개)
- PreToolUse 파이프라인: command-guard, smart-guard, tdd-enforce
- PostToolUse 파이프라인: prettier, eslint, typecheck, test-runner, metrics, pattern-check, design-lint, debate-trigger, readme-sync
- 에러 분류: 13-class error classifier (Hermes Agent 패턴)
- 컨텍스트 압축: context-prune (도구 출력 1줄 요약, 12KB 예산)
- 모델 라우팅: model-suggest (events.jsonl 패턴 분석 → 비차단 제안)
- 세션 관리: session-review, session-log, uncommitted-warn

### 인프라
- SQLite instinct store (Migration v1-v3, 13개 사전 쿼리)
- Dual-write: JSON + SQLite + JSONL 3중 기록
- 실시간 관측 스트림 (watch-events.sh + events-tail.js)
- setup.sh 원클릭 설치 + validate.sh 5단계 검증
- 오케스트레이터: Claude Squad (tmux) + Agent Orchestrator (CI/CD) + 대안 도구 안내

### 규칙 (6개)
- conventions, tdd, git, design, donts, debugging
- Memory context fencing (Hermes Agent 패턴)
- $ARGUMENTS 검증 공통 규칙

### 출처
- SQLite Store: [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code)
- 관측 스트림: [disler/claude-code-hooks-multi-agent-observability](https://github.com/disler/claude-code-hooks-multi-agent-observability)
- TDD 강제화: [obra/superpowers](https://github.com/obra/superpowers)
- Pair Mode: [disler/claude-code-hooks-mastery](https://github.com/disler/claude-code-hooks-mastery)
- Error Classifier, Context Compressor, Memory Fencing, Model Routing, Self-Evolution: [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)
- Release Skill: [Shpigford/chops](https://github.com/Shpigford/chops)
