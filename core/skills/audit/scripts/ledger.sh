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

# F-K11 (audit R11): 손상된 라인 1개가 next_num(:32) 과 id 충돌검사 둘 다를 fail-open 시킨다.
# 둘 다 `jq ... 2>/dev/null` 이라 파스 에러를 "비어있음/존재하지 않음"으로 해석하고,
# 두 fail-open read 가 합성돼 이미 존재하는 id 를 재발급한다 (중복 primary key).
# 감사 이력은 append-only 신뢰가 전제이므로 손상 시 조용히 진행하지 않고 즉시 중단한다.
if [ -s "$LEDGER" ] && ! jq empty "$LEDGER" >/dev/null 2>&1; then
  echo "error: ledger corrupt — 수동 복구 필요: $LEDGER" >&2
  exit 3
fi

cmd="${1:-}"; shift 2>/dev/null || true

# 라운드 내 다음 번호 (기존 F-<round><NN> 최대값+1, 없으면 1) — 전역 단일 시퀀스
next_num() {
  local round="$1" max
  max=$(jq -r --arg r "$round" 'select(.round==$r) | .id | ltrimstr("F-") | ltrimstr($r)' "$LEDGER" 2>/dev/null \
        | grep -E '^[0-9]+$' | sort -n | tail -1)
  # 10# 강제 base-10 — leading-zero(08/09)를 8진수로 오해석하는 버그 방지
  printf '%02d' "$(( 10#${max:-0} + 1 ))"
}

# F-I04/F-I07 (audit R9): 모든 mutating 커맨드(append/resolve/mark-fixed/enqueue)의
# read-modify-write 를 mkdir 원자 락으로 직렬화. F-H02(R8)는 append 만 보호해 병렬 resolve
# 시 lost-update 발생. trap 으로 crash/SIGINT 시 stale lock 자동 해제(F-I07).
LOCK="$LEDGER.lock"
acquire_lock() {
  local tries=0
  until mkdir "$LOCK" 2>/dev/null; do
    tries=$((tries + 1)); [ "$tries" -gt 100 ] && { echo "error: ledger lock timeout" >&2; exit 1; }
    sleep 0.05
  done
  trap 'rmdir "$LOCK" 2>/dev/null' EXIT INT TERM
}
release_lock() { rmdir "$LOCK" 2>/dev/null; trap - EXIT INT TERM; }

