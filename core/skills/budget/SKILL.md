---
name: budget
description: 비용 예산 프레임워크. 기본은 호출 카운트 기반(5 무거운 스킬 일일/주간 한도). --tokens 옵션으로 Claude Code session-logs/*.jsonl 파싱하여 모델별 정확 USD 비용 표시. 정보만 (차단 X).
model: claude-sonnet-4-6
---

# /budget

vibe-flow의 무거운 LLM 호출 5개 스킬 사용량을 호출 카운트로 추적. `--tokens`로 session-logs 기반 정확 USD 비용 보조 모드. 한도는 정보용 (차단 안 함).

## 트리거

- `/budget` — 사용량 + 한도 + 추이 출력 (호출 카운트)
- `/budget set <skill> <daily> <weekly>` — 한도 갱신
- `/budget reset` — 기본값 복귀
- `/budget --json` — JSON 출력
- `/budget --tokens [--period 7|30|90]` — Claude Code session-logs 기반 모델별 정확 USD 비용 (기본 30일)

## 절차

### 1. 인자 파싱

```bash
MODE="view"
SKILL=""; DAILY=""; WEEKLY=""
PERIOD_DAYS=30  # --tokens 모드 기본 분석 기간

while [ $# -gt 0 ]; do
  case "$1" in
    set) MODE="set"; SKILL="$2"; DAILY="$3"; WEEKLY="$4"; shift 4 || break; continue ;;
    reset) MODE="reset" ;;
    --json) MODE="json" ;;
    --tokens) MODE="tokens" ;;
    --period)
      shift
      case "$1" in
        7|30|90) PERIOD_DAYS="$1" ;;
        *) echo "warn: --period $1 무효, 30일 대체 (허용: 7|30|90)" >&2 ;;
      esac
      ;;
  esac
  shift
done
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

### 9. Token 모드 (--tokens) — Claude Code session-logs 기반 정확 비용

```bash
print_tokens() {
  local home_projects="${HOME}/.claude/projects"
  if [ ! -d "$home_projects" ]; then
    echo "Claude Code session-logs 디렉토리 없음: $home_projects" >&2
    echo "(Claude Code 사용 이력 필요)" >&2
    return 1
  fi

  # 가격 table 로드 — 우선순위: skill 설치 위치 > vibe-flow 소스
  local pricing_file=""
  for candidate in \
    ".claude/skills/budget/data/pricing.json" \
    "core/skills/budget/data/pricing.json" \
    "${HOME}/.claude/skills/budget/data/pricing.json"; do
    if [ -f "$candidate" ]; then
      pricing_file="$candidate"
      break
    fi
  done
  if [ -z "$pricing_file" ]; then
    echo "pricing.json 없음 — /budget --tokens는 가격 table이 필요합니다" >&2
    return 1
  fi

  # 분석 기간 시작점
  local since
  since=$(date -u -v-${PERIOD_DAYS}d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
       || date -u -d "${PERIOD_DAYS} days ago" +%Y-%m-%dT%H:%M:%SZ)

  # 현재 프로젝트 cwd — macOS NFD/NFC 정규화 (Claude Code log는 NFC 저장)
  local project_cwd_raw project_cwd
  project_cwd_raw=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  if command -v python3 &>/dev/null; then
    project_cwd=$(python3 -c "import unicodedata,sys;print(unicodedata.normalize('NFC', sys.argv[1]))" "$project_cwd_raw" 2>/dev/null || echo "$project_cwd_raw")
  else
    project_cwd="$project_cwd_raw"
  fi

  # 모든 session-log 순회 — cat | jq -n inputs 패턴 (jq -s는 NDJSON 다중파일 부적합)
  local agg
  agg=$(cat "$home_projects"/*/*.jsonl 2>/dev/null | jq -n --arg cwd "$project_cwd" --arg since "$since" '
    [inputs | select(
        .type == "assistant"
        and .cwd == $cwd
        and (.timestamp // .ts // "") > $since
        and ((.message.usage.input_tokens // 0) + (.message.usage.output_tokens // 0)) > 0
        and (.message.model // "") != "<synthetic>"
      )]
    | group_by(.message.model)
    | map({
        model: (.[0].message.model // "unknown"),
        input: (map(.message.usage.input_tokens // 0) | add),
        output: (map(.message.usage.output_tokens // 0) | add),
        cache_read: (map(.message.usage.cache_read_input_tokens // 0) | add),
        cache_creation: (map(.message.usage.cache_creation_input_tokens // 0) | add),
        messages: length
      })
  ' 2>/dev/null || echo '[]')

  if [ "$(echo "$agg" | jq 'length')" = "0" ]; then
    echo "📊 /budget --tokens (지난 ${PERIOD_DAYS}일, project: $project_cwd)"
    echo "   매칭되는 session-log 없음 — Claude Code에서 이 프로젝트 사용 이력이 없습니다."
    return 0
  fi

  # 각 모델별 USD 계산
  echo "📊 /budget --tokens (지난 ${PERIOD_DAYS}일, project: $project_cwd)"
  echo ""
  printf "%-22s %12s %12s %12s %12s %10s\n" "model" "input" "output" "cache_rd" "cache_cr" "USD"
  printf "%-22s %12s %12s %12s %12s %10s\n" "─────" "─────" "──────" "────────" "────────" "───"

  local total_usd=0
  echo "$agg" | jq -c '.[]' | while IFS= read -r row; do
    local model input output cache_read cache_create
    model=$(echo "$row" | jq -r '.model')
    input=$(echo "$row" | jq -r '.input')
    output=$(echo "$row" | jq -r '.output')
    cache_read=$(echo "$row" | jq -r '.cache_read')
    cache_create=$(echo "$row" | jq -r '.cache_creation')

    # pricing lookup — 정확 매치 후 _default fallback
    local p_in p_out p_cr p_cc
    p_in=$(jq -r --arg m "$model"   '.models[$m].input        // .models._default.input'        "$pricing_file")
    p_out=$(jq -r --arg m "$model"  '.models[$m].output       // .models._default.output'       "$pricing_file")
    p_cr=$(jq -r --arg m "$model"   '.models[$m].cache_read   // .models._default.cache_read'   "$pricing_file")
    p_cc=$(jq -r --arg m "$model"   '.models[$m].cache_creation // .models._default.cache_creation' "$pricing_file")

    # USD = (tokens / 1M) * price
    local usd
    usd=$(awk -v i="$input" -v o="$output" -v cr="$cache_read" -v cc="$cache_create" \
              -v pi="$p_in" -v po="$p_out" -v pcr="$p_cr" -v pcc="$p_cc" \
              'BEGIN{printf "%.4f", (i*pi + o*po + cr*pcr + cc*pcc) / 1000000}')

    printf "%-22s %12s %12s %12s %12s %10s\n" \
      "$model" \
      "$(numfmt --grouping "$input" 2>/dev/null || echo "$input")" \
      "$(numfmt --grouping "$output" 2>/dev/null || echo "$output")" \
      "$(numfmt --grouping "$cache_read" 2>/dev/null || echo "$cache_read")" \
      "$(numfmt --grouping "$cache_create" 2>/dev/null || echo "$cache_create")" \
      "\$$usd"
  done

  echo ""
  echo "출처: ${home_projects}/*/*.jsonl (cwd 매칭)"
  echo "가격: $pricing_file (변동 시 갱신)"
}
```

### 10. 모드 분기 + 출력

```bash
case "$MODE" in
  view) print_view ;;
  json) print_json ;;
  tokens) print_tokens ;;
  set|reset) ;;  # 위에서 처리
esac
```

### 11. Events 발생

```bash
NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
mkdir -p .claude
if [ "$MODE" = "tokens" ]; then
  jq -nc --arg ts "$NOW_ISO" --arg mode "$MODE" --argjson p "$PERIOD_DAYS" \
    '{type:"budget", ts:$ts, mode:$mode, period_days:$p}' \
    >> .claude/events.jsonl
else
  jq -nc --arg ts "$NOW_ISO" --arg mode "$MODE" \
    '{type:"budget", ts:$ts, mode:$mode}' \
    >> .claude/events.jsonl
fi
```

## 출처

P5 ROADMAP. spec: `docs/superpowers/specs/2026-04-30-budget-skill-design.md`.
