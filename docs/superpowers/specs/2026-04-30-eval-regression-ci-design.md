# eval 자동 회귀 알림 (CI 통합) 설계

GitHub Actions로 모든 PR에서 SKILL.md / agents.md / evals.json 구조 회귀를 자동 검증 (Phase 4 2번째).

## 의도

**문제**: vibe-flow는 28 스킬 + 12 에이전트가 PR마다 변경될 수 있다. SKILL.md frontmatter 누락, evals.json JSON 깨짐, 디렉토리 시그니처 불일치 같은 회귀가 머지 전에 자동 검출되지 않으면, 사용자가 setup.sh 실행 시 깨진 상태를 만난다.

**해결**: GitHub Actions 워크플로우로 PR + push to main에서 구조 검증 자동화. LLM 호출 없음 (즉시 가능, CI 비용 0). 회귀 시 PR check 실패.

**범위**: 구조 검증만. 실제 eval 실행(LLM 호출)은 Phase 4 미래 확장.

## 제약

- **CI 비용 0**: LLM 호출 없음. jq + bash + grep만.
- **빠름**: 1초 이내 완료 (28 스킬 × 단순 검증).
- **메이커 워크플로우 추가 0**: 메이커가 따로 할 일 없음. 자동.
- **알림 채널**: PR check (GitHub 자동 UI). 별도 Slack/email 통합 X.

## 설계

### 컴포넌트

1. **`.github/workflows/eval-regression.yml`** — Actions 워크플로우
2. **`scripts/eval-regression-check.sh`** — 검증 스크립트 (재사용 가능, 로컬 호출도 OK)

### 검증 항목

#### A. SKILL.md frontmatter

각 `core/skills/*/SKILL.md` + `extensions/*/skills/*/SKILL.md`:

```yaml
---
name: <string>           # 필수
description: <string>    # 필수, 최소 20자
model: <string>          # 필수 (예: claude-sonnet-4-6)
---
```

검증:
- frontmatter 블록 존재 (`---` 시작 + 종료)
- name / description / model 키 모두 존재
- description 길이 ≥ 20자
- model이 유효 모델명 패턴 매칭 (`claude-(opus|sonnet|haiku)-\d+` 등)

#### B. agents/*.md frontmatter

각 `core/agents/*.md` + `extensions/*/agents/*.md`:

```yaml
---
name: <string>
description: <string>
model: <string>
---
```

동일 검증.

#### C. evals.json 구조 (선택, 있으면)

각 `core/skills/*/evals/evals.json` + `extensions/*/skills/*/evals/evals.json`:

- 유효 JSON
- 필수 키: `skill`, `version`, `cases`
- `cases`는 배열, 최소 1개
- 각 케이스: `id`, `description`, `input`, `expected` 필수

evals.json 없으면 warn (fail 안 함).

#### D. 디렉토리 ↔ agents.json 일치

`core/agents.json`의 `agents` 배열과 `core/agents/*.md` 디렉토리:
- `core/agents/<name>.md` 존재해야 (agents.json에 있는 모든 항목)
- `agents.json`에 없는데 `core/agents/<name>.md` 있으면 orphan warn

#### E. 카테고리 명단 일치 (스킬)

특정 디렉토리 시그니처가 spec과 일치:
- Core skills 목록 (Phase 1 spec): brainstorm, plan, finish, release, scaffold, test, worktree, verify, security, commit, review-pr, receive-review, status, learn, onboard, menu, inbox, budget, telemetry (19 개)
- Extension skills 매핑:
  - meta-quality: eval-skill, evolve
  - design-system: design-sync, design-audit
  - deep-collaboration: pair, discuss
  - learning-loop: metrics, retrospective
  - code-feedback: feedback

명단 ↔ 디렉토리 일치 검증. 신규 스킬은 spec 갱신을 함께 요구 (PR 템플릿).

→ 단순화: spec 명단은 하드코딩하지 않고 단순 카운트 검증 (Core ≥ 19, Extensions ≥ 9). 메이커는 ROADMAP / docs/REFERENCE.md 갱신 책임.

### 출력 (검증 스크립트)

```
=== vibe-flow eval-regression check ===

✓ Core SKILL.md (19): all frontmatter valid
✓ Extension SKILL.md (9): all frontmatter valid
✓ Core agents.md (10): all frontmatter valid
✓ Extension agents.md (2): all frontmatter valid
✓ evals.json (15): all valid
✓ agents.json ↔ files: 10/10 match

=== 결과 ===
  PASS: 6 / FAIL: 0
```

실패 시:
```
✗ core/skills/foo/SKILL.md: name 누락
✗ core/skills/bar/evals/evals.json: JSON 파싱 실패
=== 결과 ===
  PASS: 4 / FAIL: 2

❌ 회귀 검출. 머지 차단.
exit 1
```

