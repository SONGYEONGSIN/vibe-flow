# /frontend-flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 참고사이트 URL + `DESIGN.md`를 입력하면 기존 디자인 스킬을 지휘해 프론트엔드를 제작하는 오케스트레이션 스킬 `/frontend-flow`를 만든다.

**Architecture:** `extensions/design-system/skills/frontend-flow/`에 얇은 오케스트레이터 `SKILL.md`를 두고, 무거운 내용은 `references/`로 분리(progressive disclosure). P1 토큰추출·P4 검증은 기존 `/design-sync`·`/design-audit`를 재사용하고, 신규는 P0 의존성 게이트 스크립트와 P4 기계적 anti-slop 체커(JS)뿐이다.

**Tech Stack:** Bash, Node.js(CommonJS, 프레임워크 없음), Markdown(SKILL.md/references), JSON(evals). 테스트는 `scripts/tests/*-smoke.sh` 셸 스모크.

## Global Constraints

- 스킬 위치: `extensions/design-system/skills/frontend-flow/` (design-sync·design-audit 형제)
- 스택 고정: **Next.js + Tailwind v4 + shadcn/ui + `src/lib/design-tokens.ts`**, 예외만 문맥 라우팅
- SKILL.md는 얇게 — 9섹션 스키마/pre-flight 매트릭스/블록 카탈로그는 `references/`로 분리
- anti-slop 기본 금지값은 **추출된 브랜드 토큰(DESIGN.md)에 양보** (브랜드 토큰이 이김)
- anti-slop **마케팅 레이아웃 규칙**은 마케팅 표면에만 스코프 (대시보드/데이터 UI 강제 금지)
- 모호한 결정은 게이트에서 `AskUserQuestion` — 조용한 추측 금지
- 테스트 관례: 스모크는 `scripts/tests/<name>-smoke.sh`, `set -u` + PASS/FAIL 카운터, 마지막에 `[ "$FAIL" -eq 0 ]` exit. CI(`.github/workflows/validation-tests.yml`)가 `for t in scripts/tests/*.sh; do bash "$t"; done`으로 자동 실행
- 스킬 frontmatter 필드: `name`, `description`, (선택)`effort`
- 커밋 메시지: `<type>(scope): <desc>` + 마지막 줄 `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`

---

### Task 1: P0 의존성 fail-closed 게이트 스크립트

**Files:**
- Create: `extensions/design-system/skills/frontend-flow/scripts/preflight-deps.sh`
- Test: `scripts/tests/frontend-flow-preflight-smoke.sh`

**Interfaces:**
- Produces: `preflight-deps.sh` — 인자 없음. 필요 커맨드 목록을 `FRONTEND_FLOW_DEPS` 환경변수(기본 `"node npx jq"`)로 읽어 검사. 모두 있으면 stdout `[frontend-flow] 의존성 OK:...` + exit 0. 하나라도 없으면 stderr에 `[frontend-flow] 의존성 누락:...` + 설치 안내 + exit 1.

- [ ] **Step 1: 스모크 테스트 작성 (실패 예상)**

Create `scripts/tests/frontend-flow-preflight-smoke.sh`:

