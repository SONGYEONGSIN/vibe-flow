---
name: budget
description: 호출 카운트 기반 비용 예산 프레임워크. 5개 무거운 스킬(/pair, /discuss, /evolve, /design-sync, /retrospective) 일일/주간 한도 추적 + sparkline 추이 + 80%+ 경고. 정보만 (차단 X).
model: claude-sonnet-4-6
---

# /budget

vibe-flow의 무거운 LLM 호출 5개 스킬 사용량을 호출 카운트로 추적. 한도는 정보용 (차단 안 함).

## 트리거

- `/budget` — 사용량 + 한도 + 추이 출력
- `/budget set <skill> <daily> <weekly>` — 한도 갱신
- `/budget reset` — 기본값 복귀
- `/budget --json` — JSON 출력

## 절차

### 1. 인자 파싱

```bash
ARG1="${1:-view}"
case "$ARG1" in
  set) MODE="set"; SKILL="$2"; DAILY="$3"; WEEKLY="$4" ;;
  reset) MODE="reset" ;;
  --json) MODE="json" ;;
  *) MODE="view" ;;
esac
```

### 2. budget.json 로드 (기본값 fallback)

```bash
BUDGET_FILE=".claude/budget.json"

DEFAULT_BUDGET='{
  "version":"1.0.0",
  "limits":{
    "pair_session":{"daily":5,"weekly":20},
    "discuss":{"daily":5,"weekly":20},
    "skill_evolve":{"daily":3,"weekly":10},
    "design_sync":{"daily":5,"weekly":20},
    "retrospective":{"daily":1,"weekly":5}
  },
  "warn_threshold":0.8
}'

if [ -f "$BUDGET_FILE" ]; then
  BUDGET=$(cat "$BUDGET_FILE")
else
  BUDGET="$DEFAULT_BUDGET"
fi
```

### 3. 별칭 매핑

```bash
# 사용자 친화 별칭 → events type
alias_to_type() {
  case "$1" in
    pair) echo "pair_session" ;;
    discuss) echo "discuss" ;;
    evolve) echo "skill_evolve" ;;
    design-sync|design_sync) echo "design_sync" ;;
    retrospective) echo "retrospective" ;;
    *) echo "$1" ;;
  esac
}

type_to_label() {
  case "$1" in
    pair_session) echo "/pair" ;;
    discuss) echo "/discuss" ;;
    skill_evolve) echo "/evolve" ;;
    design_sync) echo "/design-sync" ;;
    retrospective) echo "/retrospective" ;;
    *) echo "$1" ;;
  esac
}
```

### 4. set/reset/json 모드 분기

```bash
case "$MODE" in
  set)
    [ -z "$SKILL" ] || [ -z "$DAILY" ] || [ -z "$WEEKLY" ] && {
      echo "Usage: /budget set <skill> <daily> <weekly>" >&2
      exit 1
    }
    TYPE=$(alias_to_type "$SKILL")
    NEW=$(echo "$BUDGET" | jq --arg t "$TYPE" --argjson d "$DAILY" --argjson w "$WEEKLY" \
      '.limits[$t] = {daily: $d, weekly: $w}')
    mkdir -p .claude
    echo "$NEW" > "$BUDGET_FILE"
    echo "✓ $SKILL: daily=$DAILY, weekly=$WEEKLY 갱신됨"
    ;;
  reset)
    mkdir -p .claude
    echo "$DEFAULT_BUDGET" | jq . > "$BUDGET_FILE"
    echo "✓ 기본 한도로 복귀됨"
    ;;
esac
```

### 5. 사용량 측정 (jq aggregation)

```bash
EVENTS=".claude/events.jsonl"
TODAY=$(date -u +%Y-%m-%d)
WEEK_AGO=$(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
       || date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)

count_today() {
  local type="$1"
  [ -f "$EVENTS" ] || { echo 0; return; }
  jq -r --arg t "$type" --arg today "$TODAY" \
    'select(.type==$t and (.ts | startswith($today))) | .type' \
    "$EVENTS" 2>/dev/null | wc -l | tr -d ' '
}

count_weekly() {
  local type="$1"
  [ -f "$EVENTS" ] || { echo 0; return; }
  jq -r --arg t "$type" --arg w "$WEEK_AGO" \
    'select(.type==$t and .ts > $w) | .type' \
    "$EVENTS" 2>/dev/null | wc -l | tr -d ' '
}
```

### 6. Progress bar + sparkline + 추세

