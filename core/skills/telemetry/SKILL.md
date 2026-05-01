---
name: telemetry
description: 본인 1 머신 events.jsonl 분석 — Top 5 / Active / Stale / 개선 후보 / 추세. 기본 30일, --period 7|30|90 옵션으로 기간 조정. 4 모드 (all/skills/trends/--json).
model: claude-sonnet-4-6
---

# /telemetry

vibe-flow의 본인 1 머신 events.jsonl을 분석해 메이커 의사결정 데이터를 출력한다. 기본 분석 기간 30일, `--period 7|30|90`으로 조정 가능.

## 트리거

- `/telemetry` — 종합 보고서 (30일)
- `/telemetry skills` — Top 5 + Active + Stale만
- `/telemetry trends` — 추이만
- `/telemetry --json` — JSON 출력
- `/telemetry --period 7|30|90` — 분석 기간 조정 (다른 모드와 조합 가능: `/telemetry skills --period 7`)

## 절차

### 1. 모드 + 기간 파싱

```bash
# 기본값
MODE="all"
PERIOD_DAYS=30

# 인자 순회 — --period 와 mode 동시 허용
while [ $# -gt 0 ]; do
  case "$1" in
    --period)
      shift
      case "$1" in
        7|30|90) PERIOD_DAYS="$1" ;;
        *) echo "warn: --period $1 무효, 30일로 대체 (허용: 7|30|90)" >&2 ;;
      esac
      ;;
    skills) MODE="skills" ;;
    trends) MODE="trends" ;;
    --json) MODE="json" ;;
    ""|all) ;;
    *) ;;
  esac
  shift
done
```

### 2. 시간 기준

```bash
EVENTS=".claude/events.jsonl"
[ -f "$EVENTS" ] || { echo "events.jsonl 없음 — 먼저 vibe-flow 사용 후 다시 실행" >&2; exit 0; }

DAY_PERIOD_AGO=$(date -u -v-${PERIOD_DAYS}d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
        || date -u -d "${PERIOD_DAYS} days ago" +%Y-%m-%dT%H:%M:%SZ)
DAY_7_AGO=$(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
        || date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)
# Active/recent 서브 윈도우는 항상 7일 (period가 7이면 전체 기간과 일치)
```

### 3. 스킬 명단 + 별칭

```bash
# 27 스킬 (Core 18 + Extensions 9)
# events.jsonl type → /label 매핑
SKILL_TYPES=(
  brainstorm plan finish release
  scaffold test worktree
  verify security commit_created
  review_pr review_received
  status learn_save onboard menu inbox budget
  eval skill_evolve design_sync design_audit
  pair_session discuss
  metrics retrospective
  feedback
)

type_to_label() {
  case "$1" in
    commit_created) echo "/commit" ;;
    learn_save) echo "/learn" ;;
    skill_evolve) echo "/evolve" ;;
    pair_session) echo "/pair" ;;
    review_pr) echo "/review-pr" ;;
    review_received) echo "/receive-review" ;;
    design_sync) echo "/design-sync" ;;
    design_audit) echo "/design-audit" ;;
    *) echo "/$1" ;;
  esac
}

# Extension 식별
is_extension_type() {
  case "$1" in
    eval|skill_evolve|design_sync|design_audit|pair_session|discuss|metrics|retrospective|feedback) return 0 ;;
    *) return 1 ;;
  esac
}

extension_name() {
  case "$1" in
    eval|skill_evolve) echo "meta-quality" ;;
    design_sync|design_audit) echo "design-system" ;;
    pair_session|discuss) echo "deep-collaboration" ;;
    metrics|retrospective) echo "learning-loop" ;;
    feedback) echo "code-feedback" ;;
  esac
}
```

### 4. jq 1패스 group_by

