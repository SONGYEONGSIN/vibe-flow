# /menu 스킬 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Phase 2 두 번째 항목 — `/menu` 스킬 신설 (24 스킬 카테고리별 발견성 + 사용 분포 + Stage별 추천 강조).

**Architecture:** SKILL.md 단일 파일 + evals.json. 시그널: state + onboard-state + events.jsonl. jq aggregation 1패스. setup.sh는 디렉토리 자동 인식.

**Tech Stack:** bash, jq (필수)

**Spec 참조:** `docs/superpowers/specs/2026-04-30-menu-skill-design.md` (commit eba7685)

---

## Task 1: feature branch + 디렉토리 scaffold

**Files:**
- Create: `core/skills/menu/` (디렉토리)
- Create: `core/skills/menu/evals/` (디렉토리)

- [ ] **Step 1: 현재 상태 확인**

```bash
cd /Users/yss/개발/build/vibe-flow
git status
git log --oneline -3
```

Expected: branch `main`, working tree clean, 마지막 commit `eba7685 docs(spec): /menu 스킬 설계`.

- [ ] **Step 2: feature branch 생성**

```bash
git checkout -b feat/menu-skill
```

- [ ] **Step 3: 디렉토리 생성**

```bash
mkdir -p core/skills/menu/evals
```

---

## Task 2: SKILL.md 작성

**Files:**
- Create: `core/skills/menu/SKILL.md`

- [ ] **Step 1: SKILL.md 작성**

```bash
cat > core/skills/menu/SKILL.md <<'SKILLEOF'
---
name: menu
description: 24 스킬 카테고리별 발견성 + 사용 분포 + Stage별 추천 강조. /menu, /menu core, /menu extensions, /menu <category>.
model: claude-sonnet-4-6
---

# /menu

vibe-flow 24 스킬을 카테고리별로 보여주고 사용 분포 + Stage 추천을 함께 출력한다.

## 트리거

- 사용자: `/menu`, `/menu core`, `/menu extensions`, `/menu <category>` (사이클|작업|검증|git|메타|meta-quality|design-system|deep-collaboration|learning-loop|code-feedback)

## 절차

### 1. 활성 extensions + Stage 조회

```bash
ACTIVE_EXTS="[]"
EXT_COUNT=0
if [ -f ".claude/.vibe-flow.json" ]; then
  ACTIVE_EXTS=$(jq -c '.extensions | keys' .claude/.vibe-flow.json 2>/dev/null || echo '[]')
  EXT_COUNT=$(jq '.extensions | length' .claude/.vibe-flow.json 2>/dev/null || echo 0)
fi

STAGE=""
STAGE_NAME=""
if [ -f ".claude/memory/onboard-state.json" ]; then
  STAGE=$(jq -r '.stage // ""' .claude/memory/onboard-state.json 2>/dev/null)
  STAGE_NAME=$(jq -r '.stage_name // ""' .claude/memory/onboard-state.json 2>/dev/null)
fi
```

### 2. 스킬별 사용 횟수 (events.jsonl 1패스 aggregation)

```bash
declare -A USAGE
if [ -f ".claude/events.jsonl" ]; then
  while IFS=$'\t' read -r type count; do
    USAGE["$type"]=$count
  done < <(jq -r '.type // empty' .claude/events.jsonl 2>/dev/null | sort | uniq -c | awk '{print $2"\t"$1}')
fi

# 사용 분포 라벨 함수
usage_label() {
  local n=${USAGE[$1]:-0}
  if [ "$n" -ge 6 ]; then echo "✓ 자주 사용"
  elif [ "$n" -ge 1 ]; then echo "· 가끔"
  else echo "· 미사용"
  fi
}
```

### 3. Stage별 추천 매핑

```bash
# Stage별 추천 스킬 (⚡ 표시 대상)
RECOMMEND=""
case "$STAGE" in
  0) RECOMMEND="brainstorm" ;;
  1) RECOMMEND="commit verify" ;;
  2) RECOMMEND="test security scaffold" ;;
  3) RECOMMEND="retrospective" ;;
  4) RECOMMEND="eval evolve" ;;
esac