case "$cmd" in
  append)
    IN=$(cat)
    round=$(echo "$IN" | jq -r '.round // empty')
    [ -z "$round" ] && { echo "error: .round required" >&2; exit 1; }
    # F-K01 (audit R11): rules/harness-evolution.md §3 의 4-필드 계약을 기계 강제.
    # 종전엔 .round 만 검사해 4 필드가 전부 null 인 finding 이 유효 id 로 기록됐고,
    # predicted_delta 가 null 이면 다음 라운드 pending-verify 가 반증할 대상을 잃는다.
    # 빈 문자열도 누락과 동치로 본다 (resolve 의 F-H03 가드와 동형).
    for field in evidence root_cause fix predicted_delta; do
      if [ -z "$(echo "$IN" | jq -r --arg f "$field" '.[$f] // empty')" ]; then
        echo "error: .$field required (4-필드 계약: evidence/root_cause/fix/predicted_delta)" >&2
        exit 1
      fi
    done
    # F-O01 (audit round P): component/dimension 귀속도 강제. SKILL.md Phase2 는 finding
    # 을 7-component 중 하나 + dimension 에 귀속시키라 요구하나 F-K01 은 4-field 만 굳혔다.
    # enqueue(:하단)가 큐 task 를 "[audit \(.id)/\(.dimension)/\(.component)]" 로 만들므로
    # 미제공 시 "[audit F-X/null/null]" 이 자율 fix 큐에 그대로 적재된다.
    for field in component dimension; do
      if [ -z "$(echo "$IN" | jq -r --arg f "$field" '.[$f] // empty')" ]; then
        echo "error: .$field required (귀속: 7-component 중 하나 + dimension)" >&2
        exit 1
      fi
    done
    # F-H02(R8)+F-I04(R9): append 를 원자 락으로 직렬화 (병렬 append 동일 id race 차단).
    acquire_lock
    num=$(next_num "$round")
    id="F-${round}${num}"
    # id 충돌 방지(전역 단일): 이미 존재하면 거부
    if jq -e --arg i "$id" 'select(.id==$i)' "$LEDGER" >/dev/null 2>&1; then
      release_lock
      echo "error: id $id already exists" >&2; exit 1
    fi
    echo "$IN" | jq -c --arg id "$id" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{ts:$ts, round:.round, id:$id, component:.component, dimension:.dimension,
        evidence:.evidence, root_cause:.root_cause, fix:.fix,
        predicted_delta:.predicted_delta, actual_delta:null, status:"open", enqueued_task:null}' >> "$LEDGER"
    release_lock
    echo "$id"
    ;;
  resolve)
    id="${1:-}"; actual="${2:-}"; status="${3:-}"
    # F-H03 (audit R8): actual_delta 는 decision-observability 핵심 측정값 — 빈값 거부
    # (빈 문자열이 저장되면 pending-verify 의 ==null 필터를 통과해 미측정 fix 가 verified 로 샘)
    [ -z "$id" ] || [ -z "$actual" ] || [ -z "$status" ] && { echo "usage: resolve <id> <actual_delta> <status>" >&2; exit 1; }
    case "$status" in fixed|verified|refuted|deferred) ;; *) echo "error: status ∈ fixed|verified|refuted|deferred" >&2; exit 1 ;; esac
    acquire_lock
    jq -e --arg i "$id" 'select(.id==$i)' "$LEDGER" >/dev/null 2>&1 || { release_lock; echo "error: id $id not found" >&2; exit 1; }
    # F-K02 (audit R11): mark-fixed 는 F-H08 로 단방향 가드를 얻었으나 resolve 는 현재 상태를
    # 읽지 않아 같은 역전을 다른 진입점으로 수행할 수 있었다 (측정된 actual_delta 가 조용히 소실).
    cur=$(jq -r --arg i "$id" 'select(.id==$i) | .status' "$LEDGER")
    case "$cur" in
      verified|refuted) release_lock
        echo "error: $cur 는 종결 상태 — 재기록 불가 (현재: $cur)" >&2; exit 1 ;;
    esac
    # resolve 로 fixed 를 쓰면 actual_delta 가 채워진 채 fixed 가 되어 open(status=="open") 과
    # pending-verify(actual_delta=="") 양쪽 워크리스트에서 사라진다 → 다음 라운드 Phase 0 이
    # 빈 pending-verify 를 "전부 검증됨"으로 오독. fixed 전이는 mark-fixed 가 유일 경로.
    [ "$status" = "fixed" ] && { release_lock
      echo "error: fixed 전이는 mark-fixed 전용 (resolve 는 측정 결과만 기록)" >&2; exit 1; }
    tmp=$(mktemp)
    jq -c --arg i "$id" --arg a "$actual" --arg s "$status" \
      'if .id==$i then .actual_delta=$a | .status=$s else . end' "$LEDGER" > "$tmp" && mv "$tmp" "$LEDGER"
    release_lock
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
    acquire_lock
    count=0
    # F-K14 (audit R11): Windows jq.exe 는 매 라인에 \r\n 을 붙이고 $(...) 는 *마지막* 줄의
    # \r\n 만 뗀다 → 다중 라인 캡처는 마지막을 뺀 전 줄에 \r 이 남아 --arg 매칭이 빗나갔다.
    # 그 결과 첫 finding 의 enqueued_task 가 기록되지 않아 재실행마다 큐가 중복 적재됐다.
    ids=$(jq -r --arg r "$r" \
      'select(.status=="open") | select($r=="" or .round==$r) | select((.enqueued_task // "")=="") | .id' \
      "$LEDGER" 2>/dev/null | tr -d '\r')
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
    release_lock
    echo "enqueued $count finding(s)" >&2
    ;;
  mark-fixed)
    # fix PR 머지 시점 전이: open → fixed (actual_delta 는 null 유지 — 아직 미검증).
    # 다음 라운드가 pending-verify 로 집어 측정 후 resolve(verify/refute).
    id="${1:-}"; [ -z "$id" ] && { echo "usage: mark-fixed <id>" >&2; exit 1; }
    acquire_lock
    jq -e --arg i "$id" 'select(.id==$i)' "$LEDGER" >/dev/null 2>&1 || { release_lock; echo "error: id $id not found" >&2; exit 1; }
    # F-H08 (audit R8): 단방향 상태머신 가드 — open 에서만 fixed 전이 (verified/refuted→fixed 역전 차단)
    cur=$(jq -r --arg i "$id" 'select(.id==$i) | .status' "$LEDGER")
    [ "$cur" != "open" ] && { release_lock; echo "error: mark-fixed 는 open 에서만 (현재: $cur)" >&2; exit 1; }
    tmp=$(mktemp)
    jq -c --arg i "$id" 'if .id==$i then .status="fixed" else . end' "$LEDGER" > "$tmp" && mv "$tmp" "$LEDGER"
    release_lock
    echo "$id → fixed"
    ;;
  pending-verify)
    # decision-observability reconcile 워크리스트: fix 가 머지(status=fixed)됐으나
    # actual_delta 미기록인 finding. /audit Phase 0 가 측정 후 resolve 로 verify/refute.
    r="${1:-}"
    jq -r --arg r "$r" \
      'select(.status=="fixed") | select((.actual_delta // "")=="") | select($r=="" or .round==$r) | "\(.id)\t\(.dimension)\t\(.predicted_delta // "-")\t\(.fix)"' \
      "$LEDGER" 2>/dev/null
    ;;
  *)
    echo "usage: ledger.sh {append|resolve|open|round|next-num|enqueue|mark-fixed|pending-verify}" >&2
    exit 2
    ;;
esac
