# /onboard 스킬 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Phase 2 첫 항목 — `/onboard` 스킬 신설 (5단계 자가진단 + 데이터 우선 / 자가보고 폴백 / 24h cache + 단계별 추천).

**Architecture:** SKILL.md 단일 파일 + evals.json 단일 파일. SKILL.md 안에 jq aggregation 명령 / Stage 분류 / 출력 템플릿 / cache 로직 모두 포함. 별도 스크립트 없음. setup.sh는 디렉토리만 있으면 자동 복사.

**Tech Stack:** bash, jq (필수 의존), node (선택, store.db 폴백 시)

**Spec 참조:** `docs/superpowers/specs/2026-04-30-onboard-skill-design.md` (commit 8d16220)

---

## Pre-execution Notes

- 작업 디렉토리: `/Users/yss/개발/build/vibe-flow`
- 현재 main 브랜치 working tree clean에서 시작
- feature branch: `feat/onboard-skill`
- Big Bang 정책: 단일 PR. atomic commits 분리.

---

## Task 1: feature branch 생성 + 디렉토리 scaffold

**Files:**
- Create: `core/skills/onboard/` (디렉토리)
- Create: `core/skills/onboard/evals/` (디렉토리)

- [ ] **Step 1: 현재 상태 확인**

```bash
cd /Users/yss/개발/build/vibe-flow
git status
git log --oneline -3
git branch
```

Expected:
- Branch: `main`
- Working tree clean
- 마지막 commit: `8d16220 docs(spec): /onboard 스킬 설계 — Phase 2 첫 항목`

- [ ] **Step 2: feature branch 생성**

```bash
git checkout -b feat/onboard-skill
```

Expected: `Switched to a new branch 'feat/onboard-skill'`

- [ ] **Step 3: 디렉토리 생성**

```bash
mkdir -p core/skills/onboard/evals
ls -d core/skills/onboard core/skills/onboard/evals
```

Expected: 두 디렉토리 모두 출력.

- [ ] **Step 4: 검증 — Core 스킬 카운트 확인**

```bash
ls core/skills/ | wc -l | tr -d ' '
```

Expected: `15` (기존 14 + 1 새 디렉토리. 단, SKILL.md 없으니 setup.sh가 인식 안 할 수 있음 — 다음 task에서 채움)

---

## Task 2: SKILL.md 작성

**Files:**
- Create: `core/skills/onboard/SKILL.md`

- [ ] **Step 1: SKILL.md 작성**

```bash
cat > core/skills/onboard/SKILL.md <<'SKILLEOF'
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
      cat "$STATE_FILE" | jq -r '"📍 현재 단계: Stage \(.stage) — \(.stage_name)\n   근거: \(.evidence | tostring)\n\n🎯 지금: \(.recommendations.now | join(", "))\n📅 이번 주: \(.recommendations.this_week | join(", "))\n📆 다음 단계: \(.recommendations.next_stage)\n\n(2시간 전 진단 결과 — --refresh로 강제 재진단)"'
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
  # Core skill 발생 분포 (type 또는 skill 필드 기준)
  SKILLS_USED=$(jq -r '.type // empty' .claude/events.jsonl 2>/dev/null | sort -u)
fi

# 시그널 3: memory 흔적
HAS_IMPROVEMENTS=false
HAS_PATTERNS=false
[ -f ".claude/memory/improvements.md" ] && HAS_IMPROVEMENTS=true
[ -f ".claude/memory/patterns.md" ] && HAS_PATTERNS=true

# 시그널 4: store.db (선택, 가용 시)
COMMIT_COUNT=0
VERIFY_COUNT=0
if [ -f ".claude/store.db" ] && command -v node &>/dev/null && [ -d ".claude/scripts/node_modules" ]; then
  COMMIT_COUNT=$(node -e "
    try {
      const db = require('better-sqlite3')('.claude/store.db');
      const r = db.prepare(\"SELECT COUNT(*) as c FROM events WHERE type='commit_created'\").get();
      console.log(r.c);
    } catch(e) { console.log(0); }
  " 2>/dev/null || echo 0)
fi

# Core skill 사용 카운트 (events 타입에서 시작 부분 매칭)
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
  echo "데이터가 부족합니다. 3 질문드릴게요."
  # 자가보고 모드 — 사용자 응답 받아서 STAGE 결정
  # (실제 대화는 Claude가 진행. 다음 절차로 이어감)
  # 사용자 응답 매핑:
  #   "처음" → Stage 0
  #   "1주 미만" + "1~2 스킬" → Stage 1
  #   "1주~1개월" + "Core 6+" → Stage 2
  #   "1개월+" + "extensions까지" → Stage 3 또는 4
  STAGE=0  # 폴백 기본
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
SKILLEOF
```