```bash
#!/bin/bash
# extensions/design-system/skills/frontend-flow/scripts/preflight-deps.sh smoke
# 실행: bash scripts/tests/frontend-flow-preflight-smoke.sh
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/extensions/design-system/skills/frontend-flow/scripts/preflight-deps.sh"
PASS=0; FAIL=0

assert_contains() {
  if echo "$3" | grep -qE "$2"; then echo "  ✓ $1"; PASS=$((PASS+1));
  else echo "  ✗ $1"; echo "    pattern: '$2'"; echo "    actual:  '$3'"; FAIL=$((FAIL+1)); fi
}
assert_exit() {
  if [ "$3" = "$2" ]; then echo "  ✓ $1 (exit $2)"; PASS=$((PASS+1));
  else echo "  ✗ $1 (expected $2, got $3)"; FAIL=$((FAIL+1)); fi
}

echo "Test P1: 모든 의존성 존재 → exit 0"
OUT=$(FRONTEND_FLOW_DEPS="jq" bash "$SCRIPT" 2>&1); EC=$?
assert_exit "present-exit" "0" "$EC"
assert_contains "present-msg" "의존성 OK" "$OUT"

echo "Test P2: 누락 의존성 → exit 1 + 안내"
OUT=$(FRONTEND_FLOW_DEPS="jq __nope_missing_cmd__" bash "$SCRIPT" 2>&1); EC=$?
assert_exit "missing-exit" "1" "$EC"
assert_contains "missing-msg" "의존성 누락" "$OUT"
assert_contains "missing-name" "__nope_missing_cmd__" "$OUT"

echo ""; echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `bash scripts/tests/frontend-flow-preflight-smoke.sh`
Expected: FAIL — 스크립트가 없어 `present-exit`부터 실패(exit 127/빈 출력).

- [ ] **Step 3: preflight-deps.sh 구현**

Create `extensions/design-system/skills/frontend-flow/scripts/preflight-deps.sh`:

```bash
#!/bin/bash
# P0 fail-closed dependency gate for /frontend-flow.
# 모든 필수 커맨드가 PATH에 있으면 exit 0, 없으면 exit 1 + 설치 안내(stderr).
set -u

REQUIRED="${FRONTEND_FLOW_DEPS:-node npx jq}"

missing=""
for cmd in $REQUIRED; do
  command -v "$cmd" >/dev/null 2>&1 || missing="$missing $cmd"
done

if [ -n "$missing" ]; then
  echo "[frontend-flow] 의존성 누락:$missing" >&2
  echo "[frontend-flow] 설치 후 재시도하세요:" >&2
  for cmd in $missing; do
    case "$cmd" in
      node|npx) echo "  - $cmd: https://nodejs.org 에서 Node.js 설치" >&2 ;;
      jq)       echo "  - jq: https://jqlang.github.io/jq/download 참고" >&2 ;;
      *)        echo "  - $cmd: PATH 에서 찾을 수 없음" >&2 ;;
    esac
  done
  exit 1
fi

echo "[frontend-flow] 의존성 OK:$(for c in $REQUIRED; do printf ' %s' "$c"; done)"
exit 0
```

- [ ] **Step 4: 테스트 실행하여 통과 확인**

Run: `bash scripts/tests/frontend-flow-preflight-smoke.sh`
Expected: PASS — `PASS=5 FAIL=0`, exit 0.

- [ ] **Step 5: 커밋**

```bash
chmod +x extensions/design-system/skills/frontend-flow/scripts/preflight-deps.sh
git add extensions/design-system/skills/frontend-flow/scripts/preflight-deps.sh scripts/tests/frontend-flow-preflight-smoke.sh
git commit -m "feat(frontend-flow): P0 의존성 fail-closed 게이트 스크립트

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: P4 기계적 anti-slop 체커 (+ 규칙 문서)

**Files:**
- Create: `extensions/design-system/skills/frontend-flow/scripts/anti-slop-check.js`
- Create: `extensions/design-system/skills/frontend-flow/references/anti-slop-preflight.md`
- Test: `scripts/tests/frontend-flow-antislop-smoke.sh`

**Interfaces:**
- Produces: `anti-slop-check.js` — `node anti-slop-check.js <targetRoot> [designMdPath]`. `<targetRoot>`는 파일 또는 디렉토리(.tsx/.jsx/.css/.scss 재귀 수집). stdout에 JSON `{target, checks:[{id,status,detail}], passed, failed}`. 전부 통과 exit 0, 하나라도 실패 exit 1, 인자 없음 exit 2. `designMdPath`의 브랜드 토큰은 해당 금지 규칙을 무효화(양보).
- v1 체크 3종: `em-dash-ban`(항상), `forbidden-font`(브랜드 양보), `pure-black-ban`(브랜드 양보). 나머지 assertion(채도<80%, eyebrow 밀도, 레이아웃 다양성)은 후속 태스크 — `anti-slop-preflight.md`에 "deferred"로 명시.

