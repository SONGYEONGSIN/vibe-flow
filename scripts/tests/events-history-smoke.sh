#!/bin/bash
# session-memory-sync.sh 의 events-history 영속화 스모크 (audit F-BU01)
#
# .claude/events.jsonl 은 gitignore 돼(.gitignore:34) ephemeral cloud checkout 마다
# 비워진다 — telemetry/retrospective 가 전제하는 "장기 누적 추세" 가 cloud 세션에선
# 근 0 에서 재출발한다(실측: 2026-10-17 cloud 세션 자신의 events.jsonl 이 2줄뿐).
# session-memory-sync.sh(Stop hook)가 매 호출마다 신규 줄만 git-tracked
# .claude/memory/events-history.jsonl 로 append 해 세션 경계를 넘겨 누적시키는지 검증.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/core/hooks/session-memory-sync.sh"

PASS=0; FAIL=0
ok() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
ng() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FIXTURE="$TMP/repo"
mkdir -p "$FIXTURE/.claude"
git -C "$FIXTURE" init -q
git -C "$FIXTURE" config user.email "t@t"; git -C "$FIXTURE" config user.name "t"

run_hook() {
  # VIBE_FLOW_AUTO_MEMORY_SYNC=0 는 쓰지 않는다 — 그 opt-out 이 PROJECT_ROOT 계산보다도
  # 먼저(:21-23) exit 해, 검증 대상인 history-append 블록 자체가 실행되지 않는다.
  # sync-memory.sh 가 fixture 에 없어 그 아래 단계(push)는 어차피 :54 에서 exit 0.
  ( cd "$FIXTURE" && bash "$SCRIPT" </dev/null >/dev/null 2>&1 )
}

echo "=== Test E1: 단일 세션 — 신규 줄 전부 append ==="
printf '{"ts":"t1","type":"a"}\n{"ts":"t2","type":"b"}\n' > "$FIXTURE/.claude/events.jsonl"
run_hook
HIST="$FIXTURE/.claude/memory/events-history.jsonl"
if [ -f "$HIST" ] && [ "$(wc -l < "$HIST" | tr -d ' ')" = "2" ]; then
  ok "E1.1 history 2줄 기록"
else
  ng "E1.1 history 파일/줄수 불일치 ($([ -f "$HIST" ] && wc -l < "$HIST" || echo 'missing'))"
fi

echo "=== Test E2: 같은 세션 내 재호출 — 중복 append 없음(신규분만) ==="
printf '{"ts":"t3","type":"c"}\n' >> "$FIXTURE/.claude/events.jsonl"
run_hook
if [ "$(wc -l < "$HIST" | tr -d ' ')" = "3" ]; then
  ok "E2.1 재호출 후 3줄(중복 없음)"
else
  ng "E2.1 줄수 불일치 (got $(wc -l < "$HIST" | tr -d ' '), want 3 — 중복 또는 유실 의심)"
fi
run_hook
if [ "$(wc -l < "$HIST" | tr -d ' ')" = "3" ]; then
  ok "E2.2 변화 없는 재호출은 멱등(여전히 3줄)"
else
  ng "E2.2 멱등성 깨짐 (got $(wc -l < "$HIST" | tr -d ' '))"
fi

echo "=== Test E3: 새 세션(events.jsonl 리셋) — 기존 history 보존 + 신규만 추가 ==="
rm -f "$FIXTURE/.claude/.events-history-synced-lines"
printf '{"ts":"t4","type":"d"}\n' > "$FIXTURE/.claude/events.jsonl"
run_hook
if grep -q '"t1"' "$HIST" && grep -q '"t4"' "$HIST" && [ "$(wc -l < "$HIST" | tr -d ' ')" = "4" ]; then
  ok "E3.1 새 세션 리셋 후에도 이전 history 보존 + 신규 1줄 추가(4줄)"
else
  ng "E3.1 history 유실 또는 오버카운트 (got $(wc -l < "$HIST" | tr -d ' ') lines)"
fi

echo "=== Test E4: events.jsonl 부재 시 no-op(에러 없이 종료) ==="
rm -f "$FIXTURE/.claude/events.jsonl" "$FIXTURE/.claude/.events-history-synced-lines"
PRE=$(wc -l < "$HIST" | tr -d ' ')
run_hook
POST=$(wc -l < "$HIST" | tr -d ' ')
if [ "$PRE" = "$POST" ]; then
  ok "E4.1 events.jsonl 부재 시 history 불변"
else
  ng "E4.1 history 가 부재 상태에서도 변함 (pre=$PRE post=$POST)"
fi

echo ""
echo "=== 결과 ==="
echo "  통과: $PASS / 실패: $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ ALL TESTS PASSED"; exit 0; } || { echo "✗ SOME TESTS FAILED"; exit 1; }
