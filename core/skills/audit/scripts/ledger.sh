#!/bin/bash
# ledger.sh — AHE decision-observability 원장 (audit finding 추적)
# rules/harness-evolution.md §4. finding 의 predicted_delta 기록 + 다음 라운드 actual_delta 반증.
#
# 저장: .claude/memory/audit-ledger.jsonl (1 finding = 1 JSON 라인)
# entry: {ts,round,id,component,dimension,evidence,root_cause,fix,predicted_delta,actual_delta,status}
#   status ∈ open|fixed|verified|refuted|deferred
#
# 사용법:
#   echo '{"round":"H","component":"skills","dimension":"D2","evidence":"x:1",
#          "root_cause":"y","fix":"z","predicted_delta":"+0.2"}' | ledger.sh append
#     → 전역 단일 시퀀스 id(F-<round><NN>) 자동 부여 + append, id 를 stdout 출력
#   ledger.sh resolve <id> <actual_delta> <status>   # actual_delta 채움 + 상태 전이
#   ledger.sh open                                    # status=open finding 목록
#   ledger.sh round <round>                           # 해당 라운드 finding 목록
#   ledger.sh next-num <round>                        # 다음 finding 번호(zero-pad)
#
# 환경: LEDGER 로 경로 override 가능(테스트용). 기본 = <git root>/.claude/memory/audit-ledger.jsonl

set -u

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
LEDGER="${LEDGER:-$PROJECT_ROOT/.claude/memory/audit-ledger.jsonl}"
mkdir -p "$(dirname "$LEDGER")" 2>/dev/null || true
touch "$LEDGER" 2>/dev/null || true

cmd="${1:-}"; shift 2>/dev/null || true

# 라운드 내 다음 번호 (기존 F-<round><NN> 최대값+1, 없으면 1) — 전역 단일 시퀀스
next_num() {
  local round="$1" max
  max=$(jq -r --arg r "$round" 'select(.round==$r) | .id | ltrimstr("F-") | ltrimstr($r)' "$LEDGER" 2>/dev/null \
        | grep -E '^[0-9]+$' | sort -n | tail -1)
  printf '%02d' "$(( ${max:-0} + 1 ))"
}

