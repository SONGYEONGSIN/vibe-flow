# vibe-flow Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `claude-builds` repo를 `vibe-flow`로 리브랜드하면서 23 스킬 / 12 에이전트 / 22 훅 / 6 규칙을 Core(14 스킬 / 10 에이전트 / 22 훅 / 6 규칙) + Extensions(5 카테고리, 9 스킬 / 2 에이전트) 두 단계로 재구성한다. 단일 PR.

**Architecture:** 동일 git repo 내 `core/` + `extensions/<name>/` 디렉토리 분할. setup.sh CLI가 state 파일(`.claude/.vibe-flow.json`)을 읽고 갱신/추가/제거 처리. claude-builds → vibe-flow 마이그레이션 자동 감지(state 파일 부재 시 디렉토리 시그니처로 추론). validate.sh 9 → 10 stages.

**Tech Stack:** bash, jq (JSON parsing), git, awk/sed (text processing), Playwright (design-system extension dependency, 별도)

---

## Pre-execution Notes

**작업 디렉토리**: `/Users/yss/개발/build/claude-builds` (rename 전), Task 3 이후 `/Users/yss/개발/build/vibe-flow`.

**Spec 참조**: `docs/superpowers/specs/2026-04-30-vibe-flow-phase-1-rebrand-lighten-design.md` (커밋 8feb02d).

**전제 조건**:
- 현재 `main` 브랜치, working tree clean (`git status` 확인)
- jq, git, node, npx 설치
- GitHub repo `SONGYEONGSIN/claude-builds`에 push 권한
- 글로벌 심볼릭 (`~/.claude/{skills,agents,rules}`)이 claude-builds로 활성 (이번 세션에서 옵션 A로 설정함)

**Big Bang 정책**: 단계 commit은 logical하게 분리하되, 최종 1 PR로 머지. 각 commit은 atomic.

---

## Task 1: Pre-flight 검증 + feature branch

**Files:** None (git operations only)

- [ ] **Step 1: 현재 상태 확인**

```bash
cd /Users/yss/개발/build/claude-builds
git status
git log --oneline -3
git branch
```

Expected output:
```
On branch main
Your branch is up to date with 'origin/main'.
nothing to commit, working tree clean

8feb02d docs(spec): vibe-flow Phase 1 — rebrand + lighten 설계
20d40b9 docs: Karpathy 4 원칙 체리피킹 + 설계 철학 출처
4edfc32 fix: setup.sh의 messages/debates 디렉토리 순서 버그
```

- [ ] **Step 2: 백업 태그 생성 (롤백용)**

```bash
git tag pre-vibe-flow-phase-1 8feb02d
git push origin pre-vibe-flow-phase-1
```

Expected: `* [new tag]         pre-vibe-flow-phase-1 -> pre-vibe-flow-phase-1`

- [ ] **Step 3: feature branch 생성**

```bash
git checkout -b feat/vibe-flow-phase-1
git status
```

Expected: `On branch feat/vibe-flow-phase-1`

- [ ] **Step 4: 영향 범위 baseline 수치 확인**

```bash
echo "Skills: $(ls skills/ | wc -l | tr -d ' ')"
echo "Agents: $(ls agents/*.md | wc -l | tr -d ' ')"
echo "Hooks: $(ls hooks/*.sh | wc -l | tr -d ' ')"
echo "Rules: $(ls rules/*.md | wc -l | tr -d ' ')"
```

Expected:
```
Skills: 23
Agents: 12
Hooks: 22
Rules: 6
```

이 baseline은 마이그레이션 후 검증용 (Core 14 + Ext 9 = 23 일치 확인 등).

---

## Task 2: GitHub repo rename (수동, 5초)

**Files:** None (GitHub UI operation)

- [ ] **Step 1: GitHub 웹 UI에서 rename**

브라우저에서:
```
https://github.com/SONGYEONGSIN/claude-builds/settings
→ Repository name 필드: "claude-builds" 지우고 "vibe-flow" 입력
→ [Rename] 버튼 클릭
```

GitHub auto-redirect 활성화 확인:
```bash
curl -sI https://github.com/SONGYEONGSIN/claude-builds | grep -i location
```

Expected: `location: https://github.com/SONGYEONGSIN/vibe-flow`

- [ ] **Step 2: 재명명 확인**

```bash
curl -sI https://github.com/SONGYEONGSIN/vibe-flow | head -1
```

Expected: `HTTP/2 200`

---

## Task 3: 로컬 repo 갱신

**Files:** None (filesystem + git config)

- [ ] **Step 1: 로컬 디렉토리 mv**

```bash
cd /Users/yss/개발/build
mv claude-builds vibe-flow
ls -la | grep -E "claude-builds|vibe-flow"
```

Expected: `vibe-flow` 디렉토리만 보임 (claude-builds 없음)

- [ ] **Step 2: git remote URL 갱신**

```bash
cd /Users/yss/개발/build/vibe-flow
git remote -v
git remote set-url origin https://github.com/SONGYEONGSIN/vibe-flow.git
git remote -v
```

Expected after:
```
origin  https://github.com/SONGYEONGSIN/vibe-flow.git (fetch)
origin  https://github.com/SONGYEONGSIN/vibe-flow.git (push)
```

- [ ] **Step 3: fetch/pull 동작 검증**

```bash
git fetch origin
git status
```

Expected: 에러 없음, branch가 origin과 동기화됨.

- [ ] **Step 4: 작업 디렉토리 위치 확인**

```bash
pwd
```

Expected: `/Users/yss/개발/build/vibe-flow`

이후 모든 Task는 이 디렉토리에서 실행.

---

## Task 4: Self-reference 일괄 갱신

**Files:**
- Modify: 다수 (`claude-builds` 단순 명사 출현 위치)
- Skip: `CHANGELOG.md` (역사 기록), `.git/`

- [ ] **Step 1: 현재 출현 위치 inventory**

```bash
cd /Users/yss/개발/build/vibe-flow
grep -rln "claude-builds" --exclude-dir=.git --exclude=CHANGELOG.md > /tmp/cb-refs.txt
wc -l /tmp/cb-refs.txt
cat /tmp/cb-refs.txt
```

