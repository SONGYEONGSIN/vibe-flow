# /budget 스킬 + budget-warn hook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans

**Goal:** P5 토큰/비용 예산 프레임워크 — `/budget` 스킬 + `hooks/budget-warn.sh` Notification hook + `.claude/budget.json` 기본값.

**Architecture:** 호출 카운트 기반 (events.jsonl). 차단 X 정보만. SKILL.md + 신규 hook + setup.sh 갱신.

**Tech Stack:** bash, jq, date, bc

**Spec:** `docs/superpowers/specs/2026-04-30-budget-skill-design.md` (commit f3cce81)

---

## Task 1: branch + 디렉토리

- [ ] `git checkout -b feat/budget && mkdir -p core/skills/budget/evals`

---

## Task 2: SKILL.md — `/budget`

**Files:** `core/skills/budget/SKILL.md`

핵심 절차:
1. 인자 파싱: default | `set <skill> <daily> <weekly>` | `reset` | `--json`
2. budget.json 로드 (없으면 기본값 in-memory 사용)
3. events.jsonl jq aggregation: 일일/주간 카운트 per type
4. set/reset/json 모드 분기
5. default 모드: 텍스트 출력 (스킬별 progress bar + sparkline + 추세)
6. events.jsonl에 budget event append

진행 바: `printf "%-5s" "$(repeat '█' $filled)$(repeat '░' $empty)"` 같은 패턴.
sparkline: 7일 카운트 → `░▁▂▃▄▅▆▇█` 매핑.

- [ ] **Step 1: SKILL.md 작성**
- [ ] **Step 2: commit**

```bash
git add core/skills/budget/SKILL.md
git commit -m "feat(budget): SKILL.md — /budget 사용량/한도/추이 + set/reset/json"
```

---

## Task 3: evals.json 5 케이스

**Files:** `core/skills/budget/evals/evals.json`

5 cases: 빈 budget / 80% 일일 / 100% 일일 / set 명령 / --json 출력.

- [ ] **Step 1: 작성 + 검증**

```bash
jq empty core/skills/budget/evals/evals.json
git add core/skills/budget/evals/evals.json
git commit -m "test(budget): evals.json 5 케이스"
```

---

## Task 4: budget-warn.sh Notification hook

**Files:** `core/hooks/budget-warn.sh`

- [ ] **Step 1: 작성**

핵심:
- `CLAUDE_PROJECT_DIR` 변수 활용
- 디바운스: `.claude/.budget-last-warn` 타임스탬프 (15분)
- 80%+ 일일 사용 스킬 검출
- additionalContext JSON 출력

- [ ] **Step 2: 실행 권한 + 단위 테스트**

```bash
chmod +x core/hooks/budget-warn.sh

# 빈 .claude — 출력 없어야
TMP=$(mktemp -d) && CLAUDE_PROJECT_DIR=$TMP bash core/hooks/budget-warn.sh
echo "exit=$?"

# 80%+ 시뮬
mkdir -p $TMP/.claude
cat > $TMP/.claude/budget.json <<EOF
{"version":"1.0.0","limits":{"pair_session":{"daily":5,"weekly":20}},"warn_threshold":0.8}
EOF
TODAY=$(date -u +%Y-%m-%d)
for i in 1 2 3 4; do
  echo "{\"type\":\"pair_session\",\"ts\":\"${TODAY}T10:0${i}:00Z\"}"
done > $TMP/.claude/events.jsonl
CLAUDE_PROJECT_DIR=$TMP bash core/hooks/budget-warn.sh
# Expected: additionalContext JSON 출력
rm -rf $TMP
```

- [ ] **Step 3: commit**

```bash
git add core/hooks/budget-warn.sh
git commit -m "feat(budget): budget-warn.sh Notification hook — 80%+ 비차단 경고"
```

---

## Task 5: setup.sh + settings.template.json 갱신

**Files:** `setup.sh`, `settings/settings.template.json`

### setup.sh
- 메인 흐름 끝부분 (CLAUDE.md 직후)에 `.claude/budget.json` 기본값 생성 블록 추가.

### settings.template.json
- Notification 섹션의 hooks 배열에 budget-warn 추가:

