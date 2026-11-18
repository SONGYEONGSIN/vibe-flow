---
name: onboard
description: 사용자 단계 자가진단 + 다음 행동 추천. 신규(Stage 0)~자가 진화(Stage 4) 5단계 자동 분류. 데이터 우선 (.claude/events.jsonl + .vibe-flow.json + memory/), 부족 시 자가보고 폴백. 24h cache.
model: claude-sonnet-4-6
---

# /onboard

vibe-flow 사용자 단계를 자동 진단하고 단계별 다음 행동을 추천한다.

## 트리거

- 사용자: `/onboard` (24h cache 활용) 또는 `/onboard --refresh` (강제 재진단)

## 절차

### 1. Cache check

```bash
STATE_FILE=".claude/memory/onboard-state.json"
if [ -f "$STATE_FILE" ] && [ "$1" != "--refresh" ]; then
  LAST_TS=$(jq -r '.last_diagnosed_at // ""' "$STATE_FILE" 2>/dev/null)
  if [ -n "$LAST_TS" ]; then
    NOW=$(date -u +%s)
    LAST=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_TS" +%s 2>/dev/null || echo 0)
    AGE=$((NOW - LAST))
    if [ "$AGE" -lt 86400 ]; then
      cat "$STATE_FILE" | jq -r '"📍 현재 단계: Stage \(.stage) — \(.stage_name)\n   근거: \(.evidence | tostring)\n\n🎯 지금: \(.recommendations.now | join(", "))\n📅 이번 주: \(.recommendations.this_week | join(", "))\n📆 다음 단계: \(.recommendations.next_stage)\n\n(24h 이내 진단 결과 — --refresh로 강제 재진단)"'
      exit 0
    fi
  fi
fi
```

### 2. 진단 시그널 수집

```bash
# 시그널 1: state file
HAS_STATE=false
EXT_COUNT=0
EXT_LIST="[]"
if [ -f ".claude/.vibe-flow.json" ]; then
  HAS_STATE=true
  EXT_COUNT=$(jq '.extensions | length' .claude/.vibe-flow.json 2>/dev/null || echo 0)
  EXT_LIST=$(jq -c '.extensions | keys' .claude/.vibe-flow.json 2>/dev/null || echo '[]')
fi

# 시그널 2: events.jsonl
EVENTS_COUNT=0
SKILLS_USED=""
if [ -f ".claude/events.jsonl" ]; then
  EVENTS_COUNT=$(wc -l < .claude/events.jsonl | tr -d ' ')
  SKILLS_USED=$(jq -r '.type // empty' .claude/events.jsonl 2>/dev/null | sort -u)
fi

# 시그널 3: memory 흔적
HAS_IMPROVEMENTS=false
HAS_PATTERNS=false
[ -f ".claude/memory/improvements.md" ] && HAS_IMPROVEMENTS=true
[ -f ".claude/memory/patterns.md" ] && HAS_PATTERNS=true

# 시그널 4: store.db (선택, 가용 시)
COMMIT_COUNT=0
if [ -f ".claude/store.db" ] && command -v node &>/dev/null && [ -d ".claude/scripts/node_modules" ]; then
  COMMIT_COUNT=$(node -e "
    try {
      const db = require('better-sqlite3')('.claude/store.db');
      const r = db.prepare(\"SELECT COUNT(*) as c FROM events WHERE type='commit_created'\").get();
      console.log(r.c);
    } catch(e) { console.log(0); }
  " 2>/dev/null || echo 0)
fi

# Core skill 사용 카운트 (events 타입 매칭)
CORE_SKILL_TYPES="brainstorm plan finish release scaffold test worktree verify security commit review_pr review_received status learn"
CORE_USED=0
for t in $CORE_SKILL_TYPES; do
  if echo "$SKILLS_USED" | grep -qw "$t"; then
    CORE_USED=$((CORE_USED + 1))
  fi
done
```

### 3. Stage 결정

```bash
# 데이터 부족 → 자가보고 트리거
if [ "$HAS_STATE" = "false" ] && [ "$EVENTS_COUNT" -lt 10 ]; then
  # 자가보고 모드 (Claude가 "자가보고 폴백 질문" 섹션 따라 진행)
  # 폴백 응답 매핑 (자가보고 폴백 질문 섹션 참조):
  #   Q1=1 → Stage 0
  #   Q1=2 + Q2=1~2 → Stage 1
  #   Q1=3 + Q2=3 → Stage 2
  #   Q1=4 + Q2=4 → Stage 3 또는 4
  STAGE=0
  STAGE_NAME="신규"
else
  # 데이터 기반 분류
  if [ "$EXT_COUNT" -ge 1 ] && (echo "$SKILLS_USED" | grep -qE "^eval$|^retrospective$"); then
    STAGE=4
    STAGE_NAME="자가 진화"
  elif [ "$EVENTS_COUNT" -ge 200 ] && [ "$CORE_USED" -ge 10 ]; then
    STAGE=3
    STAGE_NAME="확장 후보"
  elif [ "$HAS_IMPROVEMENTS" = "true" ]; then
    STAGE=3
    STAGE_NAME="확장 후보"
  elif [ "$EVENTS_COUNT" -ge 50 ] && [ "$CORE_USED" -ge 6 ]; then
    STAGE=2
    STAGE_NAME="핵심 익숙"
  elif [ "$EVENTS_COUNT" -ge 1 ] && [ "$CORE_USED" -ge 1 ]; then
    STAGE=1
    STAGE_NAME="입문"
  else
    STAGE=0
    STAGE_NAME="신규"
  fi
fi
```

