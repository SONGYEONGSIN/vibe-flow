---
name: 커밋 시 모든 변경 파일 확인
description: 작업 완료 후 커밋할 때 git status로 빠진 파일이 없는지 반드시 확인
type: feedback
---

작업 후 커밋 시 반드시 `git status`로 모든 변경 파일이 스테이징되었는지 확인할 것.

**Why:** 2026-03-20 회사에서 커밋 시 20개 파일 중 8개만 포함되어 스타일 변경사항이 누락됨. 집에서 pull했을 때 변경이 반영되지 않아 재작업 필요했음.
**How to apply:** 커밋 전 `git diff --name-only`와 `git status`로 변경 파일 전수 확인. 특히 대량 수정 시 파일 누락 주의.