Expected: ~15-25개 파일. 주요 후보: README.md, ROADMAP.md, setup.sh, validate.sh, sync-memory.sh, hooks/*.sh, templates/*, rules/*.md.

- [ ] **Step 2: 일괄 sed 치환**

```bash
while read f; do
  sed -i.tmp 's/claude-builds/vibe-flow/g' "$f" && rm "${f}.tmp"
  echo "  ✓ $f"
done < /tmp/cb-refs.txt
```

Expected: 모든 파일에 `✓` 마크.

- [ ] **Step 3: 결과 검증 — 잔여 출현 확인**

```bash
grep -rln "claude-builds" --exclude-dir=.git --exclude=CHANGELOG.md
```

Expected: 출력 없음 (모두 vibe-flow로 치환).

CHANGELOG.md만 의도적으로 보존 — 역사 사실:
```bash
grep -c "claude-builds" CHANGELOG.md
```

Expected: > 0 (역사 항목에서 보존됨)

- [ ] **Step 4: 변경 파일 검토**

```bash
git status
git diff --stat | tail -5
```

수정된 파일 수와 changes 합계 확인. 약 15-25 files changed.

- [ ] **Step 5: 임시 commit (rollback 단위)**

```bash
git add -u
git commit -m "chore: claude-builds → vibe-flow 자체 참조 일괄 갱신

CHANGELOG.md는 역사 기록이라 의도적 보존."
```

Expected: 새 commit 생성. `git log --oneline -1` 확인.

---

## Task 5: 디렉토리 scaffold (Core + Extensions)

**Files:**
- Create: `core/{skills,agents,hooks,rules}/`
- Create: `extensions/{meta-quality,design-system,deep-collaboration,learning-loop,code-feedback}/{skills,agents}/`

- [ ] **Step 1: Core 디렉토리 생성**

```bash
mkdir -p core/{skills,agents,hooks,rules}
```

- [ ] **Step 2: Extensions 디렉토리 생성**

```bash
for ext in meta-quality design-system deep-collaboration learning-loop code-feedback; do
  mkdir -p "extensions/$ext/skills"
  mkdir -p "extensions/$ext/agents"
done
```

design-system, deep-collaboration, learning-loop, code-feedback은 agents 디렉토리 비어 있을 수 있음 — 비어있는 디렉토리를 git 추적하기 위해 `.gitkeep`:

```bash
for ext in design-system deep-collaboration learning-loop code-feedback; do
  touch "extensions/$ext/agents/.gitkeep"
done
```

- [ ] **Step 3: 구조 확인**

```bash
find core extensions -type d | sort
```

Expected:
```
core
core/agents
core/hooks
core/rules
core/skills
extensions
extensions/code-feedback
extensions/code-feedback/agents
extensions/code-feedback/skills
extensions/deep-collaboration
extensions/deep-collaboration/agents
extensions/deep-collaboration/skills
extensions/design-system
extensions/design-system/agents
extensions/design-system/skills
extensions/learning-loop
extensions/learning-loop/agents
extensions/learning-loop/skills
extensions/meta-quality
extensions/meta-quality/agents
extensions/meta-quality/skills
```

- [ ] **Step 4: 임시 commit (scaffold 단위)**

```bash
git add core/ extensions/
git commit -m "chore: core/ + extensions/<5> 디렉토리 scaffold"
```

---

## Task 6: Core skills 14개 이동

**Files:**
- Modify: `skills/<14>/` → `core/skills/<14>/`

Core 14 스킬: brainstorm, plan, finish, release, scaffold, test, worktree, verify, security, commit, review-pr, receive-review, status, learn

- [ ] **Step 1: 이동 대상 변수 정의**

```bash
CORE_SKILLS="brainstorm plan finish release scaffold test worktree verify security commit review-pr receive-review status learn"
echo "Core skills count: $(echo $CORE_SKILLS | wc -w | tr -d ' ')"
```

Expected: `Core skills count: 14`

- [ ] **Step 2: git mv로 이동 (각 스킬은 디렉토리)**

```bash
for skill in $CORE_SKILLS; do
  git mv "skills/$skill" "core/skills/$skill"
done
```

git mv는 history 보존 + GitHub auto-detect rename.

- [ ] **Step 3: 결과 검증**

```bash
ls core/skills/ | wc -l | tr -d ' '
ls skills/ | wc -l | tr -d ' '
```

Expected:
- core/skills/ 카운트: 14
- skills/ 카운트: 9 (extensions로 갈 9개 남음)

- [ ] **Step 4: 임시 commit**

```bash
git commit -m "refactor: Core 14 스킬을 core/skills/로 이동

git mv로 history 보존."
```

---

## Task 7: Core agents 10개 이동

**Files:**
- Modify: `agents/<10>.md` → `core/agents/<10>.md`

Core 10 에이전트: developer, qa, security, validator, planner, feedback, moderator, comparator, designer, retrospective

- [ ] **Step 1: 이동 변수**

```bash
CORE_AGENTS="developer qa security validator planner feedback moderator comparator designer retrospective"
echo "Core agents count: $(echo $CORE_AGENTS | wc -w | tr -d ' ')"
```

Expected: `Core agents count: 10`

- [ ] **Step 2: 이동**

```bash
for agent in $CORE_AGENTS; do
  git mv "agents/$agent.md" "core/agents/$agent.md"
done
```

- [ ] **Step 3: 검증**

```bash
ls core/agents/*.md | wc -l | tr -d ' '
ls agents/*.md | wc -l | tr -d ' '
```

Expected:
- core/agents/: 10
- agents/: 2 (skill-reviewer, grader → extensions/meta-quality)

- [ ] **Step 4: 임시 commit**

```bash
git commit -m "refactor: Core 10 에이전트를 core/agents/로 이동"
```

---

## Task 8: Hooks 22개 + _common.sh 이동

**Files:**
- Modify: `hooks/*.sh` → `core/hooks/*.sh`

모든 hook은 core. 22 .sh 파일 + 디렉토리 자체 통째 이동.

- [ ] **Step 1: 이동 (모든 .sh 파일)**

```bash
git mv hooks/*.sh core/hooks/
```

- [ ] **Step 2: 빈 hooks/ 디렉토리 정리**

```bash
rmdir hooks
```

- [ ] **Step 3: 검증**

```bash
ls core/hooks/*.sh | wc -l | tr -d ' '
[ -d hooks ] && echo "hooks/ 잔존" || echo "✓ hooks/ 제거됨"
```

Expected:
- core/hooks/: 22
- ✓ hooks/ 제거됨

- [ ] **Step 4: 임시 commit**

```bash
git commit -m "refactor: 22 훅을 core/hooks/로 이동"
```

---

## Task 9: Rules 6개 + agents.json 이동

**Files:**
- Modify: `rules/*.md` → `core/rules/*.md`
- Modify: `agents.json` → `core/agents.json`

- [ ] **Step 1: 규칙 이동**

```bash
git mv rules/*.md core/rules/
rmdir rules
```

- [ ] **Step 2: agents.json 이동**

```bash
git mv agents.json core/agents.json
```

- [ ] **Step 3: agents.json을 Core 10으로 필터**

agents.json은 현재 12개 모두 listing. Core는 10만:

```bash
jq '.agents |= map(select(. != "skill-reviewer" and . != "grader"))' core/agents.json > core/agents.json.tmp
mv core/agents.json.tmp core/agents.json
jq '.agents | length' core/agents.json
```

Expected: `10`

- [ ] **Step 4: 검증**

```bash
ls core/rules/*.md | wc -l | tr -d ' '
[ -f core/agents.json ] && jq '.agents' core/agents.json
```

Expected:
- core/rules/: 6
- agents.json에 10개 (skill-reviewer, grader 없음)

- [ ] **Step 5: 임시 commit**

```bash
git commit -m "refactor: Rules + agents.json을 core/로 이동, agents.json은 Core 10으로 필터"
```

---

## Task 10: Extensions skills 9개 분배

**Files:**
- Modify: `skills/<9>/` → `extensions/<category>/skills/<name>/`

분포:
- meta-quality: eval-skill, evolve
- design-system: design-sync, design-audit
- deep-collaboration: pair, discuss
- learning-loop: metrics, retrospective
- code-feedback: feedback

- [ ] **Step 1: meta-quality 스킬 이동**

```bash
git mv skills/eval-skill extensions/meta-quality/skills/eval-skill
git mv skills/evolve extensions/meta-quality/skills/evolve
```

- [ ] **Step 2: design-system 스킬 이동**

```bash
git mv skills/design-sync extensions/design-system/skills/design-sync
git mv skills/design-audit extensions/design-system/skills/design-audit
```

- [ ] **Step 3: deep-collaboration 스킬 이동**

```bash
git mv skills/pair extensions/deep-collaboration/skills/pair
git mv skills/discuss extensions/deep-collaboration/skills/discuss
```

- [ ] **Step 4: learning-loop 스킬 이동**

```bash
git mv skills/metrics extensions/learning-loop/skills/metrics
git mv skills/retrospective extensions/learning-loop/skills/retrospective
```

- [ ] **Step 5: code-feedback 스킬 이동**

```bash
git mv skills/feedback extensions/code-feedback/skills/feedback
rmdir skills
```

- [ ] **Step 6: 검증**

```bash
[ -d skills ] && echo "skills/ 잔존" || echo "✓ skills/ 제거됨"
for ext in meta-quality design-system deep-collaboration learning-loop code-feedback; do
  count=$(ls extensions/$ext/skills | wc -l | tr -d ' ')
  echo "  $ext: $count"
done
```

Expected:
```
✓ skills/ 제거됨
  meta-quality: 2
  design-system: 2
  deep-collaboration: 2
  learning-loop: 2
  code-feedback: 1
```

총 9 = β+ Extensions 정합 ✓

- [ ] **Step 7: 임시 commit**

```bash
git commit -m "refactor: Extensions 9 스킬을 카테고리별 분배

meta-quality(2) / design-system(2) / deep-collaboration(2) /
learning-loop(2) / code-feedback(1)"
```

---

## Task 11: Extension agents 2개 이동

**Files:**
- Modify: `agents/skill-reviewer.md` → `extensions/meta-quality/agents/skill-reviewer.md`
- Modify: `agents/grader.md` → `extensions/meta-quality/agents/grader.md`

- [ ] **Step 1: 이동**

```bash
git mv agents/skill-reviewer.md extensions/meta-quality/agents/skill-reviewer.md
git mv agents/grader.md extensions/meta-quality/agents/grader.md
rmdir agents
```

- [ ] **Step 2: 검증**

```bash
[ -d agents ] && echo "agents/ 잔존" || echo "✓ agents/ 제거됨"
ls extensions/meta-quality/agents/*.md | wc -l | tr -d ' '
```

Expected:
```
✓ agents/ 제거됨
2
```

- [ ] **Step 3: 임시 commit**

```bash
git commit -m "refactor: skill-reviewer + grader를 extensions/meta-quality/agents/로"
```

---

## Task 12: Extensions README.md 5개 작성

**Files:**
- Create: `extensions/{name}/README.md` (5 files)

각 extension 폴더에 자체 설명. setup.sh `--info <name>` 명령이 이걸 읽어 보여줌.

- [ ] **Step 1: meta-quality README**

```bash
cat > extensions/meta-quality/README.md <<'EOF'
# meta-quality Extension

스킬 자체 품질 측정 + 자가 진화. 메이커/상급자 도구.

## 포함

| 종류 | 항목 | 설명 |
|------|------|------|
| Skill | `/eval <skill>` | 스킬 evals 실행 → pass rate 측정 |
| Skill | `/evolve <skill>` | eval 결과 분석 → SKILL.md 개선 후보 + 5 게이트 + A/B 비교 |
| Agent | `skill-reviewer` | SKILL.md 8단계 검토 → 100점 스코어카드 |
| Agent | `grader` | eval 채점 (PASS/FAIL + 0.0~1.0) |

## 의존

- Core (events.jsonl, comparator 에이전트)
- 외부 의존 없음

## 사용 시나리오

- 메이커가 만든 스킬의 품질 정량화
- self-improving 루프 핵심 (Hermes Agent 패턴)
- 회고에서 스킬 퇴보 감지 시 evolve 후보 자동 생성

## 설치

```bash
bash setup.sh --extensions meta-quality
```
EOF
```

- [ ] **Step 2: design-system README**

```bash
cat > extensions/design-system/README.md <<'EOF'
# design-system Extension

참고 디자인을 코드와 정량 매칭. URL/이미지/HTML에서 CSS 추출 + 비주얼 회귀 테스트.

## 포함

| 종류 | 항목 | 설명 |
|------|------|------|
| Skill | `/design-sync <URL\|이미지\|--from-file>` | 7/5/6 단계 자동 워크플로우, 싱크율 95%/85~90%/92% 목표 |
| Skill | `/design-audit` | 토큰 커버리지, 하드코딩 색상, 중복 UI 패턴 감사 |

## 의존

- Core (designer 에이전트는 core에 있음 — Phase 0 자율 모드 가능)
- **외부**: `playwright`, `sharp`, `pixelmatch`, `pngjs` (별도 npm i)

```bash
npm install -D playwright sharp pixelmatch pngjs
npx playwright install chromium
```

## 사용 시나리오

- 디자이너가 제공한 참고 디자인 (URL/Figma export 이미지) → 코드베이스 자동 매칭
- 디자인 부패 정기 감사 (`/design-audit`)
- 다크 모드 / 멀티 뷰포트 / hover 상태 시각적 회귀 테스트

## 설치

```bash
bash setup.sh --extensions design-system
# 의존성 별도 설치 후
npm install -D playwright sharp pixelmatch pngjs
```
EOF
```

- [ ] **Step 3: deep-collaboration README**

```bash
cat > extensions/deep-collaboration/README.md <<'EOF'
# deep-collaboration Extension

Builder/Validator 페어 + 구조화된 토론. 다중 에이전트 협업 깊은 사용.

## 포함

| 종류 | 항목 | 설명 |
|------|------|------|
| Skill | `/pair "<task>"` | developer → validator 자동 루프 (최대 3 iter), 교착 시 moderator |
| Skill | `/discuss "<topic>"` | 에이전트 간 구조화된 토론 (Opening → Rebuttal → Verdict) |

## 의존

- Core (developer, validator, moderator 에이전트 + message-bus 훅)
- 외부 의존 없음

## 사용 시나리오

- 복잡한 기능 자가 검증 (단일 에이전트 confirmation bias 회피)
- 에이전트 간 의견 충돌 시 구조화된 합의 도출
- 토론 verdict이 retrospective 분석 입력

## 설치

```bash
bash setup.sh --extensions deep-collaboration
```
EOF
```

- [ ] **Step 4: learning-loop README**

```bash
cat > extensions/learning-loop/README.md <<'EOF'
# learning-loop Extension

장기 데이터 분석 — 메트릭 추이 + 회고 + 개선안 도출.

## 포함

| 종류 | 항목 | 설명 |
|------|------|------|
| Skill | `/metrics [today\|week\|all]` | 빌드 성공률, 에러 빈도, 핫스팟 대시보드 |
| Skill | `/retrospective` | 메트릭+세션로그+events 분석 → P0/P1/P2 개선안 |

## 의존

- Core (events.jsonl, retrospective 에이전트, store.db)
- 외부 의존 없음

## 사용 시나리오

- 주간/격주 정기 회고
- 반복 에러 패턴 식별
- 스킬 자가 진화 트리거 (퇴보 감지 → /evolve 권장)
- 장기 trend (1개월+ 누적 후 가치)

## 설치

```bash
bash setup.sh --extensions learning-loop
```

> **권장**: meta-quality와 함께 활성화 — retrospective가 eval benchmark 분석 가능.
EOF
```

- [ ] **Step 5: code-feedback README**

```bash
cat > extensions/code-feedback/README.md <<'EOF'
# code-feedback Extension

git diff 기반 변경 단위 품질 분석.

## 포함

| 종류 | 항목 | 설명 |
|------|------|------|
| Skill | `/feedback` | 최근 git diff 분석 → 코드 품질 점수 + 개선 제안 |

## 의존

- Core (feedback 에이전트는 core에 있음)
- 외부 의존: git

## 사용 시나리오

- PR 직전 자가 검토
- 작업 중간 점검 (큰 변경 후)
- review-pr / receive-review 와 함께 사용

## 설치

```bash
bash setup.sh --extensions code-feedback
```
EOF
```

- [ ] **Step 6: 검증 + commit**

```bash
ls extensions/*/README.md
git add extensions/*/README.md
git commit -m "docs: extensions/<5>/README.md 작성

각 extension의 포함, 의존, 사용 시나리오, 설치 명령 명시."
```

Expected: 5 README.md 파일.

---

## Task 13: setup.sh 리팩터링 (Core/Extensions 인식)

**Files:**
- Modify: `setup.sh` — 디렉토리 변경 반영 (skills/ → core/skills/ 등)

기존 setup.sh가 `$SCRIPT_DIR/skills/` 등 평면 구조 가정. 이를 `core/` 구조로 변경.

- [ ] **Step 1: 현재 setup.sh의 path 참조 inventory**

```bash
grep -nE '\$SCRIPT_DIR/(skills|agents|hooks|rules|agents\.json)' setup.sh
```

확인할 라인 (대략): 68, 78, 82, 102, 110(이근처) 등.

- [ ] **Step 2: setup.sh path 갱신 (sed)**

```bash
sed -i.tmp \
  -e 's|\$SCRIPT_DIR/agents.json|$SCRIPT_DIR/core/agents.json|g' \
  -e 's|\$SCRIPT_DIR/agents/|$SCRIPT_DIR/core/agents/|g' \
  -e 's|\$SCRIPT_DIR/hooks/|$SCRIPT_DIR/core/hooks/|g' \
  -e 's|\$SCRIPT_DIR/rules/|$SCRIPT_DIR/core/rules/|g' \
  -e 's|\$SCRIPT_DIR/skills"/|$SCRIPT_DIR/core/skills"/|g' \
  -e 's|\$SCRIPT_DIR/skills/|$SCRIPT_DIR/core/skills/|g' \
  setup.sh
rm setup.sh.tmp
```

- [ ] **Step 3: 검증 — 기존 사용 path가 모두 core/로 prefix됐는지**

```bash
grep -nE '\$SCRIPT_DIR/(skills|agents|hooks|rules|agents\.json)' setup.sh
# 출력 없어야 함 (모두 core/ prefix됐으니)

grep -nE '\$SCRIPT_DIR/core/' setup.sh
# 출력 있어야 함 (5+ 라인)
```

- [ ] **Step 4: 단위 테스트 — 새 빈 디렉토리에 setup 실행**

```bash
mkdir /tmp/vibe-flow-test-1 && cd /tmp/vibe-flow-test-1
bash /Users/yss/개발/build/vibe-flow/setup.sh
ls .claude/skills/ | wc -l
```

Expected: 14 (Core 14 스킬만 설치) — 단, 이번 Task에서는 setup.sh가 아직 Core only 모드를 모름 → 23 모두 설치되거나 에러 가능. 다음 Task에서 CLI 분기 추가.

만약 23이 나오면: setup.sh가 여전히 core/skills/ 만 보고 있음 — 14 정확. 또는 path 누락이 있다면 0 또는 일부.

- [ ] **Step 5: 임시 commit**

```bash
cd /Users/yss/개발/build/vibe-flow
git add setup.sh
git commit -m "refactor(setup): SCRIPT_DIR path를 core/ 구조에 맞춤

skills/, agents/, hooks/, rules/, agents.json 모두 core/ prefix."
```

---

## Task 14: setup.sh — 옵션 파싱 확장 (--extensions, --all, --remove-extension, --list-extensions, --info, --check)

**Files:**
- Modify: `setup.sh`

- [ ] **Step 1: 옵션 파싱 섹션 위치 찾기**

```bash
grep -n "옵션 파싱\|WITH_ORCHESTRATORS\|FORCE=false" setup.sh
```

- [ ] **Step 2: 기존 옵션 파싱 블록을 새 블록으로 교체**

기존 (대략 라인 52-60):
```bash
WITH_ORCHESTRATORS=false
FORCE=false
for arg in "$@"; do
  case "$arg" in
    --with-orchestrators) WITH_ORCHESTRATORS=true ;;
    --force) FORCE=true ;;
  esac
done
```

새 옵션 파싱:
```bash
# 옵션 파싱
WITH_ORCHESTRATORS=false
FORCE=false
INSTALL_ALL=false
LIST_EXTENSIONS=false
INFO_EXT=""
CHECK_ONLY=false
REMOVE_EXT=""
EXTENSIONS_TO_INSTALL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --with-orchestrators) WITH_ORCHESTRATORS=true ;;
    --force) FORCE=true ;;
    --all) INSTALL_ALL=true ;;
    --list-extensions) LIST_EXTENSIONS=true ;;
    --info) shift; INFO_EXT="$1" ;;
    --check) CHECK_ONLY=true ;;
    --remove-extension) shift; REMOVE_EXT="$1" ;;
    --extensions)
      shift
      # comma-separated 또는 반복
      if [ -n "$EXTENSIONS_TO_INSTALL" ]; then
        EXTENSIONS_TO_INSTALL="$EXTENSIONS_TO_INSTALL,$1"
      else
        EXTENSIONS_TO_INSTALL="$1"
      fi
      ;;
    *) echo "ERROR: 알 수 없는 옵션: $1" >&2; exit 1 ;;
  esac
  shift
done
```

기존 블록을 sed/Edit으로 교체 (파일 직접 편집 권장 — sed로 다중라인 교체는 복잡).

- [ ] **Step 3: 단위 테스트**

```bash
# 옵션 인식 테스트 — 본격 실행 전 단순 echo로 검증
bash setup.sh --list-extensions 2>&1 | head -3
# 아직 LIST_EXTENSIONS=true 후 처리 로직 없음 → 일반 setup 실행됨
# 다음 Task에서 처리 추가.
```

- [ ] **Step 4: 임시 commit**

```bash
git add setup.sh
git commit -m "feat(setup): CLI 옵션 파싱 확장 — --extensions/--all/--list/--info/--check/--remove-extension"
```

---

## Task 15: setup.sh — 옵션 분기 처리 + extensions metadata 함수

**Files:**
- Modify: `setup.sh`

- [ ] **Step 1: 옵션 파싱 다음에 분기 처리 + 헬퍼 함수 추가**

setup.sh 옵션 파싱 블록 다음에 추가:

```bash
# 사용 가능한 extensions 목록 (metadata)
get_extensions_list() {
  echo "meta-quality"
  echo "design-system"
  echo "deep-collaboration"
  echo "learning-loop"
  echo "code-feedback"
}

get_extension_summary() {
  case "$1" in
    meta-quality)        echo "스킬 자체 품질 측정 + 자가 진화 (/eval, /evolve)" ;;
    design-system)       echo "참고 디자인 → 코드 정량 매칭 (/design-sync, /design-audit)" ;;
    deep-collaboration)  echo "Builder/Validator 페어 + 토론 (/pair, /discuss)" ;;
    learning-loop)       echo "장기 메트릭 + 회고 (/metrics, /retrospective)" ;;
    code-feedback)       echo "git diff 기반 품질 분석 (/feedback)" ;;
    *) echo "(알 수 없는 extension)" ;;
  esac
}

# --list-extensions 처리 (조기 종료)
if [ "$LIST_EXTENSIONS" = true ]; then
  echo "=== vibe-flow Extensions ==="
  echo ""
  for ext in $(get_extensions_list); do
    printf "  %-22s %s\n" "$ext" "$(get_extension_summary "$ext")"
  done
  echo ""
  echo "설치: bash setup.sh --extensions <name>[,<name2>...]"
  echo "상세: bash setup.sh --info <name>"
  exit 0
fi

# --info <name> 처리 (조기 종료)
if [ -n "$INFO_EXT" ]; then
  README="$SCRIPT_DIR/extensions/$INFO_EXT/README.md"
  if [ -f "$README" ]; then
    cat "$README"
  else
    echo "ERROR: extension '$INFO_EXT' 없음" >&2
    echo "사용 가능: $(get_extensions_list | tr '\n' ' ')" >&2
    exit 1
  fi
  exit 0
fi

# --check 처리 (validate.sh 호출)
if [ "$CHECK_ONLY" = true ]; then
  if [ -f "$PROJECT_DIR/.claude/validate.sh" ]; then
    exec bash "$PROJECT_DIR/.claude/validate.sh"
  else
    echo "ERROR: .claude/validate.sh 없음 — 먼저 setup.sh 실행" >&2
    exit 1
  fi
fi
```

setup.sh의 SCRIPT_DIR 정의 직후 또는 옵션 파싱 직후에 위치.

- [ ] **Step 2: 단위 테스트 — `--list-extensions`**

```bash
bash setup.sh --list-extensions
```

Expected output:
```
=== vibe-flow Extensions ===

  meta-quality           스킬 자체 품질 측정 + 자가 진화 (/eval, /evolve)
  design-system          참고 디자인 → 코드 정량 매칭 (/design-sync, /design-audit)
  deep-collaboration     Builder/Validator 페어 + 토론 (/pair, /discuss)
  learning-loop          장기 메트릭 + 회고 (/metrics, /retrospective)
  code-feedback          git diff 기반 품질 분석 (/feedback)

설치: bash setup.sh --extensions <name>[,<name2>...]
상세: bash setup.sh --info <name>
```

- [ ] **Step 3: 단위 테스트 — `--info meta-quality`**

```bash
bash setup.sh --info meta-quality | head -10
```

Expected: meta-quality README의 첫 10줄 출력.

- [ ] **Step 4: 단위 테스트 — `--info nonexistent`**

```bash
bash setup.sh --info nonexistent
echo "exit=$?"
```

Expected: ERROR 메시지 + exit=1

- [ ] **Step 5: commit**

```bash
git add setup.sh
git commit -m "feat(setup): --list-extensions / --info / --check 분기 처리

list-extensions: 5 extensions 명단 + 설명
info <name>: 해당 extension의 README 출력
check: validate.sh 단축 호출"
```

---

## Task 16: setup.sh — Extensions 설치 함수 + 상태 파일 생성

**Files:**
- Modify: `setup.sh`

- [ ] **Step 1: 헬퍼 함수 추가 — install_extension**

setup.sh의 헬퍼 함수 영역 (safe_copy 근처)에 추가:

```bash
# Extension 한 개 설치 (skills + agents 디렉토리 복사)
# Args: $1 = extension name
install_extension() {
  local ext="$1"
  local src="$SCRIPT_DIR/extensions/$ext"
  if [ ! -d "$src" ]; then
    echo "  ✗ extension '$ext' 없음" >&2
    return 1
  fi

  echo "  Extension: $ext 설치..."
  local installed_files=()

  # Skills 복사
  if [ -d "$src/skills" ]; then
    for skill_dir in "$src/skills"/*/; do
      [ -d "$skill_dir" ] || continue
      local skill_name="$(basename "$skill_dir")"
      mkdir -p "$PROJECT_DIR/.claude/skills/$skill_name"
      safe_copy "$skill_dir/SKILL.md" "$PROJECT_DIR/.claude/skills/$skill_name/SKILL.md"
      # 하위 디렉토리 (evals/, references/, scripts/)
      for sub_dir in "$skill_dir"*/; do
        [ -d "$sub_dir" ] || continue
        local sub_name="$(basename "$sub_dir")"
        mkdir -p "$PROJECT_DIR/.claude/skills/$skill_name/$sub_name"
        cp "$sub_dir"* "$PROJECT_DIR/.claude/skills/$skill_name/$sub_name/" 2>/dev/null || true
      done
      installed_files+=(".claude/skills/$skill_name/")
      echo "    [+] .claude/skills/$skill_name/"
    done
  fi

  # Agents 복사
  if [ -d "$src/agents" ]; then
    for agent_file in "$src/agents"/*.md; do
      [ -f "$agent_file" ] || continue
      local agent_name="$(basename "$agent_file")"
      safe_copy "$agent_file" "$PROJECT_DIR/.claude/agents/$agent_name"
      installed_files+=(".claude/agents/$agent_name")
      echo "    [+] .claude/agents/$agent_name"
    done
  fi

  # state 파일 갱신
  update_state_extension "$ext" "${installed_files[@]}"

  echo "  ✓ $ext: ${#installed_files[@]} 파일 설치됨"
}

# State 파일에 extension 정보 추가/갱신
# Args: $1 = ext name, $2... = file list
update_state_extension() {
  local ext="$1"
  shift
  local files=("$@")

  local state_file="$PROJECT_DIR/.claude/.vibe-flow.json"
  ensure_state_file

  local files_json=$(printf '%s\n' "${files[@]}" | jq -R . | jq -s .)
  local now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  jq --arg ext "$ext" \
     --argjson files "$files_json" \
     --arg now "$now" \
     '.extensions[$ext] = {
        version: "1.0.0",
        installed_at: $now,
        files: $files
      } | .last_updated_at = $now' \
     "$state_file" > "$state_file.tmp"
  mv "$state_file.tmp" "$state_file"
}

# State 파일이 없으면 초기 생성
ensure_state_file() {
  local state_file="$PROJECT_DIR/.claude/.vibe-flow.json"
  if [ ! -f "$state_file" ]; then
    local now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    jq -n --arg now "$now" '{
      vibe_flow_version: "1.0.0",
      installed_at: $now,
      last_updated_at: $now,
      core_files: [],
      extensions: {}
    }' > "$state_file"
  fi
}
```

- [ ] **Step 2: setup.sh 메인 흐름에 extensions 설치 분기 추가**

기존 마지막 단계 (Setup complete 메시지 직전)에 추가:

```bash
# Extensions 설치
ensure_state_file

if [ "$INSTALL_ALL" = true ]; then
  echo ""
  echo "=== Installing all extensions ==="
  for ext in $(get_extensions_list); do
    install_extension "$ext"
  done
elif [ -n "$EXTENSIONS_TO_INSTALL" ]; then
  echo ""
  echo "=== Installing extensions ==="
  IFS=',' read -ra EXTS <<< "$EXTENSIONS_TO_INSTALL"
  for ext in "${EXTS[@]}"; do
    install_extension "$ext"
  done
elif [ -f "$PROJECT_DIR/.claude/.vibe-flow.json" ]; then
  # State 기반 replay (이미 설치된 extensions 갱신)
  EXISTING=$(jq -r '.extensions | keys[]' "$PROJECT_DIR/.claude/.vibe-flow.json" 2>/dev/null)
  if [ -n "$EXISTING" ]; then
    echo ""
    echo "=== Updating installed extensions ==="
    for ext in $EXISTING; do
      install_extension "$ext"
    done
  fi
fi
```

- [ ] **Step 3: 단위 테스트 — Core only**

```bash
rm -rf /tmp/vibe-flow-test-2
mkdir /tmp/vibe-flow-test-2 && cd /tmp/vibe-flow-test-2
bash /Users/yss/개발/build/vibe-flow/setup.sh 2>&1 | tail -10
ls .claude/skills/ | wc -l
[ -f .claude/.vibe-flow.json ] && echo "✓ state 파일 생성됨"
jq '.extensions' .claude/.vibe-flow.json
```

Expected:
- 14 (Core 14)
- ✓ state 파일 생성됨
- `{}` (extensions 없음)

- [ ] **Step 4: 단위 테스트 — `--extensions meta-quality`**

```bash
rm -rf /tmp/vibe-flow-test-3
mkdir /tmp/vibe-flow-test-3 && cd /tmp/vibe-flow-test-3
bash /Users/yss/개발/build/vibe-flow/setup.sh --extensions meta-quality 2>&1 | tail -15
ls .claude/skills/ | wc -l
ls .claude/agents/ | wc -l
jq '.extensions["meta-quality"]' .claude/.vibe-flow.json
```

Expected:
- skills 16 (Core 14 + 2 meta-quality)
- agents 12 (Core 10 + 2 meta-quality)
- state에 meta-quality 항목 + files 배열

- [ ] **Step 5: 단위 테스트 — `--all`**

```bash
rm -rf /tmp/vibe-flow-test-4
mkdir /tmp/vibe-flow-test-4 && cd /tmp/vibe-flow-test-4
bash /Users/yss/개발/build/vibe-flow/setup.sh --all 2>&1 | tail -20
ls .claude/skills/ | wc -l
ls .claude/agents/ | wc -l
jq '.extensions | keys' .claude/.vibe-flow.json
```

Expected:
- skills 23 (Core 14 + Ext 9)
- agents 12 (Core 10 + Ext 2)
- 5 extensions 모두 state에 등재

- [ ] **Step 6: commit**

```bash
cd /Users/yss/개발/build/vibe-flow
git add setup.sh
git commit -m "feat(setup): Extensions 설치 + state 파일 (.vibe-flow.json)

install_extension(): skills + agents 복사, state 자동 갱신
update_state_extension(): jq로 .extensions 업데이트
ensure_state_file(): 첫 실행 시 schema 초기화
--all: 5 extensions 모두 설치
--extensions <list>: 선택 설치 (comma-separated)
state replay: 옵션 없이 재실행 시 이미 설치된 ext 자동 갱신"
```

---

## Task 17: setup.sh — `--remove-extension <name>` 처리

**Files:**
- Modify: `setup.sh`

- [ ] **Step 1: 제거 함수 추가**

```bash
# Extension 제거 (state에 명시된 파일만 정확히 제거)
# Args: $1 = ext name
remove_extension() {
  local ext="$1"
  local state_file="$PROJECT_DIR/.claude/.vibe-flow.json"

  if [ ! -f "$state_file" ]; then
    echo "ERROR: .vibe-flow.json 없음 — 설치된 extension 없음" >&2
    return 1
  fi

  if ! jq -e ".extensions[\"$ext\"]" "$state_file" >/dev/null; then
    echo "ERROR: extension '$ext' 미설치" >&2
    return 1
  fi

  echo "Extension: $ext 제거..."
  jq -r ".extensions[\"$ext\"].files[]" "$state_file" | while read f; do
    full="$PROJECT_DIR/$f"
    if [ -d "$full" ]; then
      rm -rf "$full"
      echo "  [-] $f"
    elif [ -f "$full" ]; then
      rm "$full"
      echo "  [-] $f"
    fi
  done

  # state에서 항목 제거
  local now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  jq --arg ext "$ext" --arg now "$now" \
     'del(.extensions[$ext]) | .last_updated_at = $now' \
     "$state_file" > "$state_file.tmp"
  mv "$state_file.tmp" "$state_file"

  echo "  ✓ $ext 제거됨"
}
```

- [ ] **Step 2: 메인 흐름 분기 처리 추가**

옵션 분기 처리 블록 (--list-extensions / --info / --check 직후)에:

```bash
# --remove-extension 처리
if [ -n "$REMOVE_EXT" ]; then
  remove_extension "$REMOVE_EXT"
  exit $?
fi
```

- [ ] **Step 3: 단위 테스트**

```bash
cd /tmp/vibe-flow-test-3   # meta-quality 설치된 상태
bash /Users/yss/개발/build/vibe-flow/setup.sh --remove-extension meta-quality
ls .claude/skills/ | wc -l   # 14로 감소 (Core만)
ls .claude/agents/ | wc -l   # 10으로 감소
jq '.extensions' .claude/.vibe-flow.json   # {}
```

Expected:
- 14 / 10 / `{}`

- [ ] **Step 4: 에러 케이스 테스트**

```bash
bash /Users/yss/개발/build/vibe-flow/setup.sh --remove-extension nonexistent 2>&1
echo "exit=$?"
```

Expected: ERROR + exit=1

- [ ] **Step 5: commit**

```bash
cd /Users/yss/개발/build/vibe-flow
git add setup.sh
git commit -m "feat(setup): --remove-extension <name>

state.extensions[name].files 배열을 정확히 제거 + state 갱신.
미설치 / 미인식 ext에 대해 에러 메시지 + exit 1."
```

---

## Task 18: setup.sh — 마이그레이션 자동 감지 (claude-builds → vibe-flow)

**Files:**
- Modify: `setup.sh`

- [ ] **Step 1: 마이그레이션 감지 함수 추가**

```bash
# claude-builds → vibe-flow 마이그레이션 감지 및 처리
# .claude/ 존재하지만 .vibe-flow.json 없으면 마이그레이션
detect_and_migrate() {
  local claude_dir="$PROJECT_DIR/.claude"
  local state_file="$claude_dir/.vibe-flow.json"

  [ ! -d "$claude_dir" ] && return 0    # 신규 프로젝트
  [ -f "$state_file" ] && return 0      # 이미 vibe-flow

  echo ""
  echo "=== Migration: claude-builds → vibe-flow 감지 ==="

  # 시그니처 스킬 디렉토리 존재로 extensions 추론
  local detected=()
  [ -d "$claude_dir/skills/eval-skill" ] && detected+=("meta-quality")
  [ -d "$claude_dir/skills/design-sync" ] && detected+=("design-system")
  [ -d "$claude_dir/skills/pair" ] && detected+=("deep-collaboration")
  [ -d "$claude_dir/skills/metrics" ] && detected+=("learning-loop")
  [ -d "$claude_dir/skills/feedback" ] && detected+=("code-feedback")

  if [ ${#detected[@]} -eq 0 ]; then
    echo "  감지된 extensions: 없음 (Core only로 처리)"
  else
    echo "  감지된 extensions: ${detected[*]}"
  fi

  # state 파일 초기화
  ensure_state_file

  # 감지된 ext 자동 등록 (재설치는 메인 흐름에서)
  EXTENSIONS_TO_INSTALL=$(IFS=,; echo "${detected[*]}")

  echo "  ✓ state 파일 생성: .claude/.vibe-flow.json"
  echo "  → 감지된 extensions 재설치 진행..."
  echo ""
}
```

- [ ] **Step 2: 메인 흐름에 호출 추가**

setup.sh 메인 흐름의 `# .claude 디렉토리 생성` 블록 직전에:

```bash
# 마이그레이션 감지 (.claude/ 존재 + state 없음 = claude-builds 출신)
detect_and_migrate
```

- [ ] **Step 3: 단위 테스트 — claude-builds 시뮬레이션**

```bash
# claude-builds 형태로 .claude/ 만들기
rm -rf /tmp/vibe-flow-test-5
mkdir /tmp/vibe-flow-test-5
cd /tmp/vibe-flow-test-5
mkdir -p .claude/skills/{brainstorm,eval-skill,design-sync,pair}   # Core 1 + Ext 3 시뮬
# .vibe-flow.json 없는 상태

bash /Users/yss/개발/build/vibe-flow/setup.sh 2>&1 | grep -A5 "Migration"
```

Expected output 포함:
```
=== Migration: claude-builds → vibe-flow 감지 ===
  감지된 extensions: meta-quality design-system deep-collaboration
  ✓ state 파일 생성: .claude/.vibe-flow.json
```

- [ ] **Step 4: state 검증**

```bash
jq '.extensions | keys' /tmp/vibe-flow-test-5/.claude/.vibe-flow.json
```

Expected: `["deep-collaboration", "design-system", "meta-quality"]`

- [ ] **Step 5: commit**

```bash
cd /Users/yss/개발/build/vibe-flow
git add setup.sh
git commit -m "feat(setup): claude-builds → vibe-flow 마이그레이션 자동 감지

.claude/ 존재 + .vibe-flow.json 부재 시 트리거.
시그니처 스킬 디렉토리(eval-skill, design-sync, pair, metrics, feedback)로
extensions 자동 추론 → state 파일 생성 → 재설치."
```

---

## Task 19: setup.sh — 종합 통합 테스트

**Files:** None (테스트만)

- [ ] **Step 1: Core only 시나리오**

```bash
rm -rf /tmp/vf-int-1 && mkdir /tmp/vf-int-1 && cd /tmp/vf-int-1
bash /Users/yss/개발/build/vibe-flow/setup.sh
echo "Skills: $(ls .claude/skills/ | wc -l) (expected 14)"
echo "Agents: $(ls .claude/agents/ | wc -l) (expected 10)"
echo "Hooks:  $(ls .claude/hooks/ | wc -l) (expected 22)"
echo "Rules:  $(ls .claude/rules/ | wc -l) (expected 6)"
jq '.extensions | length' .claude/.vibe-flow.json
```

Expected: 14, 10, 22, 6, `0`

- [ ] **Step 2: --all 시나리오**

```bash
rm -rf /tmp/vf-int-2 && mkdir /tmp/vf-int-2 && cd /tmp/vf-int-2
bash /Users/yss/개발/build/vibe-flow/setup.sh --all
echo "Skills: $(ls .claude/skills/ | wc -l) (expected 23)"
echo "Agents: $(ls .claude/agents/ | wc -l) (expected 12)"
jq '.extensions | length' .claude/.vibe-flow.json
```

Expected: 23, 12, `5`

- [ ] **Step 3: 추가 → 제거 시나리오**

```bash
cd /tmp/vf-int-1   # Core only 상태
bash /Users/yss/개발/build/vibe-flow/setup.sh --extensions meta-quality
echo "After add: $(ls .claude/skills/ | wc -l) (expected 16)"
bash /Users/yss/개발/build/vibe-flow/setup.sh --remove-extension meta-quality
echo "After remove: $(ls .claude/skills/ | wc -l) (expected 14)"
```

Expected: 16, 14

- [ ] **Step 4: 마이그레이션 시나리오**

```bash
rm -rf /tmp/vf-mig && mkdir /tmp/vf-mig && cd /tmp/vf-mig
# claude-builds 시뮬: .claude/skills/ 평면 구조에 ext 시그니처 포함
mkdir -p .claude/skills/{brainstorm,commit,verify,eval-skill,pair}
mkdir -p .claude/agents
echo '{}' > .claude/agents.json   # 더미

bash /Users/yss/개발/build/vibe-flow/setup.sh 2>&1 | grep -E "Migration|감지"
jq '.extensions | keys' .claude/.vibe-flow.json
```

Expected output 포함 "Migration", state에 `["deep-collaboration", "meta-quality"]`

- [ ] **Step 5: --list / --info 검증**

```bash
bash /Users/yss/개발/build/vibe-flow/setup.sh --list-extensions
bash /Users/yss/개발/build/vibe-flow/setup.sh --info design-system | head -5
```

- [ ] **Step 6: 임시 commit (테스트 결과 안정 확인)**

```bash
cd /Users/yss/개발/build/vibe-flow
echo "통합 테스트 모두 통과: $(date -u +%Y-%m-%dT%H:%M:%SZ)" > /tmp/vf-test-results.txt
# 별도 commit 불필요 — setup.sh 변경은 이미 commit됨
```

---

## Task 20: validate.sh — 디렉토리 구조 검증 + state 파일 stage

**Files:**
- Modify: `validate.sh`

- [ ] **Step 1: 기존 stage 1 갱신 (디렉토리 + state 파일 추가)**

기존:
```bash
# 1. .claude 디렉토리 구조
echo "[1/9] .claude 디렉토리 구조"
[ -d "$CLAUDE_DIR" ] && ok ".claude/ 존재" || { err ".claude/ 없음 — setup.sh 실행 필요"; exit 1; }
for sub in agents hooks rules skills messages scripts plans memory; do
  [ -d "$CLAUDE_DIR/$sub" ] && ok "$sub/ 존재" || err "$sub/ 없음"
done
for sub in memory/brainstorms memory/reviews; do
  [ -d "$CLAUDE_DIR/$sub" ] && ok "$sub/ 존재" || warn "$sub/ 없음 — 첫 사용 시 자동 생성됨"
done
```

새로 추가 (디렉토리 검증 후):
```bash
# state 파일 존재 확인
if [ -f "$CLAUDE_DIR/.vibe-flow.json" ]; then
  ok ".vibe-flow.json 존재"
else
  warn ".vibe-flow.json 없음 — claude-builds 출신이거나 초기 설치 미완료"
fi
```

또한 모든 stage 표시 `/9` → `/10`으로 변경:
```bash
sed -i.tmp 's|/9]|/10]|g' validate.sh
rm validate.sh.tmp
```

- [ ] **Step 2: 단위 테스트**

```bash
cd /tmp/vf-int-1
bash /Users/yss/개발/build/vibe-flow/validate.sh 2>&1 | head -8
```

Expected: `[1/10]` 표시 + `.vibe-flow.json 존재` 또는 경고.

- [ ] **Step 3: 임시 commit**

```bash
cd /Users/yss/개발/build/vibe-flow
git add validate.sh
git commit -m "feat(validate): stage 1에 .vibe-flow.json 검증 + 9 → 10 stages"
```

---

## Task 21: validate.sh — Stage 3 (state file 무결성)

**Files:**
- Modify: `validate.sh`

- [ ] **Step 1: 새 stage 3 추가**

기존 stage 1 직후 (stage 2 = 도구 검증)에 새 stage 3을 삽입.

기존 stage 번호 2~10 → 4~10으로 한 칸씩 밀고 새 stage 3 추가.

방법: validate.sh를 직접 편집해서 stage 2 (필수 도구) 직후에 다음 블록 추가:

```bash
# 3. State file 무결성
echo ""
echo "[3/10] State file (.vibe-flow.json)"
STATE="$CLAUDE_DIR/.vibe-flow.json"
if [ -f "$STATE" ]; then
  if jq empty "$STATE" 2>/dev/null; then
    ok ".vibe-flow.json 유효 JSON"

    # Schema 검증 — 필수 필드
    for field in vibe_flow_version installed_at extensions; do
      if jq -e --arg f "$field" 'has($f)' "$STATE" >/dev/null 2>&1; then
        :
      else
        err "필수 필드 누락: $field"
      fi
    done

    # 각 extension의 files 존재 확인
    EXT_FAIL=0
    while IFS= read -r line; do
      ext=$(echo "$line" | cut -d'|' -f1)
      file=$(echo "$line" | cut -d'|' -f2)
      full="$TARGET_DIR/$file"
      if [ -e "$full" ]; then
        :
      else
        err "ext '$ext' 파일 누락: $file"
        EXT_FAIL=$((EXT_FAIL+1))
      fi
    done < <(jq -r '.extensions | to_entries[] | .key as $k | .value.files[] | "\($k)|\(.)"' "$STATE" 2>/dev/null)
    [ "$EXT_FAIL" = 0 ] && ok "모든 extension 파일 존재"

    # 설치된 extensions 카운트 출력
    EXT_COUNT=$(jq '.extensions | length' "$STATE")
    ok "설치된 extensions: ${EXT_COUNT}개"
  else
    err ".vibe-flow.json JSON 파싱 실패"
  fi
else
  warn ".vibe-flow.json 없음 — 마이그레이션 또는 첫 setup 필요"
fi
```

기존 stage 3-9 번호 sed로 한 칸씩 증가 — 또는 그냥 새 번호 매핑은 stage 1 다음에 새 3 삽입하고 기존 3을 4로… 사실 번호는 출력 텍스트만이므로 코드 동작은 변경 없음. 단순화:

```bash
# 기존 stage 번호를 모두 +1 시프트
sed -i.tmp '
  s|\[3/10\]|[4/10]|g;
  s|\[4/10\]|[5/10]|g;
  s|\[5/10\]|[6/10]|g;
  s|\[6/10\]|[7/10]|g;
  s|\[7/10\]|[8/10]|g;
  s|\[8/10\]|[9/10]|g;
  s|\[9/10\]|[10/10]|g
' validate.sh
rm validate.sh.tmp
```

⚠ 위 sed는 cascade 문제 있음 — multi-pass로:

실제로는 reverse order로:
```bash
sed -i.tmp '
  s|\[9/10\]|TMPSTAGE_10|g;
  s|\[8/10\]|TMPSTAGE_9|g;
  s|\[7/10\]|TMPSTAGE_8|g;
  s|\[6/10\]|TMPSTAGE_7|g;
  s|\[5/10\]|TMPSTAGE_6|g;
  s|\[4/10\]|TMPSTAGE_5|g;
  s|\[3/10\]|TMPSTAGE_4|g
' validate.sh

sed -i.tmp '
  s|TMPSTAGE_10|[10/10]|g;
  s|TMPSTAGE_9|[9/10]|g;
  s|TMPSTAGE_8|[8/10]|g;
  s|TMPSTAGE_7|[7/10]|g;
  s|TMPSTAGE_6|[6/10]|g;
  s|TMPSTAGE_5|[5/10]|g;
  s|TMPSTAGE_4|[4/10]|g
' validate.sh
rm validate.sh.tmp
```

→ 새 stage 3 (state file)이 도입되고 기존 [3/10]~[9/10]은 [4/10]~[10/10]으로 시프트.

- [ ] **Step 2: 단위 테스트**

```bash
cd /tmp/vf-int-1
bash /Users/yss/개발/build/vibe-flow/validate.sh 2>&1 | sed -n '1,30p'
```

Expected: stage 1, 2, 3 모두 정상 출력. stage 3에서 ".vibe-flow.json 유효 JSON", "필수 필드 OK", "extension 파일 존재" 등.

- [ ] **Step 3: 임시 commit**

```bash
cd /Users/yss/개발/build/vibe-flow
git add validate.sh
git commit -m "feat(validate): stage 3 신설 — .vibe-flow.json schema + 파일 무결성"
```

---

## Task 22: validate.sh — Stage 9 (Reconciliation: state ↔ filesystem)

**Files:**
- Modify: `validate.sh`

- [ ] **Step 1: 기존 stage 9 (design-tokens.ts) 직전에 새 stage 9 (reconciliation) 추가**

위 sed 시프트로 design-tokens.ts는 [10/10]이 됐음. 그 직전에 새 [9/10]:

```bash
# 9. Reconciliation — state ↔ filesystem
echo ""
echo "[9/10] State ↔ Filesystem reconciliation"
if [ -f "$STATE" ]; then
  # 9-1. state에 명시된 파일이 모두 존재 (Stage 3에서 확인됨)
  ok "state 명시 파일 존재 (stage 3 결과)"

  # 9-2. orphan 검출 — extension 파일 명단에 없는데 .claude/skills/<ext-skill>/ 존재
  CORE_SKILLS="brainstorm plan finish release scaffold test worktree verify security commit review-pr receive-review status learn"
  EXT_SIGNATURES="eval-skill evolve design-sync design-audit pair discuss metrics retrospective feedback"

  ORPHAN_COUNT=0
  for skill_dir in "$CLAUDE_DIR/skills"/*/; do
    [ -d "$skill_dir" ] || continue
    skill="$(basename "$skill_dir")"

    # Core skill?
    if echo "$CORE_SKILLS" | grep -qw "$skill"; then continue; fi

    # Extension skill — state.extensions[].files에 매칭?
    if jq -r '.extensions | to_entries[] | .value.files[]' "$STATE" 2>/dev/null \
        | grep -q "skills/$skill/"; then
      continue
    fi

    # Orphan — Extension signature 일치하는데 state에는 없음
    if echo "$EXT_SIGNATURES" | grep -qw "$skill"; then
      warn "orphan ext skill: $skill (state에 없음)"
      ORPHAN_COUNT=$((ORPHAN_COUNT+1))
    fi
  done
  [ "$ORPHAN_COUNT" = 0 ] && ok "orphan 파일 없음"
