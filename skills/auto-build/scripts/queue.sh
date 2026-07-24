#!/bin/bash
# /auto-build queue — task 큐 CRUD (Phase 3.0 PR-A)
# 사용:
#   queue.sh add "<task>"        — 신규 entry append (status: queued)
#   queue.sh list [--all]        — queued entry 표시 (--all로 done/aborted 포함)
#   queue.sh remove <id>         — status_update queued → aborted
#   queue.sh clear               — 모든 queued → aborted (일괄)
#
# 영속 store: .claude/memory/auto-build-queue.jsonl (append-only)
# entry payload: {id, task, created_ts, status, depends_on?}
# status_update payload: {op:"status_update", id, new_status, ts}

set -u

CMD="${1:-}"
shift || true

# ── store / lock 경로 (테스트 fixture가 override 가능) ──
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
QUEUE_STORE="${QUEUE_STORE:-${PROJECT_ROOT}/.claude/memory/auto-build-queue.jsonl}"
QUEUE_LOCK_DIR="${QUEUE_LOCK_DIR:-${PROJECT_ROOT}/.claude/.queue.lock}"

mkdir -p "$(dirname "$QUEUE_STORE")"
[ -f "$QUEUE_STORE" ] || touch "$QUEUE_STORE"

# ── lock helpers (macOS flock 미기본 — mkdir 원자성 활용 + stale 회수) ──
# stale 정책: SIGKILL/전원차단 후 lockdir 잔존 시 lockdir/pid의 프로세스가 죽었으면 회수.
# mkdir 자체는 원자적이므로 회수 race는 mkdir 재시도가 흡수한다.
acquire_lock() {
  local tries=50
  while ! mkdir "$QUEUE_LOCK_DIR" 2>/dev/null; do
    # stale 검사: lockdir/pid 읽고 kill -0
    local stale_pid=""
    [ -f "$QUEUE_LOCK_DIR/pid" ] && stale_pid=$(cat "$QUEUE_LOCK_DIR/pid" 2>/dev/null || echo "")
    if [ -n "$stale_pid" ] && ! kill -0 "$stale_pid" 2>/dev/null; then
      # owner 죽음 — 회수
      rm -rf "$QUEUE_LOCK_DIR" 2>/dev/null || true
      continue
    fi
    tries=$((tries - 1))
    [ "$tries" -le 0 ] && { echo "queue: lock acquisition timeout (held by pid $stale_pid)" >&2; exit 2; }
    sleep 0.05
  done
  echo $$ > "$QUEUE_LOCK_DIR/pid"
}

release_lock() {
  rm -rf "$QUEUE_LOCK_DIR" 2>/dev/null || true
}

trap 'release_lock' EXIT INT TERM

# ── id / ts helpers ──
gen_id() {
  local hex
  hex=$(openssl rand -hex 2 2>/dev/null || head -c 4 /dev/urandom | xxd -p | head -c 4)
  echo "$(date -u +%Y%m%dT%H%M%SZ)-${hex}"
}

iso_ts() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# ── NFC 정규화 (macOS NFD 회피, commit_pushed hook 패턴 일관) ──
nfc() {
  local input="$1"
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$input" | python3 -c "import sys, unicodedata; sys.stdout.write(unicodedata.normalize('NFC', sys.stdin.read()))"
  else
    printf '%s' "$input"
  fi
}

