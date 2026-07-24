#!/bin/bash
# jq CRLF 이식성 스모크 — Windows jq.exe 가 CRLF 를 출력할 때 쉘 제어흐름이 깨지지 않는가
#
# 배경 (audit R11, 뿌리 A):
#   Windows 의 jq.exe 는 모든 출력 라인에 \r\n 을 붙인다. `$(...)` 는 *마지막* 줄의
#   \r\n 만 통째로 떼므로, 다중 라인 캡처는 마지막을 제외한 전 줄에 \r 이 남는다.
#     $ jq -r '.id' two-lines.jsonl | od -c   →  A \r \n B \r \n
#     $ ids=$(jq -r '.id' two-lines.jsonl)    →  A \r \n B
#   그 결과 --arg 매칭·산술비교·루프 아이템이 조용히 빗나간다. 단일 값 캡처는 안전해서
#   기존 스모크가 green 을 유지했고, ubuntu CI(jq=LF)에서는 재현되지 않았다.
#
# 본 스모크는 플랫폼 무관하게 CRLF 를 *주입*해 회귀를 고정한다 — ubuntu 에서도 RED 가 된다.
# (실제 jq 의 CRLF 여부에 의존하지 않는다.)
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0; FAIL=0
ok() { echo "  ✓ $1"; PASS=$((PASS+1)); }
ng() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

# 검사 대상은 "다중 라인 캡처를 CR 제거 없이 소비하는" 지점뿐이다.
# 다음은 결함이 아님을 실측으로 확인했으므로 검사하지 않는다 (false positive 방지):
#   - 단일 값 캡처            — 마지막 줄의 \r\n 이 통째로 떨어져 깨끗하다
#   - `... | head -1` 파이프  — 한 줄로 줄어들어 위와 동일 (auto-build-safety 의 CUR_ITER)
#   - `... | grep -E` 파이프  — git-bash grep 이 텍스트 모드로 \r 을 흡수 (ledger next_num)

# ── 1. ledger.sh enqueue: 다중 라인 id 캡처 (`for id in $ids`) ──
echo "=== ledger.sh enqueue: 다중 finding 전건 enqueued_task 기록 ==="
LED="$TMP/led.jsonl"; : > "$LED"
mkf() { jq -nc --arg r "$1" '{round:$r,component:"skills",dimension:"D1",
  evidence:"e",root_cause:"r",fix:"f",predicted_delta:"p"}'; }
for i in 1 2 3; do mkf T | LEDGER="$LED" bash "$REPO_ROOT/core/skills/audit/scripts/ledger.sh" append >/dev/null; done

export QSTORE="$TMP/q.jsonl"; : > "$QSTORE"
cat > "$TMP/queue.sh" <<'STUB'
#!/bin/bash
[ "$1" = "add" ] || exit 1
echo "$2" >> "$QSTORE"
echo "queued: Q-$(wc -l < "$QSTORE" | tr -d ' ')"
STUB
chmod +x "$TMP/queue.sh"

QUEUE_SH="$TMP/queue.sh" LEDGER="$LED" bash "$REPO_ROOT/core/skills/audit/scripts/ledger.sh" enqueue >/dev/null 2>&1
missing=$(jq -r 'select((.enqueued_task // "")=="") | .id' "$LED" | tr -d '\r' | wc -l | tr -d ' ')
[ "$missing" -eq 0 ] && ok "3건 전부 enqueued_task 기록 (첫 줄 \\r 로 누락 없음)" \
                     || ng "${missing}건 enqueued_task 누락 — 다중 라인 캡처 결함"

# idempotency: 재실행해도 큐가 늘지 않아야 한다 (enqueued_task 가 제대로 기록됐다면)
before=$(wc -l < "$QSTORE" | tr -d ' ')
QUEUE_SH="$TMP/queue.sh" LEDGER="$LED" bash "$REPO_ROOT/core/skills/audit/scripts/ledger.sh" enqueue >/dev/null 2>&1
after=$(wc -l < "$QSTORE" | tr -d ' ')
[ "$before" = "$after" ] && ok "재실행 idempotent (큐 $before 유지)" || ng "중복 큐잉: $before → $after"

