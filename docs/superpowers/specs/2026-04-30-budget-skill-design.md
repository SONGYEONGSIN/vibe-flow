# /budget 스킬 + budget-warn hook 설계

호출 카운트 기반 토큰/비용 예산 프레임워크 (P5).

## 의도

**문제**: vibe-flow는 `/pair`, `/discuss`, `/evolve`, `/design-sync`, `/retrospective` 같은 무거운 스킬이 다중 LLM 호출을 트리거. 사용자가 의도치 않게 자주 실행하면 비용이 빠르게 누적되지만 자가 인지 수단이 없다. Anthropic console로 가야 비용 확인 가능.

**해결**: 호출 카운트 기반 budget 프레임워크. mechanical enforcement는 안 함 (정확한 토큰 비용 측정 불가). 정보 제공으로 자가 제동.

**범위**: 무거운 LLM 호출 5개 스킬만 추적 (Core/Extension 가벼운 스킬은 제외).

## 제약

- **mechanical enforcement 없음**: 차단 안 함, 정보만. vibe-flow의 "정확한 영역에만 강제" 철학 준수.
- **외부 의존 없음**: events.jsonl + jq + date만 사용.
- **token 추정 X**: 호출 카운트만. 정확도 한계 명시.
- **사용자 편집 가능**: `.claude/budget.json` 직접 편집 또는 `/budget set` 명령.

## 설계

### 컴포넌트

1. **`.claude/budget.json`** — 한도 설정 (사용자 편집 + setup.sh가 기본값 생성)
2. **`/budget` 스킬** — 사용량/한도/추이 출력 + 한도 갱신
3. **`hooks/budget-warn.sh`** — Notification hook, 80%+ 사용 시 비차단 경고

### `.claude/budget.json` 스키마

```json
{
  "version": "1.0.0",
  "limits": {
    "pair_session":   {"daily": 5, "weekly": 20},
    "discuss":        {"daily": 5, "weekly": 20},
    "skill_evolve":   {"daily": 3, "weekly": 10},
    "design_sync":    {"daily": 5, "weekly": 20},
    "retrospective":  {"daily": 1, "weekly": 5}
  },
  "warn_threshold": 0.8
}
```

`warn_threshold`: 0.0~1.0. 일일 한도 대비 사용률 N% 이상이면 budget-warn.sh 발화.

### 대상 스킬 매핑

| 스킬 | events.jsonl type | 기본 일일 | 기본 주간 |
|------|-------------------|-----------|-----------|
| /pair | `pair_session` | 5 | 20 |
| /discuss | `discuss` | 5 | 20 |
| /evolve | `skill_evolve` | 3 | 10 |
| /design-sync | `design_sync` | 5 | 20 |
| /retrospective | `retrospective` | 1 | 5 |

기본값 근거: 일반 개발자 일일 사용 패턴 추정 + 무거운 스킬일수록 보수적.

### 사용량 측정 (jq aggregation)

```bash
TODAY=$(date -u +%Y-%m-%d)
WEEK_AGO=$(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
       || date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)

count_today() {
  local type="$1"
  jq -r --arg t "$type" --arg today "$TODAY" \
    'select(.type==$t and (.ts | startswith($today)))' \
    .claude/events.jsonl 2>/dev/null | wc -l | tr -d ' '
}

count_weekly() {
  local type="$1"
  jq -r --arg t "$type" --arg w "$WEEK_AGO" \
    'select(.type==$t and .ts > $w)' \
    .claude/events.jsonl 2>/dev/null | wc -l | tr -d ' '
}
```

### `/budget` 출력 (default)

