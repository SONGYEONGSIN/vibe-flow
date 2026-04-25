---
name: commit
description: Conventional Commit 메시지를 자동 생성하고 커밋한다
effort: low
---

Conventional Commit 메시지를 자동 생성하여 커밋한다.

## 현재 상태

- 스테이징: !`git diff --cached --stat 2>/dev/null || echo "(없음)"`
- 미스테이징: !`git diff --stat 2>/dev/null || echo "(없음)"`
- 최근 커밋 스타일: !`git log --oneline -3 2>/dev/null`

## 절차

1. 위 상태를 확인하여 스테이징된 변경 파악
2. 스테이징된 파일이 없으면 변경사항 확인 후 관련 파일 스테이징
3. `git diff --cached` 로 상세 diff 분석
4. 변경 내용에 맞는 Conventional Commit 메시지 생성:
   - `feat:` — 새 기능
   - `fix:` — 버그 수정
   - `refactor:` — 리팩토링
   - `test:` — 테스트 추가/수정
   - `chore:` — 설정, 의존성 등
   - `docs:` — 문서
5. 메시지를 사용자에게 보여주고 확인 후 커밋
6. 커밋 후 events.jsonl 기록 (retrospective의 커밋 패턴 분석 입력):
   ```bash
   COMMIT_TYPE=$(echo "$MSG" | grep -oE '^[a-z]+' | head -1)
   FILES=$(git diff-tree --no-commit-id --name-only -r HEAD | wc -l | tr -d ' ')
   echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"type\":\"commit_created\",\"commit_type\":\"$COMMIT_TYPE\",\"files_changed\":$FILES,\"sha\":\"$(git rev-parse --short HEAD)\"}" >> .claude/events.jsonl
   ```

## 규칙

- 메시지는 한국어로 작성
- 제목은 50자 이하
- 본문이 필요하면 빈 줄 후 상세 설명 추가
- `.env`, credentials 등 민감 파일은 커밋하지 않음
