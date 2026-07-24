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

### 4. 출력 함수 + 카테고리 정의

```bash
# 단일 스킬 행 출력
print_skill() {
  local skill="$1"
  local cmd="$2"
  local desc="$3"
  printf "  %-30s %-30s %s%s\n" "$cmd" "$desc" "$(usage_label "$skill")" "$(is_recommended "$skill")"
}

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