- [ ] **Step 1: 스모크 테스트 작성 (실패 예상)**

Create `scripts/tests/frontend-flow-antislop-smoke.sh`:

```bash
#!/bin/bash
# anti-slop-check.js smoke
# 실행: bash scripts/tests/frontend-flow-antislop-smoke.sh
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
JS="$REPO_ROOT/extensions/design-system/skills/frontend-flow/scripts/anti-slop-check.js"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0

assert_exit() {
  if [ "$3" = "$2" ]; then echo "  ✓ $1 (exit $2)"; PASS=$((PASS+1));
  else echo "  ✗ $1 (expected $2, got $3)"; FAIL=$((FAIL+1)); fi
}
# jq -e 로 stdout JSON 필드를 검증 (여러 줄 grep 불가 → jq 사용)
assert_jq() {
  if echo "$3" | jq -e "$2" >/dev/null 2>&1; then echo "  ✓ $1"; PASS=$((PASS+1));
  else echo "  ✗ $1"; echo "    filter: '$2'"; echo "    actual:  '$3'"; FAIL=$((FAIL+1)); fi
}
status_of() { echo "$1" | jq -r --arg id "$2" '.checks[] | select(.id==$id) | .status'; }

# clean fixture — 위반 없음
printf 'export const H = () => <h1 className="font-geist text-zinc-900">Hi</h1>\n' > "$TMP/clean.tsx"
# dirty fixture — em-dash, Inter, #000
printf 'export const B = () => <p className="font-inter text-[#000000]">A \xe2\x80\x94 B</p>\n' > "$TMP/dirty.tsx"
# DESIGN.md — Inter/black 브랜드 승인
printf '# DESIGN\n- Body font: Inter\n- Text: #000000 (black)\n' > "$TMP/DESIGN.md"

echo "Test A1: clean → exit 0, failed=0"
OUT=$(node "$JS" "$TMP/clean.tsx" 2>/dev/null); EC=$?
assert_exit "clean-exit" "0" "$EC"
assert_jq "clean-failed0" '.failed == 0' "$OUT"

echo "Test A2: dirty (DESIGN.md 없음) → exit 1, em-dash·font 위반"
OUT=$(node "$JS" "$TMP/dirty.tsx" 2>/dev/null); EC=$?
assert_exit "dirty-exit" "1" "$EC"
[ "$(status_of "$OUT" em-dash-ban)" = "fail" ] && { echo "  ✓ dirty-emdash-fail"; PASS=$((PASS+1)); } || { echo "  ✗ dirty-emdash-fail"; FAIL=$((FAIL+1)); }
[ "$(status_of "$OUT" forbidden-font)" = "fail" ] && { echo "  ✓ dirty-font-fail"; PASS=$((PASS+1)); } || { echo "  ✗ dirty-font-fail"; FAIL=$((FAIL+1)); }

echo "Test A3: dirty + DESIGN.md(Inter/black 승인) → font·black 양보, em-dash만 실패 → exit 1"
OUT=$(node "$JS" "$TMP/dirty.tsx" "$TMP/DESIGN.md" 2>/dev/null); EC=$?
assert_exit "override-exit" "1" "$EC"
[ "$(status_of "$OUT" forbidden-font)" = "pass" ] && { echo "  ✓ override-font-pass"; PASS=$((PASS+1)); } || { echo "  ✗ override-font-pass"; FAIL=$((FAIL+1)); }
[ "$(status_of "$OUT" pure-black-ban)" = "pass" ] && { echo "  ✓ override-black-pass"; PASS=$((PASS+1)); } || { echo "  ✗ override-black-pass"; FAIL=$((FAIL+1)); }
[ "$(status_of "$OUT" em-dash-ban)" = "fail" ] && { echo "  ✓ override-emdash-still-fail"; PASS=$((PASS+1)); } || { echo "  ✗ override-emdash-still-fail"; FAIL=$((FAIL+1)); }

echo "Test A4: 인자 없음 → exit 2"
node "$JS" >/dev/null 2>&1; assert_exit "noarg-exit" "2" "$?"

echo ""; echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

Run: `bash scripts/tests/frontend-flow-antislop-smoke.sh`
Expected: FAIL — `anti-slop-check.js` 없어 전 케이스 실패.

- [ ] **Step 3: anti-slop-check.js 구현**

Create `extensions/design-system/skills/frontend-flow/scripts/anti-slop-check.js`:

```js
#!/usr/bin/env node
// P4 기계적 anti-slop 단언. DESIGN.md 브랜드 토큰이 일반 금지 규칙을 무효화한다.
// Usage: node anti-slop-check.js <targetRoot> [designMdPath]
const fs = require('fs');
const path = require('path');