```bash
# 분석 기간 카운트 (group)
COUNTS_PERIOD=$(jq -s --arg d "$DAY_PERIOD_AGO" \
  'map(select(.ts > $d)) | group_by(.type) | map({type: .[0].type, count: length}) | from_entries' \
  "$EVENTS" 2>/dev/null || echo '{}')

# 7일 카운트 (서브 윈도우 — Active/추세용)
COUNTS_7D=$(jq -s --arg d "$DAY_7_AGO" \
  'map(select(.ts > $d)) | group_by(.type) | map({type: .[0].type, count: length}) | from_entries' \
  "$EVENTS" 2>/dev/null || echo '{}')

# last_used per type
LAST_USED=$(jq -s 'group_by(.type) | map({type: .[0].type, last: (max_by(.ts) | .ts)}) | from_entries' \
  "$EVENTS" 2>/dev/null || echo '{}')

# 분석 기간 일별 totals (sparkline용)
DAILY_TOTALS=$(jq -s --arg d "$DAY_PERIOD_AGO" \
  'map(select(.ts > $d)) | group_by(.ts | .[0:10]) | map({date: .[0].ts[0:10], count: length})' \
  "$EVENTS" 2>/dev/null || echo '[]')

# 활성 extension
ACTIVE_EXTS="[]"
[ -f ".claude/.vibe-flow.json" ] && \
  ACTIVE_EXTS=$(jq -c '.extensions | keys' .claude/.vibe-flow.json 2>/dev/null || echo '[]')

# 분석 기간 총 events
TOTAL_PERIOD=$(echo "$COUNTS_PERIOD" | jq -r 'to_entries | map(.value) | add // 0')
```

### 5. 헬퍼 함수

```bash
# 분석 기간 카운트 조회
count_period() {
  echo "$COUNTS_PERIOD" | jq -r --arg t "$1" '.[$t] // 0'
}

count_7d() {
  echo "$COUNTS_7D" | jq -r --arg t "$1" '.[$t] // 0'
}

last_used_iso() {
  echo "$LAST_USED" | jq -r --arg t "$1" '.[$t] // ""'
}

# ISO ts → "N일 전"
days_ago() {
  local ts="$1"
  [ -z "$ts" ] && { echo "never"; return; }
  local now then diff
  now=$(date -u +%s)
  then=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null || echo $now)
  diff=$((now - then))
  if [ $diff -lt 86400 ]; then echo "오늘"
  else echo "$((diff / 86400))일 전"
  fi
}

# Sparkline
sparkline() {
  local counts="$1"
  local max=$(echo $counts | tr ' ' '\n' | sort -n | tail -1)
  if [ -z "$max" ] || [ "$max" = "0" ]; then
    local len=$(echo $counts | wc -w | tr -d ' ')
    printf '░%.0s' $(seq 1 $len 2>/dev/null) 2>/dev/null
    return
  fi
  local chars=("░" "▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")
  for n in $counts; do
    local idx=$((n * 8 / max))
    [ "$idx" -gt 8 ] && idx=8
    printf "%s" "${chars[$idx]}"
  done
}

# 추세 라벨 (전체 기간 평균 vs 마지막 7일 평균)
trend_label_for_type() {
  local type="$1"
  local last7
  last7=$(count_7d "$type")
  # 분석 기간 대비 7일 비율
  local d_period
  d_period=$(count_period "$type")
  [ "$d_period" = "0" ] && { echo "→ 평탄"; return; }
  # 일평균 비교
  local avg_period=$((d_period / PERIOD_DAYS))
  local avg7=$((last7 / 7))
  if [ "$avg7" -gt $((avg_period * 110 / 100)) ]; then echo "↗ 증가"
  elif [ "$avg7" -lt $((avg_period * 90 / 100)) ]; then echo "↘ 감소"
  else echo "→ 평탄"
  fi
}
```

### 6. Top 5 + Active + Stale 분류

