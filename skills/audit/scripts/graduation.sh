#!/bin/bash
set -u
# graduation.sh — auto-merge tier graduation 상태기계 + circuit breaker (T6/PR-5).
#
# T4/T5 는 메커니즘을 default-OFF 로 지었다. 본 스크립트가 tier 를 **점진 개방**한다:
#   off → docs → structural → generative. 각 tier 는 M(기본 3)밤 연속 클린 후 다음 개방.
#   merge-gate/self-update 가 `graduation.sh tier`(또는 상태파일)를 읽어 실제 자율머지/릴리즈 결정.
#
# **default-safe**: 상태는 **disarmed(armed=false)** 로 시작 → `tier`=off → 자율머지 안 켜짐.
#   운영자가 `graduation.sh arm` 을 **명시 실행**해야 클린-밤 집계가 시작된다.
#
# **circuit breaker**: `tick regressed`(health regression 또는 auto-revert 발생) → **trip**:
#   current_tier=off + tripped=true. 이후 tick 은 no-op. 운영자가 원인 조사 후 `reset` 해야 재개.
#   runbook: core/skills/audit/references/breaker-runbook.md
#
# 명령: arm | disarm | tick <clean|regressed> | trip [reason] | reset | tier | status
# 상태: .claude/graduation-state.json {armed,current_tier,clean_nights,tripped,tripped_reason}
# env: GRADUATION_STATE(경로 override) / GRADUATION_M(밤 수, 기본 3)

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
STATE="${GRADUATION_STATE:-$ROOT/.claude/graduation-state.json}"
M="${GRADUATION_M:-3}"
CMD="${1:-status}"

init_state() {
  [ -f "$STATE" ] && return
  mkdir -p "$(dirname "$STATE")"
  echo '{"armed":false,"current_tier":"off","clean_nights":0,"tripped":false,"tripped_reason":""}' > "$STATE"
}
get() { jq -r "$1" "$STATE" 2>/dev/null; }
set_state() { local tmp; tmp=$(mktemp); jq -c "$@" "$STATE" > "$tmp" && mv "$tmp" "$STATE"; }

next_tier() {
  case "$1" in
    off) echo docs ;; docs) echo structural ;; structural) echo generative ;;
    *) echo generative ;;   # generative = 최상위, cap
  esac
}

init_state

case "$CMD" in
  arm)     set_state '.armed=true';  echo "armed — 클린-밤 집계 시작 (M=$M/tier)" >&2 ;;
  disarm)  set_state '.armed=false'; echo "disarmed — tier=off (집계 중단)" >&2 ;;
  reset)   set_state '.tripped=false | .tripped_reason="" | .current_tier="off" | .clean_nights=0'
           echo "reset — breaker 해제, off 부터 재graduation (armed 유지)" >&2 ;;
  trip)    set_state --arg r "${2:-manual}" '.tripped=true | .tripped_reason=$r | .current_tier="off"'
           echo "TRIPPED — circuit breaker 발화, tier=off" >&2 ;;
  status)  cat "$STATE" ;;
  tier)
    # 실효 tier: disarmed 또는 tripped → off
    if [ "$(get '.armed')" != "true" ] || [ "$(get '.tripped')" = "true" ]; then echo "off"; else get '.current_tier'; fi
    ;;
  tick)
    health="${2:-}"
    [ "$(get '.armed')" != "true" ] && { echo "disarmed — tick no-op" >&2; exit 0; }
    [ "$(get '.tripped')" = "true" ] && { echo "tripped — tick no-op (reset 필요)" >&2; exit 0; }
    case "$health" in
      regressed)
        set_state '.tripped=true | .tripped_reason="health regression / auto-revert" | .current_tier="off"'
        echo "TRIPPED — health regressed, tier=off (reset 필요)" >&2 ;;
      clean)
        cn=$(( $(get '.clean_nights') + 1 ))
        if [ "$cn" -ge "$M" ]; then
          nt=$(next_tier "$(get '.current_tier')")
          set_state --arg t "$nt" '.current_tier=$t | .clean_nights=0'
          echo "graduated → $nt (클린 ${M}밤 충족)" >&2
        else
          set_state --argjson c "$cn" '.clean_nights=$c'
          echo "clean night $cn/$M ($(get '.current_tier') 유지)" >&2
        fi ;;
      *) echo "usage: tick <clean|regressed>" >&2; exit 1 ;;
    esac ;;
  *) echo "usage: graduation.sh arm|disarm|tick <clean|regressed>|trip|reset|tier|status" >&2; exit 1 ;;
esac