case "$cmd" in
  append)
    IN=$(cat)
    round=$(echo "$IN" | jq -r '.round // empty')
    [ -z "$round" ] && { echo "error: .round required" >&2; exit 1; }
    num=$(next_num "$round")
    id="F-${round}${num}"
    # id 충돌 방지(전역 단일): 이미 존재하면 거부
    if jq -e --arg i "$id" 'select(.id==$i)' "$LEDGER" >/dev/null 2>&1; then
      echo "error: id $id already exists" >&2; exit 1
    fi
    echo "$IN" | jq -c --arg id "$id" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{ts:$ts, round:.round, id:$id, component:.component, dimension:.dimension,
        evidence:.evidence, root_cause:.root_cause, fix:.fix,
        predicted_delta:.predicted_delta, actual_delta:null, status:"open", enqueued_task:null}' >> "$LEDGER"
    echo "$id"
    ;;
  resolve)
    id="${1:-}"; actual="${2:-}"; status="${3:-}"
    [ -z "$id" ] || [ -z "$status" ] && { echo "usage: resolve <id> <actual_delta> <status>" >&2; exit 1; }
    case "$status" in fixed|verified|refuted|deferred) ;; *) echo "error: status ∈ fixed|verified|refuted|deferred" >&2; exit 1 ;; esac
    jq -e --arg i "$id" 'select(.id==$i)' "$LEDGER" >/dev/null 2>&1 || { echo "error: id $id not found" >&2; exit 1; }
    tmp=$(mktemp)
    jq -c --arg i "$id" --arg a "$actual" --arg s "$status" \
      'if .id==$i then .actual_delta=$a | .status=$s else . end' "$LEDGER" > "$tmp" && mv "$tmp" "$LEDGER"
    echo "resolved $id → $status"
    ;;
  open)
    jq -r 'select(.status=="open") | "\(.id)\t\(.dimension)\t\(.fix)"' "$LEDGER" 2>/dev/null
    ;;
  round)
    r="${1:-}"; [ -z "$r" ] && { echo "usage: round <round>" >&2; exit 1; }
    jq -r --arg r "$r" 'select(.round==$r) | "\(.id)\t\(.status)\t\(.predicted_delta // "-")\t\(.actual_delta // "-")"' "$LEDGER" 2>/dev/null
    ;;
  next-num)
    r="${1:-}"; [ -z "$r" ] && { echo "usage: next-num <round>" >&2; exit 1; }
    next_num "$r"
    ;;
  enqueue)
    # improve 자동화: open finding(선택 round 필터)을 auto-build 큐에 적재 → cloud cycle 이 fix.
    # idempotent — .enqueued_task 있으면 skip(중복 큐잉 방지). harness-evolution.md §1 improve.
    r="${1:-}"
    QUEUE_SH="${QUEUE_SH:-$PROJECT_ROOT/core/skills/auto-build/scripts/queue.sh}"
    [ -f "$QUEUE_SH" ] || { echo "error: queue.sh not found: $QUEUE_SH" >&2; exit 1; }
    count=0
    ids=$(jq -r --arg r "$r" \
      'select(.status=="open") | select($r=="" or .round==$r) | select((.enqueued_task // null)==null) | .id' \
      "$LEDGER" 2>/dev/null)
    for id in $ids; do
      task=$(jq -r --arg i "$id" \
        'select(.id==$i) | "[audit \(.id)/\(.dimension)/\(.component)] \(.fix). 근거: \(.evidence). 원인: \(.root_cause). 예상효과: \(.predicted_delta)."' \
        "$LEDGER")
      qid=$(bash "$QUEUE_SH" add "$task" 2>/dev/null | sed -n 's/^queued: //p')
      [ -z "$qid" ] && { echo "warn: enqueue failed for $id" >&2; continue; }
      tmp=$(mktemp)
      jq -c --arg i "$id" --arg q "$qid" 'if .id==$i then .enqueued_task=$q else . end' "$LEDGER" > "$tmp" && mv "$tmp" "$LEDGER"
      echo "$id → queued $qid"
      count=$((count+1))
    done
    echo "enqueued $count finding(s)" >&2
    ;;
  mark-fixed)
    # fix PR 머지 시점 전이: open → fixed (actual_delta 는 null 유지 — 아직 미검증).
    # 다음 라운드가 pending-verify 로 집어 측정 후 resolve(verify/refute).
    id="${1:-}"; [ -z "$id" ] && { echo "usage: mark-fixed <id>" >&2; exit 1; }
    jq -e --arg i "$id" 'select(.id==$i)' "$LEDGER" >/dev/null 2>&1 || { echo "error: id $id not found" >&2; exit 1; }
    tmp=$(mktemp)
    jq -c --arg i "$id" 'if .id==$i then .status="fixed" else . end' "$LEDGER" > "$tmp" && mv "$tmp" "$LEDGER"
    echo "$id → fixed"
    ;;
  pending-verify)
    # decision-observability reconcile 워크리스트: fix 가 머지(status=fixed)됐으나
    # actual_delta 미기록인 finding. /audit Phase 0 가 측정 후 resolve 로 verify/refute.
    r="${1:-}"
    jq -r --arg r "$r" \
      'select(.status=="fixed") | select(.actual_delta==null) | select($r=="" or .round==$r) | "\(.id)\t\(.dimension)\t\(.predicted_delta // "-")\t\(.fix)"' \
      "$LEDGER" 2>/dev/null
    ;;
  *)
    echo "usage: ledger.sh {append|resolve|open|round|next-num|enqueue|mark-fixed|pending-verify}" >&2
    exit 2
    ;;
esac