const [, , targetRoot, designMdPath] = process.argv;
if (!targetRoot) {
  console.error('usage: node anti-slop-check.js <targetRoot> [designMdPath]');
  process.exit(2);
}

// 브랜드 승인 신호 (금지 규칙 양보 근거)
const FORBIDDEN_FONTS = ['Inter', 'Fraunces', 'Instrument Serif'];
let brandFonts = [];
let brandAllowsBlack = false;
if (designMdPath && fs.existsSync(designMdPath)) {
  const dm = fs.readFileSync(designMdPath, 'utf8').toLowerCase();
  brandFonts = FORBIDDEN_FONTS.filter((f) => dm.includes(f.toLowerCase()));
  brandAllowsBlack = /#000000|#000\b|\bblack\b/.test(dm);
}

// 대상 소스 수집
function walk(dir, acc) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) { if (e.name !== 'node_modules') walk(p, acc); }
    else if (/\.(tsx|jsx|css|scss)$/.test(e.name)) acc.push(p);
  }
  return acc;
}
const files = fs.statSync(targetRoot).isDirectory() ? walk(targetRoot, []) : [targetRoot];
const corpus = files.map((f) => fs.readFileSync(f, 'utf8')).join('\n');

const checks = [];
const record = (id, ok, detail) => checks.push({ id, status: ok ? 'pass' : 'fail', detail });

// 1. em-dash 금지 (—) — 브랜드 무관 항상 적용
const emDashes = (corpus.match(/—/g) || []).length;
record('em-dash-ban', emDashes === 0, `em-dash count = ${emDashes}`);

// 2. 금지 폰트 — 브랜드 승인분 양보
const foundFonts = FORBIDDEN_FONTS
  .filter((f) => new RegExp(`\\b${f.replace(/ /g, '[ _-]?')}\\b`, 'i').test(corpus))
  .filter((f) => !brandFonts.includes(f));
record('forbidden-font', foundFonts.length === 0,
  foundFonts.length ? `not-brand-approved: ${foundFonts.join(', ')}` : 'none');

// 3. 순수 검정 금지 — 브랜드 승인 시 양보
const pureBlack = /#000000|#000\b/i.test(corpus);
record('pure-black-ban', !pureBlack || brandAllowsBlack,
  pureBlack ? (brandAllowsBlack ? 'present-but-brand-approved' : 'pure black #000 present') : 'none');

const failed = checks.filter((c) => c.status === 'fail').length;
console.log(JSON.stringify({ target: targetRoot, checks, passed: checks.length - failed, failed }, null, 2));
process.exit(failed === 0 ? 0 : 1);
```

- [ ] **Step 4: 규칙 문서 작성 `references/anti-slop-preflight.md`**

Create `extensions/design-system/skills/frontend-flow/references/anti-slop-preflight.md` — 아래 필수 섹션을 포함:

```markdown
# Anti-Slop Pre-Flight (P4)