is_recommended() {
  echo "$RECOMMEND" | grep -qw "$1" && echo " ⚡추천" || echo ""
}
```

### 4. 카테고리 정의 + 출력 함수

```bash
# Core 카테고리 (5)
print_core_category() {
  case "$1" in
    "사이클")
      echo "🔄 사이클 (4)"
      print_skill brainstorm "/brainstorm \"<주제>\"" "의도/제약/대안 탐색"
      print_skill plan "/plan" "멀티스텝 계획 추적"
      print_skill finish "/finish" "머지/PR/cleanup 결정"
      print_skill release "/release [version]" "semver + CHANGELOG"
      ;;
    "작업")
      echo "🛠 작업 (3)"
      print_skill scaffold "/scaffold [domain]" "보일러플레이트 생성"
      print_skill test "/test [file]" "Vitest 테스트 자동 생성"
      print_skill worktree "/worktree [...]" "git worktree 격리"
      ;;
    "검증")
      echo "✅ 검증 (2)"
      print_skill verify "/verify" "lint+tsc+test+e2e"
      print_skill security "/security" "OWASP Top 10"
      ;;
    "git")
      echo "🔀 Git (3)"
      print_skill commit "/commit" "Conventional commit"
      print_skill review_pr "/review-pr [N]" "GitHub PR 리뷰"
      print_skill review_received "/receive-review" "리뷰 비판적 수용"
      ;;
    "메타")
      echo "🎯 메타 (3)"
      print_skill status "/status" "프로젝트 상태"
      print_skill learn "/learn [save|show]" "메모리 관리"
      print_skill onboard "/onboard [--refresh]" "단계 진단 + 추천"
      ;;
  esac
  echo ""
}

# 단일 스킬 행 출력
print_skill() {
  local skill="$1"
  local cmd="$2"
  local desc="$3"
  printf "  %-30s %-30s %s%s\n" "$cmd" "$desc" "$(usage_label "$skill")" "$(is_recommended "$skill")"
}

# Extension 카테고리 (5)
print_ext_category() {
  local ext="$1"
  local active=""
  echo "$ACTIVE_EXTS" | jq -e --arg e "$ext" 'index($e)' >/dev/null 2>&1 && active="활성" || active="미설치"

  case "$ext" in
    "meta-quality")
      echo "💎 meta-quality ($active)"
      [ "$active" = "미설치" ] && echo "   bash setup.sh --extensions meta-quality"
      print_skill eval "/eval <skill>" "스킬 evals 실행 → pass rate"
      print_skill skill_evolve "/evolve <skill>" "스킬 자동 개선 후보"
      ;;
    "design-system")
      echo "🎨 design-system ($active)"
      [ "$active" = "미설치" ] && echo "   bash setup.sh --extensions design-system"
      print_skill design_sync "/design-sync <URL|이미지>" "참고 디자인 → 코드 매칭"
      print_skill design_audit "/design-audit" "토큰 커버리지 + 하드코딩 감사"
      ;;
    "deep-collaboration")
      echo "🤝 deep-collaboration ($active)"
      [ "$active" = "미설치" ] && echo "   bash setup.sh --extensions deep-collaboration"
      print_skill pair_session "/pair \"<task>\"" "Builder/Validator 페어"
      print_skill discuss "/discuss \"<주제>\"" "구조화된 토론"
      ;;
    "learning-loop")
      echo "📈 learning-loop ($active)"
      [ "$active" = "미설치" ] && echo "   bash setup.sh --extensions learning-loop"
      print_skill metrics "/metrics [today|week|all]" "메트릭 대시보드"
      print_skill retrospective "/retrospective" "회고 분석"
      ;;
    "code-feedback")
      echo "📝 code-feedback ($active)"
      [ "$active" = "미설치" ] && echo "   bash setup.sh --extensions code-feedback"
      print_skill feedback "/feedback" "git diff 품질 분석"
      ;;
  esac
  echo ""
}
```

### 5. 필터 처리 + 출력

```bash
FILTER="${1:-all}"

# 헤더
echo "📚 vibe-flow 24 스킬 (Core 15 + Extensions 9)"
if [ -n "$STAGE" ]; then
  echo "   현재 Stage: $STAGE — $STAGE_NAME"
fi
echo ""

# Core 출력
if [ "$FILTER" = "all" ] || [ "$FILTER" = "core" ]; then
  echo "━━━ Core ━━━"
  echo ""
  for cat in "사이클" "작업" "검증" "git" "메타"; do
    print_core_category "$cat"
  done
fi

