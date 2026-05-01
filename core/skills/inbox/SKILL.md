---
name: inbox
description: 12 에이전트 inbox + broadcast + debates 통합 뷰 + 메시지 발송. /inbox, /inbox <agent>, /inbox --unread-only, /inbox --broadcast, /inbox send <to> <subject> <body>.
model: claude-sonnet-4-6
---

# /inbox

vibe-flow의 12 에이전트 메시지 큐를 한 화면에 보여준다. message-bus.sh CLI 호환 (read/archive/send는 그대로 위임).

## 트리거

- 사용자: `/inbox` (전체 통합 뷰), `/inbox <agent>` (단일 풀 리스트), `/inbox --unread-only` (Active만), `/inbox --broadcast` (broadcast/debates만)
- 발송: `/inbox send <to> <subject> <body> [--type info|alert|request|reply] [--priority low|medium|high|critical]` — 사용자가 에이전트에게 메시지 발송 (기본 type=info, priority=medium)

## 절차

### 1. 인자 파싱

```bash
ARG="${1:-all}"
case "$ARG" in
  send)
    MODE="send"
    shift
    SEND_TO="${1:-}"; shift || true
    SEND_SUBJECT="${1:-}"; shift || true
    SEND_BODY="${1:-}"; shift || true
    SEND_TYPE="info"
    SEND_PRIORITY="medium"
    while [ $# -gt 0 ]; do
      case "$1" in
        --type)
          shift
          case "$1" in
            info|alert|request|reply) SEND_TYPE="$1" ;;
            *) echo "warn: --type $1 무효, info로 대체 (허용: info|alert|request|reply)" >&2 ;;
          esac
          ;;
        --priority)
          shift
          case "$1" in
            low|medium|high|critical) SEND_PRIORITY="$1" ;;
            *) echo "warn: --priority $1 무효, medium으로 대체 (허용: low|medium|high|critical)" >&2 ;;
          esac
          ;;
      esac
      shift
    done
    ;;
  --unread-only) MODE="unread-only" ;;
  --broadcast) MODE="broadcast" ;;
  "" | "all") MODE="all" ;;
  *) MODE="agent"; AGENT="$ARG" ;;
esac
```

### 2. 에이전트 명단 로드

```bash
MSG_DIR=".claude/messages"
INBOX_DIR="$MSG_DIR/inbox"
BROADCAST_DIR="$MSG_DIR/broadcast"
DEBATES_DIR="$MSG_DIR/debates"

# 명단: agents.json 우선, 없으면 inbox 디렉토리에서 추론
AGENTS=""
if [ -f ".claude/agents.json" ]; then
  AGENTS=$(jq -r '.agents[]' .claude/agents.json)
elif [ -d "$INBOX_DIR" ]; then
  AGENTS=$(ls "$INBOX_DIR" 2>/dev/null)
fi
```

### 3. 상대 시간 변환 함수

```bash
relative_time() {
  local ts="$1"
  local now then diff
  now=$(date -u +%s)
  then=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null || echo $now)
  diff=$((now - then))
  if [ $diff -lt 3600 ]; then echo "$((diff / 60))분 전"
  elif [ $diff -lt 86400 ]; then echo "$((diff / 3600))시간 전"
  else echo "$((diff / 86400))일 전"
  fi
}
```

### 4. Per-agent aggregation

```bash
# count_unread <agent>: 미읽음 카운트
count_unread() {
  local agent="$1"
  local dir="$INBOX_DIR/$agent"
  [ -d "$dir" ] || { echo 0; return; }
  jq -s '[.[] | select(.status=="unread")] | length' "$dir"/*.json 2>/dev/null || echo 0
}

# count_total <agent>: 전체 카운트
count_total() {
  local agent="$1"
  local dir="$INBOX_DIR/$agent"
  [ -d "$dir" ] || { echo 0; return; }
  ls "$dir"/*.json 2>/dev/null | wc -l | tr -d ' '
}

# preview_unread <agent>: 최근 unread 3개 출력 (subject + from + ts)
preview_unread() {
  local agent="$1"
  local dir="$INBOX_DIR/$agent"
  [ -d "$dir" ] || return
  jq -s --raw-output '
    map(select(.status=="unread"))
    | sort_by(.ts)
    | reverse
    | .[0:3]
    | .[]
    | "  → \"\(.subject)\"\t\(.from)\t\(.ts)"
  ' "$dir"/*.json 2>/dev/null | while IFS=$'\t' read -r subj from ts; do
    rel=$(relative_time "$ts")
    printf "%-60s (%s %s, unread)\n" "$subj" "$from" "$rel"
  done
}
```

### 5. Active vs Quiet 분류 + 출력 (전체 뷰)

