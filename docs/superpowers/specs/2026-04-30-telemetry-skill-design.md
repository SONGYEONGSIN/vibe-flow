# /telemetry 스킬 설계

본인 1 머신 events.jsonl 분석으로 스킬 사용 빈도 + 미사용 + 추세 + 개선 후보를 출력하는 메이커 + 사용자 자가 진단 도구 (Phase 4).

## 의도

**문제**: vibe-flow는 27 스킬을 운영하지만, 메이커가 빌드 개선 결정(스킬 통합 / deprecate / 경량화)을 할 데이터가 흩어져 있다. /metrics는 이벤트 메트릭 일반 대시, /menu는 카탈로그, /budget은 비용 한도 — 모두 "빌드 자체를 어떻게 개선할지"의 메이커 관점은 부족.

**해결**: `/telemetry` — 30일 events.jsonl 분석 → Top 5 / Active / Stale / 개선 후보 / 추세 출력. 메이커는 본인 머신 데이터로 빌드 결정. 일반 사용자도 자기 사용 패턴 진단 가능.

**범위**: 본인 1 머신만. 머신 간 sync는 Phase 3 dashboard 영역.

## 제약

- **데이터 우선**: events.jsonl + jq. 외부 의존 0 (date 기본).
- **읽기 전용**: events 변경 안 함. /telemetry 자체 호출 시 1줄 append만.
- **단순 분석**: 스킬 페어 / eval 회귀는 YAGNI. 단일 스킬 빈도/추세/last-used만.
- **명령 표면**: 단일 명령 + 4 모드 (all/skills/trends/--json).

## 설계

### 입력

```bash
/telemetry              # 종합 보고서 (default)
/telemetry skills       # 스킬 사용 빈도만 (Top 5 + Active + Stale)
/telemetry trends       # 30일 추이만 (sparkline + daily avg)
/telemetry --json       # JSON 출력
```

### 대상 스킬 명단 (27)

events.jsonl `type` 필드 기준 매핑:

**Core 18**:
- brainstorm, plan, finish, release
- scaffold, test, worktree
- verify, security, commit (commit_created), review_pr (review_pr), review_received
- status, learn (learn_save), onboard, menu, inbox, budget

**Extensions 9**:
- eval, skill_evolve (evolve), design_sync, design_audit
- pair_session (pair), discuss
- metrics, retrospective
- feedback

스킬명 → events type 매핑은 SKILL.md 안 alias 함수.

### 분류

| 분류 | 조건 | 출력 |
|------|------|------|
| Top 5 | 30일 카운트 상위 5 | 카운트 + sparkline + 추세 |
| Active | 7일 내 1회+ | 콤마 구분 명단 |
| Stale | 30일 내 0회 | 명단 + last 사용일 |
| 개선 후보 | stale ≥ 30일 + total < 5 → deprecate / 14~30일 → workflow 변화 | 항목별 메시지 |

### 시그널 (jq aggregation)

```bash
EVENTS=".claude/events.jsonl"
TODAY_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
DAY_30_AGO=$(date -u -v-30d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
        || date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%SZ)
DAY_7_AGO=$(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
        || date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)

# 전체 분석된 events
TOTAL=$(jq -r --arg d "$DAY_30_AGO" \
  'select(.ts > $d) | .type' "$EVENTS" 2>/dev/null | wc -l | tr -d ' ')

# 30일 카운트 per type
count_30d() {
  local type="$1"
  jq -r --arg t "$type" --arg d "$DAY_30_AGO" \
    'select(.type==$t and .ts > $d) | .type' \
    "$EVENTS" 2>/dev/null | wc -l | tr -d ' '
}

# 7일 카운트 per type
count_7d() {
  local type="$1"
  jq -r --arg t "$type" --arg d "$DAY_7_AGO" \
    'select(.type==$t and .ts > $d) | .type' \
    "$EVENTS" 2>/dev/null | wc -l | tr -d ' '
}

# 마지막 사용 (ts max)
last_used() {
  local type="$1"
  jq -r --arg t "$type" \
    'select(.type==$t) | .ts' \
    "$EVENTS" 2>/dev/null | sort | tail -1
}
```

### 종합 보고서 출력 (default)

```
📊 vibe-flow Telemetry (1 머신, 30일 분석)
   분석된 events: <TOTAL>

━━━ Top 5 ━━━
  1. /commit          312회  ▂▃▄▆█  ↗ 증가
  2. /verify          287회  ▃▄▅▆█  ↗ 증가
  3. /brainstorm       58회  ▁▁▂▂▃  ↗ 증가
  4. /test             42회  ▁▁▂▂▂  → 평탄
  5. /menu             18회  ▁▁▁▂▂  → 평탄

━━━ Active (7일 내 사용) ━━━
  /commit, /verify, /brainstorm, /test, /menu, /onboard,
  /status, /finish, /budget, /inbox

━━━ Stale (30일 내 0회) ━━━
  /release         (last: 45일 전)
  /security        (last: never)
  /design-sync     (last: never — design-system extension)
  /pair            (last: 32일 전 — deep-collaboration extension)
  /retrospective   (last: never — learning-loop extension)

━━━ 개선 후보 ━━━
  • /security 미사용 — 사용 시나리오 발견 또는 deprecate 검토
  • /pair 32일 전 — workflow 변화 가능성 (Solo 또는 단순 도구로 대체)
  • /design-sync, /retrospective never — extension 미설치 가능

━━━ 30일 추이 ━━━
  total events: ▁▁▂▂▃▃▄▄▅▆▇█  ↗ 증가
  daily avg: 24 → 38 (지난 7일)

설정: /telemetry skills | trends | --json
```