```bash
# Top 5: 분석 기간 카운트 상위 5
TOP_5=$(echo "$COUNTS_PERIOD" | jq -r 'to_entries | sort_by(-.value) | .[0:5] | .[] | "\(.key)\t\(.value)"')

# Active: 7일 내 1회+
ACTIVE=()
for type in "${SKILL_TYPES[@]}"; do
  c=$(count_7d "$type")
  [ "$c" -gt 0 ] && ACTIVE+=("$(type_to_label "$type")")
done

# Stale: 분석 기간 0회
STALE=()
for type in "${SKILL_TYPES[@]}"; do
  c=$(count_period "$type")
  [ "$c" = "0" ] && STALE+=("$type")
done

# 개선 후보 매핑
IMPROVEMENTS=()
for type in "${STALE[@]}"; do
  last=$(last_used_iso "$type")
  ago=$(days_ago "$last")
  label=$(type_to_label "$type")
  if is_extension_type "$type"; then
    ext=$(extension_name "$type")
    if ! echo "$ACTIVE_EXTS" | jq -e --arg e "$ext" 'index($e)' >/dev/null 2>&1; then
      IMPROVEMENTS+=("$label never — extension $ext 미설치 가능")
      continue
    fi
  fi
  if [ "$ago" = "never" ]; then
    IMPROVEMENTS+=("$label 미사용 — 사용 시나리오 발견 또는 deprecate 검토")
  else
    IMPROVEMENTS+=("$label $ago — workflow 변화 가능성")
  fi
done
```

### 7. 출력 함수

```bash
print_top5() {
  echo "━━━ Top 5 ━━━"
  if [ -z "$TOP_5" ]; then
    echo "  (데이터 없음)"
  else
    local rank=1
    while IFS=$'\t' read -r type count; do
      [ -z "$type" ] && continue
      local label trend
      label=$(type_to_label "$type")
      trend=$(trend_label_for_type "$type")
      printf "  %d. %-15s %4d회  %s\n" "$rank" "$label" "$count" "$trend"
      rank=$((rank + 1))
    done <<< "$TOP_5"
  fi
  echo ""
}

print_active() {
  echo "━━━ Active (7일 내 사용) ━━━"
  if [ ${#ACTIVE[@]} -eq 0 ]; then
    echo "  (없음)"
  else
    echo "  ${ACTIVE[*]}" | sed 's/ /, /g'
  fi
  echo ""
}

print_stale() {
  echo "━━━ Stale (${PERIOD_DAYS}일 내 0회) ━━━"
  if [ ${#STALE[@]} -eq 0 ]; then
    echo "  (없음 — 모든 스킬 활용)"
  else
    for type in "${STALE[@]}"; do
      local label last ago
      label=$(type_to_label "$type")
      last=$(last_used_iso "$type")
      ago=$(days_ago "$last")
      printf "  %-20s (last: %s)\n" "$label" "$ago"
    done
  fi
  echo ""
}

print_improvements() {
  echo "━━━ 개선 후보 ━━━"
  if [ ${#IMPROVEMENTS[@]} -eq 0 ]; then
    echo "  (없음)"
  else
    for imp in "${IMPROVEMENTS[@]}"; do
      echo "  • $imp"
    done
  fi
  echo ""
}

print_trends() {
  echo "━━━ ${PERIOD_DAYS}일 추이 ━━━"
  local daily_counts
  daily_counts=$(echo "$DAILY_TOTALS" | jq -r 'map(.count) | join(" ")')
  local total_spark
  total_spark=$(sparkline "$daily_counts")
  echo "  total events: $total_spark"

  local avg_period avg_7
  avg_period=$((TOTAL_PERIOD / PERIOD_DAYS))
  local last_7d_total
  last_7d_total=$(echo "$COUNTS_7D" | jq -r 'to_entries | map(.value) | add // 0')
  avg_7=$((last_7d_total / 7))
  echo "  daily avg: $avg_period → $avg_7 (지난 7일)"
  echo ""
}
```

### 8. JSON 출력