```
💰 vibe-flow Budget

스킬             일일                주간
─────────────────────────────────────────
/pair            ████░ 4/5 (80%)    ██░░░ 8/20 (40%)  ⚠
/discuss         █░░░░ 1/5 (20%)    █░░░░ 2/20 (10%)
/evolve          ░░░░░ 0/3 (0%)     ░░░░░ 0/10 (0%)
/design-sync     ░░░░░ 0/5 (0%)     ░░░░░ 0/20 (0%)
/retrospective   ████░ 1/1 (100%)   ████░ 4/5 (80%)   ⚠⚠

추이 (지난 7일):
  /pair        ▁▂▁▃▂▄█  ↗ 증가
  /discuss     ▁▁▁▂▁▁▁
  /evolve      ░░░░░░░
  /design-sync ░░░░░░░
  /retrospective ▁░░░░░█

설정 파일: .claude/budget.json
한도 변경: /budget set <skill> <daily> <weekly>
JSON 출력: /budget --json
```

`⚠`: 80% 이상 / `⚠⚠`: 100% 이상.

### `/budget` 명령 모드

| 입력 | 동작 |
|------|------|
| `/budget` | 사용량 + 한도 + 추이 출력 (default) |
| `/budget set <skill> <daily> <weekly>` | 한도 갱신 (`.claude/budget.json` 직접 수정) |
| `/budget reset` | 기본값 복귀 |
| `/budget --json` | JSON 출력 (스크립트 친화) |

`<skill>` 인자는 events 타입 (`pair_session`) 또는 별칭 (`pair`, `discuss`, `evolve`, `design-sync`, `retrospective`).

### `hooks/budget-warn.sh` (Notification hook)

idle_prompt 시 트리거. model-suggest처럼 디바운스 (15분 기본).

```bash
#!/bin/bash
# budget-warn.sh — 일일 한도 80%+ 사용 시 비차단 경고

set -u

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
BUDGET_FILE="$PROJECT_DIR/.claude/budget.json"
EVENTS="$PROJECT_DIR/.claude/events.jsonl"
LAST_WARN_FILE="$PROJECT_DIR/.claude/.budget-last-warn"

# 디바운스 — 15분
if [ -f "$LAST_WARN_FILE" ]; then
  LAST=$(cat "$LAST_WARN_FILE")
  NOW=$(date +%s)
  AGE=$((NOW - LAST))
  [ "$AGE" -lt 900 ] && exit 0
fi

[ -f "$BUDGET_FILE" ] || exit 0
[ -f "$EVENTS" ] || exit 0

THRESHOLD=$(jq -r '.warn_threshold // 0.8' "$BUDGET_FILE")
TODAY=$(date -u +%Y-%m-%d)

WARNINGS=()
for type in $(jq -r '.limits | keys[]' "$BUDGET_FILE"); do
  daily_limit=$(jq -r --arg t "$type" '.limits[$t].daily' "$BUDGET_FILE")
  count=$(jq -r --arg t "$type" --arg today "$TODAY" \
    'select(.type==$t and (.ts | startswith($today)))' \
    "$EVENTS" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$daily_limit" -gt 0 ]; then
    ratio=$(echo "scale=2; $count / $daily_limit" | bc)
    if (( $(echo "$ratio >= $THRESHOLD" | bc -l) )); then
      WARNINGS+=("$type: $count/$daily_limit ($(echo "$ratio * 100" | bc)%)")
    fi
  fi
done

if [ ${#WARNINGS[@]} -gt 0 ]; then
  echo '{"additionalContext": "💰 일일 budget 80%+ 사용 중:\n'"$(printf '  • %s\n' "${WARNINGS[@]}")"'\n\n자세한 사용량: /budget"}'
  date +%s > "$LAST_WARN_FILE"
fi

exit 0
```

### Events 발생

`/budget` 실행 시:
```json
{"type":"budget","ts":"...","mode":"view|set|reset|json"}
```

### setup.sh 변경

1. `.claude/budget.json` 기본값 생성 (파일 없을 때만):