# ── 2. persona-vote: 다중 persona 전건 dispatch 라인 ──
echo "=== persona-vote: 전 persona AGENT_DISPATCH 라인 정상 ==="
out=$(bash "$REPO_ROOT/core/skills/auto-build/scripts/persona-vote.sh" design "a vs b" 2>/dev/null)
# CR 개수는 바이트로 센다. `grep $'\r'` 은 쓸 수 없다 — git-bash grep 은 패턴에서도 \r 을
# 텍스트 모드로 흡수해 빈 패턴이 되고, 그러면 모든 줄이 매칭돼 항상 실패한다(공허한 단언).
bad=$(printf '%s' "$out" | tr -cd '\r' | wc -c | tr -d ' ')
[ "$bad" -eq 0 ] && ok "출력에 CR 바이트 0" || ng "출력에 CR ${bad}바이트 잔존"
printf '%s' "$out" | grep -qE '^AGENT_DISPATCH:designer:' \
  && ok "첫 persona(designer) dispatch 라인 정상" || ng "designer dispatch 라인 깨짐"

# ── 3. setup.sh remove_extension: `파이프 | while read` 소비처 (F-N01) ──
# 위 두 케이스와 형태가 다르다. `$(...)` 캡처는 마지막 줄의 \r\n 이 통째로 떨어져
# 원소가 1개면 안전하지만, 파이프-while 은 *마지막 줄까지* CR 이 남아 원소 수와 무관하게
# 깨진다. 그래서 :24-28 의 제외 근거("단일 값 캡처는 안전")가 이 형태를 덮지 못했다.
# 플랫폼 무관 RED 를 위해 매 라인에 \r 을 붙이는 jq shim 을 PATH 앞에 둔다 (ubuntu 에서도 RED).
echo "=== setup.sh remove_extension: CRLF 하에서도 실파일 삭제 ==="
SHIM="$TMP/shim"; mkdir -p "$SHIM"
REAL_JQ="$(command -v jq)"
cat > "$SHIM/jq" <<SHIMEOF
#!/bin/bash
"$REAL_JQ" "\$@" | sed 's/\$/\r/'
exit "\${PIPESTATUS[0]}"
SHIMEOF
chmod +x "$SHIM/jq"

mkproj() {  # $1 = 프로젝트 경로, $2.. = manifest 에 올릴 상대 경로
  local p="$1"; shift
  mkdir -p "$p/.claude" "$p/skills/demo"
  jq -nc --args '{extensions:{demo:{files:$ARGS.positional}}}' "$@" > "$p/.claude/.vibe-flow.json"
}

# 3-1. manifest 의 파일이 실제로 지워지는가
PROJ="$TMP/proj"
mkproj "$PROJ" "skills/demo/SKILL.md" "skills/demo/extra.md"
: > "$PROJ/skills/demo/SKILL.md"; : > "$PROJ/skills/demo/extra.md"
(cd "$PROJ" && PATH="$SHIM:$PATH" bash "$REPO_ROOT/setup.sh" --remove-extension demo) >/dev/null 2>&1
left=$(ls "$PROJ/skills/demo/" 2>/dev/null | wc -l | tr -d ' ')
[ "$left" -eq 0 ] && ok "manifest 2건 전건 삭제 (CRLF 주입 하)" \
                  || ng "${left}건 잔존 — state 만 삭제되고 파일은 남는 orphan"

# 3-2. 목록에 있으나 없는 파일은 조용히 통과하지 않는다 (무증상 orphan 재발 방지)
PROJ2="$TMP/proj2"
mkproj "$PROJ2" "skills/demo/ghost.md"
warn=$( (cd "$PROJ2" && PATH="$SHIM:$PATH" bash "$REPO_ROOT/setup.sh" --remove-extension demo) 2>&1 >/dev/null )
printf '%s' "$warn" | grep -q '\[!\]' \
  && ok "미삭제 파일 stderr 경고 노출" || ng "미삭제가 무증상 통과 — 삭제 실패가 관측 불가"

echo ""
echo "=== 결과 ==="
echo "  통과: $PASS / 실패: $FAIL"
[ "$FAIL" -eq 0 ]
