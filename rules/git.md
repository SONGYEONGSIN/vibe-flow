# Git

## Conventional Commits

- 접두사 필수: `feat:`, `fix:`, `refactor:`, `test:`, `chore:`, `docs:`
- 한국어 메시지 (접두사만 영어)
- 제목 50자 이내, 본문은 선택

### Squash merge 기본 정책 하의 운용

PR 규칙은 squash merge 기본이다. 따라서 conventional 형식의 강제 지점은 다음과 같다:

- **PR 제목 (필수)**: squash 후 main에 남는 단일 커밋이 되므로 **반드시** conventional 형식
- **개별 커밋 (자유)**: 작업 중 커밋은 의미 단위로 자유롭게 (한국어 자유 문장 허용)
- **권장**: 머지 직전 `git rebase -i`로 의미 단위로 정리하여 squash 후에도 의도가 살도록 한다

이렇게 하면 main 히스토리는 conventional 형식으로 일관되고, 작업 중에는 부담 없이 작은 커밋을 쌓을 수 있다.

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
- **복잡도 보정**: 파일 수 외에 영향도 큰 변경(모듈 추출, DB 스키마, 공개 API 변경, 인증/권한 로직 수정)은 한 등급 상향. 1개 파일이라도 200줄 이상 리팩토링이면 간략 설계 이상 적용.

## Git Worktree

대규모 기능 개발 시 worktree로 격리하여 병렬 작업한다.

- 생성: `git worktree add ../project-feat-xxx feat/xxx`
- 네이밍: `../project-<branch-type>-<name>`
- 완료 후 정리: `git worktree remove ../project-feat-xxx`
- worktree에서도 동일한 커밋/PR 규칙 적용