# 단일 Core 카테고리 필터
case "$FILTER" in
  "사이클"|"작업"|"검증"|"git"|"메타")
    echo "📚 $FILTER 카테고리"
    echo ""
    print_core_category "$FILTER"
    ;;
esac

# Extensions 출력
if [ "$FILTER" = "all" ] || [ "$FILTER" = "extensions" ]; then
  echo "━━━ Extensions (활성: $EXT_COUNT) ━━━"
  echo ""
  for ext in "meta-quality" "design-system" "deep-collaboration" "learning-loop" "code-feedback"; do
    print_ext_category "$ext"
  done
fi

# 단일 Extension 카테고리 필터
case "$FILTER" in
  "meta-quality"|"design-system"|"deep-collaboration"|"learning-loop"|"code-feedback")
    echo "📚 $FILTER 카테고리"
    echo ""
    print_ext_category "$FILTER"
    ;;
esac

# 레전드
LEGEND_STAGE=""
[ -n "$STAGE" ] && LEGEND_STAGE=" / ⚡ Stage $STAGE 추천"
echo "(레전드: ✓ 자주 (6+회) / · 가끔(1-5회)/미사용(0회)$LEGEND_STAGE)"
```

### 6. Events 발생

```bash
NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
mkdir -p .claude
jq -nc \
  --arg ts "$NOW_ISO" \
  --arg filter "$FILTER" \
  '{type: "menu", ts: $ts, filter: $filter}' \
  >> .claude/events.jsonl
```

## 출처

Phase 2 ROADMAP 두 번째 항목. spec: `docs/superpowers/specs/2026-04-30-menu-skill-design.md`.
SKILLEOF
```

- [ ] **Step 2: 검증 — frontmatter + 라인 수**

```bash
head -5 core/skills/menu/SKILL.md
wc -l core/skills/menu/SKILL.md
```

Expected: 처음 5줄 frontmatter, 라인 수 약 200-220줄.

- [ ] **Step 3: 임시 commit**

```bash
git add core/skills/menu/SKILL.md
git commit -m "feat(menu): SKILL.md — 24 스킬 카테고리별 발견성 + 사용 분포 + Stage 추천

state + onboard-state + events.jsonl 시그널.
필터: core/extensions/<category>.
events.jsonl에 menu append."
```

---

## Task 3: evals.json 작성

**Files:**
- Create: `core/skills/menu/evals/evals.json`

- [ ] **Step 1: 5 evaluation 케이스 작성**

```bash
cat > core/skills/menu/evals/evals.json <<'EVALEOF'
{
  "skill": "menu",
  "version": "1.0.0",
  "cases": [
    {
      "id": "full-menu-with-stage",
      "description": "전체 출력 — 24 스킬 모두 + stage 라벨 + 추천 ⚡",
      "setup": {
        "files": {
          ".claude/.vibe-flow.json": "{\"vibe_flow_version\":\"1.1.0\",\"installed_at\":\"2026-04-01T00:00:00Z\",\"extensions\":{}}",
          ".claude/memory/onboard-state.json": "{\"stage\":2,\"stage_name\":\"핵심 익숙\"}",
          ".claude/events.jsonl_lines": 100,
          ".claude/events_skill_distribution": {"commit": 30, "verify": 25, "brainstorm": 10}
        }
      },
      "input": "/menu",
      "expected": {
        "contains_skills_count": 24,
        "shows_stage": "Stage 2 — 핵심 익숙",
        "shows_recommend_for": ["/test", "/security", "/scaffold"]
      }
    },
    {
      "id": "core-only",
      "description": "/menu core — Core 15만 출력, Extensions 섹션 없음",
      "setup": {
        "files": {
          ".claude/.vibe-flow.json": "{\"vibe_flow_version\":\"1.1.0\",\"installed_at\":\"2026-04-01T00:00:00Z\",\"extensions\":{}}"
        }
      },
      "input": "/menu core",
      "expected": {
        "contains_section": "━━━ Core ━━━",
        "missing_section": "━━━ Extensions ━━━",
        "skills_listed": 15
      }
    },
    {
      "id": "extensions-only",
      "description": "/menu extensions — Extensions 9만 출력",
      "setup": {
        "files": {
          ".claude/.vibe-flow.json": "{\"vibe_flow_version\":\"1.1.0\",\"installed_at\":\"2026-04-01T00:00:00Z\",\"extensions\":{\"meta-quality\":{\"version\":\"1.0.0\",\"installed_at\":\"2026-04-15T00:00:00Z\",\"files\":[]}}}"
        }
      },
      "input": "/menu extensions",
      "expected": {
        "contains_section": "━━━ Extensions",
        "missing_section": "━━━ Core ━━━",
        "shows_active": "meta-quality (활성)"
      }
    },
    {
      "id": "category-filter",
      "description": "/menu 사이클 — 사이클 4 스킬만",
      "setup": {
        "files": {}
      },
      "input": "/menu 사이클",
      "expected": {
        "skills_listed": 4,
        "skills_contain": ["/brainstorm", "/plan", "/finish", "/release"]
      }
    },
    {
      "id": "no-onboard-state-fallback",
      "description": "onboard-state 없음 — Stage 라벨 없이 단순 카탈로그",
      "setup": {
        "files": {
          ".claude/memory/onboard-state.json": null
        }
      },
      "input": "/menu",
      "expected": {
        "missing_text": "현재 Stage:",
        "missing_text_2": "⚡추천",
        "skills_listed": 24
      }
    }
  ]
}
EVALEOF
```

