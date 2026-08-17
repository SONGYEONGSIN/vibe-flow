#!/bin/bash
# firing-log.sh — cloud firing heartbeat (audit F-Y16)
#
# 왜: 무산출 firing 이 저장소에 아무 흔적도 남기지 않는다. 2026-08-12 / 08-15 / 08-17
# 세 번 모두 브랜치 0 / PR 0 / 커밋 0 이었고, "왜 조용한지" 를 사후에 알 방법이 없었다.
# 프롬프트는 "abort 시 stderr 에 사유"를 지시하지만 stderr 는 클라우드 세션에만 존재한다.
# heartbeat 는 firing 이 **어디까지 갔는지**를 저장소에 남겨 관측 가능하게 만든다.
#
# 제약 (둘 다 실측):
#   - 루프는 main 에 push 할 수 없다 — 브랜치 보호가 "Changes must be made through a
#     pull request" 로 거부한다.
#   - `git push --force` 는 auto-build-safety.sh 가 차단한다(destructive op).
#   → 전용 브랜치 `auto-build/firing-<UTC일자>` 에 **fast-forward 로만** 쌓는다.
#
# 사용:
#   bash core/skills/auto-build/scripts/firing-log.sh <phase> [<detail>]
#
# env:
#   FIRING_LOG_DRYRUN=1  — git 조작 없이 레코드만 stdout (smoke 안전 격리)
#   FIRING_LOG_STORE     — 로그 경로 override (기본 .claude/memory/firing-log.jsonl)
#   FIRING_LOG_BRANCH    — 브랜치 이름 override

set -u

PHASE="${1:-}"
DETAIL="${2:-}"
[ -z "$PHASE" ] && { echo "usage: firing-log.sh <phase> [<detail>]" >&2; exit 1; }

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
STORE="${FIRING_LOG_STORE:-$PROJECT_ROOT/.claude/memory/firing-log.jsonl}"
REL="${STORE#$PROJECT_ROOT/}"
BRANCH="${FIRING_LOG_BRANCH:-auto-build/firing-$(date -u +%Y%m%d)}"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SHA=$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo "-")

RECORD=$(jq -nc --arg ts "$TS" --arg p "$PHASE" --arg d "$DETAIL" --arg s "$SHA" \
  '{ts:$ts, phase:$p, detail:$d, base_sha:$s}')

if [ "${FIRING_LOG_DRYRUN:-0}" = "1" ]; then
  echo "$RECORD"
  echo "[firing-log] DRYRUN — would append to $REL on $BRANCH" >&2
  exit 0
fi

cd "$PROJECT_ROOT" || exit 1

# 현재 브랜치를 보존한다 — heartbeat 는 사이클 작업 흐름을 방해하면 안 된다.
PREV=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# 오늘자 heartbeat 브랜치가 origin 에 있으면 그 위에, 없으면 현재 HEAD 에서 시작.
if git fetch -q origin "$BRANCH" 2>/dev/null; then
  git checkout -q -B "$BRANCH" FETCH_HEAD 2>/dev/null || git checkout -q -B "$BRANCH"
else
  git checkout -q -B "$BRANCH" 2>/dev/null || { echo "[firing-log] WARN — 브랜치 생성 실패" >&2; exit 0; }
fi

mkdir -p "$(dirname "$STORE")"
echo "$RECORD" >> "$STORE"

git add "$REL" 2>/dev/null
if git diff --cached --quiet 2>/dev/null; then
  echo "[firing-log] 변경 없음 — skip" >&2
else
  git commit -q -m "chore(firing): $PHASE heartbeat $TS" 2>/dev/null || true
  # fast-forward push. 실패해도 사이클을 죽이지 않는다 — heartbeat 는 관찰 보조지 게이트가 아니다.
  git push -q origin "$BRANCH" 2>/dev/null \
    || echo "[firing-log] WARN — push 실패 (heartbeat 유실, 사이클은 계속)" >&2
fi

[ -n "$PREV" ] && git checkout -q "$PREV" 2>/dev/null
exit 0