> 전부 이진 pass/fail 기계 단언. `scripts/anti-slop-check.js`가 실행한다.
> **브랜드 우선 원칙**: DESIGN.md에 명시된 폰트/색은 아래 금지 규칙을 무효화한다.

## v1 체크 (구현됨)
- **em-dash-ban** — 소스에 `—`(U+2014) 0개. 브랜드 무관 항상 적용.
- **forbidden-font** — `Inter`, `Fraunces`, `Instrument Serif` 금지. DESIGN.md에 명시되면 양보.
- **pure-black-ban** — `#000000`/`#000` 금지. DESIGN.md가 검정을 명시하면 양보.

## deferred 체크 (후속 태스크)
- accent-color==1, radius-system==1, 레이아웃 패밀리 ≥4/8, 채도<80%, eyebrow 밀도 ≤ ceil(sectionCount/3)

## 스코프
- 마케팅 표면(랜딩/포트폴리오)에만 레이아웃 규칙 적용. 대시보드/데이터 UI 제외.
```

- [ ] **Step 5: 테스트 실행하여 통과 확인**

Run: `bash scripts/tests/frontend-flow-antislop-smoke.sh`
Expected: PASS — `FAIL=0`, exit 0.

- [ ] **Step 6: 커밋**

```bash
git add extensions/design-system/skills/frontend-flow/scripts/anti-slop-check.js \
        extensions/design-system/skills/frontend-flow/references/anti-slop-preflight.md \
        scripts/tests/frontend-flow-antislop-smoke.sh
git commit -m "feat(frontend-flow): P4 기계적 anti-slop 체커 + 규칙 문서

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: 정본 DESIGN.md 포맷 레퍼런스 (9섹션 + YAML)

**Files:**
- Create: `extensions/design-system/skills/frontend-flow/references/designmd-format.md`

**Interfaces:**
- Produces: P1 병합 산출물의 스키마 문서. 9개 섹션 헤더 + YAML 프론트매터 키(`colors`, `typography`, `rounded`)를 명시.

- [ ] **Step 1: 레퍼런스 작성**

Create `references/designmd-format.md`, 아래 9개 `##` 섹션을 정확히 포함(VoltAgent/awesome-design-md 표준):

```markdown
# 정본 DESIGN.md 포맷 (P1 병합 산출물)

> 상단 YAML 프론트매터(머신리더블 토큰) + 9개 산문 섹션.
> `why(입력 DESIGN.md)` + `what(사이트 HTML 추출)` 병합 결과를 이 형태로 emit.

```yaml
---
colors:   { primary: "#hex", ... }      # 시맨틱명 + hex
typography: { heading: { fontFamily, size, weight, lineHeight, letterSpacing }, body: {...} }
rounded:  { card, button, badge }
---
```

## 1. Visual Theme & Atmosphere
## 2. Color Palette & Roles
## 3. Typography Rules
## 4. Component Stylings
## 5. Layout Principles
## 6. Depth & Elevation
## 7. Do's and Don'ts
## 8. Responsive Behavior
## 9. Agent Prompt Guide
```

- [ ] **Step 2: 구조 검증**

Run:
```bash
F=extensions/design-system/skills/frontend-flow/references/designmd-format.md
grep -c '^## [1-9]\.' "$F"
```
Expected: `9` (9개 번호 섹션 존재). 또한 `grep -q 'colors:' "$F" && grep -q 'typography:' "$F" && echo OK` → `OK`.

- [ ] **Step 3: 커밋**