```bash
# Setup 끝부분에 추가 (CLAUDE.md 복사 직후)
if [ ! -f "$PROJECT_DIR/.claude/budget.json" ]; then
  cat > "$PROJECT_DIR/.claude/budget.json" <<'EOF'
{
  "version": "1.0.0",
  "limits": {
    "pair_session":   {"daily": 5, "weekly": 20},
    "discuss":        {"daily": 5, "weekly": 20},
    "skill_evolve":   {"daily": 3, "weekly": 10},
    "design_sync":    {"daily": 5, "weekly": 20},
    "retrospective":  {"daily": 1, "weekly": 5}
  },
  "warn_threshold": 0.8
}
EOF
  echo "  Created .claude/budget.json (default limits)"
fi
```

2. `settings/settings.template.json` Notification 섹션에 budget-warn.sh 추가:

```json
"Notification": [
  {
    "matcher": "idle_prompt",
    "hooks": [
      { "type": "command", "command": ".claude/hooks/notify.sh", "timeout": 3000 },
      { "type": "command", "command": ".claude/hooks/model-suggest.sh", "timeout": 5000 },
      { "type": "command", "command": ".claude/hooks/budget-warn.sh", "timeout": 5000 }
    ]
  }
]
```

### Evals (`evals/evals.json`)

5 케이스:
1. **빈 budget** — 모든 0/N → 정상 출력
2. **80% 일일 사용** — `/pair` 4회 today → ⚠ 표시
3. **100% 일일 사용** — `/retrospective` 1회 today → ⚠⚠ 표시
4. **`/budget set pair 10 30`** — `.claude/budget.json` 갱신 검증
5. **JSON 출력** — `/budget --json` → 유효 JSON

### 추이 sparkline

지난 7일 일별 카운트를 sparkline 문자(`░▁▂▃▄▅▆▇█`)로 변환:

```bash
sparkline() {
  local counts="$1"  # 공백 구분 7개 정수
  local max=$(echo "$counts" | tr ' ' '\n' | sort -n | tail -1)
  [ "$max" -eq 0 ] && { echo "░░░░░░░"; return; }
  local chars=("░" "▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")
  local out=""
  for n in $counts; do
    idx=$((n * 8 / max))
    [ "$idx" -gt 8 ] && idx=8
    out+="${chars[$idx]}"
  done
  echo "$out"
}
```

추이 추세: 첫 3일 평균 vs 마지막 3일 평균 비교 → `↗ 증가` / `↘ 감소` / `→ 평탄` 라벨.

## 데이터 흐름

```
사용자 행동 (/pair, /discuss, ...)
   │
   ▼
events.jsonl에 type 발생 (이미 구현됨)
   │
   ▼
사용자: /budget
   │
   ├─ jq aggregation (today + 7일)
   ├─ budget.json 한도와 비교
   ├─ 사용량 + sparkline + 추세 출력
   └─ events.jsonl에 budget event append

(별도 흐름)
사용자 idle (Notification trigger)
   │
   ▼
budget-warn.sh
   ├─ 디바운스 체크 (15분)
   ├─ 80%+ 스킬 검출
   └─ additionalContext로 비차단 경고
```

## 의존

- **Core**: events.jsonl
- **외부**: jq + date + bc (POSIX)
- **Hook**: 신규 budget-warn.sh (Notification 영역)

## /onboard, /menu, /inbox와의 관계

| | /onboard | /menu | /inbox | /budget |
|---|----------|-------|--------|---------|
| 영역 | 학습 경로 | 도구 카탈로그 | 메시지 큐 | 비용 인지 |
| 데이터 | events + state | events + state | messages | events + budget.json |
| 차단 | X | X | X | X (정보만) |
| Hook 통합 | X | X | X | budget-warn (Notification) |

4개 모두 메타 카테고리. 데이터 다른 영역 + 모두 비차단.

## YAGNI 제외

- **token 정확 비용** — 추정 불가, 외부 console 영역
- **block 모드** — 부정확 카운트로 차단 부적절
- **alerting/email** — Notification hook은 ChatGPT 응답 영역만
- **다국어** — 한국어/이모지 혼합
- **PDF/CSV export** — 사용 사례 없음 (로그 파일 직접 가능)
- **historical compare** — Phase 4 telemetry 영역
