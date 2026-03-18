#!/bin/bash
# message-bus.sh — 에이전트 간 메시지 버스
#
# 사용법:
#   message-bus.sh send <from> <to> <type> <priority> <subject> <body> [context_json]
#   message-bus.sh list <agent-name>
#   message-bus.sh read <agent-name>
#   message-bus.sh archive <msg-file>
#   message-bus.sh broadcast <from> <subject> <body>
#   message-bus.sh count <agent-name>
#   message-bus.sh cleanup
#
# 메시지 타입: alert, request, reply, debate-invite, debate-round, debate-verdict, info
# 우선순위: critical, high, medium, low

set -e

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$PROJECT_ROOT" ]; then
  echo "ERROR: git 프로젝트가 아닙니다" >&2
  exit 1
fi

MSG_DIR="${PROJECT_ROOT}/.claude/messages"
INBOX_DIR="${MSG_DIR}/inbox"
ARCHIVE_DIR="${MSG_DIR}/archive"
BROADCAST_DIR="${MSG_DIR}/broadcast"
DEBATES_DIR="${MSG_DIR}/debates"

AGENTS="developer qa security feedback planner designer retrospective grader comparator skill-reviewer moderator"

ACTION="$1"
shift || true

ensure_dirs() {
  for agent in $AGENTS; do
    mkdir -p "${INBOX_DIR}/${agent}"
  done
  mkdir -p "${ARCHIVE_DIR}" "${BROADCAST_DIR}" "${DEBATES_DIR}"
}

generate_id() {
  local ts
  ts=$(date '+%Y%m%d-%H%M%S')
  local rand
  rand=$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 4)
  echo "msg-${ts}-${rand}"
}

case "$ACTION" in
  send)
    if [ $# -lt 6 ]; then
      echo "ERROR: send 명령은 최소 6개 인자 필요 (from, to, type, priority, subject, body)" >&2
      exit 1
    fi
    ensure_dirs
    FROM="$1"; TO="$2"; TYPE="$3"; PRIORITY="$4"; SUBJECT="$5"; BODY="$6"
    CONTEXT="${7:-null}"
    MSG_ID=$(generate_id)
    TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S%z')

    if [ "$CONTEXT" != "null" ]; then
      echo "$CONTEXT" | jq . >/dev/null 2>&1 || CONTEXT="null"
    fi

    if [ ! -d "${INBOX_DIR}/${TO}" ]; then
      mkdir -p "${INBOX_DIR}/${TO}"
    fi

    jq -n \
      --arg id "$MSG_ID" \
      --arg ts "$TIMESTAMP" \
      --arg from "$FROM" \
      --arg to "$TO" \
      --arg type "$TYPE" \
      --arg pri "$PRIORITY" \
      --arg subj "$SUBJECT" \
      --arg body "$BODY" \
      --argjson ctx "$CONTEXT" \
      '{
        id: $id,
        timestamp: $ts,
        from: $from,
        to: $to,
        type: $type,
        priority: $pri,
        subject: $subj,
        body: $body,
        context: $ctx,
        debate_id: null,
        reply_to: null,
        status: "unread"
      }' > "${INBOX_DIR}/${TO}/${MSG_ID}.json"

    echo "$MSG_ID"
    ;;

  list)
    AGENT="$1"
    if [ -d "${INBOX_DIR}/${AGENT}" ]; then
      for f in "${INBOX_DIR}/${AGENT}/"*.json; do
        [ -f "$f" ] || continue
        jq -r '[.priority, .from, .type, .subject] | join(" | ")' "$f" 2>/dev/null
      done
    fi
    ;;

  read)
    AGENT="$1"
    if [ -d "${INBOX_DIR}/${AGENT}" ]; then
      for f in "${INBOX_DIR}/${AGENT}/"*.json; do
        [ -f "$f" ] || continue
        jq '.status = "read"' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
        cat "$f"
        echo ""
      done
    fi
    ;;

  archive)
    MSG_FILE="$1"
    if [ -f "$MSG_FILE" ]; then
      TODAY=$(date '+%Y-%m-%d')
      mkdir -p "${ARCHIVE_DIR}/${TODAY}"
      jq '.status = "archived"' "$MSG_FILE" > "${ARCHIVE_DIR}/${TODAY}/$(basename "$MSG_FILE")"
      rm "$MSG_FILE"
    fi
    ;;

  broadcast)
    ensure_dirs
    FROM="$1"; SUBJECT="$2"; BODY="$3"
    MSG_ID=$(generate_id)
    TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S%z')

    jq -n \
      --arg id "$MSG_ID" \
      --arg ts "$TIMESTAMP" \
      --arg from "$FROM" \
      --arg subj "$SUBJECT" \
      --arg body "$BODY" \
      '{
        id: $id,
        timestamp: $ts,
        from: $from,
        to: "all",
        type: "info",
        priority: "low",
        subject: $subj,
        body: $body,
        context: null,
        debate_id: null,
        reply_to: null,
        status: "unread"
      }' > "${BROADCAST_DIR}/${MSG_ID}.json"

    echo "$MSG_ID"
    ;;

  count)
    AGENT="$1"
    if [ -d "${INBOX_DIR}/${AGENT}" ]; then
      ls -1 "${INBOX_DIR}/${AGENT}/"*.json 2>/dev/null | wc -l | tr -d ' '
    else
      echo "0"
    fi
    ;;

  cleanup)
    # 7일 이상 아카이브 메시지 삭제
    find "${ARCHIVE_DIR}" -name "*.json" -mtime +7 -delete 2>/dev/null || true
    find "${BROADCAST_DIR}" -name "*.json" -mtime +7 -delete 2>/dev/null || true
    echo "cleanup done"
    ;;

  *)
    echo "Usage: message-bus.sh {send|list|read|archive|broadcast|count|cleanup}" >&2
    exit 1
    ;;
esac