```bash
git add extensions/design-system/skills/frontend-flow/references/designmd-format.md
git commit -m "docs(frontend-flow): 정본 DESIGN.md 9섹션+YAML 포맷 레퍼런스

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: 파이프라인 · 컴포넌트 카탈로그 레퍼런스

**Files:**
- Create: `extensions/design-system/skills/frontend-flow/references/pipeline.md`
- Create: `extensions/design-system/skills/frontend-flow/references/component-catalog.md`

**Interfaces:**
- Produces: `pipeline.md` — P0~P5 단계별 입출력·게이트·실패처리 상세(스펙 §3·§5 복제). `component-catalog.md` — shadcn 블록별 `when_to_use`/`not_for` 계약 표.

- [ ] **Step 1: `pipeline.md` 작성**

Create `references/pipeline.md`, 아래 `##` 헤더를 포함하고 각 단계에 입력·출력·게이트·실패처리를 기술: `## P0 Intake`, `## P1 Analyze`, `## Gate A`, `## P2 Research/Select`, `## Gate B`, `## P3 Build`, `## P4 Verify`, `## Gate C`, `## P5 Learn`. 내용은 설계 스펙(`docs/superpowers/specs/2026-07-06-frontend-flow-design.md`) §3·§5의 각 단계 설명을 그대로 옮긴다(재사용 스킬 호출 지점 명시: P1=`/design-sync`, P4=`/design-audit`).

- [ ] **Step 2: `component-catalog.md` 작성**

Create `references/component-catalog.md`, 최소 6개 shadcn 블록 행을 가진 표:

```markdown
# 컴포넌트 카탈로그 (P2 선정 계약)

> shadcn/ui 블록을 계약으로 선정. 자유 창작 금지 — 이 표에서 고른다.

| 블록 | when_to_use | not_for |
|---|---|---|
| button | 모든 액션 트리거 | 링크 네비게이션(Link 사용) |
| card | 실제 elevation 위계 필요 시 | 단순 그룹핑(border-t/divide-y 사용) |
| dialog | 모달 확인/폼 | 인라인 피드백 |
| table | 정형 데이터 행 | 카드형 컬렉션 |
| tabs | 동일 레벨 뷰 전환 | 순차 마법사(Stepper) |
| form | 검증 있는 입력 | 단일 검색창 |
```

- [ ] **Step 3: 구조 검증**

Run:
```bash
P=extensions/design-system/skills/frontend-flow/references
grep -c '^## P[0-9]\|^## Gate' "$P/pipeline.md"   # ≥ 9
grep -c '^| ' "$P/component-catalog.md"            # ≥ 8 (헤더+구분선+6행)
```
Expected: 첫 명령 ≥ 9, 둘째 ≥ 8.

- [ ] **Step 4: 커밋**

```bash
git add extensions/design-system/skills/frontend-flow/references/pipeline.md \
        extensions/design-system/skills/frontend-flow/references/component-catalog.md
git commit -m "docs(frontend-flow): 파이프라인·컴포넌트 카탈로그 레퍼런스

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: SKILL.md 오케스트레이터 + evals

**Files:**
- Create: `extensions/design-system/skills/frontend-flow/SKILL.md`
- Create: `extensions/design-system/skills/frontend-flow/evals/evals.json`

**Interfaces:**
- Consumes: Task 1 `preflight-deps.sh`, Task 2 `anti-slop-check.js`+`anti-slop-preflight.md`, Task 3 `designmd-format.md`, Task 4 `pipeline.md`·`component-catalog.md`.
- Produces: `/frontend-flow` 진입점. frontmatter `name: frontend-flow`, `description`(사용법 포함), `effort: high`. 본문은 얇게 — 각 단계에서 해당 reference를 로드하라고 지시.

- [ ] **Step 1: SKILL.md 작성**

Create `SKILL.md`:

```markdown
---
name: frontend-flow
description: 참고사이트 URL과 DESIGN.md를 입력하면 토큰 추출→정본화→기술선정→구현→검증까지 프론트엔드를 제작한다. 사용법 /frontend-flow <URL|--from-image 경로> [--design DESIGN.md]
effort: high
---