```bash
print_json() {
  local top5_json="[]"
  local stale_json="[]"
  local imp_json="[]"
  local active_json="[]"

  # top_5
  if [ -n "$TOP_5" ]; then
    local items=""
    while IFS=$'\t' read -r type count; do
      [ -z "$type" ] && continue
      local label trend
      label=$(type_to_label "$type")
      trend=$(trend_label_for_type "$type")
      items+="$(jq -nc --arg s "$label" --argjson c "$count" --arg t "$trend" \
        '{skill: $s, count_30d: $c, trend: $t}'),"
    done <<< "$TOP_5"
    top5_json="[${items%,}]"
  fi

  # active_7d
  if [ ${#ACTIVE[@]} -gt 0 ]; then
    active_json=$(printf '%s\n' "${ACTIVE[@]}" | jq -R . | jq -s .)
  fi

  # stale_30d
  if [ ${#STALE[@]} -gt 0 ]; then
    local items=""
    for type in "${STALE[@]}"; do
      local label last
      label=$(type_to_label "$type")
      last=$(last_used_iso "$type")
      [ -z "$last" ] && last="null" || last="\"$last\""
      items+="$(jq -nc --arg s "$label" --argjson l "$last" '{skill: $s, last_used: $l}'),"
    done
    stale_json="[${items%,}]"
  fi

  # improvements
  if [ ${#IMPROVEMENTS[@]} -gt 0 ]; then
    imp_json=$(printf '%s\n' "${IMPROVEMENTS[@]}" | jq -R . | jq -s .)
  fi

  local daily_counts daily_spark avg_period last_7d_total avg_7
  daily_counts=$(echo "$DAILY_TOTALS" | jq -r 'map(.count) | join(" ")')
  daily_spark=$(sparkline "$daily_counts")
  avg_period=$((TOTAL_PERIOD / PERIOD_DAYS))
  last_7d_total=$(echo "$COUNTS_7D" | jq -r 'to_entries | map(.value) | add // 0')
  avg_7=$((last_7d_total / 7))

  jq -n \
    --argjson total "$TOTAL_PERIOD" \
    --argjson period "$PERIOD_DAYS" \
    --argjson top5 "$top5_json" \
    --argjson active "$active_json" \
    --argjson stale "$stale_json" \
    --argjson imp "$imp_json" \
    --arg spark "$daily_spark" \
    --argjson avg_period "$avg_period" \
    --argjson avg7 "$avg_7" \
    '{
      analyzed_events: $total,
      period_days: $period,
      top_5: $top5,
      active_7d: $active,
      stale_period: $stale,
      improvements: $imp,
      trends: {
        total_events_sparkline: $spark,
        daily_avg_period: $avg_period,
        daily_avg_7d: $avg7
      }
    }'
}
```

### 9. 모드별 출력

```bash
case "$MODE" in
  all)
    echo "📊 vibe-flow Telemetry (1 머신, ${PERIOD_DAYS}일 분석)"
    echo "   분석된 events: $TOTAL_PERIOD"
    echo ""
    print_top5
    print_active
    print_stale
    print_improvements
    print_trends
    echo "설정: /telemetry skills | trends | --json | --period 7|30|90"
    ;;
  skills)
    echo "📊 vibe-flow Telemetry — Skills (${PERIOD_DAYS}일)"
    echo ""
    print_top5
    print_active
    print_stale
    ;;
  trends)
    echo "📊 vibe-flow Trends (${PERIOD_DAYS}일)"
    echo ""
    print_trends
    echo "스킬별 추이 (Top 5):"
    if [ -n "$TOP_5" ]; then
      while IFS=$'\t' read -r type count; do
        [ -z "$type" ] && continue
        local label trend
        label=$(type_to_label "$type")
        trend=$(trend_label_for_type "$type")
        printf "  %-15s  %s\n" "$label" "$trend"
      done <<< "$TOP_5"
    fi
    ;;
  json)
    print_json
    ;;
esac
```

### 10. Events 발생

```bash
NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
mkdir -p .claude
jq -nc --arg ts "$NOW_ISO" --arg mode "$MODE" --argjson n "$TOTAL_PERIOD" --argjson p "$PERIOD_DAYS" \
  '{type:"telemetry", ts:$ts, mode:$mode, period_days:$p, analyzed_events:$n}' \
  >> .claude/events.jsonl
```

## 출처

Phase 4 첫 항목. spec: `docs/superpowers/specs/2026-04-30-telemetry-skill-design.md`.
