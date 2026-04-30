# eval 자동 회귀 알림 (CI) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans

**Goal:** Phase 4 2번째 — `.github/workflows/eval-regression.yml` + `scripts/eval-regression-check.sh` (구조 회귀 검증, LLM 호출 0).

**Tech Stack:** bash, jq, GitHub Actions

**Spec:** `docs/superpowers/specs/2026-04-30-eval-regression-ci-design.md`

---

## Task 1: branch + 디렉토리

```bash
git checkout -b feat/eval-regression-ci
mkdir -p .github/workflows
```

---

## Task 2: 검증 스크립트 작성

**Files:** `scripts/eval-regression-check.sh`

검증 항목:
- A. SKILL.md frontmatter (name/description/model + description ≥ 20자)
- B. agents.md frontmatter (동일)
- C. evals.json 유효 JSON + cases 배열 + 케이스별 필수 필드
- D. agents.json ↔ core/agents/*.md 일치
- E. Core skills ≥ 19, Extension skills ≥ 9 카운트

출력 + exit code 0/1.

- [ ] **Step 1: 작성 + chmod +x**
- [ ] **Step 2: 로컬 실행 — 모든 검증 PASS 확인**

```bash
bash scripts/eval-regression-check.sh
echo "exit=$?"
```

- [ ] **Step 3: commit**

```bash
git add scripts/eval-regression-check.sh
git commit -m "feat(ci): eval-regression-check.sh — SKILL/agents/evals 구조 검증"
```

---

## Task 3: GitHub Actions workflow

**Files:** `.github/workflows/eval-regression.yml`

```yaml
name: eval-regression

on:
  pull_request:
    paths:
      - 'core/skills/**'
      - 'core/agents/**'
      - 'extensions/**'
      - 'core/agents.json'
      - 'scripts/eval-regression-check.sh'
      - '.github/workflows/eval-regression.yml'
  push:
    branches: [main]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install jq
        run: sudo apt-get update && sudo apt-get install -y jq
      - name: Run eval regression check
        run: bash scripts/eval-regression-check.sh
```

- [ ] **Step 1: 작성 + commit**

```bash
git add .github/workflows/eval-regression.yml
git commit -m "ci(eval-regression): GitHub Actions workflow — PR/push trigger"
```

---

## Task 4: docs 갱신

**Files:** `docs/REFERENCE.md`, `CHANGELOG.md`, `ROADMAP.md`

### docs/REFERENCE.md
`## Statusline` 섹션 직후 또는 `## setup.sh CLI` 직전:

```markdown
## CI / 회귀 검증

`.github/workflows/eval-regression.yml`이 PR + push to main에서 자동 실행. `scripts/eval-regression-check.sh`가 구조 회귀를 검증한다.

검증:
- SKILL.md / agents.md frontmatter (name/description/model)
- evals.json 유효 JSON + cases 배열
- agents.json ↔ files 일치
- Core/Extension 스킬 카운트

LLM 호출 없음 (CI 비용 0). 메이커 로컬 사용:
\`\`\`bash
bash scripts/eval-regression-check.sh
\`\`\`
```

### CHANGELOG.md [Unreleased]
```markdown
- **eval 회귀 CI 통합 (Phase 4 2번째)** — `.github/workflows/eval-regression.yml` + `scripts/eval-regression-check.sh` 신설. PR/push 시 SKILL.md / agents.md frontmatter + evals.json 구조 + agents.json 일치 자동 검증. LLM 호출 없음 (CI 비용 0). 메이커 로컬에서도 동일 스크립트 호출 가능.
```

### ROADMAP.md
```markdown
- [x] eval 자동 회귀 알림 (CI 통합) — `.github/workflows/eval-regression.yml`
```

- [ ] **Step 1: 4 파일 갱신 + commit**

---

## Task 5: PR + 머지

```bash
git push -u origin feat/eval-regression-ci
gh pr create --title "ci(eval-regression): SKILL.md/agents.md/evals.json 구조 회귀 자동 검증 (Phase 4 2번째)" --body "..."
PR_NUM=$(gh pr view --json number --jq '.number')
gh pr merge $PR_NUM --squash --delete-branch
git checkout main && git fetch origin && git reset --hard origin/main
git branch -D feat/eval-regression-ci 2>/dev/null
git fetch --prune
```

---

## Self-Review

- [ ] Spec coverage: 검증 5 항목 / workflow 트리거 / 로컬 사용 / CI 비용 0 모두 매핑 ✓
- [ ] Path consistency: `scripts/eval-regression-check.sh`, `.github/workflows/eval-regression.yml` 일관