```bash
print_full_inbox() {
  echo "📬 vibe-flow Inbox (12 에이전트)"
  echo ""

  ACTIVE=()
  QUIET=()
  UNREAD_TOTAL=0

  for agent in $AGENTS; do
    unread=$(count_unread "$agent")
    total=$(count_total "$agent")
    UNREAD_TOTAL=$((UNREAD_TOTAL + unread))
    if [ "$unread" -gt 0 ]; then
      ACTIVE+=("$agent|$unread|$total")
    else
      QUIET+=("$agent")
    fi
  done

  echo "━━━ Active (${#ACTIVE[@]}) ━━━"
  echo ""
  for entry in "${ACTIVE[@]}"; do
    IFS='|' read -r agent unread total <<< "$entry"
    printf "@%-15s %d unread / %d total\n" "$agent" "$unread" "$total"
    preview_unread "$agent"
    echo ""
  done

  echo "━━━ Quiet (${#QUIET[@]}) ━━━"
  echo ""
  if [ ${#QUIET[@]} -gt 0 ]; then
    quiet_list=$(printf "@%s, " "${QUIET[@]}" | sed 's/, $//')
    echo "$quiet_list: 0 unread"
    echo ""
  fi

  print_broadcast_section
}

print_broadcast_section() {
  echo "━━━ Broadcast / Debates ━━━"
  echo ""
  bc_count=$(ls "$BROADCAST_DIR"/*.json 2>/dev/null | wc -l | tr -d ' ')
  echo "📢 broadcast/: $bc_count messages"

  dbg_count=$(ls "$DEBATES_DIR"/*.json 2>/dev/null | wc -l | tr -d ' ')
  echo "🗣  debates/: $dbg_count active"
  if [ "$dbg_count" -gt 0 ]; then
    for f in "$DEBATES_DIR"/*.json; do
      [ -f "$f" ] || continue
      did=$(jq -r '.debate_id // (input_filename | split("/")[-1] | split(".")[0])' "$f" 2>/dev/null)
      verdict=$(jq -r '.verdict_type // "in_progress"' "$f" 2>/dev/null)
      echo "    $did — $verdict"
    done
  fi
  echo ""
  echo "(레전드: unread = status:\"unread\" / total = 전체)"
}
```

### 6. Mode별 출력

```bash
case "$MODE" in
  all)
    print_full_inbox
    ;;
  unread-only)
    echo "📬 Unread Only"
    echo ""
    UNREAD_TOTAL=0
    for agent in $AGENTS; do
      unread=$(count_unread "$agent")
      UNREAD_TOTAL=$((UNREAD_TOTAL + unread))
      [ "$unread" -gt 0 ] || continue
      printf "@%-15s %d unread\n" "$agent" "$unread"
      preview_unread "$agent"
      echo ""
    done
    echo "(읽음 처리: bash .claude/hooks/message-bus.sh read <agent>)"
    ;;
  broadcast)
    print_broadcast_section
    ;;
  agent)
    # message-bus.sh list 래퍼
    if [ -f ".claude/hooks/message-bus.sh" ]; then
      bash .claude/hooks/message-bus.sh list "$AGENT"
    else
      echo "ERROR: .claude/hooks/message-bus.sh 없음 — setup.sh 필요" >&2
      exit 1
    fi
    UNREAD_TOTAL=$(count_unread "$AGENT")
    ;;
  send)
    # 검증
    if [ -z "$SEND_TO" ] || [ -z "$SEND_SUBJECT" ] || [ -z "$SEND_BODY" ]; then
      echo "Usage: /inbox send <to> <subject> <body> [--type info|alert|request|reply] [--priority low|medium|high|critical]" >&2
      exit 1
    fi
    # 수신자 에이전트가 명단에 있는지 확인 (없으면 경고만 — message-bus.sh가 폴더 자동 생성)
    if [ -n "$AGENTS" ] && ! echo "$AGENTS" | tr ' \n' '\n\n' | grep -qx "$SEND_TO"; then
      echo "warn: '$SEND_TO'은(는) 알려진 에이전트 명단에 없음 (계속 진행)" >&2
    fi
    if [ ! -f ".claude/hooks/message-bus.sh" ]; then
      echo "ERROR: .claude/hooks/message-bus.sh 없음 — setup.sh 필요" >&2
      exit 1
    fi
    # message-bus.sh send <from> <to> <type> <priority> <subject> <body>
    bash .claude/hooks/message-bus.sh send user "$SEND_TO" "$SEND_TYPE" "$SEND_PRIORITY" "$SEND_SUBJECT" "$SEND_BODY"
    SEND_RC=$?
    if [ $SEND_RC -eq 0 ]; then
      echo "✓ 메시지 발송 → @$SEND_TO ($SEND_TYPE/$SEND_PRIORITY)"
    fi
    UNREAD_TOTAL=0
    ;;
esac
```

### 7. Events 발생

```bash
NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
mkdir -p .claude
if [ "$MODE" = "send" ] && [ "${SEND_RC:-1}" -eq 0 ]; then
  jq -nc \
    --arg ts "$NOW_ISO" \
    --arg to "$SEND_TO" \
    --arg msg_type "$SEND_TYPE" \
    --arg priority "$SEND_PRIORITY" \
    '{type: "inbox_sent", ts: $ts, to: $to, msg_type: $msg_type, priority: $priority}' \
    >> .claude/events.jsonl
else
  jq -nc \
    --arg ts "$NOW_ISO" \
    --arg filter "$MODE" \
    --argjson unread "${UNREAD_TOTAL:-0}" \
    '{type: "inbox", ts: $ts, filter: $filter, unread_total: $unread}' \
    >> .claude/events.jsonl
fi
```

## 출처

Phase 2 ROADMAP 세 번째 항목. spec: `docs/superpowers/specs/2026-04-30-inbox-skill-design.md`.
