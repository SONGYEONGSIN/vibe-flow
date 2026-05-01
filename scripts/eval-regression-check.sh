#!/bin/bash
# eval-regression-check.sh
# vibe-flow repo 자체 SKILL.md / agents.md / evals.json 구조 회귀 검증
#
# 사용:
#   bash scripts/eval-regression-check.sh
#
# 검증:
#   A. SKILL.md frontmatter (name/description/model + description ≥ 20자)
#   B. agents/*.md frontmatter (동일)
#   C. evals.json 유효 JSON + cases 배열 + 케이스별 필수 필드
#   D. agents.json ↔ core/agents/*.md 일치
#   E. Core skills ≥ 19, Extension skills ≥ 9
#   F. templates/.github/workflows/*.yml YAML 유효성
#
# Exit:
#   0 — 모두 통과
#   1 — 하나 이상 실패

set -u

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT" || exit 1

PASS=0
FAIL=0

ok()   { echo "✓ $1"; PASS=$((PASS+1)); }
err()  { echo "✗ $1"; FAIL=$((FAIL+1)); }
warn() { echo "⚠ $1"; }

echo "=== vibe-flow eval-regression check ==="
echo "Target: $REPO_ROOT"
echo ""

# ─── A. SKILL.md frontmatter ───
# 필수: name + description (≥ 20자)
# 선택: model (Phase 2+ 도입), effort (Phase 0/1 시기)
check_skill_md() {
  local f="$1"
  local fm
  fm=$(awk '/^---$/{f++; if(f==2) exit; next} f==1{print}' "$f")
  # frontmatter 블록 없을 가능성 — 일부 SKILL.md는 frontmatter 시작 ---가 없을 수 있음
  if [ -z "$fm" ]; then
    # 첫 줄에 name: 으로 시작하면 frontmatter (단순 형태)
    fm=$(head -10 "$f" | awk '/^name:|^description:|^effort:|^model:/')
  fi
  if [ -z "$fm" ]; then
    err "$f: frontmatter 또는 메타 블록 없음"
    return
  fi
  for key in name description; do
    if ! echo "$fm" | grep -q "^${key}:"; then
      err "$f: ${key} 누락"
      return
    fi
  done
  local desc
  desc=$(echo "$fm" | awk '/^description:/' | sed 's/^description: *//')
  local desc_len=${#desc}
  if [ "$desc_len" -lt 20 ]; then
    err "$f: description < 20자 (현재 ${desc_len})"
    return
  fi
}

SKILL_BEFORE=$FAIL
SKILL_COUNT=0
for f in core/skills/*/SKILL.md extensions/*/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  check_skill_md "$f"
  SKILL_COUNT=$((SKILL_COUNT+1))
done
[ "$FAIL" = "$SKILL_BEFORE" ] && ok "All SKILL.md frontmatter valid (${SKILL_COUNT} files)"

# ─── B. agents/*.md frontmatter ───
check_agent_md() {
  local f="$1"
  local fm
  fm=$(awk '/^---$/{f++; if(f==2) exit; next} f==1{print}' "$f")
  if [ -z "$fm" ]; then
    err "$f: frontmatter 블록 없음"
    return
  fi
  for key in name description model; do
    if ! echo "$fm" | grep -q "^${key}:"; then
      err "$f: ${key} 누락"
      return
    fi
  done
}

AGENT_BEFORE=$FAIL
AGENT_COUNT=0
for f in core/agents/*.md extensions/*/agents/*.md; do
  [ -f "$f" ] || continue
  # .gitkeep 또는 README 같은 비-에이전트 파일 제외 (frontmatter 없을 가능성)
  case "$(basename "$f")" in
    .gitkeep|README.md) continue ;;
  esac
  check_agent_md "$f"
  AGENT_COUNT=$((AGENT_COUNT+1))
done
[ "$FAIL" = "$AGENT_BEFORE" ] && ok "All agents.md frontmatter valid (${AGENT_COUNT} files)"

# ─── C. evals.json 구조 ───
# 두 스키마 허용:
#   v1 (Phase 0/1): {skill_name, description, evals: [{id, prompt, expectations}]}
#   v2 (Phase 2+):  {skill, version, cases: [{id, description, input, expected}]}
check_evals_json() {
  local f="$1"
  if ! jq empty "$f" >/dev/null 2>&1; then
    err "$f: 유효 JSON 아님"
    return
  fi
  # 스키마 감지
  local schema=""
  if jq -e 'has("evals")' "$f" >/dev/null 2>&1; then
    schema="v1"
  elif jq -e 'has("cases")' "$f" >/dev/null 2>&1; then
    schema="v2"
  else
    err "$f: 'evals' 또는 'cases' 배열 누락"
    return
  fi

  # 공통: skill / skill_name 키는 선택 (스키마 변형 다양 — description으로 추론 가능)

  # 배열 길이
  local items_len
  if [ "$schema" = "v1" ]; then
    items_len=$(jq '.evals | length' "$f" 2>/dev/null)
  else
    items_len=$(jq '.cases | length' "$f" 2>/dev/null)
  fi
  if [ "$items_len" -lt 1 ]; then
    err "$f: evals/cases 배열 비어 있음"
    return
  fi
}

EVALS_BEFORE=$FAIL
EVALS_COUNT=0
for f in core/skills/*/evals/evals.json extensions/*/skills/*/evals/evals.json; do
  [ -f "$f" ] || continue
  check_evals_json "$f"
  EVALS_COUNT=$((EVALS_COUNT+1))
done
[ "$FAIL" = "$EVALS_BEFORE" ] && ok "All evals.json valid (${EVALS_COUNT} files)"

# ─── D. agents.json ↔ files ───
AGENTS_JSON="core/agents.json"
if [ -f "$AGENTS_JSON" ]; then
  if jq empty "$AGENTS_JSON" >/dev/null 2>&1; then
    AGENTS_BEFORE=$FAIL
    JSON_AGENTS=$(jq -r '.agents[]' "$AGENTS_JSON" 2>/dev/null)
    for agent in $JSON_AGENTS; do
      if [ ! -f "core/agents/${agent}.md" ]; then
        err "agents.json에 '${agent}' 있으나 core/agents/${agent}.md 없음"
      fi
    done
    [ "$FAIL" = "$AGENTS_BEFORE" ] && ok "agents.json ↔ files: $(echo "$JSON_AGENTS" | wc -l | tr -d ' ')/$(echo "$JSON_AGENTS" | wc -l | tr -d ' ') match"
  else
    err "core/agents.json: 유효 JSON 아님"
  fi
else
  err "core/agents.json 없음"
fi

# ─── E. Core/Extension 카운트 ───
CORE_SKILLS=$(find core/skills -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
EXT_SKILLS=$(find extensions -mindepth 3 -maxdepth 3 -type d -path '*/skills/*' 2>/dev/null | wc -l | tr -d ' ')

if [ "$CORE_SKILLS" -ge 19 ]; then
  ok "Core skills count: ${CORE_SKILLS} (≥ 19)"
else
  err "Core skills count: ${CORE_SKILLS} (< 19)"
fi

if [ "$EXT_SKILLS" -ge 9 ]; then
  ok "Extension skills count: ${EXT_SKILLS} (≥ 9)"
else
  err "Extension skills count: ${EXT_SKILLS} (< 9)"
fi

# ─── F. Templates GH Actions YAML 유효성 ───
# templates/.github/workflows/*.yml가 valid YAML인지 검증.
# yq 우선, 없으면 python3 yaml fallback. 둘 다 없으면 warn + skip (실패 X).
TEMPLATE_DIR="templates/.github/workflows"
if [ -d "$TEMPLATE_DIR" ]; then
  TEMPLATE_BEFORE=$FAIL
  TEMPLATE_COUNT=0
  TEMPLATE_TOOL=""
  if command -v yq &>/dev/null; then
    TEMPLATE_TOOL="yq"
  elif command -v python3 &>/dev/null && python3 -c "import yaml" 2>/dev/null; then
    TEMPLATE_TOOL="python3"
  fi
  if [ -z "$TEMPLATE_TOOL" ]; then
    warn "yq + python3 yaml 모두 없음 — templates YAML 검증 skip"
  else
    for f in "$TEMPLATE_DIR"/*.yml "$TEMPLATE_DIR"/*.yaml; do
      [ -f "$f" ] || continue
      TEMPLATE_COUNT=$((TEMPLATE_COUNT+1))
      if [ "$TEMPLATE_TOOL" = "yq" ]; then
        if ! yq e '.' "$f" >/dev/null 2>&1; then
          err "$f: invalid YAML (yq)"
        fi
      else
        if ! python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$f" 2>/dev/null; then
          err "$f: invalid YAML (python3 yaml)"
        fi
      fi
    done
    if [ "$TEMPLATE_COUNT" -gt 0 ] && [ "$FAIL" = "$TEMPLATE_BEFORE" ]; then
      ok "Templates GH Actions YAML valid (${TEMPLATE_COUNT} files, ${TEMPLATE_TOOL})"
    fi
  fi
fi

# ─── 결과 ───
echo ""
echo "=== 결과 ==="
echo "  PASS: $PASS / FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "❌ 회귀 검출. 머지 차단."
  exit 1
fi
echo ""
echo "✅ 모두 통과"
exit 0
