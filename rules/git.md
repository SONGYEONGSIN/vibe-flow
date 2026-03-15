# Git

## Conventional Commits

- 접두사 필수: `feat:`, `fix:`, `refactor:`, `test:`, `chore:`, `docs:`
- 한국어 메시지 (접두사만 영어)
- 제목 50자 이내, 본문은 선택

## 브랜치 네이밍

- `feat/<기능명>` — 새 기능
- `fix/<버그명>` — 버그 수정
- `refactor/<대상>` — 리팩토링
- `chore/<작업명>` — 설정, 의존성 등
- 이름은 케밥 케이스: `feat/user-auth`, `fix/login-redirect`

## PR 규칙

- PR 생성 시 전체 커밋 히스토리 분석
- PR 제목: Conventional Commit 형식 (`feat: 사용자 인증 추가`)
- PR 본문: `## Summary` + `## Test plan` 포함
- Squash merge 기본

## HARD-GATE

- **20개 이상** 파일 변경 시 Planner 에이전트 분석 필수
- Planner 호출: `subagent_type: Plan` 또는 `.claude/agents/planner.md` 직접 위임
- 그 외에는 바로 구현 가능