- [ ] **Step 2: JSON 유효성 검증**

```bash
jq empty core/skills/menu/evals/evals.json && echo "✓ valid JSON"
jq '.cases | length' core/skills/menu/evals/evals.json
```

Expected: `✓ valid JSON` + `5`

- [ ] **Step 3: 임시 commit**

```bash
git add core/skills/menu/evals/evals.json
git commit -m "test(menu): evals.json 5 케이스 — 전체/core/extensions/카테고리/폴백"
```

---

## Task 4: setup.sh 자동 인식 검증

**Files:** None

- [ ] **Step 1: 임시 setup**

```bash
rm -rf /tmp/vf-menu-test && mkdir /tmp/vf-menu-test && cd /tmp/vf-menu-test
bash /Users/yss/개발/build/vibe-flow/setup.sh > /tmp/vf-menu-setup.log 2>&1
```

- [ ] **Step 2: 검증**

```bash
echo "skills count: $(ls .claude/skills/ | wc -l | tr -d ' ')"
[ -f .claude/skills/menu/SKILL.md ] && echo "✓ menu/SKILL.md"
[ -f .claude/skills/menu/evals/evals.json ] && echo "✓ menu/evals.json"
cd /Users/yss/개발/build/vibe-flow
```

Expected: skills 카운트 16 (Core 14 + onboard + menu), 두 ✓ 출력.

---

## Task 5: README/REFERENCE/CHANGELOG/ROADMAP 갱신

**Files:**
- Modify: `README.md` (Core 15 → 16, /menu 추가)
- Modify: `docs/REFERENCE.md` (Core 15 → 16, /menu 행 추가)
- Modify: `CHANGELOG.md` ([Unreleased]에 /menu 추가)
- Modify: `ROADMAP.md` (`/onboard` [x] 처리 + `/menu` [x])

- [ ] **Step 1: README.md 갱신**

`Core 15` → `Core 16` (2 곳: 헤더 텍스트 + Core 15 섹션 헤더).
`메타` 행을 다음으로 교체:
```markdown
| 메타 | `/status` `/learn` `/onboard` `/menu` |
```

- [ ] **Step 2: docs/REFERENCE.md 갱신**

`## Skills (24 — Core 15 + Extensions 9)` → `## Skills (25 — Core 16 + Extensions 9)`.
`### Core 15` → `### Core 16`.
`onboard` 행 다음에 추가:
```markdown
| menu | `/menu [core\|extensions\|<category>]` | 24 스킬 카테고리별 + 사용 분포 + Stage 추천 |
```

- [ ] **Step 3: CHANGELOG.md [Unreleased] 추가**

```markdown
- **`/menu` 스킬** — Phase 2 두 번째 항목. 24 스킬 카테고리별 발견성 + events.jsonl 사용 분포 + onboard-state.json 기반 Stage 추천 강조. 필터: `/menu core|extensions|<category>`. /onboard와 보완 (좁은 학습 경로 vs 넓은 카탈로그).
```

- [ ] **Step 4: ROADMAP.md 갱신**

