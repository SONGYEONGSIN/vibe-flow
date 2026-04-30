# Statusline 강화 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans

**Goal:** statusline.sh 스크립트 + settings.template.json statusLine 추가로 verify/hook/plan 시그널 합성 출력.

**Tech Stack:** bash, jq

**Spec:** `docs/superpowers/specs/2026-04-30-statusline-enhancement-design.md` (commit 71c7b0b)

---

## Task 1: branch + 디렉토리

- [ ] **Step 1**

```bash
git checkout -b feat/statusline
mkdir -p core/scripts/tests
```

---

## Task 2: statusline.sh 작성

**Files:** `core/scripts/statusline.sh`

핵심 로직:
1. `VIBE_FLOW_STATUSLINE=off` → exit 0
2. tail events.jsonl → verify_complete + tool_result/failure 마지막
3. grep plans/*.md → in_progress + step count
4. parts 배열 합성 → " · " join → echo

에러 강건성: set -e 미사용, 모든 jq/grep 실패는 무시 (statusLine 깨지면 안 됨).

- [ ] **Step 1: 작성**

```bash
chmod +x core/scripts/statusline.sh
```

- [ ] **Step 2: 단위 테스트 — 데이터 없음 시 빈 출력**

```bash
cd /tmp && bash /Users/yss/개발/build/vibe-flow/core/scripts/statusline.sh
# Expected: 빈 출력 또는 줄바꿈만
```

- [ ] **Step 3: commit**

```bash
git add core/scripts/statusline.sh
git commit -m "feat(statusline): statusline.sh — verify/hook/plan 합성 한 줄 출력"
```

---

## Task 3: settings.template.json 갱신

**Files:** `settings/settings.template.json`

- [ ] **Step 1: statusLine 항목 추가**

기존 `permissions` 또는 `autoMode` 다음에:
```json
"statusLine": {
  "type": "command",
  "command": "bash $CLAUDE_PROJECT_DIR/.claude/scripts/statusline.sh"
}
```

- [ ] **Step 2: JSON 유효성 검증**

```bash
jq empty settings/settings.template.json && echo "✓ valid JSON"
jq '.statusLine.command' settings/settings.template.json
# Expected: "bash $CLAUDE_PROJECT_DIR/.claude/scripts/statusline.sh"
```

- [ ] **Step 3: commit**

```bash
git add settings/settings.template.json
git commit -m "feat(statusline): settings.template.json에 statusLine 명령 추가"
```

---

## Task 4: 단위 테스트 스크립트

**Files:** `core/scripts/tests/statusline-tests.sh`

5 케이스:
1. 데이터 없음 → 빈 출력
2. verify pass + hook OK + 활성 plan → `✓v · 🔧✓ · 📋N/M`
3. verify fail + 활성 plan → `✗v(N fail) · 📋N/M`
4. verify pass, plan 없음 → `✓v · 🔧✓`
5. `VIBE_FLOW_STATUSLINE=off` → 빈 출력

각 케이스: 임시 디렉토리 fixture 생성 → statusline.sh 실행 → 출력 검증.

- [ ] **Step 1: 작성**

```bash
chmod +x core/scripts/tests/statusline-tests.sh
```

- [ ] **Step 2: 실행**

```bash
bash core/scripts/tests/statusline-tests.sh
# Expected: 5/5 PASS
```

- [ ] **Step 3: commit**

```bash
git add core/scripts/tests/statusline-tests.sh
git commit -m "test(statusline): 5 케이스 단위 테스트 (bash)"
```

---

## Task 5: setup.sh + validate.sh 검증

setup.sh는 scripts/ 디렉토리 자동 복사 + settings.template.json → settings.local.json 변환. statusLine은 `$CLAUDE_PROJECT_DIR` 변수만 사용 (sed 치환 패턴 외부).

- [ ] **Step 1: 임시 setup 검증**

```bash
rm -rf /tmp/vf-statusline-test && mkdir /tmp/vf-statusline-test && cd /tmp/vf-statusline-test
bash /Users/yss/개발/build/vibe-flow/setup.sh > /tmp/vf-statusline-setup.log 2>&1
[ -f .claude/scripts/statusline.sh ] && echo "✓ statusline.sh 복사됨"
[ -x .claude/scripts/statusline.sh ] && echo "✓ 실행 권한"
jq -r '.statusLine.command' .claude/settings.local.json
cd /Users/yss/개발/build/vibe-flow
```

Expected:
- ✓ statusline.sh 복사됨
- ✓ 실행 권한
- statusLine.command 값 출력

---

## Task 6: docs 갱신

**Files:** README.md, docs/REFERENCE.md, CHANGELOG.md, ROADMAP.md

- [ ] **Step 1: docs/REFERENCE.md — Statusline 섹션 추가**

`## setup.sh CLI` 섹션 직전에 추가:

```markdown
## Statusline

`.claude/settings.local.json`의 `statusLine` 항목으로 활성. `core/scripts/statusline.sh`가 한 줄 출력.

출력 예시:
- `✓v · 🔧✓ · 📋3/7 (auth)`
- `✗v(2 fail) · 🔧✗ tsc`

env 옵션:
- `VIBE_FLOW_STATUSLINE=off` — 비활성
- `VIBE_FLOW_STATUSLINE_VERBOSE=1` — 자세한 형태
```

- [ ] **Step 2: CHANGELOG.md [Unreleased] 추가**

```markdown
- **Statusline 강화** — Phase 2 statusline 3 항목 통합. `core/scripts/statusline.sh` 신설 + `settings.template.json`의 `statusLine` 항목. verify 결과 / 마지막 hook 결과 / 활성 plan 진행도를 한 줄로 합성 (`✓v · 🔧✓ · 📋N/M`). `VIBE_FLOW_STATUSLINE=off` 비활성 옵션.
```

- [ ] **Step 3: ROADMAP.md Phase 2 statusline [x] 처리**

```markdown
#### Statusline 강화
- [x] hook live status 표시 (마지막 실행 결과)
- [x] 활성 plan 진행도 표시
- [x] verify 결과 표시 (✓/✗/⊘)
```

- [ ] **Step 4: commit**

```bash
git add docs/REFERENCE.md CHANGELOG.md ROADMAP.md
git commit -m "docs: statusline 강화를 REFERENCE/CHANGELOG/ROADMAP에 추가"
```

---

## Task 7: PR + 머지

- [ ] **Step 1**

```bash
git push -u origin feat/statusline
gh pr create --title "feat(statusline): Phase 2 statusline 3 항목 통합" --body "..."
PR_NUM=$(gh pr view --json number --jq '.number')
gh pr merge $PR_NUM --squash --delete-branch
git checkout main && git fetch origin && git reset --hard origin/main
git branch -D feat/statusline 2>/dev/null
git fetch --prune
```

---

## Self-Review

- [ ] Spec coverage: statusline.sh 모든 시그널 / settings 통합 / verbose mode / 비활성 옵션 / 테스트 모두 매핑 ✓
- [ ] Placeholder 없음
- [ ] Path consistency: `core/scripts/statusline.sh` 일관
