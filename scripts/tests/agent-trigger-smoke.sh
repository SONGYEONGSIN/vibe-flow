#!/bin/bash
# agent-trigger-smoke.sh — agent 호출 조건 명시 계약 (audit F-AA10)
# 실행: bash scripts/tests/agent-trigger-smoke.sh
#
# vibe-flow 는 **능동 라우팅** 하네스다 — `orchestrate/references/agent-routing.md` 의
# 의사결정 트리가 "요청 성격에 따라 적절한 agent 로 보낸다"를 규정하고, `runner`(haiku)
# 같은 저비용 티어는 자동 라우팅돼야 값을 한다. 따라서 계약은 **억제가 아니라 라우팅**이다.
#
# 계약: 모든 agent description 은 **언제 이 agent 로 오는지**를 밝혀야 한다.
#   (a) 라우팅 기준 — `<example>` 로 진입 조건 + **다른 agent 로 보낼 대조 케이스**
#   (b) 스킬 내부 전용 — "내부 전용" 선언 (사용자 직접 호출 대상 아님, 라우팅 정밀도↑)
# 역할만 적힌 description("코드 구현 전문 에이전트")은 둘 다 아니어서 **라우팅이 안 된다**
# — 언제 developer 이고 언제 frontend-design-specialist 인지 구분할 근거가 없다.
#
# 주의(F-AA10 정정): "위임하지 말고 직접 편집" 류의 **억제형 문구는 금지**한다.
# agent-routing.md 의 트리와 정면 충돌하며, 하네스가 존재하는 이유(자동 위임)를 없앤다.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
AGENT_DIR="$REPO_ROOT/core/agents"

PASS=0; FAIL=0
ok() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
ng() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