fi
```

- [ ] **Step 2: 단위 테스트 — 깨끗한 상태**

```bash
cd /tmp/vf-int-1
bash /Users/yss/개발/build/vibe-flow/validate.sh 2>&1 | sed -n '/\[9/,/\[10/p'
```

Expected: "orphan 파일 없음" 표시.

- [ ] **Step 3: 단위 테스트 — orphan 시뮬**

```bash
cd /tmp/vf-int-1
mkdir -p .claude/skills/eval-skill   # state에는 없는데 디렉토리만 존재
bash /Users/yss/개발/build/vibe-flow/validate.sh 2>&1 | grep -i orphan
```

Expected: "orphan ext skill: eval-skill (state에 없음)"

cleanup:
```bash
rmdir .claude/skills/eval-skill
```

- [ ] **Step 4: 임시 commit**

```bash
cd /Users/yss/개발/build/vibe-flow
git add validate.sh
git commit -m "feat(validate): stage 9 신설 — state ↔ filesystem reconciliation

extension signature 디렉토리 존재하지만 state에 없으면 orphan으로 보고."
```

---

## Task 23: validate.sh — Stage 10 디자인 토큰 (기존, 번호만 갱신) + ext deps 추가

**Files:**
- Modify: `validate.sh`

- [ ] **Step 1: stage 10에 ext deps 통합**

기존 [10/10] design-tokens.ts 검증 블록 직후에 ext deps 추가:

```bash
# 10. Extension dependencies (state에 design-system 있으면 playwright 등 검증)
if [ -f "$STATE" ] && jq -e '.extensions["design-system"]' "$STATE" >/dev/null 2>&1; then
  echo ""
  echo "  design-system 의존성:"
  for dep in playwright sharp pixelmatch pngjs; do
    if (cd "$TARGET_DIR" && node -e "require('$dep')" 2>/dev/null); then
      ok "  ✓ $dep 설치됨"
    else
      warn "  ⚠ $dep 미설치 (npm i -D $dep)"
    fi
  done