- [ ] **Step 2: 검증 — frontmatter + 라인 수**

```bash
head -5 core/skills/onboard/SKILL.md
wc -l core/skills/onboard/SKILL.md
```

Expected:
- 처음 5줄: `---` + `name: onboard` + `description: ...` + `model: ...` + `---`
- 라인 수: 약 180-200줄

- [ ] **Step 3: 임시 commit**

```bash
git add core/skills/onboard/SKILL.md
git commit -m "feat(onboard): SKILL.md — 5단계 자가진단 + jq 시그널 수집 + 추천 매핑

cache check / state·events·memory·store.db 시그널 / Stage 0~4 분류 /
Stage별 추천 / 출력 / state 저장 + event append.
자가보고 폴백 3 질문 정의."
```

---

## Task 3: evals.json 작성

**Files:**
- Create: `core/skills/onboard/evals/evals.json`

- [ ] **Step 1: 5 evaluation 케이스 작성**

```bash
cat > core/skills/onboard/evals/evals.json <<'EVALEOF'
{
  "skill": "onboard",
  "version": "1.0.0",
  "cases": [
    {
      "id": "stage-0-new-user",
      "description": "신규 사용자 — state 없음, events 0건",
      "setup": {
        "files": {
          ".claude/.vibe-flow.json": null,
          ".claude/events.jsonl": null
        }
      },
      "input": "/onboard",
      "expected": {
        "stage": 0,
        "stage_name": "신규",
        "fallback_triggered": true,
        "recommends": ["/brainstorm"]
      }
    },
    {
      "id": "stage-1-beginner",
      "description": "입문 — events 30건, Core 4 스킬 사용",
      "setup": {
        "files": {
          ".claude/.vibe-flow.json": "{\"vibe_flow_version\":\"1.1.0\",\"installed_at\":\"2026-04-25T00:00:00Z\",\"extensions\":{}}",
          ".claude/events.jsonl_lines": 30,
          ".claude/events_skill_types": ["brainstorm", "commit", "verify", "status"]
        }
      },
      "input": "/onboard",
      "expected": {
        "stage": 1,
        "stage_name": "입문",
        "recommends_now": ["/commit", "/verify"],
        "recommends_week": ["/finish", "/status"]
      }
    },
    {
      "id": "stage-2-routine",
      "description": "핵심 익숙 — events 137건, Core 8 스킬",
      "setup": {
        "files": {
          ".claude/.vibe-flow.json": "{\"vibe_flow_version\":\"1.1.0\",\"installed_at\":\"2026-04-01T00:00:00Z\",\"extensions\":{}}",
          ".claude/events.jsonl_lines": 137,
          ".claude/events_skill_types": ["brainstorm", "plan", "commit", "verify", "test", "status", "learn", "finish"]
        }
      },
      "input": "/onboard",
      "expected": {
        "stage": 2,
        "stage_name": "핵심 익숙",
        "recommends_now": ["/test", "/security"],
        "recommends_week": ["/scaffold", "/worktree"]
      }
    },
    {
      "id": "stage-3-extension-candidate",
      "description": "확장 후보 — events 250건, Core 12 스킬, improvements.md 존재",
      "setup": {
        "files": {
          ".claude/.vibe-flow.json": "{\"vibe_flow_version\":\"1.1.0\",\"installed_at\":\"2026-03-15T00:00:00Z\",\"extensions\":{}}",
          ".claude/events.jsonl_lines": 250,
          ".claude/events_skill_types": ["brainstorm", "plan", "finish", "release", "scaffold", "test", "worktree", "verify", "security", "commit", "review_pr", "status"],
          ".claude/memory/improvements.md": "exists"
        }
      },
      "input": "/onboard",
      "expected": {
        "stage": 3,
        "stage_name": "확장 후보",
        "recommends_now_contains": "learning-loop"
      }
    },
    {
      "id": "stage-4-self-evolving",
      "description": "자가 진화 — meta-quality 활성 + /eval 사용 events",
      "setup": {
        "files": {
          ".claude/.vibe-flow.json": "{\"vibe_flow_version\":\"1.1.0\",\"installed_at\":\"2026-02-01T00:00:00Z\",\"extensions\":{\"meta-quality\":{\"version\":\"1.0.0\",\"installed_at\":\"2026-04-15T00:00:00Z\",\"files\":[]}}}",
          ".claude/events.jsonl_lines": 300,
          ".claude/events_skill_types": ["brainstorm", "commit", "verify", "test", "eval", "retrospective"]
        }
      },
      "input": "/onboard",
      "expected": {
        "stage": 4,
        "stage_name": "자가 진화",
        "recommends_now_contains": "/eval",
        "recommends_week_contains": "/evolve"
      }
    },
    {
      "id": "cache-hit",
      "description": "Cache hit — 1시간 전 진단된 onboard-state.json 존재",
      "setup": {
        "files": {
          ".claude/memory/onboard-state.json": "{\"last_diagnosed_at\":\"<1시간 전 ISO>\",\"stage\":2,\"stage_name\":\"핵심 익숙\",\"recommendations\":{\"now\":[\"/test\"],\"this_week\":[\"/scaffold\"],\"next_stage\":\"Stage 3\"}}"
        }
      },
      "input": "/onboard",
      "expected": {
        "stage": 2,
        "cache_hit": true,
        "cache_message_contains": "강제 재진단"
      }
    },
    {
      "id": "refresh-bypasses-cache",
      "description": "--refresh로 cache 무효화",
      "setup": {
        "files": {
          ".claude/memory/onboard-state.json": "{\"last_diagnosed_at\":\"<1시간 전\",\"stage\":2}"
        }
      },
      "input": "/onboard --refresh",
      "expected": {
        "cache_hit": false,
        "rediagnosed": true
      }
    }
  ]
}
EVALEOF
```

