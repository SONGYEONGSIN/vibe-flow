---
name: status
description: 프로젝트 상태 대시보드 — git, CI, 배포 상태를 한눈에 보여준다
effort: low
---

프로젝트의 현재 상태를 대시보드 형태로 출력한다.

## 실시간 데이터

### Git
- 상태: !`git status --short 2>/dev/null | head -15 || echo "(git 미초기화)"`
- 브랜치: !`git branch --show-current 2>/dev/null`
- 최근 커밋: !`git log --oneline -5 2>/dev/null`
- 미커밋: !`git diff --stat 2>/dev/null | tail -1`
- 스테이징: !`git diff --cached --stat 2>/dev/null | tail -1`

### CI (GitHub Actions)
- !`gh run list --limit 3 2>/dev/null || echo "(gh CLI 미설치 또는 미연결)"`

### 의존성
- !`npm outdated 2>/dev/null | head -5 || echo "(package.json 없음)"`

## 출력 형식

```markdown
## 프로젝트 상태 대시보드

### Git

- **브랜치**: main
- **미커밋 변경**: N개 파일
- **최근 커밋**:
  - abc1234 feat: ...
  - def5678 fix: ...

### CI/CD

| 워크플로우 | 상태 | 커밋    | 시간   |
| ---------- | ---- | ------- | ------ |
| CI         | PASS | abc1234 | 2분 전 |

### 배포

- **URL**: https://...vercel.app
- **상태**: Ready

### 의존성

- 업데이트 가능: N개
```