fi
```

이 블록은 stage 10 안에 통합 (별도 stage 11 만들지 않음).

- [ ] **Step 2: 단위 테스트 — design-system 미설치**

```bash
cd /tmp/vf-int-1
bash /Users/yss/개발/build/vibe-flow/validate.sh 2>&1 | sed -n '/\[10/,$p'
```

Expected: design-system 의존성 검증 안 함 (state에 없음).

- [ ] **Step 3: 단위 테스트 — design-system 설치 후**

```bash
cd /tmp/vf-int-1
bash /Users/yss/개발/build/vibe-flow/setup.sh --extensions design-system
bash /Users/yss/개발/build/vibe-flow/validate.sh 2>&1 | grep -A5 "design-system 의존성"
```

Expected: playwright/sharp/pixelmatch 설치 여부 출력 (대부분 미설치 ⚠).

- [ ] **Step 4: 임시 commit**

```bash
cd /Users/yss/개발/build/vibe-flow
git add validate.sh
git commit -m "feat(validate): stage 10에 design-system 의존성 점검 통합

state.extensions['design-system'] 있을 때만 playwright/sharp/pixelmatch/pngjs
require 검증. 미설치면 warn (block 안 함)."
```

---

## Task 24: README 재구성 (~180줄)

**Files:**
- Modify: `README.md` (전면 재작성)

- [ ] **Step 1: 기존 README 백업 (참조용 임시)**

```bash
cp README.md README.md.OLD
wc -l README.md README.md.OLD
```

- [ ] **Step 2: 새 README 작성**

```bash
cat > README.md <<'EOF'
# vibe-flow