echo "Test AT1: agent description 이 라우팅 기준을 명시"
missing=""
total=0
for f in "$AGENT_DIR"/*.md; do
  [ -f "$f" ] || continue
  total=$((total + 1))
  name=$(basename "$f" .md)
  # frontmatter(첫 --- ~ 두번째 ---) 안의 description 블록만 검사
  fm=$(awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f' "$f")
  # 라우팅 기준 = <example>Context: …</example> 로 진입 조건 서술. 또는 내부 전용 선언.
  if printf '%s' "$fm" | grep -qE '<example>Context:|내부 전용'; then
    continue
  fi
  missing="$missing $name"
done
if [ -z "$missing" ]; then
  ok "AT1.1 전 agent($total) 가 라우팅 기준 명시 (example / 내부 전용)"
else
  ng "AT1.2 라우팅 기준 미표기:$missing — 언제 이 agent 로 보낼지 판단 근거가 없다"
fi

echo "Test AT2: 스킬 내부 전용 agent 는 직접 호출 대상이 아님을 선언"
# 다른 스킬이 오케스트레이션용으로만 쓰는 agent 들. 사용자가 직접 부를 일이 없으므로
# "내부 전용" 을 명시해 Claude 가 자발적으로 집지 않게 한다.
for name in comparator moderator validator; do
  f="$AGENT_DIR/$name.md"
  [ -f "$f" ] || { ng "AT2 $name.md 부재"; continue; }
  fm=$(awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f' "$f")
  if printf '%s' "$fm" | grep -q '내부 전용'; then
    ok "AT2 $name — 내부 전용 선언"
  else
    ng "AT2 $name — 내부 전용 미선언 (사용자 요청 없이 호출될 수 있다)"
  fi
done

echo "Test AT3: 억제형 문구 부재 (라우팅 트리와 충돌 방지)"
sup=""
for f in "$AGENT_DIR"/*.md; do
  [ -f "$f" ] || continue
  if grep -qE '위임하지 (말고|않고)' "$f"; then sup="$sup $(basename "$f" .md)"; fi
done
if [ -z "$sup" ]; then
  ok "AT3.1 억제형('위임하지 말고/않고') 0건 — 능동 라우팅 설계와 정합"
else
  ng "AT3.2 억제형 문구:$sup — agent-routing.md 트리와 충돌"
fi

echo "Test AT4: 라우팅 정책이 상시 컨텍스트에 노출 (F-AA12)"
# agent description 은 항상 로드되지만, **비용 티어 규율**(잡무→runner/haiku 등)은
# agent-routing.md 에만 있고 그 파일은 `/orchestrate` 스킬 reference 라 평소 로드되지
# 않는다. 즉 라우팅은 되지만 "싼 티어로 내리기" 는 컨텍스트에 없어 일어나지 않는다.
# 전체 트리는 /orchestrate 에 두고(leaves 분리), 요약만 프로젝트 CLAUDE.md 에 올린다.
TPL="$REPO_ROOT/templates/CLAUDE.md.template"
if [ ! -f "$TPL" ]; then
  ng "AT4.0 CLAUDE.md.template 부재"
else
  if grep -q "Agent Routing" "$TPL"; then
    ok "AT4.1 템플릿에 Agent Routing 섹션 존재"
  else
    ng "AT4.1 템플릿에 라우팅 요약 없음 — 비용 티어 규율이 상시 컨텍스트 밖"
  fi
  if grep -q "runner" "$TPL" && grep -q "haiku" "$TPL"; then
    ok "AT4.2 저비용 티어(runner/haiku) 명시"
  else
    ng "AT4.2 저비용 티어 미명시 — 잡무가 opus 로 흘러간다"
  fi
  if grep -q "agent-routing.md" "$TPL"; then
    ok "AT4.3 전체 트리 위치를 가리킴 (leaves 분리)"
  else
    ng "AT4.3 상세 참조 없음 — 요약만 있고 근거를 못 찾는다"
  fi
fi

echo "Test AT5: 라우팅 문서의 모델 컬럼 == agent frontmatter (F-AA13)"
# frontmatter 의 `model:` 이 실효 설정이고 문서 표는 서술일 뿐이다. 둘을 잇는 게이트가
# 없어 문서가 sonnet 이라 적은 agent 들이 전부 opus 로 떠 있었다(R-AA 실측 7건).
# 문서를 읽고 라우팅해도 적힌 모델이 안 뜨면 비용 설계는 문서상에만 존재한다.
ROUTING="$REPO_ROOT/core/skills/orchestrate/references/agent-routing.md"
if [ ! -f "$ROUTING" ]; then
  ng "AT5.0 agent-routing.md 부재"
else
  mism=""; checked=0
  # 표 행 형식: | <에이전트> | <전문 분야> | <모델> |  — plugin 행은 core/agents 밖이라 제외
  while IFS= read -r line; do
    a=$(printf '%s' "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$2); print $2}')
    dm=$(printf '%s' "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$4); print $4}')
    case "$a" in *"(plugin)"*|""|"에이전트"|*"---"*) continue ;; esac
    af="$AGENT_DIR/$a.md"
    [ -f "$af" ] || continue
    fm=$(awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f' "$af" | grep -E '^model:' | sed 's/^model: *//')
    checked=$((checked + 1))
    [ "$dm" = "$fm" ] || mism="$mism $a(문서=$dm/설정=$fm)"
  done < "$ROUTING"
  if [ -z "$mism" ]; then
    ok "AT5.1 문서 모델 컬럼 == frontmatter ($checked 건 대조)"
  else
    ng "AT5.2 모델 불일치:$mism — 문서대로 라우팅해도 그 모델이 안 뜬다"
  fi
  # 표만 게이트하면 산문(`agent (sonnet) → …` 워크플로 예시)으로 드리프트가 되돌아온다.
  # 문서 전체의 `<이름> (<모델>)` 표기도 같은 기준으로 대조한다. 내장 agent
  # (Explore/general-purpose/Plan 등)는 frontmatter 가 없어 호출부 인자 소관 — 제외.
  imism=""
  while IFS= read -r pair; do
    a=${pair%% *}; dm=$(printf '%s' "$pair" | sed 's/.*(\(.*\))/\1/')
    af="$AGENT_DIR/$a.md"; [ -f "$af" ] || continue
    fm=$(awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f' "$af" | grep -E '^model:' | sed 's/^model: *//')
    [ "$dm" = "$fm" ] || imism="$imism $a(본문=$dm/설정=$fm)"
  done <<EOF_INLINE
$(grep -oE '[a-z][a-z-]+ \((haiku|sonnet|opus)\)' "$ROUTING" | sort -u)
EOF_INLINE
  if [ -z "$imism" ]; then
    ok "AT5.3 본문 인라인 표기도 frontmatter 와 일치"
  else
    ng "AT5.4 인라인 불일치:$imism — 표만 고치고 산문에 옛 모델이 남았다"
  fi
fi

echo
echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ ALL TESTS PASSED"; exit 0; } || { echo "✗ SOME TESTS FAILED"; exit 1; }