### GitHub Actions 워크플로우

```yaml
name: eval-regression

on:
  pull_request:
    paths:
      - 'core/skills/**'
      - 'core/agents/**'
      - 'extensions/**'
      - 'core/agents.json'
  push:
    branches: [main]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install jq
        run: sudo apt-get install -y jq
      - name: Run eval regression check
        run: bash scripts/eval-regression-check.sh
```

`paths` 필터로 관련 파일 변경 시만 트리거 (CI 비용 절약).

### 검증 스크립트 핵심 로직

```bash
#!/bin/bash
# eval-regression-check.sh — 구조 회귀 검증

set -u

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT" || exit 1

PASS=0
FAIL=0

ok() { echo "✓ $1"; PASS=$((PASS+1)); }
err() { echo "✗ $1"; FAIL=$((FAIL+1)); }

# A. SKILL.md frontmatter
check_skill_md() {
  local f="$1"
  local fm
  fm=$(awk '/^---$/{f++; if(f==2) exit; next} f==1{print}' "$f")
  for key in name description model; do
    if ! echo "$fm" | grep -q "^$key:"; then
      err "$f: $key 누락"
      return
    fi
  done
  local desc_len
  desc_len=$(echo "$fm" | awk '/^description:/' | sed 's/^description://;s/^ *//' | wc -c | tr -d ' ')
  [ "$desc_len" -lt 20 ] && err "$f: description < 20자"
}

# 모든 SKILL.md 검증
SKILL_FAIL_BEFORE=$FAIL
for f in core/skills/*/SKILL.md extensions/*/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  check_skill_md "$f"
done
[ "$FAIL" = "$SKILL_FAIL_BEFORE" ] && ok "All SKILL.md frontmatter valid ($(ls core/skills/*/SKILL.md extensions/*/skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' '))"

# B. agents.md frontmatter (유사)
# C. evals.json 검증
# D. agents.json ↔ files 일치
# E. 카운트 검증

# 결과
echo ""
echo "=== 결과 ==="
echo "  PASS: $PASS / FAIL: $FAIL"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
```

### Local 사용

메이커도 PR 만들기 전에 로컬 검증:
```bash
bash scripts/eval-regression-check.sh
```

### CI 알림 형태

- PR check status: `eval-regression / check` ✓ 또는 ✗
- check 실패 시 Files changed 탭에서 자동 메시지 (없음 — 표준 GH check만)
- 추가 알림 (PR 코멘트 등) YAGNI 제외

## 데이터 흐름

```
PR 생성/갱신 → GitHub Actions 트리거
   │ (paths 필터: core/skills, core/agents, extensions, agents.json)
   ▼
ubuntu-latest runner
   │
   ├─ checkout
   ├─ install jq
   └─ bash scripts/eval-regression-check.sh
      │
      ├─ A. SKILL.md frontmatter (28 파일)
      ├─ B. agents.md frontmatter (12 파일)
      ├─ C. evals.json 구조 (15 파일, 선택)
      └─ D. agents.json ↔ files 일치
      │
      ▼
   exit 0 (pass) 또는 exit 1 (fail)
   │
   ▼
GitHub PR check status 반영
```

## 의존

- **CI**: GitHub Actions (ubuntu-latest)
- **외부**: jq (apt 설치)
- **로컬 사용**: 동일 스크립트, jq 필요 (이미 vibe-flow 필수 의존)

## 다른 도구와의 비교

| | validate.sh | eval-regression-check.sh |
|---|-------------|--------------------------|
| 영역 | 사용자 프로젝트 .claude/ 검증 | vibe-flow repo 자체 SKILL.md/agents.md 검증 |
| 실행 위치 | 프로젝트 (post-setup) | repo root (pre-merge) |
| 트리거 | 수동 (`bash .claude/validate.sh`) | 자동 (CI) + 수동 |
| 회귀 영향 | 사용자 환경 | 머지 후 모든 사용자 |

`validate.sh`는 프로젝트 측 검증. `eval-regression-check.sh`는 vibe-flow 자체 PR 검증.

## YAGNI 제외

- **실제 LLM eval 실행** — Phase 4 미래 확장 (CI 비용 + secret)
- **PR 코멘트 알림** — GitHub UI check status로 충분
- **Slack/email 알림** — 외부 통합 영역
- **메이커 워크플로우 변경** — 메이커는 별도 작업 X
- **다국어** — 한국어/영어 혼용 (CI 출력은 영어 위주)

## 추가 고려

- 신규 스킬 추가 시 README/REFERENCE/CHANGELOG/ROADMAP 갱신 누락 검출은 별도 워크플로우 (이번 PR 범위 외).
- workflow 자체 회귀 (eval-regression.yml 자체 변경) 검출은 GH Actions 자체 dry-run으로 가능 (별도 작업).