`Phase 1` 섹션의 미완 항목 `[ ] **글로벌 심볼릭 갱신** (Core only) — Task 32` → `[x] **글로벌 심볼릭 갱신** (Core only) — vibe-flow 1.1.0 머지 시 완료`.
`[ ] **CHANGELOG 1.1.0** breaking notice + 호환 명시 — Task 30` → `[x] **CHANGELOG 1.1.0**` (Phase 1에서 이미 처리).

`Phase 2` 신규 스킬 섹션:
```markdown
- [x] `/onboard` — 인터랙티브 단계별 가이드 (실력 자가진단 + 추천) (#2 머지)
- [x] `/menu` — 24 스킬 카테고리별 발견성 (실력별 추천)
- [ ] `/inbox` — 12 에이전트 inbox 통합 뷰
```

- [ ] **Step 5: 검증**

```bash
grep -c "/menu" README.md docs/REFERENCE.md CHANGELOG.md
grep "Core 16" README.md docs/REFERENCE.md
grep "\[x\] .onboard" ROADMAP.md
```

Expected: 각 파일에 1회 이상, Core 16 출현, ROADMAP에 onboard 체크.

- [ ] **Step 6: commit**

```bash
git add README.md docs/REFERENCE.md CHANGELOG.md ROADMAP.md
git commit -m "docs: /menu 스킬을 README/REFERENCE/CHANGELOG에 추가 + ROADMAP 갱신

Core 15 → 16. /menu는 메타 카테고리.
ROADMAP: Phase 1 잔여 항목 [x], Phase 2 onboard/menu [x]."
```

---

## Task 6: PR 생성 + 머지

**Files:** None

- [ ] **Step 1: push + PR 생성**

```bash
git log --oneline main..HEAD
git push -u origin feat/menu-skill
```

- [ ] **Step 2: gh pr create**

```bash
gh pr create --title "feat(menu): /menu 스킬 — 24 스킬 카테고리별 발견성" --body "$(cat <<'PRBODY'
## Summary

Phase 2 ROADMAP 두 번째 항목. 24 스킬 카탈로그 + 사용 분포 + Stage 추천 강조.

- 카테고리별 분류 (Core 5 + Extensions 5)
- events.jsonl 기반 사용 분포 (✓ 자주 / · 가끔 / · 미사용)
- onboard-state.json 활용 Stage 추천 (⚡)
- 필터: \`/menu core | extensions | <category>\`

## 입력 spec

[docs/superpowers/specs/2026-04-30-menu-skill-design.md](docs/superpowers/specs/2026-04-30-menu-skill-design.md)

## 구현 plan

[docs/superpowers/plans/2026-04-30-menu-skill.md](docs/superpowers/plans/2026-04-30-menu-skill.md) — 6 tasks

## Test plan

- [x] setup.sh 자동 인식 (skills 15 → 16)
- [x] evals.json 5 케이스 (전체/core/extensions/카테고리/폴백)

## /onboard와의 관계

| | /onboard | /menu |
|---|---|---|
| 출력 | 좁음 (다음 1-2) | 넓음 (전체) |
| Cache | 24h | 없음 |
| 의도 | 학습 경로 | 도구 카탈로그 |

🤖 Generated with [Claude Code](https://claude.com/claude-code)
PRBODY
)"
```

- [ ] **Step 3: squash 머지 + 정리**

```bash
PR_NUM=$(gh pr view --json number --jq '.number')
gh pr merge $PR_NUM --squash --delete-branch
git checkout main
git fetch origin
git reset --hard origin/main
git branch -D feat/menu-skill 2>/dev/null
git fetch --prune
```

---

## Self-Review Checklist

- [ ] **Spec coverage**:
  - 입력 (전체/core/extensions/category) → Task 2 step 5
  - 카테고리 정의 (Core 5 + Ext 5) → Task 2 step 4
  - 시그널 (state + onboard + events) → Task 2 step 1-2
  - Stage 추천 매핑 → Task 2 step 3
  - 출력 포맷 (헤더/Core/Ext/레전드) → Task 2 step 5
  - 폴백 (onboard-state 없음) → Task 2 step 5 (조건문)
  - Events 발생 → Task 2 step 6
  - Evals → Task 3
- [ ] **Placeholder scan**: 없음
- [ ] **Type consistency**: 카테고리 명칭 ("사이클/작업/검증/git/메타") 모든 task 동일
- [ ] **Path consistency**: `core/skills/menu/` 일관