- [ ] **Step 2: JSON 유효성 검증**

```bash
jq empty core/skills/onboard/evals/evals.json && echo "✓ valid JSON"
jq '.cases | length' core/skills/onboard/evals/evals.json
```

Expected: `✓ valid JSON` + `7`

- [ ] **Step 3: 임시 commit**

```bash
git add core/skills/onboard/evals/evals.json
git commit -m "test(onboard): evals.json 7 케이스 — Stage 0~4 + cache hit/refresh"
```

---

## Task 4: setup.sh 자동 인식 검증 (수정 불필요 확인)

**Files:** None (테스트만)

setup.sh의 Skills 복사 루프(`for skill_dir in "$SCRIPT_DIR/core/skills"/*/`)는 디렉토리 자동 감지. SKILL.md 있는 새 디렉토리는 자동 포함.

- [ ] **Step 1: 임시 디렉토리에 setup**

```bash
rm -rf /tmp/vf-onboard-test && mkdir /tmp/vf-onboard-test && cd /tmp/vf-onboard-test
bash /Users/yss/개발/build/vibe-flow/setup.sh 2>&1 | tail -10
```

- [ ] **Step 2: Core 스킬 카운트 확인**

```bash
ls .claude/skills/ | wc -l | tr -d ' '
[ -d .claude/skills/onboard ] && echo "✓ onboard 설치됨"
[ -f .claude/skills/onboard/SKILL.md ] && echo "✓ SKILL.md 존재"
[ -f .claude/skills/onboard/evals/evals.json ] && echo "✓ evals.json 존재"
```

