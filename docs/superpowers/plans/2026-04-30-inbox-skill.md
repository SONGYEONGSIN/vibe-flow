# /inbox 스킬 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Phase 2 세 번째 — `/inbox` 스킬 (12 에이전트 inbox + broadcast + debates 통합 뷰).

**Architecture:** SKILL.md + evals.json 단일 파일. message-bus.sh CLI 호환, jq aggregation으로 per-agent 카운트 + 최근 미리보기.

**Tech Stack:** bash, jq

**Spec:** `docs/superpowers/specs/2026-04-30-inbox-skill-design.md` (commit e8a5581)

---

## Task 1: branch + scaffold

- [ ] **Step 1: 브랜치**

```bash
cd /Users/yss/개발/build/vibe-flow
git checkout -b feat/inbox-skill
mkdir -p core/skills/inbox/evals
```

---

## Task 2: SKILL.md 작성

**Files:** `core/skills/inbox/SKILL.md`

- [ ] **Step 1: SKILL.md 작성**

frontmatter (name, description, model) + 절차 섹션:
1. 인자 파싱 (default | <agent> | --unread-only | --broadcast)
2. 에이전트 명단 로드 (agents.json 또는 inbox/ 디렉토리)
3. per-agent jq aggregation (unread/total + 최근 3 unread)
4. broadcast/debates 카운트
5. Active/Quiet 분류 출력
6. events.jsonl에 inbox append

핵심 jq 패턴:
```bash
# Per-agent unread count
UNREAD=$(jq -s '[.[] | select(.status=="unread")] | length' .claude/messages/inbox/<agent>/*.json 2>/dev/null || echo 0)

# Per-agent total
TOTAL=$(ls .claude/messages/inbox/<agent>/*.json 2>/dev/null | wc -l | tr -d ' ')

# 최근 3 unread (subject + from + ts)
jq -s 'map(select(.status=="unread")) | sort_by(.ts) | reverse | .[0:3]' \
  .claude/messages/inbox/<agent>/*.json
```

상대 시간 변환 함수 (now - ts):
```bash
relative_time() {
  local ts="$1"
  local now=$(date -u +%s)
  local then=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null || echo $now)
  local diff=$((now - then))
  if [ $diff -lt 3600 ]; then echo "$((diff / 60))분 전"
  elif [ $diff -lt 86400 ]; then echo "$((diff / 3600))시간 전"
  else echo "$((diff / 86400))일 전"
  fi
}
```

- [ ] **Step 2: commit**

```bash
git add core/skills/inbox/SKILL.md
git commit -m "feat(inbox): SKILL.md — 12 에이전트 통합 inbox 뷰

per-agent jq aggregation (unread/total + 최근 3) +
broadcast/debates 카운트 + Active/Quiet 분류."
```

---

## Task 3: evals.json — 5 케이스

**Files:** `core/skills/inbox/evals/evals.json`

5 cases:
1. empty — 모든 에이전트 0 → Quiet 12
2. mixed — developer 3 unread, validator 1 → Active 2 + Quiet 10
3. single agent — `/inbox developer` → message-bus list 형태
4. unread-only — Active 섹션만
5. broadcast — broadcast/debates 섹션만

JSON 구조: id, description, setup(파일 fixture), input, expected.

- [ ] **Step 1: 작성 + 검증**

```bash
jq empty core/skills/inbox/evals/evals.json
jq '.cases | length' core/skills/inbox/evals/evals.json   # Expected: 5
git add core/skills/inbox/evals/evals.json
git commit -m "test(inbox): evals.json 5 케이스"
```

---

## Task 4: setup.sh 자동 인식 검증

- [ ] **Step 1: 임시 setup**

```bash
rm -rf /tmp/vf-inbox-test && mkdir /tmp/vf-inbox-test && cd /tmp/vf-inbox-test
bash /Users/yss/개발/build/vibe-flow/setup.sh > /tmp/vf-inbox-setup.log 2>&1
echo "skills count: $(ls .claude/skills/ | wc -l | tr -d ' ')"   # Expected: 17
[ -f .claude/skills/inbox/SKILL.md ] && echo "✓ inbox/SKILL.md"
cd /Users/yss/개발/build/vibe-flow
```

---

## Task 5: docs 갱신

**Files:** README.md, docs/REFERENCE.md, CHANGELOG.md, ROADMAP.md

- [ ] **Step 1: README.md**

`Core 16` → `Core 17` (2 곳).
메타 행:
```markdown
| 메타 | `/status` `/learn` `/onboard` `/menu` `/inbox` |
```

- [ ] **Step 2: docs/REFERENCE.md**

`## Skills (25 — Core 16 + Extensions 9)` → `## Skills (26 — Core 17 + Extensions 9)`.
`### Core 16` → `### Core 17`.
`menu` 행 다음:
```markdown
| inbox | `/inbox [<agent>\|--unread-only\|--broadcast]` | 12 에이전트 inbox 통합 뷰 |
```

- [ ] **Step 3: CHANGELOG.md [Unreleased]**

```markdown
- **`/inbox` 스킬** — Phase 2 세 번째 항목. 12 에이전트 inbox + broadcast + debates 통합 뷰. message-bus.sh CLI 호환 (read/archive는 그대로 위임). Active/Quiet 분류 + 최근 미리보기 3. 필터: `/inbox <agent>|--unread-only|--broadcast`.
```

- [ ] **Step 4: ROADMAP.md**

Phase 2 신규 스킬 `/inbox` 행:
```markdown
- [x] `/inbox` — 12 에이전트 inbox 통합 뷰
```

- [ ] **Step 5: commit**

```bash
git add README.md docs/REFERENCE.md CHANGELOG.md ROADMAP.md
git commit -m "docs: /inbox 스킬을 README/REFERENCE/CHANGELOG/ROADMAP에 추가

Core 16 → 17. /inbox는 메타 카테고리. ROADMAP Phase 2 신규 스킬 [x] 완료."
```

---

## Task 6: PR 생성 + squash 머지

- [ ] **Step 1: push + PR**

```bash
git push -u origin feat/inbox-skill
gh pr create --title "feat(inbox): /inbox 스킬 — 12 에이전트 통합 inbox 뷰" --body "..."
```

- [ ] **Step 2: 머지 + 정리**

```bash
PR_NUM=$(gh pr view --json number --jq '.number')
gh pr merge $PR_NUM --squash --delete-branch
git checkout main && git fetch origin && git reset --hard origin/main
git branch -D feat/inbox-skill 2>/dev/null
git fetch --prune
```

---

## Self-Review

- [ ] Spec coverage: 입력 4 모드 / Active-Quiet / 미리보기 3 / events 발생 / message-bus 호환 모두 task 매핑 ✓
- [ ] Placeholder scan: 없음
- [ ] Path consistency: `core/skills/inbox/` 일관
