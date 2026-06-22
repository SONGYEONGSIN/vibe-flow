---
name: telemetry
description: 본인 1 머신 사용량 분석 — Top 5 / Active / Stale / 개선 후보 / 추세. 두 데이터 소스 — `--source events` (default, .claude/events.jsonl) / `--source session` (~/.claude/projects/<project>/*.jsonl raw 호출 빈도, F-D2 R3 instrumentation gap 우회). 기본 30일, --period 7|30|90. 4 모드 (all/skills/trends/--json). "텔레메트리 보여줘", "사용량", "내 패턴" 요청 시 사용.
model: claude-sonnet-4-6
---

# /telemetry

vibe-flow의 본인 1 머신 사용량을 분석해 메이커 의사결정 데이터를 출력한다. 기본 분석 기간 30일, `--period 7|30|90`으로 조정 가능. 두 데이터 소스 지원:

| Source | 데이터 위치 | 측정 대상 | 한계 |
|--------|-----------|----------|------|
| `events` (default) | `.claude/events.jsonl` | 자체 hook이 기록한 의미 있는 이벤트 (brainstorm/plan_created/commit_created 등) | instrumentation gap — Skill 자동 trigger + Agent dispatch는 PR #81(`tool-invocation-tracker.sh`) 머지 이후만 기록 |
| `session` (F-D2 R3) | `~/.claude/projects/<project>/*.jsonl` | Claude Code raw 세션 로그의 Skill tool / Agent tool 호출 직접 추출 | 의미 있는 events(brainstorm/plan_created)는 부재 |

**권장 사용**:
- 일상 점검: `--source events` (의미 있는 활동 단위)
- 실 호출 빈도 정밀 측정: `--source session` (instrumentation gap 우회, raw 데이터)
- 둘 다 보고 싶으면: 두 번 실행 후 비교

## 트리거

- `/telemetry` — 종합 보고서 (30일, events)
- `/telemetry skills` — Top 5 + Active + Stale만
- `/telemetry trends` — 추이만
- `/telemetry --json` — JSON 출력
- `/telemetry --period 7|30|90` — 분석 기간 조정 (다른 모드와 조합 가능)
- `/telemetry --source session` — Claude Code raw 세션 로그 분석 (F-D2 R3)
- `/telemetry skills --source session --period 7` — 조합 가능

## 절차

### 1. 모드 + 기간 + 소스 파싱

```bash
# 기본값
MODE="all"
PERIOD_DAYS=30
SOURCE="events"   # events (default) | session (F-D2 R3)

# 인자 순회 — --period / --source / mode 동시 허용
while [ $# -gt 0 ]; do
  case "$1" in
    --period)
      shift
      case "$1" in
        7|30|90) PERIOD_DAYS="$1" ;;
        *) echo "warn: --period $1 무효, 30일로 대체 (허용: 7|30|90)" >&2 ;;
      esac
      ;;
    --source)
      shift
      case "$1" in
        events|session) SOURCE="$1" ;;
        *) echo "warn: --source $1 무효, events로 대체 (허용: events|session)" >&2 ;;
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

### 2. 시간 기준 + 소스 경로

```bash
if [ "$SOURCE" = "session" ]; then
  # F-D2 R3: Claude Code raw 세션 로그 (~/.claude/projects/<project>/*.jsonl)
  # 현 프로젝트 디렉토리에 매핑된 sub-dir 자동 인식 (path → slug 변환)
  PROJECT_SLUG=$(pwd | sed 's|/|-|g' | sed 's/^-//')
  SESSION_DIR="$HOME/.claude/projects/-${PROJECT_SLUG}"
  [ -d "$SESSION_DIR" ] || { echo "session-logs 없음 — $SESSION_DIR" >&2; exit 0; }
  SESSION_FILES=$(find "$SESSION_DIR" -name "*.jsonl" -type f 2>/dev/null)
  [ -z "$SESSION_FILES" ] || true
else
  EVENTS=".claude/events.jsonl"
  [ -f "$EVENTS" ] || { echo "events.jsonl 없음 — 먼저 vibe-flow 사용 후 다시 실행" >&2; exit 0; }
fi

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
  verify security commit_created commit_pushed
  review_pr review_received
  status learn_save onboard menu inbox budget
  eval skill_evolve design_sync design_audit
  pair_session discuss
  metrics retrospective
  feedback
  # F-G04 (audit R7): PR #81 계측 이벤트 — 자동 trigger 추적 (Active/Stale 가시화)
  skill_invoked skill_invoked_auto agent_invoked
)

type_to_label() {
  case "$1" in
    commit_created) echo "/commit" ;;
    commit_pushed) echo "커밋" ;;
    learn_save) echo "/learn" ;;
    skill_evolve) echo "/evolve" ;;
    pair_session) echo "/pair" ;;
    review_pr) echo "/review-pr" ;;
    review_received) echo "/receive-review" ;;
    design_sync) echo "/design-sync" ;;
    design_audit) echo "/design-audit" ;;
    skill_invoked) echo "스킬(슬래시)" ;;
    skill_invoked_auto) echo "스킬(자동)" ;;
    agent_invoked) echo "에이전트" ;;
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
# F-G04 (audit R7) ① 집계 idiom 교정: 기존 `map({type,count}) | from_entries` 는
#   from_entries 가 key/value 키만 인식해 "null object key" 에러 → `|| echo {}` 폴백으로
#   events-source COUNTS 가 항상 빈 객체였음(Top5/Total 무력화). `map({(.[0].type): length}) | add` 로 수정.
# F-G04 (audit R7) ② hook-internal noise 타입 — 자동 hook 부산물이라 Top5/Total 을 오염시킴.
#   집계(Top5/Total/sparkline)에서만 제외. Active/Stale/개선후보는 SKILL_TYPES 기반이라 무관.
NOISE_TYPES='["memory_sync_triggered","tool_failure","tool_result"]'

# 분석 기간 카운트 (group)
COUNTS_PERIOD=$(jq -s --arg d "$DAY_PERIOD_AGO" --argjson noise "$NOISE_TYPES" \
  'map(select(.ts > $d and (.type as $t | ($noise | index($t)) == null))) | group_by(.type) | map({(.[0].type): length}) | add // {}' \
  "$EVENTS" 2>/dev/null || echo '{}')

# 7일 카운트 (서브 윈도우 — Active/추세용)
COUNTS_7D=$(jq -s --arg d "$DAY_7_AGO" --argjson noise "$NOISE_TYPES" \
  'map(select(.ts > $d and (.type as $t | ($noise | index($t)) == null))) | group_by(.type) | map({(.[0].type): length}) | add // {}' \
  "$EVENTS" 2>/dev/null || echo '{}')

# last_used per type
LAST_USED=$(jq -s 'group_by(.type) | map({(.[0].type): (max_by(.ts) | .ts)}) | add // {}' \
  "$EVENTS" 2>/dev/null || echo '{}')

# 분석 기간 일별 totals (sparkline용)
DAILY_TOTALS=$(jq -s --arg d "$DAY_PERIOD_AGO" --argjson noise "$NOISE_TYPES" \
  'map(select(.ts > $d and (.type as $t | ($noise | index($t)) == null))) | group_by(.ts | .[0:10]) | map({date: .[0].ts[0:10], count: length})' \
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

## Session Source 분석 (F-D2 R3 신설)

`SOURCE=session` 분기로 진입 시 위 절차의 jq 명령은 **session-logs/*.jsonl** 직접 파싱으로 대체된다. 다른 의미 있는 자체 이벤트(brainstorm/plan_created)는 없는 대신 **모든 Skill tool / Agent tool 호출이 raw로 기록**되어 instrumentation gap 0.

### 핵심 jq 명령어

```bash
# Skill tool 자동 호출 빈도 (input.skill 별)
jq -c '
  select(.message.content) |
  .message.content[]? |
  select(.type == "tool_use" and .name == "Skill") |
  .input.skill
' $SESSION_FILES 2>/dev/null | sort | uniq -c | sort -rn

# Agent / Task tool 호출 빈도 (input.subagent_type 별)
jq -c '
  .. | objects |
  select(.name == "Task" or .name == "Agent") |
  .input.subagent_type // empty
' $SESSION_FILES 2>/dev/null | sort | uniq -c | sort -rn

# User prompt 형식 분포 (slash vs 자연어)
jq -r '
  select(.message.role == "user") |
  .message.content |
  if type == "string" then . else (.[0].text // "") end |
  if startswith("/") then "slash" else "natural" end
' $SESSION_FILES 2>/dev/null | sort | uniq -c

# 기간 필터링은 .timestamp 또는 jsonl 라인의 .ts 필드 사용
# (session-logs는 .timestamp가 ISO 8601, 라인별 다름 — 정확한 필드는 head -1로 확인)
```

### 시간 필터링

```bash
# session-logs의 timestamp 필드를 ISO 8601로 보고 DAY_PERIOD_AGO 이상만 필터
jq -c --arg since "$DAY_PERIOD_AGO" '
  select(.timestamp >= $since) |
  ...  # 위 명령들과 조합
' $SESSION_FILES 2>/dev/null
```

### 출력 형식 (mode 별 일관성)

기존 events 모드의 출력 헤더 + 표 형식 그대로. 다만 헤더에 `source: session` 명시. 예:

```
[telemetry] source=session period=30d analyzed_files=12

## Skill tool 자동 호출 Top 10
  brainstorm    10
  plan          6
  ...

## Agent dispatch Top 10
  general-purpose 25
  ...

## User prompt 형식
  natural   939 (76%)
  slash      31 (2.5%)
```

### Events 발생 (session source 시)

```bash
# session source 분석도 events.jsonl에 메타 이벤트 1라인 기록
jq -nc --arg ts "$NOW_ISO" --arg mode "$MODE" --arg src "session" \
  --argjson n "$TOTAL_CALLS" --argjson p "$PERIOD_DAYS" \
  '{type:"telemetry", source:$src, ts:$ts, mode:$mode, period_days:$p, analyzed_events:$n}' \
  >> .claude/events.jsonl
```

### 한계

- **자체 이벤트 부재**: brainstorm spec 작성 / plan 생성 / commit 같은 의미 단위 활동은 session-logs에 raw tool call로만 기록. events 모드가 이런 의미 단위를 더 잘 잡음.
- **권장**: `--source events` 와 `--source session` 둘 다 실행해서 격차 비교가 가장 풍부 (R3 PR 이후 기본 패턴).

## 출처

- Phase 4 첫 항목. spec: `docs/superpowers/specs/2026-04-30-telemetry-skill-design.md`.
- Session source: F-D2 R3 audit 결과 (events.jsonl skill_invoked 7 vs session-logs 41, 83% gap). PR #81 `tool-invocation-tracker.sh`가 자동 trigger 추적 시작했으나, 과거 데이터는 session-logs 직접 분석으로만 복원 가능.