Expected:
- skills 카운트: `15` (Core 14 + onboard)
- 모든 ✓ 출력

- [ ] **Step 3: 작업 디렉토리 복귀**

```bash
cd /Users/yss/개발/build/vibe-flow
```

---

## Task 5: 기존 docs / README 갱신

**Files:**
- Modify: `README.md` (Core 14 → 15, onboard 추가)
- Modify: `docs/REFERENCE.md` (Core 14 → 15, /onboard 행 추가)
- Modify: `CHANGELOG.md` ([Unreleased] 섹션에 /onboard 항목)

- [ ] **Step 1: README.md 갱신 — Core 표에 onboard 추가**

기존 README.md의 Core 14 섹션:
```markdown
## 📦 Core 14 — 기본 설치

| 카테고리 | 스킬 |
|---------|------|
| 사이클 | `/brainstorm` `/plan` `/finish` `/release` |
...
| 메타 | `/status` `/learn` |
```

`메타` 행을 다음으로 교체:
```markdown
| 메타 | `/status` `/learn` `/onboard` |
```

또한 헤더의 "Core 14" 표기를 "Core 15"로 + "→ Core 14 스킬 + 22 훅" 도 "Core 15 스킬 + 22 훅"으로 변경 (3 곳).

- [ ] **Step 2: docs/REFERENCE.md 갱신**

기존 `## Skills (23 — Core 14 + Extensions 9)` → `## Skills (24 — Core 15 + Extensions 9)`.
기존 `### Core 14` → `### Core 15`.
Core 14 표 마지막 행(`learn`) 다음에 추가:
```markdown
| onboard | `/onboard [--refresh]` | 5단계 자가진단 + 다음 행동 추천 |
```

- [ ] **Step 3: CHANGELOG.md [Unreleased] 섹션 추가**

```markdown
## [Unreleased]

### 추가
- **`/onboard` 스킬** — Phase 2 첫 항목. 사용자 단계 자가진단(Stage 0 신규 ~ Stage 4 자가 진화) + 단계별 다음 행동 추천. 데이터 우선 (events.jsonl + .vibe-flow.json + memory/), 부족 시 자가보고 3 질문 폴백. 24h cache (--refresh로 무효화). docs/ONBOARDING.md(정적)를 보완하는 daily 인터랙티브 도구.
```

- [ ] **Step 4: 검증**

```bash
grep -c "/onboard" README.md docs/REFERENCE.md CHANGELOG.md
grep "Core 15" README.md docs/REFERENCE.md
```

Expected:
- 각 파일에 1회 이상 출현
- "Core 15" 출현 (README + REFERENCE)

- [ ] **Step 5: 임시 commit**

```bash
git add README.md docs/REFERENCE.md CHANGELOG.md
git commit -m "docs: /onboard 스킬을 README/REFERENCE/CHANGELOG에 추가

Core 14 → 15. /onboard는 메타 카테고리 (status, learn과 같은 그룹)."
```

---

## Task 6: validate.sh 카운트 갱신 검토

**Files:**
- Modify (옵션): `validate.sh` (Core skill 카운트 명시 부분 있으면)

- [ ] **Step 1: validate.sh에 Core 스킬 카운트 하드코딩 여부 확인**

```bash
grep -nE "Core (14|15)|14.*skill|15.*skill" validate.sh
```

만약 출력 있으면 14 → 15로 갱신. 없으면 skip.

- [ ] **Step 2: 통합 재검증**

```bash
cd /tmp/vf-onboard-test
bash /Users/yss/개발/build/vibe-flow/validate.sh 2>&1 | tail -10
cd /Users/yss/개발/build/vibe-flow
```

Expected: PASS / WARN만 (FAIL 없어야).

- [ ] **Step 3: 변경 있으면 commit**

