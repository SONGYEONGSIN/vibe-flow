#!/bin/bash
# git post-commit hook — emit commit_pushed event to .claude/events.jsonl
# 설치: setup.sh가 .git/hooks/post-commit으로 카피
# 직접 호출: bash core/hooks/git-post-commit.sh (cwd가 git repo)

set -u
# emit 실패해도 commit 자체는 성공 (post-commit hook 실패 시 commit 롤백 X이지만 stderr 출력은 회피)
trap '' ERR

# git 환경 확인 — 외부 (non-git) 환경에서 호출 시 silent 종료
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
EVENTS="${PROJECT_ROOT}/.claude/events.jsonl"

# .claude/ + events.jsonl 자동 생성
mkdir -p "${PROJECT_ROOT}/.claude"
[ -f "$EVENTS" ] || touch "$EVENTS"

# payload 4 필드
TYPE="commit_pushed"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
SUBJECT_RAW=$(git log -1 --pretty=%s 2>/dev/null || echo "")

# NFC 정규화 + 80자(character) truncate
if command -v python3 >/dev/null 2>&1; then
  SUBJECT=$(printf '%s' "$SUBJECT_RAW" | python3 -c "import sys, unicodedata; s = unicodedata.normalize('NFC', sys.stdin.read()); sys.stdout.write(s[:80])")
else
  # python3 부재 시 byte truncate fallback (한글 깨질 수 있음)
  SUBJECT=$(printf '%s' "$SUBJECT_RAW" | head -c 80)
fi

# jq로 escape 안전한 jsonl 라인 생성
LINE=$(jq -nc \
  --arg type "$TYPE" \
  --arg ts "$TS" \
  --arg branch "$BRANCH" \
  --arg subject "$SUBJECT" \
  '{type:$type, ts:$ts, branch:$branch, subject:$subject}')

echo "$LINE" >> "$EVENTS"