```json
{ "type": "command", "command": ".claude/hooks/budget-warn.sh", "timeout": 5000 }
```

- [ ] **Step 1: 두 파일 갱신**
- [ ] **Step 2: 임시 setup 검증**

```bash
rm -rf /tmp/vf-budget-test && mkdir /tmp/vf-budget-test && cd /tmp/vf-budget-test
bash /Users/yss/개발/build/vibe-flow/setup.sh > /tmp/vf-budget-setup.log 2>&1
[ -f .claude/budget.json ] && echo "✓ budget.json 생성"
[ -f .claude/hooks/budget-warn.sh ] && echo "✓ budget-warn.sh 복사"
[ -f .claude/skills/budget/SKILL.md ] && echo "✓ /budget 스킬 복사"
echo "skills count: $(ls .claude/skills/ | wc -l | tr -d ' ')"
jq '.hooks.Notification[0].hooks | map(.command) | length' .claude/settings.local.json
cd /Users/yss/개발/build/vibe-flow
```

Expected: 모두 ✓ + skills 18 + Notification hook 3개 (notify, model-suggest, budget-warn).

- [ ] **Step 3: commit**

```bash
git add setup.sh settings/settings.template.json
git commit -m "feat(budget): setup.sh budget.json 기본값 생성 + Notification에 budget-warn 등록"
```

---

## Task 6: docs 갱신

**Files:** README.md, docs/REFERENCE.md, CHANGELOG.md, ROADMAP.md

### README.md
- `Core 17` → `Core 18` (2 곳)
- 메타 행: `/status /learn /onboard /menu /inbox /budget`

### docs/REFERENCE.md
- `Skills (26 — Core 17 + Extensions 9)` → `Skills (27 — Core 18 + Extensions 9)`
- `### Core 17` → `### Core 18`
- `inbox` 행 다음에:
```markdown
| budget | `/budget [set\|reset\|--json]` | 호출 카운트 기반 비용 예산 (5 무거운 스킬) |
```
- Hooks 섹션 Notification 영역에 추가:
```markdown
- `budget-warn.sh` — 일일 한도 80%+ 사용 시 비차단 경고 (15분 디바운스)
```

### CHANGELOG.md [Unreleased]
```markdown
- **`/budget` 스킬 + budget-warn hook (P5)** — 호출 카운트 기반 비용 예산 프레임워크. 5개 무거운 스킬(/pair, /discuss, /evolve, /design-sync, /retrospective) 일일/주간 한도 추적. `.claude/budget.json` 사용자 편집 + `/budget set <skill> <daily> <weekly>` 명령. 정보만 (차단 X). budget-warn.sh Notification hook이 80%+ 사용 시 비차단 경고.
```

### ROADMAP.md
- P5 섹션에:
```markdown
### 🔵 P5 전략 공백: 토큰/비용 예산 프레임워크 ✓ 완료

- **배경**: /pair / /discuss / 오케스트레이터 병렬 실행 시 무제한 과금 가능
- **구현**: `/budget` 스킬 + budget-warn.sh hook + .claude/budget.json
- **머지**: PR (이번)
```

- [ ] **Step 1: 4개 파일 갱신**
- [ ] **Step 2: commit**

```bash
git add README.md docs/REFERENCE.md CHANGELOG.md ROADMAP.md
git commit -m "docs: /budget을 README/REFERENCE/CHANGELOG/ROADMAP에 추가"
```

---

## Task 7: PR 생성 + 머지

```bash
git push -u origin feat/budget
gh pr create --title "feat(budget): /budget 스킬 + budget-warn hook (P5 비용 예산 프레임워크)" --body "..."
PR_NUM=$(gh pr view --json number --jq '.number')
gh pr merge $PR_NUM --squash --delete-branch
git checkout main && git fetch origin && git reset --hard origin/main
git branch -D feat/budget 2>/dev/null
git fetch --prune
```

---

## Self-Review

- [ ] Spec coverage: budget.json schema / 5 모드(/budget set reset --json) / sparkline / hook 디바운스 / setup 통합 모두 매핑 ✓
- [ ] Placeholder 없음
- [ ] Path consistency: `core/skills/budget/`, `core/hooks/budget-warn.sh` 일관