### 4. Stage별 추천 매핑

```bash
case "$STAGE" in
  0)
    NOW='["/brainstorm \"<주제>\""]'
    THIS_WEEK='["/commit", "/verify"]'
    NEXT='Stage 1 입문 (events 50+ 누적 시 자동)'
    ;;
  1)
    NOW='["/commit", "/verify"]'
    THIS_WEEK='["/finish", "/status"]'
    NEXT='Stage 2 핵심 익숙 (Core 6 사용 시)'
    ;;
  2)
    NOW='["/test", "/security"]'
    THIS_WEEK='["/scaffold", "/worktree"]'
    NEXT='Stage 3 확장 후보 (events 200+ 또는 첫 retrospective)'
    ;;
  3)
    NOW='["bash setup.sh --extensions learning-loop"]'
    THIS_WEEK='["/retrospective"]'
    NEXT='Stage 4 자가 진화 (extensions + /eval/retrospective 사용)'
    ;;
  4)
    NOW='["bash setup.sh --extensions meta-quality (없으면)", "/eval <skill>"]'
    THIS_WEEK='["/evolve <skill> 1회 시도"]'
    NEXT='(최종) — 메이커 활동'
    ;;
esac
```

### 5. 출력

```bash
EVIDENCE_JSON=$(jq -n \
  --argjson e "$EVENTS_COUNT" \
  --argjson c "$CORE_USED" \
  --argjson x "$EXT_LIST" \
  '{events_count: $e, core_skills_used: $c, extensions_active: $x}')

cat <<EOF
📍 현재 단계: Stage $STAGE — $STAGE_NAME
   근거: $EVENTS_COUNT events / Core 스킬 $CORE_USED종 / extensions: $EXT_LIST

🎯 지금 (오늘~3일): $(echo "$NOW" | jq -r 'join(", ")')
📅 이번 주: $(echo "$THIS_WEEK" | jq -r 'join(", ")')
📆 다음 단계: $NEXT
EOF
```

### 6. State 저장 + event append

```bash
NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
mkdir -p .claude/memory
jq -n \
  --arg ts "$NOW_ISO" \
  --argjson stage "$STAGE" \
  --arg name "$STAGE_NAME" \
  --argjson evidence "$EVIDENCE_JSON" \
  --argjson now "$NOW" \
  --argjson week "$THIS_WEEK" \
  --arg next "$NEXT" \
  '{
    last_diagnosed_at: $ts,
    stage: $stage,
    stage_name: $name,
    evidence: $evidence,
    recommendations: {
      now: $now,
      this_week: $week,
      next_stage: $next
    }
  }' > .claude/memory/onboard-state.json

# events.jsonl append
REFRESH_FLAG="false"
[ "$1" = "--refresh" ] && REFRESH_FLAG="true"
jq -nc \
  --arg ts "$NOW_ISO" \
  --argjson stage "$STAGE" \
  --argjson refresh "$REFRESH_FLAG" \
  '{type: "onboard", ts: $ts, stage: $stage, refresh: $refresh}' \
  >> .claude/events.jsonl
```

## 자가보고 폴백 질문

데이터 부족 시 (`HAS_STATE=false && EVENTS_COUNT<10`) Claude가 다음 3 질문을 순차 제시:

```
Q1. vibe-flow 며칠 썼어요?
  1) 처음
  2) 1주 미만
  3) 1주~1개월
  4) 1개월+

Q2. 주로 쓰는 스킬은?
  1) 모름
  2) 1~2개 (commit, verify)
  3) Core 6개+
  4) extensions까지

Q3. (선택) 다음 배우고 싶은 영역?
  1) 기본 사이클
  2) 협업 (pair, discuss)
  3) 디자인 (design-sync, design-audit)
  4) 메트릭/회고 (metrics, retrospective)
  5) 자가 진화 (eval, evolve)
```

응답 매핑:
- Q1=1 → Stage 0
- Q1=2 + Q2=1~2 → Stage 1
- Q1=3 + Q2=3 → Stage 2
- Q1=4 + Q2=4 → Stage 3 또는 4
- Q3는 추천 가중치 조정용 (해당 영역 스킬 우선 추천)

## 출처

Phase 2 ROADMAP 첫 항목. spec: `docs/superpowers/specs/2026-04-30-onboard-skill-design.md`.