```bash
[ -n "$(git status --porcelain validate.sh)" ] && {
  git add validate.sh
  git commit -m "chore(validate): Core 스킬 카운트 14 → 15 (onboard 추가 반영)"
}
```

---

## Task 7: PR 생성 + 머지

**Files:** None (git operations)

- [ ] **Step 1: 모든 commit 확인**

```bash
git log --oneline main..HEAD
```

Expected: 4-5 commits (디렉토리 + SKILL.md + evals + docs + 선택적 validate).

- [ ] **Step 2: branch push**

```bash
git push -u origin feat/onboard-skill
```

- [ ] **Step 3: PR 생성**

```bash
gh pr create --title "feat(onboard): /onboard 스킬 — 5단계 자가진단 + 단계별 추천" --body "$(cat <<'PRBODY'
## Summary

Phase 2 ROADMAP 첫 항목. 사용자 단계를 자동 진단하고 다음 행동을 추천하는 인터랙티브 스킬.

- 5단계 분류 (Stage 0 신규 ~ Stage 4 자가 진화)
- 데이터 우선 진단 (events.jsonl / .vibe-flow.json / memory / store.db)
- 데이터 부족 시 자가보고 3 질문 폴백
- 24h cache (--refresh로 무효화)
- 단계별 "지금 / 이번 주 / 다음 단계" 추천

## 입력 spec

[docs/superpowers/specs/2026-04-30-onboard-skill-design.md](docs/superpowers/specs/2026-04-30-onboard-skill-design.md) (commit 8d16220)

## Test plan

- [x] 임시 디렉토리 setup → `core/skills/onboard/SKILL.md` 자동 복사
- [x] Skills 카운트: 14 → 15
- [x] evals.json 7 케이스 (Stage 0~4 + cache hit + refresh)
- [x] validate.sh PASS

## 변경 안 됨

- Core / Extensions / setup.sh 옵션 / state schema 그대로
- `docs/ONBOARDING.md` 그대로 (보완 관계)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
PRBODY
)"
```

- [ ] **Step 4: PR URL 확인**

```bash
gh pr view --json url --jq '.url'
```

- [ ] **Step 5: Squash 머지 + branch 정리**

```bash
PR_NUM=$(gh pr view --json number --jq '.number')
gh pr merge $PR_NUM --squash --delete-branch
git checkout main
git fetch origin
git reset --hard origin/main
git branch -D feat/onboard-skill 2>/dev/null || true
git fetch --prune
```

Expected: main이 squash 머지된 새 commit으로 갱신, feature branch 정리.

- [ ] **Step 6: ROADMAP.md 갱신 (다음 plan에서 처리 가능)**

ROADMAP.md `Phase 2 / 신규 스킬` 섹션의 `[ ] /onboard` → `[x] /onboard`.
이 갱신은 본 plan 범위 밖 — 다음 작업 시작 시 함께 처리.

---

## Self-Review Checklist

(작성자가 plan 완료 후 자체 점검)

- [ ] **Spec coverage**: spec의 모든 섹션이 적어도 1 task에 매핑되는가?
  - 입력/cache → Task 2 step 1 (Cache check), Task 3 (eval cases 6-7)
  - 단계 분류 5단계 → Task 2 step 3, Task 3 (eval cases 1-5)
  - 진단 시그널 우선순위 → Task 2 step 2
  - 자가보고 폴백 → Task 2 (자가보고 폴백 섹션)
  - 출력 포맷 → Task 2 step 5
  - Stage별 추천 매핑 → Task 2 step 4, Task 3
  - 상태 저장 → Task 2 step 6
  - Events 발생 → Task 2 step 6
  - Evals → Task 3
  - SKILL.md 구조 → Task 2

- [ ] **Placeholder scan**: TBD/TODO/FIXME 없음
- [ ] **Type consistency**: stage 명칭 ("신규/입문/핵심 익숙/확장 후보/자가 진화") 모든 task에서 동일
- [ ] **Path consistency**: `core/skills/onboard/` 모든 task 동일