참고사이트 + DESIGN.md를 받아 기존 디자인 스킬을 지휘해 프론트엔드를 제작한다.

## 사전 요구사항 (P0, fail-closed)
`bash scripts/preflight-deps.sh` — 실패 시 즉시 종료.

## 파이프라인
단계별 상세는 `references/pipeline.md`를 로드해 따른다.
- **P1 Analyze** — 참고사이트는 `/design-sync`로 토큰 역추출, DESIGN.md는 9섹션 파싱.
  병합해 루트 `DESIGN.md` 정본 생성 (`references/designmd-format.md` 스키마). 충돌 시 **게이트 A**.
- **P2 Research/Select** — `references/component-catalog.md` 계약에서 컴포넌트 선정, frontend-plan 작성.
- **게이트 B (메인 디렉팅)** — prototype + 정본 DESIGN.md + 기술선정안 승인. 모호점은 `AskUserQuestion`.
- **P3 Build** — `frontend-design-specialist` 에이전트로 구현. 토큰만 사용(design-lint 훅).
- **P4 Verify** — `/design-audit`(색상 커버리지) + `node scripts/anti-slop-check.js <src> <DESIGN.md>`
  (`references/anti-slop-preflight.md`). 실패 항목 수정. **게이트 C**.
- **P5 Learn** — ≥90% 성공 시 learned/ 캐시.

## 범위 밖
백엔드 구현, 배포/CI, 비-프론트 초기화, 카피라이팅.
```

- [ ] **Step 2: evals.json 작성**

Create `evals/evals.json` (design-audit evals 포맷 준수):

```json
{
  "skill_name": "frontend-flow",
  "description": "참고사이트+DESIGN.md 기반 프론트엔드 제작 오케스트레이션 품질 평가",
  "evals": [
    {
      "id": 1,
      "prompt": "/frontend-flow https://example.com --design ./DESIGN.md 를 실행한다. 참고사이트와 DESIGN.md가 모두 주어진 상황이다.",
      "expectations": [
        { "description": "P0에서 의존성 게이트를 먼저 실행한다", "type": "must_pass" },
        { "description": "P1에서 /design-sync로 토큰을 추출하고 DESIGN.md와 병합해 정본을 만든다", "type": "must_pass" },
        { "description": "P3 구현 전 게이트 B에서 사용자 승인을 받는다", "type": "must_pass" },
        { "description": "P4에서 anti-slop-check.js와 /design-audit를 실행한다", "type": "should_pass" }
      ]
    },
    {
      "id": 2,
      "prompt": "/frontend-flow 를 DESIGN.md 없이 참고 URL만으로 실행한다.",
      "expectations": [
        { "description": "사이트에서 정본 DESIGN.md를 생성한다", "type": "must_pass" },
        { "description": "DESIGN.md 미제공을 이유로 실패하지 않는다", "type": "must_pass" }
      ]
    },
    {
      "id": 3,
      "prompt": "참고사이트가 Inter 폰트와 #000000 텍스트를 쓰는 브랜드다. /frontend-flow 실행 후 P4 anti-slop 검사가 도는 상황이다.",
      "expectations": [
        { "description": "브랜드 토큰(Inter/black)이 anti-slop 금지 규칙을 무효화한다", "type": "must_pass" },
        { "description": "em-dash 등 브랜드 무관 규칙은 계속 적용한다", "type": "should_pass" }
      ]
    }
  ]
}
```

- [ ] **Step 3: 검증**

Run:
```bash
S=extensions/design-system/skills/frontend-flow
head -5 "$S/SKILL.md" | grep -q 'name: frontend-flow' && echo "frontmatter OK"
jq -e '.evals | length >= 3' "$S/evals/evals.json" && echo "evals OK"
for r in pipeline designmd-format anti-slop-preflight component-catalog; do
  grep -q "$r" "$S/SKILL.md" && echo "ref $r linked" || echo "MISSING ref $r"