# ── 명령 분기 ──
case "$CMD" in

  add)
    TASK_RAW="${1:-}"
    [ -z "$TASK_RAW" ] && { echo "queue add: <task> 필수" >&2; exit 1; }
    TASK=$(nfc "$TASK_RAW")
    ID=$(gen_id)
    TS=$(iso_ts)
    DEPENDS_ON="${2:-}"

    LINE=$(jq -nc \
      --arg id "$ID" \
      --arg task "$TASK" \
      --arg created_ts "$TS" \
      --arg status "queued" \
      --arg depends_on "$DEPENDS_ON" \
      'if $depends_on == "" then
         {id:$id, task:$task, created_ts:$created_ts, status:$status}
       else
         {id:$id, task:$task, created_ts:$created_ts, status:$status, depends_on:$depends_on}
       end')

    acquire_lock
    echo "$LINE" >> "$QUEUE_STORE"
    release_lock

    echo "queued: $ID"
    ;;

  list)
    SHOW_ALL=0
    [ "${1:-}" = "--all" ] && SHOW_ALL=1

    # entry 라인별 최신 status fold (status_update 라인 반영)
    jq -rs --argjson all "$SHOW_ALL" '
      reduce .[] as $l ({};
        if ($l | has("op")) and $l.op == "status_update" then
          if .[$l.id] then .[$l.id].status = $l.new_status else . end
        elif ($l | has("id")) and ($l | has("task")) then
          .[$l.id] = $l
        else . end
      )
      | to_entries
      | map(.value)
      | sort_by(.created_ts)
      | if $all == 1 then . else map(select(.status == "queued")) end
      | .[]
      | "\(.id)\t\(.status)\t\(.created_ts)\t\(.task)"
    ' "$QUEUE_STORE" 2>/dev/null
    ;;

  remove)
    TARGET_ID="${1:-}"
    [ -z "$TARGET_ID" ] && { echo "queue remove: <id> 필수" >&2; exit 1; }

    LINE=$(jq -nc \
      --arg id "$TARGET_ID" \
      --arg ts "$(iso_ts)" \
      '{op:"status_update", id:$id, new_status:"aborted", ts:$ts}')

    acquire_lock
    echo "$LINE" >> "$QUEUE_STORE"
    release_lock

    echo "aborted: $TARGET_ID"
    ;;

  next)
    # status=queued 첫 entry id 출력 + status_update running 라인 append
    acquire_lock
    ID=$(jq -rs '
      reduce .[] as $l ({};
        if ($l | has("op")) and $l.op == "status_update" then
          if .[$l.id] then .[$l.id].status = $l.new_status else . end
        elif ($l | has("id")) and ($l | has("task")) then
          .[$l.id] = $l
        else . end
      )
      | to_entries
      | map(.value)
      | sort_by(.created_ts)
      | map(select(.status == "queued"))
      | if length > 0 then .[0].id else "" end
    ' "$QUEUE_STORE" 2>/dev/null)

    if [ -n "$ID" ]; then
      jq -nc --arg id "$ID" --arg ts "$(iso_ts)" \
        '{op:"status_update", id:$id, new_status:"running", ts:$ts}' >> "$QUEUE_STORE"
      echo "$ID"
    fi
    release_lock
    ;;

  status-update)
    TARGET_ID="${1:-}"
    NEW_STATUS="${2:-}"
    if [ -z "$TARGET_ID" ] || [ -z "$NEW_STATUS" ]; then
      echo "queue status-update: <id> <new_status> 필수" >&2
      exit 1
    fi

    LINE=$(jq -nc \
      --arg id "$TARGET_ID" \
      --arg new_status "$NEW_STATUS" \
      --arg ts "$(iso_ts)" \
      '{op:"status_update", id:$id, new_status:$new_status, ts:$ts}')

    acquire_lock
    echo "$LINE" >> "$QUEUE_STORE"
    release_lock

    echo "$NEW_STATUS: $TARGET_ID"
    ;;

  clear)
    # 모든 status=queued entry에 대해 status_update aborted 일괄 append
    QUEUED_IDS=$(jq -rs '
      reduce .[] as $l ({};
        if ($l | has("op")) and $l.op == "status_update" then
          if .[$l.id] then .[$l.id].status = $l.new_status else . end
        elif ($l | has("id")) and ($l | has("task")) then
          .[$l.id] = $l
        else . end
      )
      | to_entries
      | map(select(.value.status == "queued") | .key)
      | .[]
    ' "$QUEUE_STORE" 2>/dev/null | tr -d '\r')
    # tr -d '\r': Windows jq.exe CRLF. 다중 라인이라 아래 `while read <<< "$QUEUED_IDS"` 의
    # 마지막을 뺀 전 id 에 \r 이 남아 status_update 가 매칭되지 않았다 (clear 후에도 queued 잔존).

    [ -z "$QUEUED_IDS" ] && { echo "queue clear: queued entry 없음"; exit 0; }

    TS=$(iso_ts)
    acquire_lock
    while IFS= read -r ID; do
      jq -nc --arg id "$ID" --arg ts "$TS" \
        '{op:"status_update", id:$id, new_status:"aborted", ts:$ts}' >> "$QUEUE_STORE"
    done <<< "$QUEUED_IDS"
    release_lock

    COUNT=$(echo "$QUEUED_IDS" | wc -l | tr -d ' ')
    echo "cleared: $COUNT queued → aborted"
    ;;

  ""|help|-h|--help)
    cat <<'USAGE'
queue.sh — /auto-build task 큐 CRUD

사용:
  queue.sh add "<task>" [depends_on_id]
  queue.sh list [--all]
  queue.sh remove <id>
  queue.sh clear
  queue.sh next                       # status=queued 첫 entry pop + running 마킹
  queue.sh status-update <id> <status># 단일 status_update 라인 append (run-queue 전용)

영속 store: $QUEUE_STORE (기본 .claude/memory/auto-build-queue.jsonl)
USAGE
    if [ "$CMD" = "" ]; then
      exit 1
    else
      exit 0
    fi
    ;;

  *)
    echo "queue.sh: unknown command '$CMD'" >&2
    echo "use: add | list | remove | clear | next | status-update" >&2
    exit 1
    ;;
esac
