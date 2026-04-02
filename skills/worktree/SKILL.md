---
name: worktree
description: Git worktree 기반 격리 작업 환경을 생성/관리한다. 대규모 기능 개발 시 메인 브랜치에 영향 없이 병렬 작업한다.
---

Git worktree로 격리된 작업 환경을 관리한다.

## 사용법

```
/worktree create <branch-name>   — 새 worktree 생성
/worktree list                    — 현재 worktree 목록
/worktree remove <branch-name>   — worktree 정리
```

## 절차

### create

1. 브랜치명 확인 (케밥 케이스: `feat/user-auth`)
2. 프로젝트 루트 확인: `git rev-parse --show-toplevel`
3. worktree 생성:
   ```bash
   PROJECT_NAME=$(basename $(pwd))
   WORKTREE_PATH="../${PROJECT_NAME}-${BRANCH_NAME//\//-}"
   git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME"
   ```
4. 생성된 경로 안내
5. 해당 worktree에서도 `.claude/` 설정이 상속되는지 확인

### list

```bash
git worktree list
```

### remove

1. 해당 worktree에 미커밋 변경이 있는지 확인
2. 미커밋 있으면 경고 후 사용자 확인
3. 정리:
   ```bash
   git worktree remove "$WORKTREE_PATH"
   ```

## 사용 기준

- 20개 이상 파일 변경이 예상될 때 (HARD-GATE)
- 3개 이상 도메인에 걸치는 변경
- 실험적 변경 (성공 여부 불확실)
- 여러 기능을 병렬로 개발할 때

## 규칙

- worktree에서도 동일한 커밋/PR/TDD 규칙 적용
- worktree 네이밍: `../project-branch-type-name`
- 작업 완료 후 반드시 remove로 정리