### Skills 모드

Top 5 + Active + Stale 섹션만 (개선 후보 + 추이 제외).

### Trends 모드

```
📊 vibe-flow Trends (30일)

총 events: 720
일평균: 24
지난 7일 평균: 38 (↗ 증가)

일별 sparkline:
  ▁▁▁▂▂▂▃▃▃▄▄▄▅▅▅▆▆▆▇▇▇████████

스킬별 추이 (Top 5):
  /commit       ▂▃▄▆█  ↗ 증가
  /verify       ▃▄▅▆█  ↗ 증가
  ...
```

### JSON 모드

```json
{
  "analyzed_events": 720,
  "period_days": 30,
  "top_5": [
    {"skill": "/commit", "count_30d": 312, "trend": "increasing"},
    ...
  ],
  "active_7d": ["/commit", "/verify", ...],
  "stale_30d": [
    {"skill": "/security", "last_used": null},
    {"skill": "/pair", "last_used": "2026-03-29T10:00:00Z"}
  ],
  "improvements": [
    "/security 미사용 — 사용 시나리오 발견 또는 deprecate 검토"
  ],
  "trends": {
    "total_events_sparkline": "▁▁▂▂▃...",
    "daily_avg_30d": 24,
    "daily_avg_7d": 38
  }
}
```

### Sparkline 매핑

7일 또는 30일 카운트 → `░▁▂▃▄▅▆▇█` 9-level UTF-8.

```bash
sparkline() {
  local counts="$1"  # 공백 구분 정수
  local max=$(echo $counts | tr ' ' '\n' | sort -n | tail -1)
  [ -z "$max" ] || [ "$max" = "0" ] && {
    local len=$(echo $counts | wc -w | tr -d ' ')
    printf '░%.0s' $(seq 1 $len)
    return
  }
  local chars=("░" "▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")
  for n in $counts; do
    local idx=$((n * 8 / max))
    [ "$idx" -gt 8 ] && idx=8
    printf "%s" "${chars[$idx]}"
  done
}
```

### 추세 라벨

전반 vs 후반 평균 비교 (30일을 7일 단위로 나눠 첫 4주 평균 vs 마지막 7일 평균):

```bash
trend_label() {
  local first_avg="$1" last_avg="$2"
  if [ "$last_avg" -gt $((first_avg * 110 / 100)) ]; then echo "↗ 증가"
  elif [ "$last_avg" -lt $((first_avg * 90 / 100)) ]; then echo "↘ 감소"
  else echo "→ 평탄"
  fi
}
```

### 개선 후보 매핑

```
1. stale ≥ 30일 + total < 5 → "deprecate 검토"
2. stale 14~30일 + 활성 카테고리 → "workflow 변화 가능성"
3. extension 스킬 + state.extensions에 없음 → "extension 미설치"
```

extension 스킬 식별: design_sync/design_audit (design-system), pair_session/discuss (deep-collaboration), metrics/retrospective (learning-loop), feedback (code-feedback), eval/skill_evolve (meta-quality).

### Events 발생

`/telemetry` 실행 시:
```json
{
  "type": "telemetry",
  "ts": "...",
  "mode": "all|skills|trends|json",
  "analyzed_events": <count>
}
```

## 데이터 흐름

```
사용자: /telemetry [mode]
   │
   ▼
1. 모드 파싱 (default | skills | trends | --json)
2. 시그널 수집:
   - 27 스킬별 30일/7일 카운트 (jq, 27회 호출 또는 1패스 group)
   - 27 스킬별 last_used (jq, 1패스)
   - 30일 일별 total event 카운트 (sparkline용)
   - extension 활성 명단 (.vibe-flow.json)
3. 분류: Top 5 / Active / Stale / 개선 후보
4. 모드별 출력
5. events.jsonl에 telemetry append
```

성능 최적화: 27회 jq 호출 대신 1패스로 group_by(.type) → object 캐시.

```bash
# 30일 events 한 번에 group
COUNTS_30D=$(jq -s --arg d "$DAY_30_AGO" \
  'map(select(.ts > $d)) | group_by(.type) | map({type: .[0].type, count: length}) | from_entries' \
  "$EVENTS" 2>/dev/null)

# 사용:
DAILY=$(echo "$COUNTS_30D" | jq -r --arg t "commit_created" '.[$t] // 0')
```

## 의존

- **Core**: events.jsonl (필수), .vibe-flow.json (선택, extension 미설치 식별)
- **외부**: jq (필수), date, awk (POSIX)
- **Hook 불필요**

## /menu, /budget, /metrics와의 관계

| | /menu | /budget | /metrics (ext) | /telemetry |
|---|-------|---------|----------------|------------|
| 영역 | 카탈로그 + 사용 분포 | 비용 한도 | 일반 메트릭 대시 | 메이커 보고서 |
| 데이터 기간 | 전체 | 일/주간 | 일/주/전체 | 30일 |
| 개선 후보 | X | X | X | ✓ (deprecate / workflow 변화) |
| 대상 사용자 | 일반 | 일반 | 일반 | 메이커 + 자가 진단 |

`/telemetry`는 메이커 의사결정 도구. `/metrics`는 일반 대시.

## YAGNI 제외

- **스킬 페어 분석** — 복잡, 단일 스킬만
- **eval 회귀** — Phase 4 다른 항목 (eval CI 통합)
- **token 추정 비용** — P5와 동일 이유
- **외부 사용자 데이터** — Phase 3+ 결정
- **시각화 차트** — 텍스트만 (sparkline 충분)
- **알림 통합** — budget-warn처럼 별도 hook 불필요 (메이커가 명시 호출)