> vibe coder의 작업 흐름 — 초보부터 상급자까지, mechanical enforcement로

## ⚡ 30초 시작

```bash
git clone https://github.com/SONGYEONGSIN/vibe-flow.git
cd /your/project
bash /path/to/vibe-flow/setup.sh
```

→ Core 14 스킬 + 22 훅 + 10 에이전트 + 6 규칙 즉시 활성화

## 🎯 첫 사이클 (5분)

```bash
claude
> /brainstorm "사용자 인증 기능 추가"   # 의도 탐색 (4문항 + 대안 2개)
> /plan from-brainstorm <file>           # 단계 분해
# ...코드 작성...
> /verify                                  # lint + tsc + test
> /commit                                  # Conventional commit
> /finish                                  # PR/머지 결정 트리
```

## 📦 Core 14 — 기본 설치

| 카테고리 | 스킬 |
|---------|------|
| 사이클 | `/brainstorm` `/plan` `/finish` `/release` |
| 작업 | `/scaffold` `/test` `/worktree` |
| 검증 | `/verify` `/security` |
| Git | `/commit` `/review-pr` `/receive-review` |
| 메타 | `/status` `/learn` |

자세한 명령 → [docs/REFERENCE.md](docs/REFERENCE.md)

## 🔌 Extensions 5 — opt-in

```bash
bash setup.sh --list-extensions       # 사용 가능한 것 보기
bash setup.sh --extensions <name>     # 추가
bash setup.sh --all                   # 전체 설치
```

| Extension | 용도 |
|-----------|------|
| `meta-quality` | 스킬 자체 품질 측정 + 자가 진화 (`/eval`, `/evolve`) |
| `design-system` | 참고 디자인 → 코드 정량 매칭 (`/design-sync`, `/design-audit`) |
| `deep-collaboration` | Builder/Validator 페어, 토론 (`/pair`, `/discuss`) |
| `learning-loop` | 장기 메트릭, 회고 (`/metrics`, `/retrospective`) |
| `code-feedback` | git diff 기반 품질 분석 (`/feedback`) |

각 extension 상세 → [extensions/<name>/README.md](extensions/)

## 🚀 학습 경로

```
첫날     → Core 6 (brainstorm, commit, verify, finish, status, learn)
3일차    → + plan, test, security
1주차    → + scaffold, worktree, review-pr, receive-review, release
1개월    → Extensions 활성화 (meta-quality / learning-loop 등)
```

자세한 단계별 가이드 → [docs/ONBOARDING.md](docs/ONBOARDING.md)

## 📐 아키텍처

```
brainstorm → plan → 구현 → verify → commit → finish → release
   │                            │                   │
   ↓                            ↓                   ↓
 memory ─────────────────  events.jsonl ─────  retrospective
                                  ↓
                        /eval → /evolve (extensions/meta-quality)
```

