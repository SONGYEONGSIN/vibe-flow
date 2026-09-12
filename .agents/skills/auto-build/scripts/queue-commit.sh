#!/bin/bash
# /auto-build queue commit — queue.jsonl 변경 자동 git commit/push (Phase 3.1 PR-C3)
#
# 사용:
#   bash core/skills/auto-build/scripts/queue-commit.sh
#
# 동작:
#   1. queue.jsonl만 git add (drive-by 회피 — 다른 dirty 파일 무시)
#   2. commit message: "chore(auto-build): queue.jsonl 갱신 (<ts>)"
#   3. git push (현재 branch)
#
# env:
#   QUEUE_COMMIT_DRYRUN=1 — 실 commit/push 안 함, stderr echo만 (smoke 안전)
#   QUEUE_STORE          — queue.jsonl 경로 (기본 .claude/memory/auto-build-queue.jsonl)
#
# 정책 (PR-C3):
#   - queue.jsonl만 commit — auto-build cycle 중 다른 dirty 파일 commit 금지 (Surgical Changes)
#   - cloud agent는 clone 후 git pull --rebase로 충돌 회피 (single-writer 가정)
#   - branch 미명시 (현 HEAD 사용) — cloud는 main만 push 가정

set -u

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
QUEUE_STORE="${QUEUE_STORE:-$PROJECT_ROOT/.claude/memory/auto-build-queue.jsonl}"
DRYRUN="${QUEUE_COMMIT_DRYRUN:-0}"

if [ ! -f "$QUEUE_STORE" ]; then
  echo "queue-commit: $QUEUE_STORE 부재 — skip" >&2
  exit 0
fi

REL_PATH=$(realpath --relative-to="$PROJECT_ROOT" "$QUEUE_STORE" 2>/dev/null || \
           python3 -c "import os; print(os.path.relpath('$QUEUE_STORE', '$PROJECT_ROOT'))" 2>/dev/null || \
           echo ".claude/memory/auto-build-queue.jsonl")

if [ "$DRYRUN" = "1" ]; then
  echo "would commit & push: $REL_PATH (current branch)" >&2
  exit 0
fi

# ── 실 commit/push ─────────────────────────────────────────
cd "$PROJECT_ROOT" || { echo "queue-commit: cd $PROJECT_ROOT 실패" >&2; exit 1; }

# queue.jsonl만 add (drive-by 회피)
git add "$REL_PATH" || { echo "queue-commit: git add 실패" >&2; exit 1; }

# 변경 없으면 skip
if git diff --cached --quiet "$REL_PATH"; then
  echo "queue-commit: $REL_PATH 변경 없음 — commit skip" >&2
  exit 0
fi

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
git commit -m "chore(auto-build): queue.jsonl 갱신 ($TS)" >&2 || \
  { echo "queue-commit: git commit 실패" >&2; exit 1; }

git push >&2 || { echo "queue-commit: git push 실패" >&2; exit 1; }
echo "queue-commit: $REL_PATH committed & pushed ($TS)" >&2
exit 0
