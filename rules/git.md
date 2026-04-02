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

## HARD-GATE (설계 등급)

모든 코드 변경에 설계가 필요하다. 규모에 따라 등급이 다르다.

| 변경 파일 수 | 설계 등급 | 요구사항 |
|-------------|----------|---------|
| 1~5개 | **인라인 설계** | 변경 의도 + 검증 방법 한 줄 |
| 6~19개 | **간략 설계** | 영향 분석 + 태스크 분해 (Planner 권장) |
| 20개 이상 | **전체 설계** | Planner 에이전트 분석 **필수** + 설계 문서 |

- Planner 호출: `subagent_type: Plan` 또는 `.claude/agents/planner.md` 직접 위임
- 20개 이상 변경 시 `git worktree` 격리 작업 권장 (`/worktree` 스킬 참조)

## Git Worktree

대규모 기능 개발 시 worktree로 격리하여 병렬 작업한다.

- 생성: `git worktree add ../project-feat-xxx feat/xxx`
- 네이밍: `../project-<branch-type>-<name>`
- 완료 후 정리: `git worktree remove ../project-feat-xxx`
- worktree에서도 동일한 커밋/PR 규칙 적용