자세한 데이터 흐름 → [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

## 🤝 에이전트 위임 (12개)

`@developer`, `@qa`, `@security`, `@validator`, `@planner`, `@feedback`,
`@moderator`, `@comparator`, `@designer`, `@retrospective`
+ extensions: `@skill-reviewer`, `@grader`

## 🛠 자동 강제 (Hooks 22개)

`/verify` 안 돌려도 자동:
- 매 `Write/Edit` → prettier, eslint, typecheck, test, design-lint
- TDD strict — 테스트 없이 코드 수정 차단
- 위험 명령 27 패턴 차단 (`git push --force`, `rm -rf /`, ...)
- 메트릭 자동 수집 (events.jsonl + SQLite + JSON)

## 🆙 업그레이드

```bash
cd /path/to/vibe-flow && git pull
cd /your/project && bash /path/to/vibe-flow/setup.sh
# → 사용자 수정본 자동 .bak 백업, extensions state 보존
```

## 📚 더 읽기

- [docs/REFERENCE.md](docs/REFERENCE.md) — 전체 명령/규칙 레퍼런스
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — self-improving 루프 상세
- [docs/MIGRATION.md](docs/MIGRATION.md) — claude-builds에서 마이그레이션
- [docs/ONBOARDING.md](docs/ONBOARDING.md) — vibe coder 단계별 가이드
- [extensions/](extensions/) — 각 extension 사용법

## 출처

이 빌드의 핵심 원칙은 다음 패턴을 mechanical enforcement로 통합한 것:

- Surgical change / Goal-driven: [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills)
- TDD Iron Law: [obra/superpowers](https://github.com/obra/superpowers)
- Self-evolution: [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)
- Pair mode: [disler/claude-code-hooks-mastery](https://github.com/disler/claude-code-hooks-mastery)
- Pair mode: [disler/claude-code-hooks-mastery](https://github.com/disler/claude-code-hooks-mastery)
- 등 8개 — 자세한 매핑은 [CHANGELOG.md](CHANGELOG.md) 1.0.0

## 라이선스

MIT
EOF

wc -l README.md
```

Expected: ~120-150 라인 (목표 180줄 이내).

- [ ] **Step 3: README 검증 — 모든 섹션 존재**

```bash
grep -c "^## " README.md
```

Expected: 12-13개 섹션.

- [ ] **Step 4: 백업 제거**

```bash
rm README.md.OLD
```

- [ ] **Step 5: commit**

```bash
git add README.md
git commit -m "docs(readme): 재구성 — 686 → ~150줄

Quick Start 중심으로 재작성. 상세 정보는 docs/* 분리.
- 30초 시작
- 첫 사이클 5분
- Core 14 표
- Extensions 5 표
- 학습 경로
- 아키텍처 다이어그램 요약
- docs/ 링크"
```

---

## Task 25: docs/REFERENCE.md (NEW)

**Files:**
- Create: `docs/REFERENCE.md`

기존 README의 상세 정보 (스킬/에이전트/훅/규칙 표) 이전.

- [ ] **Step 1: REFERENCE.md 작성**

```bash
cat > docs/REFERENCE.md <<'REFEOF'
# vibe-flow Reference

전체 명령 / 에이전트 / 훅 / 규칙 레퍼런스.

## Skills (23 — Core 14 + Extensions 9)

### Core 14

| 스킬 | 호출 | 설명 |
|------|------|------|
| brainstorm | `/brainstorm "<주제>"` | 의도/제약/대안 구조화 탐색 |
| plan | `/plan` | 멀티스텝 계획 파일화·추적 |
| finish | `/finish` | 머지/PR/cleanup 의사결정 트리 |
| release | `/release [version]` | semver + CHANGELOG + tag |
| scaffold | `/scaffold [domain]` | 보일러플레이트 자동 생성 |
| test | `/test [file]` | Vitest 단위 테스트 자동 생성 |
| worktree | `/worktree [create\|list\|remove]` | git worktree 격리 |
| verify | `/verify` | lint + tsc + test + e2e |
| security | `/security` | OWASP Top 10 스캔 |
| commit | `/commit` | Conventional commit 자동 생성 |
| review-pr | `/review-pr [N]` | GitHub PR 리뷰 |
| receive-review | `/receive-review [<source>]` | 리뷰 피드백 비판적 수용 |
| status | `/status` | 프로젝트 상태 대시보드 |
| learn | `/learn [save\|show]` | 메모리 관리 |

### Extensions 9

#### meta-quality
| 스킬 | 호출 |
|------|------|
| eval-skill | `/eval <skill>` |
| evolve | `/evolve <skill>` |

#### design-system
| 스킬 | 호출 |
|------|------|
| design-sync | `/design-sync <URL\|이미지\|--from-file>` |
| design-audit | `/design-audit` |

#### deep-collaboration
| 스킬 | 호출 |
|------|------|
| pair | `/pair "<task>"` |
| discuss | `/discuss "<주제>"` |

#### learning-loop
| 스킬 | 호출 |
|------|------|
| metrics | `/metrics [today\|week\|all]` |
| retrospective | `/retrospective` |

#### code-feedback
| 스킬 | 호출 |
|------|------|
| feedback | `/feedback` |

## Agents (12 — Core 10 + Extensions 2)

### Core 10
- `@developer` — 구현
- `@qa` — 테스트
- `@security` — OWASP
- `@validator` — Pair mode 검증
- `@planner` — 작업 분해
- `@feedback` — 코드 품질
- `@moderator` — 토론 중재
- `@comparator` — A/B 비교
- `@designer` — UI/UX (Phase 0 자율 모드)
- `@retrospective` — 회고 분석

### Extensions 2 (meta-quality)
- `@skill-reviewer` — 8단계 100점 스코어카드
- `@grader` — eval 채점

## Hooks (22 — 모두 Core)

### PreToolUse
- `command-guard.sh` — 27 패턴 위험 명령 차단 (jq fail-closed)
- `smart-guard.sh` — patterns.md 학습 패턴 2차 검증
- `tdd-enforce.sh` — 테스트 없이 코드 수정 차단 (strict 기본)

### PostToolUse (Write/Edit)
- `prettier-format.sh` — 포맷
- `eslint-fix.sh` — 린트 자동 수정
- `typecheck.sh` — TypeScript 체크
- `test-runner.sh` — 관련 테스트 실행
- `metrics-collector.sh` — 3중 기록 (JSON + SQLite + JSONL)
- `pattern-check.sh` — 학습 패턴 준수
- `design-lint.sh` — 하드코딩 색상 (oklch 포함) 감지
- `debate-trigger.sh` — 충돌 시 토론 자동 개시
- `readme-sync.sh` — README 수치 자동 동기화

### PostToolUseFailure
- `tool-failure-handler.sh` — 13-class 에러 분류 + 복구 힌트

### PreCompact
- `pre-compact.sh` — 컨텍스트 압축 전 브랜치/커밋 보존
- `context-prune.sh` — events.jsonl 1줄 요약 (12KB 예산)

### Stop
- `uncommitted-warn.sh` — 미커밋 변경 경고
- `session-review.sh` — 품질 종합 리뷰
- `session-log.sh` — 세션 로그 저장

### Notification
- `notify.sh` — 데스크톱 알림 (macOS)
- `model-suggest.sh` — events 패턴 분석 → 모델 전환 제안

### 유틸리티
- `_common.sh` — 공용 함수 (truncate, mtime, hex)
- `message-bus.sh` — 에이전트 간 메시지 송수신

## Rules (6)

- `tdd.md` — Iron Law: RED-GREEN-REFACTOR
- `donts.md` — 합리화 방지 표 13건
- `git.md` — Conventional Commits + HARD-GATE
- `design.md` — 디자인 토큰 / 하드코딩 금지 / arbitrary value 정책
- `conventions.md` — 코드 스타일 + Server Action 패턴
- `debugging.md` — 4단계 체계적 디버깅

## setup.sh CLI

```bash
bash setup.sh                                   # Core only
bash setup.sh --all                             # Core + 5 extensions
bash setup.sh --extensions <name>[,<name>...]   # 선택
bash setup.sh --remove-extension <name>         # 제거
bash setup.sh --list-extensions                 # 목록
bash setup.sh --info <name>                     # 상세
bash setup.sh --check                           # validate.sh 단축
bash setup.sh --with-orchestrators              # Squad/AO 포함
bash setup.sh --force                           # 백업 없이 덮어쓰기
```

## State File — `.claude/.vibe-flow.json`

```json
{
  "vibe_flow_version": "1.0.0",
  "installed_at": "ISO 8601",
  "last_updated_at": "ISO 8601",
  "core_files": ["..."],
  "extensions": {
    "<name>": {
      "version": "1.0.0",
      "installed_at": "ISO 8601",
      "files": ["..."]
    }
  }
}
```

## Events.jsonl Type 분포

| Type | 발생 위치 | 핵심 필드 |
|------|----------|----------|
| `tool_result` | metrics-collector | tool, file, results |
| `tool_failure` | tool-failure-handler | tool, error_class, error |
| `verify_complete` | verify | overall, results |
| `commit_created` | commit | commit_type, files_changed, sha |
| `security_scan` | security | high, medium, low, overall |
| `release` | release | version, semver_type, commits |
| `feedback` | feedback | score, items, files |
| `review_pr` | review-pr | pr, score, verdict |
| `discuss` | discuss | debate_id, participants, rounds, verdict_type |
| `design_audit` | design-audit | coverage, violations, duplicate_patterns |
| `design_sync` | design-sync | mode, sync_rate_initial/final |
| `learn_save` | learn | category, summary |
| `brainstorm` | brainstorm | topic, alternatives, chosen |
| `plan_created` / `plan_step_complete` | plan | plan_id, steps, hard_gate |
| `finish` | finish | path, branch, changed_files |
| `review_received` | receive-review | source, items, accepted/rejected/clarify |
| `pair_session` | pair | iterations, verdict |
| `skill_evolve` | evolve | skill, baseline, candidate, improved |

REFEOF
wc -l docs/REFERENCE.md
```

Expected: ~200-300 라인.

- [ ] **Step 2: commit**

```bash
git add docs/REFERENCE.md
git commit -m "docs: REFERENCE.md 신설 — 전체 명령/에이전트/훅/규칙 레퍼런스

기존 README의 상세 표를 분리. setup.sh CLI + state schema + events 분포 포함."
```

---

## Task 26: docs/ARCHITECTURE.md (NEW)

**Files:**
- Create: `docs/ARCHITECTURE.md`

기존 README L23-186의 아키텍처 다이어그램 + 데이터 흐름 보강.

- [ ] **Step 1: ARCHITECTURE.md 작성**

```bash
cat > docs/ARCHITECTURE.md <<'ARCHEOF'
# vibe-flow Architecture

self-improving 시스템의 데이터 흐름 + 컴포넌트 통합 패턴.

## 4 Layer 구조

```
┌─ Skills (23) ──────────────────────────────────┐
│  Core 14: brainstorm/plan/finish/...            │
│  Extensions 9: eval/evolve/pair/...             │
└────────────────────────────────────────────────┘
                       │
                       ▼ 호출
┌─ Agents (12) ──────────────────────────────────┐
│  Core 10: developer/qa/security/...             │
│  Extensions 2: skill-reviewer/grader            │
└────────────────────────────────────────────────┘
                       │
                       ▼ 행동
┌─ Hooks (22) ───────────────────────────────────┐
│  PreToolUse: command-guard, tdd-enforce         │
│  PostToolUse: prettier, eslint, metrics-collect │
│  Stop: session-review, session-log              │
│  PreCompact: context-prune                      │
└────────────────────────────────────────────────┘
                       │
                       ▼ 강제
┌─ Rules (6) ────────────────────────────────────┐
│  tdd / donts / git / design / conventions /     │
│  debugging                                       │
└────────────────────────────────────────────────┘
```

## Self-Improving Loop

```
brainstorm → plan → 구현 → verify → commit → finish → release
   │           │       │      │        │        │        │
   ↓           ↓       ↓      ↓        ↓        ↓        ↓
.claude/   .claude/  hooks  events  events   events    git
memory/    plans/    auto    .jsonl  .jsonl   .jsonl    tag
brainstorms ──────  trigger
                                  ↓
                        retrospective(/retrospective skill or agent)
                                  ↓
                            P0/P1/P2 개선안
                                  ↓
                  patterns.md ← /learn save
                  improvements.md ← retrospective
                                  ↓
                       /evolve <skill> (extensions/meta-quality)
                                  ↓
                            5 게이트 + A/B 비교
                                  ↓
                            SKILL.md 갱신 후보
```

## 데이터 저장소

| 위치 | 용도 | 추적 |
|------|------|------|
| `.claude/memory/patterns.md` | 학습 패턴 (코드/에러/hook 룰) | git ✓ |
| `.claude/memory/project-profile.md` | 프로젝트 특성 | git ✓ |
| `.claude/memory/improvements.md` | 회고 결과 누적 | git ✓ |
| `.claude/memory/brainstorms/` | brainstorm spec 파일 | git ✓ |
| `.claude/memory/reviews/` | 리뷰 수용 기록 | git ✓ |
| `.claude/plans/` | 활성 + 완료 plans | git ✓ |
| `.claude/messages/debates/` | 토론 verdict | git ✓ |
| `.claude/metrics/daily-*.json` | 일별 메트릭 | git ✗ (개인) |
| `.claude/events.jsonl` | 실시간 이벤트 스트림 | git ✗ |
| `.claude/store.db` | SQLite 누적 메트릭 | git ✗ |
| `.claude/session-logs/` | 세션 로그 | git ✗ |
| `.claude/messages/inbox/` | 에이전트 inbox | git ✗ |

## Hook Pipeline

```
사용자 명령 / 에이전트 행동
    │
    ▼ Claude가 도구 호출
┌─ PreToolUse (차단 가능) ──────────────────────┐
│  Bash → command-guard, smart-guard            │
│  Write/Edit → tdd-enforce                     │
└───────────────────────────────────────────────┘
    │ exit 0 통과
    ▼ 도구 실행
┌─ PostToolUse (비차단) ─────────────────────────┐
│  Bash 실패 → tool-failure-handler              │
│  Write/Edit → 8개 hook 병렬                    │
│    prettier → eslint → tsc → test              │
│    metrics-collector → events.jsonl            │
│    pattern-check / design-lint                 │
│    debate-trigger / readme-sync                │
└───────────────────────────────────────────────┘
    │
    ▼ Claude 응답 생성
    ▼ (Compact 필요 시)
┌─ PreCompact ──────────────────────────────────┐
│  pre-compact: 브랜치/커밋 보존                  │
│  context-prune: 12KB 예산 1줄 요약              │
└───────────────────────────────────────────────┘
    │
    ▼ 사용자 idle
┌─ Notification ────────────────────────────────┐
│  notify: 데스크톱 알림                          │
│  model-suggest: events.jsonl 패턴 → 모델 제안   │
└───────────────────────────────────────────────┘
    │
    ▼ 세션 종료
┌─ Stop ────────────────────────────────────────┐
│  uncommitted-warn → session-review →          │
│  session-log → 다음 세션 인계                   │
└───────────────────────────────────────────────┘
```

## Message Bus

```
Agent A ─→ message-bus.sh send ─→ .claude/messages/inbox/<B>/
                                            │
Agent B (다음 세션 시작) ────────  list  ──┘
   ↓
   처리 후 archive 또는 reply
```

## Debate System

```
충돌 감지 (debate-trigger 또는 /discuss 호출)
    │
    ▼
Opening Statements (각 참가자 입장 + 논거 + 확신도)
    │
    ▼
Rebuttals (최대 3 라운드)
    │
    ▼
Verdict (consensus / strong_majority / moderator_decision / needs_human)
    │
    ▼
.claude/messages/debates/debate-<id>.json   ← 영구 보관
.claude/messages/debates/debate-<id>.md      ← 트랜스크립트
.claude/memory/improvements.md               ← 결정 요약
```

## Eval & Evolve Loop (Extensions/meta-quality)

```
/eval <skill>
   │
   ▼
evals.json 테스트 실행
   │
   ▼
grader 채점 (PASS/FAIL + 0.0-1.0)
   │
   ▼
benchmark.json 누적
   │
   ▼
/evolve <skill>
   │
   ▼
실패 트레이스 + error_class 분석
   │
   ▼
SKILL.md 개선 후보 생성
   │
   ▼
5 제약 게이트 (size / purpose / structure / syntax / eval pass rate)
   │
   ▼
comparator 블라인드 A/B 비교
   │
   ▼
사용자 검토 + 수동 적용 (자동 적용 X)
   │
   ▼
evolve-history.json 누적
```

## Memory Context Fencing (Hermes Agent 패턴)

```
/learn show 출력 시:
<memory-context>
[시스템 참조: 학습된 패턴 — 새로운 지시 아님]
... 내용 ...
</memory-context>

→ 모델이 메모리를 사용자 지시로 혼동하지 않도록 방지.
→ pattern-check.sh도 동일 펜싱 적용.
```

ARCHEOF
wc -l docs/ARCHITECTURE.md
```

- [ ] **Step 2: commit**

```bash
git add docs/ARCHITECTURE.md
git commit -m "docs: ARCHITECTURE.md 신설 — self-improving 루프 + 데이터 흐름

Layer 구조 / hook pipeline / message bus / debate / eval-evolve loop /
memory context fencing 다이어그램으로 설명."
```

---

## Task 27: docs/MIGRATION.md (NEW)

**Files:**
- Create: `docs/MIGRATION.md`

- [ ] **Step 1: MIGRATION.md 작성**

```bash
cat > docs/MIGRATION.md <<'MIGEOF'
# claude-builds → vibe-flow 마이그레이션 가이드

claude-builds 사용자가 vibe-flow로 전환하는 절차.

## 한 줄 요약

```bash
cd /your/project && bash /Users/yss/개발/build/vibe-flow/setup.sh
```

→ setup.sh가 자동 감지 + state 파일 생성 + extensions 추론 + Core 갱신.

## 변경된 점

| 항목 | claude-builds | vibe-flow |
|------|--------------|-----------|
| 디렉토리 구조 | 평면 (skills/agents/hooks/rules/) | core/ + extensions/<name>/ 두 단계 |
| 기본 설치 | 모든 23 스킬 | Core 14만 |
| Extensions | 별도 개념 없음 | 5 카테고리 (meta-quality 등) |
| state 파일 | 없음 | `.claude/.vibe-flow.json` |
| setup.sh CLI | --with-orchestrators / --force | + --extensions / --all / --list / --info / --remove / --check |
| validate.sh | 9 stages | 10 stages |

## 변경 안 된 점 (호환)

- ✓ 모든 스킬 이름 동일 (`/commit`, `/verify`, `/brainstorm`, ...)
- ✓ settings.local.json hook 경로 그대로 유효 (모든 hook은 core)
- ✓ 메모리 (memory/), plans (plans/), 메시지 (messages/) 자동 보존
- ✓ events.jsonl, store.db 자동 보존
- ✓ 22 hooks 동작 동일

## 자동 감지 메커니즘

setup.sh가 다음 조건 검출:

```
.claude/ 존재 + .claude/.vibe-flow.json 부재 → 마이그레이션 시작
```

설치된 extensions 추론 (시그니처 디렉토리):
| 디렉토리 존재 | 추론 |
|--------------|------|
| `skills/eval-skill/` | meta-quality 설치됨 |
| `skills/design-sync/` | design-system 설치됨 |
| `skills/pair/` | deep-collaboration 설치됨 |
| `skills/metrics/` | learning-loop 설치됨 |
| `skills/feedback/` | code-feedback 설치됨 |

## 절차 (사용자 측)

### 1. setup.sh 한 번 실행

```bash
cd /your/project
bash /Users/yss/개발/build/vibe-flow/setup.sh
```

출력 예시:
```
=== Migration: claude-builds → vibe-flow 감지 ===
  감지된 extensions: meta-quality, design-system
  ✓ state 파일 생성: .claude/.vibe-flow.json
  → 감지된 extensions 재설치 진행...

[1/7] Agents...
  ↻ backup: .claude/agents/developer.md.bak.20260430-...
  ✓ 갱신
[2/7] Hooks...
  ✓ 22 갱신
...

=== Installing extensions ===
  Extension: meta-quality 설치...
  Extension: design-system 설치...

=== Setup complete ===
```

### 2. state 파일 검토

```bash
cat .claude/.vibe-flow.json | jq '.extensions | keys'
```

추론 결과 정확한지 확인. 잘못 추론된 경우:

### 3. 정정

```bash
# 잘못 감지된 extension 제거
bash /path/to/vibe-flow/setup.sh --remove-extension <name>

# 빠진 extension 추가
bash /path/to/vibe-flow/setup.sh --extensions <name>
```

### 4. 검증

```bash
bash /path/to/vibe-flow/setup.sh --check
# 또는
bash .claude/validate.sh
```

10 stages 모두 PASS / 0 FAIL이면 성공.

## 메이커 본인 (글로벌 활성 사용자)

### 1. 글로벌 심볼릭 갱신

```bash
# 기존 dead 심볼릭 제거 (claude-builds → 옛 경로)
for link in skills agents rules; do
  [ -L "$HOME/.claude/$link" ] && rm "$HOME/.claude/$link"
done

# vibe-flow Core 가리키도록 재생성
ln -s /Users/yss/개발/build/vibe-flow/core/skills /Users/yss/.claude/skills
ln -s /Users/yss/개발/build/vibe-flow/core/agents /Users/yss/.claude/agents
ln -s /Users/yss/개발/build/vibe-flow/core/rules /Users/yss/.claude/rules
cp /Users/yss/개발/build/vibe-flow/core/agents.json /Users/yss/.claude/agents.json
```

### 2. Claude Code 재시작 후 확인

```
/skills    # 23 스킬 보이는지
@developer # 에이전트 호출 가능한지
```

## 트러블슈팅

### Q. orphan 파일 경고가 나옴

`validate.sh` Stage 9에서:
```
warn: orphan ext skill: feedback (state에 없음)
```

→ 추론 누락. 수동 명시:
```bash
bash setup.sh --extensions code-feedback
```

### Q. .vibe-flow.json이 손상됨

```bash
# state 파일 재생성
rm .claude/.vibe-flow.json
bash /path/to/vibe-flow/setup.sh
```

자동 감지가 다시 트리거됨.

### Q. 디렉토리 rename 안 됨 (메이커 본인)

GitHub auto-redirect는 살아있어 git push/pull은 작동. 단:
- 새 컴퓨터에서 clone 시 새 URL 사용 권장
- 기존 클론은 `git remote set-url origin https://github.com/SONGYEONGSIN/vibe-flow.git`

### Q. settings.local.json hook 경로가 깨짐

새 setup.sh가 settings.local.json **있으면 보존** (재생성 안 함). 따라서 기존 hook 경로 그대로 유효 (hook 파일은 같은 위치 `.claude/hooks/`).

만약 강제로 재생성 원하면:
```bash
rm .claude/settings.local.json
bash /path/to/vibe-flow/setup.sh
```

## 롤백

문제 발생 시:
```bash
# git 롤백 (메이커)
cd /Users/yss/개발/build/vibe-flow
git reset --hard pre-vibe-flow-phase-1   # 사전 태그
mv /Users/yss/개발/build/vibe-flow /Users/yss/개발/build/claude-builds
git remote set-url origin https://github.com/SONGYEONGSIN/claude-builds.git

# 또는 사용자 측 단순 복구
cp .claude/.bak.* / .claude/    # safe_copy로 백업된 사용자 수정본 복구
```

MIGEOF
wc -l docs/MIGRATION.md
```

- [ ] **Step 2: commit**

```bash
git add docs/MIGRATION.md
git commit -m "docs: MIGRATION.md — claude-builds → vibe-flow 가이드

자동 감지 메커니즘, 사용자 절차, 메이커 본인 글로벌 갱신, 트러블슈팅, 롤백."
```

---

## Task 28: docs/ONBOARDING.md (NEW)

**Files:**
- Create: `docs/ONBOARDING.md`

- [ ] **Step 1: ONBOARDING.md 작성**

```bash
cat > docs/ONBOARDING.md <<'ONBEOF'
# vibe-flow Onboarding

vibe coder를 위한 단계별 가이드.

## 단계 0 — 설치 (5분)

```bash
git clone https://github.com/SONGYEONGSIN/vibe-flow.git ~/dev/vibe-flow
cd /your/project
bash ~/dev/vibe-flow/setup.sh
```

→ Core 14 스킬 + 22 훅 + 10 에이전트 + 6 규칙 활성. extensions는 나중에 필요할 때.

검증:
```bash
bash .claude/validate.sh
```

## 단계 1 — 첫 코드 한 사이클 (30분)

목표: 작은 기능 하나를 brainstorm부터 finish까지.

```bash
# Claude Code 시작
claude

# 1. 의도 탐색 (3분)
> /brainstorm "유저 프로필 페이지에 아바타 업로드"

# 결과: .claude/memory/brainstorms/<file>.md 생성됨
# 내용: 의도 4문항 + 대안 2-3개 + 추천

# 2. 코드 작성 (10분)
> 위 brainstorm 결과대로 구현해줘

# Claude가 code 작성. 자동으로:
#   - prettier 포맷
#   - eslint 자동 수정
#   - tsc 타입 체크
#   - 관련 test 실행
#   - design-lint 하드코딩 색상 검사

# 3. 검증 (5분)
> /verify

# lint + tsc + test + e2e 순차 실행. PASS여야 다음.

# 4. 커밋 (1분)
> /commit

# Conventional commit 메시지 자동 생성. 사용자 확인 후 커밋.

# 5. 마무리 결정 (2분)
> /finish

# 변경 규모 / verify 상태 / branch 자동 점검
# → PR / Direct push / Cleanup 경로 자동 추천
```

**5분짜리 하루 사이클**: brainstorm → code → verify → commit → finish.

## 단계 2 — 첫 프로젝트 (3일)

추가로 활용:

```bash
> /plan "큰 기능 — 결제 통합"
# 멀티스텝 계획을 .claude/plans/<file>.md로 추적
# 단계별 진행 상태 (pending → in_progress → done)

> /test src/payment.ts
# Vitest 단위 테스트 자동 생성

> /security
# OWASP 스캔
```

자동 강제:
- TDD strict 기본 — 테스트 없이 .ts 코드 수정 시 차단
- 위험 명령 27 패턴 차단 (rm -rf /, force push 등)
- 디자인 토큰 강제 (하드코딩 색상 감지)

## 단계 3 — 협업 (1주)

```bash
> /worktree create feat/dashboard
# 격리된 git worktree 생성, 병렬 작업 가능

> /review-pr 42
# GitHub PR #42 코드 리뷰

> /receive-review pr 42
# 받은 리뷰 항목별 분류 + 증거 기반 accept/reject/clarify
```

`design-lint` hook이 자동으로:
- 하드코딩 색상 (oklch 포함) 경고
- 인접 주석 false positive 처리

## 단계 4 — Extensions 활성화 (1개월~)

데이터가 누적되고 익숙해지면:

```bash
bash ~/dev/vibe-flow/setup.sh --list-extensions
# 5 카테고리 보고

# 가장 흔한 추가:
bash ~/dev/vibe-flow/setup.sh --extensions learning-loop
# /metrics, /retrospective 활성

# 회고 정기화
> /retrospective
# 메트릭+세션로그+events 분석 → P0/P1/P2 개선안

# 메이커 도구 (스킬 자체 진화)
bash ~/dev/vibe-flow/setup.sh --extensions meta-quality
> /eval brainstorm    # 정량 측정
> /evolve brainstorm  # 자동 개선 후보 (5 게이트 + A/B)
```

## 흔한 함정

### "스킬 23개 다 외워야 하나?"

**No.** Core 14만 익히고 시작. extensions는 필요할 때.

```
첫주: brainstorm/commit/verify/finish/status/learn 만으로 충분
```

### "TDD strict가 너무 빡빡"

```bash
# 일시적 완화 (특정 세션)
export CLAUDE_TDD_ENFORCE=warn

# 영구 완화 (해당 프로젝트만)
# .claude/settings.local.json의 env에 추가
```

### "에이전트 12개 헷갈림"

평소엔 명시 호출 안 함. /pair, /discuss, /retrospective 등이 내부적으로 호출.
직접 부르고 싶으면: `@developer 인증 로직 구현해줘`

### "설계 안 하고 그냥 만들고 싶어"

작은 변경(3 파일 미만)은 brainstorm 스킵 가능. 큰 변경은 강제 권고. 그래도 무시하면 결국 retrospective에서 "brainstorm 스킵 후 회귀" 패턴 잡힘.

### "메모리가 너무 많아져"

```bash
> /learn show
# 어떤 패턴이 누적됐는지 확인

# 불필요한 항목 직접 .claude/memory/patterns.md에서 삭제
```

## FAQ

### Q. 글로벌에 설치하면 모든 프로젝트에 적용?

`~/.claude/skills`/`agents`/`rules`로 심볼릭 링크하면 글로벌 활성.
hook 자동화는 프로젝트별 setup.sh로만 활성 (settings.local.json 필요).

### Q. 다른 사람과 메모리 공유?

`.claude/memory/` 는 git 추적 (default). 팀원이 clone하면 자동 공유.
민감하면 `.gitignore`에 추가.

### Q. 다른 IDE에서 사용?

Claude Code 전용. 다른 IDE 통합 계획 미정.

### Q. AI cost는?

Hooks는 LLM 호출 안 함 (단순 shell script). 비용은 사용자가 호출하는 스킬 LLM 비용만.
무거운 스킬: /pair, /discuss, /evolve, /design-sync.

ONBEOF
wc -l docs/ONBOARDING.md
```

- [ ] **Step 2: commit**

```bash
git add docs/ONBOARDING.md
git commit -m "docs: ONBOARDING.md — vibe coder 단계별 가이드

단계 0 (설치) → 1 (첫 사이클) → 2 (프로젝트) → 3 (협업) → 4 (extensions).
흔한 함정 + FAQ 포함."
```

---

## Task 29: ROADMAP.md 갱신

**Files:**
- Modify: `ROADMAP.md`

- [ ] **Step 1: 새 구조로 재작성**

```bash
cat > ROADMAP.md <<'ROADEOF'
# vibe-flow ROADMAP

내부 감사 결과 + 커뮤니티 리서치 + 메이커 비전 기반 작업 큐.

**머신 간 동기화**: Claude Code 메모리는 로컬 저장이라 회사↔집 공유가 안 됨.
이 파일이 진행 상황의 **단일 진실의 원천(single source of truth)**.

---

## 완료

### Phase 0 — claude-builds 시기 (1.0.0 이전)

#### 디자인 시스템
- [x] DESIGN.md 9섹션 포맷 지원 (VoltAgent/Google Stitch)
- [x] 디자인 토큰 / 하드코딩 색상 / 다크 모드 분리 규칙
- [x] /design-sync 7/5/6단계 워크플로우 (URL/이미지/HTML)
- [x] /design-audit + design-lint 훅 (oklch 포함)

#### 인프라
- [x] _common.sh DRY화, agents.json 단일 소스, validate.sh 5단계
- [x] settings 매처 통합 (PostToolUse 9→5, Stop 3→1)

#### 커뮤니티 출처 통합
- [x] SQLite Instinct Store (affaan-m/everything-claude-code)
- [x] 실시간 관측 스트림 (disler/claude-code-hooks-multi-agent-observability)
- [x] TDD 강제화 (obra/superpowers)
- [x] Pair Mode + Validator (disler/claude-code-hooks-mastery)
- [x] Hermes Agent 5 패턴 (NousResearch/hermes-agent)
  - Error Classifier (13-class)
  - Context Compressor (12KB 예산)
  - Memory Context Fencing
  - Smart Model Routing
  - Self-Evolution Loop (5 게이트 + A/B 비교)
- [x] Release skill (Shpigford/chops)
- [x] Karpathy 4 원칙 체리피킹 (forrestchang/andrej-karpathy-skills)

#### 4 process skills 도입
- [x] /brainstorm — 의도 탐색
- [x] /plan — 멀티스텝 추적
- [x] /finish — 의사결정 트리
- [x] /receive-review — 리뷰 비판적 수용

### Phase 1 — vibe-flow 리브랜드 + 경량화 (1.0.0)

- [x] **Repo rename**: claude-builds → vibe-flow
- [x] **Core/Extensions 분리**: 14 스킬 core / 9 스킬 extensions / 모든 hook core
- [x] **setup.sh CLI**: --extensions, --all, --list, --info, --remove, --check
- [x] **State 파일** (.vibe-flow.json) 도입
- [x] **마이그레이션 자동 감지** (시그니처 추론)
- [x] **validate.sh 10 stages** (state + reconciliation 추가)
- [x] **README 재구성**: 686 → ~150줄
- [x] **docs/ 분리**: REFERENCE / ARCHITECTURE / MIGRATION / ONBOARDING
- [x] **글로벌 심볼릭 갱신** (Core only)
- [x] **CHANGELOG 1.0.0** breaking notice + 호환 명시

---

## 미완 (우선순위 순)

### 🟢 Phase 2 — UX 개선 (다음 후보)

#### 신규 스킬
- [ ] `/onboard` — 인터랙티브 단계별 가이드 (실력 자가진단 + 추천)
- [ ] `/menu` — 23 스킬 카테고리별 발견성 (실력별 추천)
- [ ] `/inbox` — 12 에이전트 inbox 통합 뷰

#### Statusline 강화
- [ ] hook live status 표시 (마지막 실행 결과)
- [ ] 활성 plan 진행도 표시
- [ ] verify 결과 표시 (✓/✗/⊘)

### 🟡 Phase 3 — UI 레이어 (장기)

- [ ] **vibe-flow-dashboard** (별도 npm 패키지)
  - localhost:9999 — Next.js + WebSocket
  - 현재 작업 / 자동 실행 / inbox / 메트릭 라이브 뷰
  - events.jsonl 실시간 tail
  - .claude/* 상태 시각화
  - **Source 침범 0** — Layer 1/2 그대로

- [ ] **TUI 옵션** (claude-builds-tui — 터미널 대시보드)

### 🔵 Phase 4 — 거버넌스 + 확장

#### 메이커 도구화
- [ ] telemetry 통합 (스킬별 사용 빈도 → 경량화 결정 데이터)
- [ ] eval 자동 회귀 알림 (CI 통합)
- [ ] 빌드 자체 메트릭 dashboard

#### 새 Extensions 후보
- [ ] **i18n** — 국제화 자동화 워크플로우
- [ ] **k8s** — Kubernetes 배포 자동화
- [ ] **mobile** — React Native / Flutter 보강

### 🔵 P5 전략 공백: 토큰/비용 예산 프레임워크

- **배경**: /pair / /discuss / 오케스트레이터 병렬 실행 시 무제한 과금 가능
- **통합 지점**: 신규 hook 또는 wrapper / .claude/budget.json / /metrics 비용 차트
- **예상 공수**: 반나절
- **우선순위**: 실제 과금 사례 발생 시 착수

---

## 작업 재개 절차 (머신 간)

```bash
# 1. 최신 상태 확보
cd ~/dev/vibe-flow && git pull origin main

# 2. ROADMAP 확인 → 다음 항목 선택
cat ROADMAP.md

# 3. 작업 시작 — Claude Code 세션에서:
#    "ROADMAP Phase 2 첫 항목 진행"
```

## 갱신 규칙

- 작업 **시작** 시: 해당 항목 앞에 "🚧 진행중" + 커밋
- 작업 **완료** 시: `[ ]` → `[x]`, 미완 → 완료 섹션 이동, 커밋 해시 추가
- 새 아이디어: "미완"에 우선순위와 함께 추가
- ROADMAP 갱신은 해당 작업 커밋과 함께 묶음

ROADEOF
```

- [ ] **Step 2: commit**

```bash
git add ROADMAP.md
git commit -m "docs(roadmap): vibe-flow 1.0.0 기준 재구성

Phase 0 (claude-builds 시기 완료) / Phase 1 (이번 vibe-flow rename, 완료) /
Phase 2 (UX 개선, 다음) / Phase 3 (UI 레이어) / Phase 4 (거버넌스) /
P5 (토큰 예산)."
```

---

## Task 30: CHANGELOG.md 1.0.0 항목 추가

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Unreleased 섹션을 1.0.0으로 promote**

기존 `## [Unreleased]` 아래 내용을 `## [1.0.0] - 2026-04-30`으로 이동.

```bash
# 현재 CHANGELOG.md 읽고 [Unreleased] 항목 변환
# 직접 편집 권장 — 다음 형태로:
```

```markdown
## [Unreleased]

## [1.0.0] - 2026-04-30 — vibe-flow

### 변경 (Breaking — claude-builds 사용자에게)

- **Repo rename**: `claude-builds` → `vibe-flow`. GitHub auto-redirect 작동.
- **디렉토리 구조**: 평면 → `core/` + `extensions/<name>/` 두 단계.
- **setup.sh 기본 동작 변경**: 이전엔 모든 스킬 설치, 이제 Core 14만. `--all` 또는 `--extensions <name>`로 확장.
- **State 파일 도입**: `.claude/.vibe-flow.json` — 설치 추적/갱신/제거.

### 호환

- ✓ 모든 스킬 이름 그대로 (`/commit`, `/verify`, ...)
- ✓ settings.local.json 그대로 유효 (모든 hook 22개 core)
- ✓ 메모리 / 메트릭 / plans / messages 자동 보존
- ✓ 마이그레이션: `bash setup.sh` 한 번 실행으로 자동

### 추가

- `--list-extensions` / `--info <name>` / `--remove-extension <name>` / `--check`
- `--all` (Core + 5 extensions 모두)
- 마이그레이션 자동 감지 (시그니처 디렉토리 추론)
- validate.sh 10 stages (state 무결성 + state↔fs reconciliation 추가)
- docs/REFERENCE.md / docs/ARCHITECTURE.md / docs/MIGRATION.md / docs/ONBOARDING.md 신설
- extensions/<name>/README.md 5개 신설
- README 686 → ~150줄로 재구성

### 출처 (1.0.0 정식)

- Surgical change / Goal-driven: forrestchang/andrej-karpathy-skills
- TDD Iron Law: obra/superpowers
- Self-evolution + Memory fencing + Error classifier: NousResearch/hermes-agent
- Pair mode (Builder/Validator): disler/claude-code-hooks-mastery
- SQLite instinct store: affaan-m/everything-claude-code
- Observability stream: disler/claude-code-hooks-multi-agent-observability
- Release skill (semver + CHANGELOG): Shpigford/chops
- DESIGN.md 9섹션 포맷: VoltAgent/awesome-design-md
```

기존 `## [1.0.0] - 2026-04-16` (claude-builds 시절) 항목은 `## [0.x.0] - 2026-04-16` 등으로 demote — vibe-flow 1.0.0이 새 첫 안정 릴리즈로 표시:

실제로 이 부분은 정책 결정. 권장:
- **claude-builds 1.0.0 (2026-04-16)을 0.9.0으로 demote**: vibe-flow가 새 1.0.0
- 또는 **유지**: 같은 line의 1.0.0 두 개 (claude-builds 시기 + vibe-flow 시기)

후자 안전. CHANGELOG는 역사 기록.

```markdown
## [1.0.0] - 2026-04-30 — vibe-flow rename + Core/Extensions

### 변경 (Breaking)
[위와 동일]

## [1.0.0-claude-builds] - 2026-04-16

[claude-builds 시기 1.0.0 항목 그대로 보존 — 역사]
```

또는 단순화 — 새 vibe-flow 항목만 추가하고 claude-builds 1.0.0은 그대로 두기. 컨텍스트가 명확하므로 후자도 OK.

여기서는 후자 채택 (단순):

```markdown
## [1.1.0] - 2026-04-30 — vibe-flow rename

[위 변경 내용]

## [1.0.0] - 2026-04-16
[claude-builds 시기 그대로]
```

claude-builds 1.0.0은 첫 안정, vibe-flow 1.1.0은 minor (rename은 breaking이지만 semver는 사용자 1명의 단일 환경 변경이라 minor로 처리).

- [ ] **Step 2: 검증 + commit**

```bash
head -30 CHANGELOG.md
git add CHANGELOG.md
git commit -m "docs(changelog): 1.1.0 — vibe-flow rename + Core/Extensions

Breaking: 디렉토리 구조 / setup.sh 기본 동작 / state 파일 도입.
호환: 스킬 이름 / settings.local.json / 메모리 / 마이그레이션 자동.
추가: --extensions/--all/--list/--info/--remove/--check, validate stage 10,
docs/* 4개 신설, extensions README 5개."
```

---

## Task 31: CLAUDE.md.template + 기타 self-references 정리

**Files:**
- Modify: `templates/CLAUDE.md.template`
- Modify: 잔여 self-references (이전 sed 누락분)

- [ ] **Step 1: 잔여 출현 재검색**

```bash
grep -rln "claude-builds" --exclude-dir=.git --exclude=CHANGELOG.md
```

만약 출현 있으면 (Task 4에서 sed 적용 안 됐을 수도):
```bash
grep -rln "claude-builds" --exclude-dir=.git --exclude=CHANGELOG.md | while read f; do
  sed -i.tmp 's/claude-builds/vibe-flow/g' "$f" && rm "${f}.tmp"
done
```

- [ ] **Step 2: CLAUDE.md.template 검토**

```bash
cat templates/CLAUDE.md.template
```

확인할 사항:
- 프로젝트 설명에 "vibe-flow가 적용된 프로젝트" 언급 가능
- 디렉토리 경로 참조 정확

- [ ] **Step 3: 필요 시 미세 갱신**

(필요한 경우만)

- [ ] **Step 4: commit**

```bash
git add templates/ -A
git status   # 변경 없으면 skip
[ -n "$(git diff --cached)" ] && git commit -m "chore: 잔여 self-references 정리"
```

---

## Task 32: 글로벌 심볼릭 갱신 (메이커 본인)

**Files:** None (filesystem operations on `~/.claude/`)

- [ ] **Step 1: 기존 dead 심볼릭 제거**

```bash
for link in skills agents rules; do
  if [ -L "$HOME/.claude/$link" ]; then
    target=$(readlink "$HOME/.claude/$link")
    echo "  ✗ removing: $link → $target"
    rm "$HOME/.claude/$link"
  fi
done
```

- [ ] **Step 2: vibe-flow Core로 새 심볼릭**

```bash
ln -s /Users/yss/개발/build/vibe-flow/core/skills /Users/yss/.claude/skills
ln -s /Users/yss/개발/build/vibe-flow/core/agents /Users/yss/.claude/agents
ln -s /Users/yss/개발/build/vibe-flow/core/rules /Users/yss/.claude/rules
```

- [ ] **Step 3: agents.json 갱신**

```bash
cp /Users/yss/개발/build/vibe-flow/core/agents.json /Users/yss/.claude/agents.json
jq '.agents | length' /Users/yss/.claude/agents.json
```

Expected: `10`

- [ ] **Step 4: 검증**

```bash
ls -la "$HOME/.claude/" | grep -E "skills|agents|rules"
ls /Users/yss/.claude/skills/ | wc -l
ls /Users/yss/.claude/agents/*.md | wc -l
ls /Users/yss/.claude/rules/*.md | wc -l
```

Expected:
- 3 alive 심볼릭
- skills: 14
- agents: 10
- rules: 6

---

## Task 33: 기존 1 사용 프로젝트에서 마이그레이션 테스트

**Files:** None (테스트만)

- [ ] **Step 1: 기존 사용 프로젝트 식별**

(어떤 프로젝트가 claude-builds로 setup됐는지 사용자가 안내)

```bash
# 예시
PROJECT_DIR=/path/to/your/actual/project
cd "$PROJECT_DIR"
ls -la .claude/
[ -f .claude/.vibe-flow.json ] && echo "이미 vibe-flow" || echo "마이그레이션 필요"
```

- [ ] **Step 2: setup.sh 실행 (마이그레이션 자동 감지)**

```bash
bash /Users/yss/개발/build/vibe-flow/setup.sh 2>&1 | tee /tmp/migration-log.txt
```

마이그레이션 메시지 + 추론된 extensions 확인.

- [ ] **Step 3: 검증**

```bash
bash .claude/validate.sh
```

10 stages 모두 PASS / 0 FAIL이면 성공. 경고만 있으면 OK.

- [ ] **Step 4: 결과 기록**

```bash
echo "== Migration test result ==" 
echo "Project: $PROJECT_DIR"
echo "Detected extensions: $(jq -r '.extensions | keys | join(",")' .claude/.vibe-flow.json)"
echo "validate.sh: PASS/WARN/FAIL counts"
bash .claude/validate.sh 2>&1 | tail -5
```

---

## Task 34: Final 검증 (전체)

**Files:** None

- [ ] **Step 1: vibe-flow repo 자체 무결성**

```bash
cd /Users/yss/개발/build/vibe-flow

echo "== Directory structure =="
find core extensions -type d | wc -l
find core -type f | wc -l
find extensions -type f | wc -l

echo "== Counts =="
echo "Core skills: $(ls core/skills/ | wc -l)"
echo "Core agents: $(ls core/agents/*.md | wc -l)"
echo "Core hooks: $(ls core/hooks/*.sh | wc -l)"
echo "Core rules: $(ls core/rules/*.md | wc -l)"
echo "Core agents.json count: $(jq '.agents | length' core/agents.json)"

for ext in meta-quality design-system deep-collaboration learning-loop code-feedback; do
  s=$(ls "extensions/$ext/skills" 2>/dev/null | wc -l | tr -d ' ')
  a=$(ls "extensions/$ext/agents"/*.md 2>/dev/null | wc -l | tr -d ' ')
  echo "  $ext: skills=$s agents=$a"
done
```

Expected:
```
Core skills: 14
Core agents: 10
Core hooks: 22
Core rules: 6
Core agents.json count: 10
  meta-quality: skills=2 agents=2
  design-system: skills=2 agents=0
  deep-collaboration: skills=2 agents=0
  learning-loop: skills=2 agents=0
  code-feedback: skills=1 agents=0
```

- [ ] **Step 2: setup.sh 통합 테스트 재확인**

```bash
rm -rf /tmp/vf-final-test
mkdir /tmp/vf-final-test && cd /tmp/vf-final-test
bash /Users/yss/개발/build/vibe-flow/setup.sh --all
bash /Users/yss/개발/build/vibe-flow/setup.sh --check
```

10 stages 통과 + 23 스킬 + 12 에이전트 + 22 훅 + 6 규칙.

- [ ] **Step 3: 글로벌 작동 확인**

새 Claude Code 세션에서:
```
/skills   # 23 보이는지 (Core + Extensions)
@developer 안녕  # 응답 가능한지
```

- [ ] **Step 4: 마이그레이션 시나리오 재시연**

```bash
rm -rf /tmp/vf-mig-final
mkdir /tmp/vf-mig-final && cd /tmp/vf-mig-final
mkdir -p .claude/skills/{brainstorm,commit,eval-skill,pair,metrics}
bash /Users/yss/개발/build/vibe-flow/setup.sh
jq '.extensions | keys' .claude/.vibe-flow.json
# Expected: ["deep-collaboration", "learning-loop", "meta-quality"]
```

---

## Task 35: PR 생성 + push

**Files:** None (git operations)

- [ ] **Step 1: 모든 commit 확인**

```bash
cd /Users/yss/개발/build/vibe-flow
git log --oneline pre-vibe-flow-phase-1..HEAD
```

이전 태그(pre-vibe-flow-phase-1) 이후 commits 30+ 개 정도 예상.

- [ ] **Step 2: branch push**

```bash
git push -u origin feat/vibe-flow-phase-1
```

- [ ] **Step 3: PR 생성**

```bash
gh pr create --title "feat: vibe-flow Phase 1 — rebrand + Core/Extensions 분리" --body "$(cat <<'PRBODY'
## Summary

- claude-builds → vibe-flow 리브랜드
- 23 스킬 / 12 에이전트 / 22 훅 / 6 규칙을 Core(14/10/22/6) + Extensions(9 스킬 / 2 에이전트, 5 카테고리)로 재구성
- setup.sh CLI 신설 (--list/--info/--extensions/--all/--remove/--check)
- state 파일 (.vibe-flow.json) 도입
- validate.sh 9 → 10 stages
- README 686 → ~150줄, docs/* 4개 분리

## 입력 spec

[docs/superpowers/specs/2026-04-30-vibe-flow-phase-1-rebrand-lighten-design.md](https://github.com/SONGYEONGSIN/vibe-flow/blob/main/docs/superpowers/specs/2026-04-30-vibe-flow-phase-1-rebrand-lighten-design.md) (commit 8feb02d)

## Test plan

- [x] setup.sh Core only — 14 스킬, 10 에이전트
- [x] setup.sh --all — 23 스킬, 12 에이전트
- [x] setup.sh --extensions <name> — 선택 설치
- [x] setup.sh --remove-extension <name> — 정확한 제거
- [x] setup.sh --list-extensions — 5 표시
- [x] setup.sh --info <name> — README 출력
- [x] setup.sh --check — validate.sh 호출
- [x] 마이그레이션 자동 감지 — 시그니처 디렉토리로 extensions 추론
- [x] validate.sh 10 stages — state + reconciliation 새 stage 작동
- [x] 글로벌 심볼릭 갱신 — Core 14/10/6 노출
- [x] 기존 사용 프로젝트 마이그레이션 (1회 setup.sh 실행)

## Breaking changes

- 디렉토리 구조: 평면 → core/ + extensions/<name>/
- setup.sh 기본 동작: 모든 스킬 → Core 14만 (이전 동작은 --all)

## 호환

- 스킬 이름 그대로 (/commit, /verify, ...)
- settings.local.json 그대로 (모든 hook은 core)
- 메모리/메트릭/plans 자동 보존

🤖 Generated with [Claude Code](https://claude.com/claude-code)
PRBODY
)"
```

- [ ] **Step 4: PR URL 확인**

```bash
gh pr view --json url --jq '.url'
```

URL 출력 — 사용자에게 보고.

---

## Task 36: PR 머지 + 후속

**Files:** None

- [ ] **Step 1: 자체 리뷰**

PR diff 검토 (브라우저):
- 새 파일 추가 정확
- 이동된 파일 history 보존 (git mv)
- README 새 구조 가독성

- [ ] **Step 2: 머지 (squash 권장)**

```bash
gh pr merge --squash --delete-branch
```

- [ ] **Step 3: main 동기화**

```bash
git checkout main
git pull origin main
git log --oneline -3
```

- [ ] **Step 4: feature 브랜치 정리 (이미 GitHub에서 삭제됨, 로컬 정리)**

```bash
git branch -d feat/vibe-flow-phase-1 || git branch -D feat/vibe-flow-phase-1
git fetch --prune
```

---

## 최종 정리

Phase 1 완료 시:
- ✓ 1 PR 머지 (squash, breaking commit 1개)
- ✓ vibe-flow GitHub repo 활성
- ✓ 글로벌 심볼릭 vibe-flow Core 활성
- ✓ 기존 1 프로젝트 마이그레이션 완료
- ✓ ROADMAP Phase 1 [x] 처리됨

다음 Phase 후보:
- Phase 2 — UX 개선 (/onboard, /menu, /inbox, statusline 강화)
- Phase 3 — UI 레이어 (vibe-flow-dashboard 별도 패키지)
- Phase 4 — 거버넌스 (telemetry, eval CI 통합)

---

## Self-Review Checklist (스킬 표준)

(작성자가 plan 완료 후 자체 점검)

- [ ] **Spec coverage**: spec의 모든 섹션이 적어도 1 task에 매핑되는가?
  - Section 1 (스킬 이름 정책 = 유지) → Task 4 (sed에 ~/.claude-builds → vibe-flow만, 스킬 이름 변경 없음)
  - Section 2 (디렉토리 레이아웃) → Task 5-12
  - Section 3 (setup.sh CLI) → Task 13-19
  - Section 4 (마이그레이션) → Task 18, 32, 33
  - Section 5 (validate.sh) → Task 20-23
  - Section 6 (문서) → Task 24-31

- [ ] **Placeholder scan**: TBD/TODO/FIXME 없는지
- [ ] **Type consistency**: extension 이름 (meta-quality 등) 모든 task에서 동일하게 표기
- [ ] **Path consistency**: `/Users/yss/개발/build/vibe-flow` (Task 3 이후)와 `/Users/yss/개발/build/claude-builds` (Task 3 이전) 정확히 구분

</content>