```bash
# 5칸 progress bar
progress_bar() {
  local n="$1" max="$2"
  [ "$max" -eq 0 ] && { echo "░░░░░"; return; }
  local filled=$((n * 5 / max))
  [ "$filled" -gt 5 ] && filled=5
  local empty=$((5 - filled))
  printf '%.0s█' $(seq 1 $filled 2>/dev/null) 2>/dev/null
  printf '%.0s░' $(seq 1 $empty 2>/dev/null) 2>/dev/null
}

# 7일 sparkline (UTF-8 8-level)
sparkline_7d() {
  local type="$1"
  local counts=""
  for i in 6 5 4 3 2 1 0; do
    local d
    d=$(date -u -v-${i}d +%Y-%m-%d 2>/dev/null \
        || date -u -d "$i days ago" +%Y-%m-%d)
    local c
    c=$(jq -r --arg t "$type" --arg d "$d" \
      'select(.type==$t and (.ts | startswith($d))) | .type' \
      "$EVENTS" 2>/dev/null | wc -l | tr -d ' ')
    counts="$counts $c"
  done

  local max
  max=$(echo $counts | tr ' ' '\n' | sort -n | tail -1)
  [ -z "$max" ] || [ "$max" = "0" ] && { echo "░░░░░░░"; return; }

  local chars=("░" "▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")
  local out=""
  for n in $counts; do
    local idx=$((n * 8 / max))
    [ "$idx" -gt 8 ] && idx=8
    out+="${chars[$idx]}"
  done
  echo "$out"
}

# 추세 라벨 (전반 3일 vs 후반 3일 비교)
trend_label() {
  local type="$1"
  local sum_first=0 sum_last=0
  for i in 6 5 4; do
    local d c
    d=$(date -u -v-${i}d +%Y-%m-%d 2>/dev/null \
        || date -u -d "$i days ago" +%Y-%m-%d)
    c=$(jq -r --arg t "$type" --arg d "$d" \
      'select(.type==$t and (.ts | startswith($d))) | .type' \
      "$EVENTS" 2>/dev/null | wc -l | tr -d ' ')
    sum_first=$((sum_first + c))
  done
  for i in 2 1 0; do
    local d c
    d=$(date -u -v-${i}d +%Y-%m-%d 2>/dev/null \
        || date -u -d "$i days ago" +%Y-%m-%d)
    c=$(jq -r --arg t "$type" --arg d "$d" \
      'select(.type==$t and (.ts | startswith($d))) | .type' \
      "$EVENTS" 2>/dev/null | wc -l | tr -d ' ')
    sum_last=$((sum_last + c))
  done
  if [ "$sum_last" -gt "$sum_first" ]; then echo "↗ 증가"
  elif [ "$sum_last" -lt "$sum_first" ]; then echo "↘ 감소"
  else echo "→ 평탄"
  fi
}
```

### 7. View 모드 출력

```bash
print_view() {
  echo "💰 vibe-flow Budget"
  echo ""
  echo "스킬             일일                주간"
  echo "─────────────────────────────────────────"

  for type in $(echo "$BUDGET" | jq -r '.limits | keys[]'); do
    local label daily_limit weekly_limit today week
    label=$(type_to_label "$type")
    daily_limit=$(echo "$BUDGET" | jq -r --arg t "$type" '.limits[$t].daily')
    weekly_limit=$(echo "$BUDGET" | jq -r --arg t "$type" '.limits[$t].weekly')
    today=$(count_today "$type")
    week=$(count_weekly "$type")

    local daily_pct weekly_pct daily_warn=""
    daily_pct=$((today * 100 / (daily_limit > 0 ? daily_limit : 1)))
    weekly_pct=$((week * 100 / (weekly_limit > 0 ? weekly_limit : 1)))
    if [ "$daily_pct" -ge 100 ]; then daily_warn=" ⚠⚠"
    elif [ "$daily_pct" -ge 80 ]; then daily_warn=" ⚠"
    fi

    printf "%-15s %s %d/%d (%d%%)    %s %d/%d (%d%%)%s\n" \
      "$label" \
      "$(progress_bar "$today" "$daily_limit")" "$today" "$daily_limit" "$daily_pct" \
      "$(progress_bar "$week" "$weekly_limit")" "$week" "$weekly_limit" "$weekly_pct" \
      "$daily_warn"
  done

  echo ""
  echo "추이 (지난 7일):"
  for type in $(echo "$BUDGET" | jq -r '.limits | keys[]'); do
    local label spark trend
    label=$(type_to_label "$type")
    spark=$(sparkline_7d "$type")
    trend=$(trend_label "$type")
    printf "  %-15s %s  %s\n" "$label" "$spark" "$trend"
  done

  echo ""
  echo "설정 파일: .claude/budget.json"
  echo "한도 변경: /budget set <skill> <daily> <weekly>"
  echo "JSON 출력: /budget --json"
}
```

### 8. JSON 모드 출력

```bash
print_json() {
  local result='{"limits":{},"usage":{}}'
  for type in $(echo "$BUDGET" | jq -r '.limits | keys[]'); do
    local today week daily_limit weekly_limit
    today=$(count_today "$type")
    week=$(count_weekly "$type")
    daily_limit=$(echo "$BUDGET" | jq -r --arg t "$type" '.limits[$t].daily')
    weekly_limit=$(echo "$BUDGET" | jq -r --arg t "$type" '.limits[$t].weekly')
    result=$(echo "$result" | jq --arg t "$type" \
      --argjson dl "$daily_limit" --argjson wl "$weekly_limit" \
      --argjson td "$today" --argjson wk "$week" \
      '.limits[$t] = {daily: $dl, weekly: $wl} | .usage[$t] = {today: $td, week: $wk}')
  done
  echo "$result" | jq .
}
```

### 9. 모드 분기 + 출력

```bash
case "$MODE" in
  view) print_view ;;
  json) print_json ;;
  set|reset) ;;  # 위에서 처리
esac
```

### 10. Events 발생

```bash
NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
mkdir -p .claude
jq -nc --arg ts "$NOW_ISO" --arg mode "$MODE" \
  '{type:"budget", ts:$ts, mode:$mode}' \
  >> .claude/events.jsonl
```

## 출처

P5 ROADMAP. spec: `docs/superpowers/specs/2026-04-30-budget-skill-design.md`.