done
```
Expected: `frontmatter OK`, `evals OK`, 4개 `ref ... linked`.

- [ ] **Step 4: 커밋**

```bash
git add extensions/design-system/skills/frontend-flow/SKILL.md \
        extensions/design-system/skills/frontend-flow/evals/evals.json
git commit -m "feat(frontend-flow): SKILL.md 오케스트레이터 + evals

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: 충돌 해소 규칙 반영 + 확장 등록

**Files:**
- Modify: `core/rules/design.md` (안티-제네릭 가드레일 섹션 뒤에 추가)
- Modify: `extensions/design-system/README.md` (스킬 목록에 등록)

**Interfaces:**
- Consumes: 없음 (독립 문서 편집).
- Produces: `rules/design.md`에 "브랜드 토큰 우선 무효화" + "마케팅/앱-UI 스코프" 조항. README에 `frontend-flow` 항목.

- [ ] **Step 1: rules/design.md에 조항 추가**

`core/rules/design.md` 파일 맨 끝(150행 "정당화 없는 사용은 디폴트 의존이다." 뒤)에 append:

```markdown

## 브랜드 우선 원칙 (frontend-flow 연동)

- **추출된 브랜드 토큰이 anti-slop 기본 금지값을 이긴다.** 참고사이트/DESIGN.md가 `Inter`·순수 검정(`#000`)·채도>80% 색을 명시하면, 일반 anti-slop 규칙은 그 항목에 한해 무효화된다. 충실한 클론이 우선.
- **마케팅 레이아웃 규칙의 스코프**: "3카드 금지, hero 2줄 제한, eyebrow 밀도" 등 마케팅 표면 규칙은 랜딩/포트폴리오에만 적용한다. 대시보드·데이터 테이블·관리자 UI에는 강제하지 않는다.
```

- [ ] **Step 2: README에 스킬 등록**

`extensions/design-system/README.md`에서 스킬 목록에 한 줄 추가(기존 design-sync/design-audit 항목과 동일 형식). 정확한 형식을 먼저 확인:

```bash
grep -nE 'design-sync|design-audit' extensions/design-system/README.md
```
그 라인 형식에 맞춰 `frontend-flow — 참고사이트+DESIGN.md → 프론트엔드 제작 오케스트레이션` 항목을 같은 스타일로 삽입.

- [ ] **Step 3: 검증**

Run:
```bash
grep -q '브랜드 우선 원칙' core/rules/design.md && echo "rule OK"
grep -q 'frontend-flow' extensions/design-system/README.md && echo "readme OK"
```
Expected: `rule OK`, `readme OK`.

- [ ] **Step 4: 전체 스모크 회귀 + 커밋**

Run(회귀 — 신규 스모크가 CI 루프에서 통과하는지):
```bash
bash scripts/tests/frontend-flow-preflight-smoke.sh && bash scripts/tests/frontend-flow-antislop-smoke.sh && echo "ALL SMOKE PASS"
```
Expected: `ALL SMOKE PASS`.

```bash
git add core/rules/design.md extensions/design-system/README.md
git commit -m "feat(frontend-flow): 브랜드 우선 규칙 반영 + 확장 등록

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## 완료 기준 (Definition of Done)

- [ ] 신규 스모크 2종(`frontend-flow-preflight-smoke.sh`, `frontend-flow-antislop-smoke.sh`) 통과
- [ ] `extensions/design-system/skills/frontend-flow/`에 SKILL.md + 4개 references + 2개 scripts + evals.json 존재
- [ ] `core/rules/design.md`에 브랜드 우선 원칙 조항 존재
- [ ] `extensions/design-system/README.md`에 frontend-flow 등록
- [ ] 브랜치 `design/frontend-flow-spec`(또는 신규 feature 브랜치)에서 작업, PR 준비
