#!/bin/bash
set -u
# health-metric.sh — harness health 3-지표 산출 (circuit breaker 입력).
#
# 출력: JSON 1줄 {ci_pass_rate, ledger_health, safetycore_checksum}
#   지표는 라운드 간 비교용 — T6 circuit breaker 가 baseline 대비 regression 시 auto-merge freeze.
#   본 스크립트는 산출만 담당(판정 X, Simplicity First).
#
# 지표:
#   ci_pass_rate       최근 20 GitHub Actions 런의 success 비율 (0~1, gh 부재 시 null)
#   ledger_health      verified/(verified+refuted+open) — fix 유효성 + 미해결 부채 (0~1)
#   safetycore_checksum denylist 등재 파일 결합 sha256 (무단 변경 탐지)

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

sha256() {  # 이식성: sha256sum(리눅스) 또는 shasum(macOS)
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
  else echo ""; fi
}

# 1. CI pass rate
ci_pass_rate="null"
if command -v gh >/dev/null 2>&1; then
  concl=$(gh run list --limit 20 --json conclusion -q '.[].conclusion' 2>/dev/null || true)
  if [ -n "$concl" ]; then
    total=$(printf '%s\n' "$concl" | grep -c .)
    ok=$(printf '%s\n' "$concl" | grep -c '^success$')
    [ "$total" -gt 0 ] && ci_pass_rate=$(awk "BEGIN{printf \"%.3f\", $ok/$total}")
  fi
fi

# 2. ledger health
LEDGER="$ROOT/.claude/memory/audit-ledger.jsonl"
ledger_health="null"
if [ -f "$LEDGER" ] && command -v jq >/dev/null 2>&1; then
  v=$(jq -r 'select(.status=="verified")|.id' "$LEDGER" 2>/dev/null | grep -c .)
  r=$(jq -r 'select(.status=="refuted")|.id' "$LEDGER" 2>/dev/null | grep -c .)
  o=$(jq -r 'select(.status=="open")|.id' "$LEDGER" 2>/dev/null | grep -c .)
  denom=$((v + r + o))
  [ "$denom" -gt 0 ] && ledger_health=$(awk "BEGIN{printf \"%.3f\", $v/$denom}")
fi

# 3. safety-core checksum (denylist 등재 존재 파일 결합)
DENYLIST="$ROOT/.claude/evolution-protected"
checksum="null"
if [ -f "$DENYLIST" ]; then
  existing=""
  while IFS= read -r f; do
    case "$f" in ''|\#*) continue ;; esac
    [ -f "$ROOT/$f" ] && existing="$existing $ROOT/$f"
  done < "$DENYLIST"
  if [ -n "$existing" ]; then
    cs=$(cat $existing 2>/dev/null | sha256)
    [ -n "$cs" ] && checksum="$cs"
  fi
fi

printf '{"ci_pass_rate":%s,"ledger_health":%s,"safetycore_checksum":"%s"}\n' \
  "$ci_pass_rate" "$ledger_health" "$checksum"
