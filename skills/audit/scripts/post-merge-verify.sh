#!/bin/bash
set -u
# post-merge-verify.sh — 자율머지 직후 fresh 검증 + 실패 시 auto-revert (T4/PR-3).
#
# auto-merge(merge-gate 통과)로 main 에 커밋이 랜딩한 직후 즉시 실행. deterministic
# health gate 를 돌려 머지가 구조 무결성을 깼는지 본다. 깼으면 그 커밋을 git revert 해
# 노출창(bad merge 가 main 에 존재하는 시간)을 최소화한다.
#
# health gate: sync-drift.sh --check + check-doc-counts.sh (둘 다 clean 시 exit 0).
#   ※ validate.sh full 은 self-hosted 에서 결정론적 오탐 baseline(F-P04)이라 제외 —
#     실제 회귀 판단엔 drift/doc-counts 같은 clean-exit 게이트를 쓴다. 심층은 CI(main) 백스톱.
#
# 입력:
#   $1                 = 검증·revert 대상 커밋 SHA (필수)
#   MERGE_VERIFY_CHECK = health 명령 override (테스트/커스텀; 기본 drift+doc-counts)
#   MERGE_VERIFY_DRYRUN=1 = 실 revert 안 함, "would revert" 만
# 출력: stderr 진행/alert. exit 0(healthy) / 3(bad merge — reverted 또는 would-revert) / 1(사용법).

COMMIT="${1:-}"
[ -z "$COMMIT" ] && { echo "usage: post-merge-verify.sh <commit-sha>" >&2; exit 1; }

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
DRYRUN="${MERGE_VERIFY_DRYRUN:-0}"

# ── health gate ──
if [ -n "${MERGE_VERIFY_CHECK:-}" ]; then
  HEALTH_CMD="$MERGE_VERIFY_CHECK"
else
  HEALTH_CMD="bash '$ROOT/core/scripts/sync-drift.sh' --check && bash '$ROOT/scripts/check-doc-counts.sh'"
fi

echo "[post-merge-verify] health gate 실행: $HEALTH_CMD" >&2
if eval "$HEALTH_CMD" >/dev/null 2>&1; then
  echo "[post-merge-verify] healthy — 머지 $COMMIT 유지" >&2
  exit 0
fi

# ── health 실패 → revert ──
echo "[post-merge-verify] ⚠ health FAIL — bad merge 감지: $COMMIT" >&2

if [ "$DRYRUN" = "1" ]; then
  echo "[post-merge-verify] DRYRUN — would revert $COMMIT (실 revert 안 함)" >&2
  exit 3
fi

# squash 머지(일반 커밋)면 그대로, merge 커밋이면 -m 1 폴백
if git revert --no-edit "$COMMIT" >/dev/null 2>&1; then
  :
elif git revert --no-edit -m 1 "$COMMIT" >/dev/null 2>&1; then
  :
else
  echo "[post-merge-verify] ✗ revert 실패 — 수동 개입 필요 (git revert $COMMIT)" >&2
  exit 3
fi

echo "[post-merge-verify] ✓ auto-revert 완료 — bad merge $COMMIT 되돌림. circuit breaker 검토 권장." >&2
# message-bus alert (있으면; 실패해도 비차단)
MB="$ROOT/.claude/hooks/message-bus.sh"
[ -x "$MB" ] && bash "$MB" send post-merge-verify retrospective regression high \
  "auto-revert: bad merge $COMMIT" "health gate 실패로 자율머지 되돌림" >/dev/null 2>&1 || true
exit 3
