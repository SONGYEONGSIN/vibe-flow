# Audit Automation Guide

web-design-guidelines의 130+ 규칙을 자동화하고 CI/CD에 통합하는 가이드.

---

## 자동화 가능한 규칙 분류

### Level 1: 정규식 기반 (즉시 자동화)

```bash
# A01: div에 onClick 사용 감지
grep -rn '<div.*onClick' --include="*.tsx" app/ components/

# A20: outline: none 감지
grep -rn 'outline:\s*none\|outline:\s*0' --include="*.tsx" --include="*.css"

# A30 → A35: img에 alt 누락 감지
grep -rn '<img\b' --include="*.tsx" | grep -v 'alt='

# F01: input에 label 연결 확인
grep -rn '<input' --include="*.tsx" | grep -v 'id=' | grep -v 'aria-label'

# F02: placeholder만 사용하는 input 감지
grep -rn 'placeholder=' --include="*.tsx" | grep -v 'aria-label\|htmlFor\|<label'

# M01: prefers-reduced-motion 미사용 확인
grep -rn 'transition\|animation' --include="*.css" --include="*.tsx" | head -5
grep -rn 'prefers-reduced-motion' --include="*.css" --include="*.tsx" | wc -l

# X01: user-scalable=no 감지
grep -rn 'user-scalable.*no' --include="*.tsx" --include="*.html"

# X06: !important 과용
grep -rn '!important' --include="*.css" --include="*.tsx" | wc -l

# ── Tailwind 전용 패턴 ──────────────────────────────

# TW01: arbitrary value 감지 (px 단위)
grep -rn '\-\[[0-9]*px\]' --include="*.tsx" "$PROJECT_DIR" | grep -v 'node_modules'

# TW01: arbitrary value 감지 (rem 단위)
grep -rn '\-\[[0-9.]*rem\]' --include="*.tsx" "$PROJECT_DIR" | grep -v 'node_modules'

# TW03: 하드코딩 색상 감지
grep -rn 'bg-\[#\|text-\[#\|border-\[#' --include="*.tsx" "$PROJECT_DIR" | grep -v 'node_modules'

# TW05: outline-none 사용 시 focus-visible 확인
grep -rn 'outline-none' --include="*.tsx" "$PROJECT_DIR" | grep -v 'focus-visible\|ring' | grep -v 'node_modules'

# ── 다크모드 패턴 ────────────────────────────────────

# C08: color-scheme CSS 속성 확인
grep -rn 'color-scheme' --include="*.css" --include="*.tsx" "$PROJECT_DIR" | grep -v 'node_modules'

# C10: dark: variant 누락 (색상 클래스에 dark: 없는 경우)
grep -rn 'className=.*bg-white\|className=.*bg-gray\|className=.*text-gray' --include="*.tsx" "$PROJECT_DIR" | grep -v 'dark:' | grep -v 'node_modules'

# ── RSC 경계 패턴 ────────────────────────────────────

# R14: 불필요한 use client 감지 (상태/이벤트 없는 파일)
grep -rn '"use client"' --include="*.tsx" "$PROJECT_DIR" | while read -r line; do
  file=$(echo "$line" | cut -d: -f1)
  if ! grep -q 'useState\|useEffect\|useCallback\|onClick\|onChange' "$file"; then
    echo "[WARN] R14: $file - 상태/이벤트 없는 use client 선언"
  fi
done

# R15: Server Component 내 브라우저 API 사용
grep -rn 'window\.\|document\.\|localStorage\.' --include="*.tsx" "$PROJECT_DIR" | \
  grep -v '"use client"' | grep -v 'node_modules' | grep -v '.test.'

# P24: barrel file 재수출 감지
grep -rn "export.*from './" --include="index.ts" --include="index.tsx" "$PROJECT_DIR" | \
  grep -v 'node_modules' | head -20
```

### Level 2: AST 분석 기반 (ESLint flat config)

```javascript
// eslint.config.js (ESLint v9+ flat config)
import jsxA11y from 'eslint-plugin-jsx-a11y';
import tailwindcss from 'eslint-plugin-tailwindcss';
import reactHooks from 'eslint-plugin-react-hooks';

export default [
  // 접근성 규칙 (jsx-a11y)
  jsxA11y.flatConfigs.recommended,
  {
    plugins: {
      'jsx-a11y': jsxA11y,
    },
    rules: {
      // A01: 클릭 가능 div 금지
      'jsx-a11y/click-events-have-key-events': 'error',
      'jsx-a11y/no-static-element-interactions': 'error',

      // A02: heading 레벨 건너뛰기
      'jsx-a11y/heading-has-content': 'error',

      // A10: aria-label 중복 경고
      'jsx-a11y/aria-props': 'error',

      // A21: tabindex > 0 금지
      'jsx-a11y/tabindex-no-positive': 'error',

      // A35: img alt 필수
      'jsx-a11y/alt-text': 'error',

      // A38: 자동재생 금지
      'jsx-a11y/media-has-caption': 'warn',

      // F01: label 연결
      'jsx-a11y/label-has-associated-control': 'error',
    },
  },

  // Tailwind 규칙
  {
    plugins: { tailwindcss },
    rules: {
      // TW02: 모순 클래스 금지
      'tailwindcss/no-contradicting-classname': 'error',

      // TW01: arbitrary value 경고
      'tailwindcss/no-unnecessary-arbitrary-value': 'warn',

      // TW07: className 정렬 일관성
      'tailwindcss/classnames-order': 'warn',
    },
  },

  // React Hooks 규칙
  {
    plugins: { 'react-hooks': reactHooks },
    rules: {
      // R11: useEffect 의존성 배열
      'react-hooks/exhaustive-deps': 'warn',

      // R04: controlled input
      'react/jsx-key': 'error',
    },
  },
];
```

### Level 3: 런타임 분석 (Playwright + axe-core)

```typescript
// e2e/audit.spec.ts
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

const pages = ['/', '/about', '/pricing', '/blog'];

for (const pagePath of pages) {
  test(`accessibility audit: ${pagePath}`, async ({ page }) => {
    await page.goto(pagePath);

    const results = await new AxeBuilder({ page })
      .withTags([
        'wcag2a',
        'wcag2aa',
        'wcag21aa',
        'wcag22aa',  // WCAG 2.2 태그 추가
      ])
      .analyze();

    // 위반 상세 출력
    if (results.violations.length > 0) {
      console.log('Violations:', JSON.stringify(results.violations, null, 2));
    }

    expect(results.violations).toEqual([]);
  });
}

// 다크모드 접근성 검사
test('dark mode accessibility', async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'dark' });
  await page.goto('/');

  const results = await new AxeBuilder({ page })
    .withTags(['wcag2aa', 'wcag22aa'])
    .analyze();

  expect(results.violations).toEqual([]);
});
```

---

## 자동 감사 스크립트

→ 실행 가능 스크립트: `scripts/audit.sh` 참조

아래는 주요 섹션 스니펫:

```bash
# ─── Tailwind 검사 ──────────────────────────────────
check_tailwind() {
  local SECTION_FAIL=0
  local SECTION_WARN=0

  # TW01: arbitrary value
  count=$(grep -rn '\-\[[0-9]*px\]\|\-\[[0-9.]*rem\]' \
    --include="*.tsx" "$PROJECT_DIR" 2>/dev/null \
    | grep -v 'node_modules' | wc -l | tr -d ' ')
  if [ "$count" -gt 0 ]; then
    log_warn "TW01" "arbitrary value ${count}개 발견 → 테마 토큰 사용 권장"
    SECTION_WARN=$((SECTION_WARN + count))
  fi

  # TW02: 모순 클래스
  count=$(grep -rn 'className=' --include="*.tsx" "$PROJECT_DIR" 2>/dev/null \
    | grep -oP 'p-\d+' | sort | uniq -d | wc -l | tr -d ' ')
  if [ "$count" -gt 0 ]; then
    log_fail "TW02" "모순 클래스 ${count}개 발견"
    SECTION_FAIL=$((SECTION_FAIL + count))
  fi

  # TW03: 하드코딩 색상
  count=$(grep -rn 'bg-\[#\|text-\[#\|border-\[#' \
    --include="*.tsx" "$PROJECT_DIR" 2>/dev/null \
    | grep -v 'node_modules' | wc -l | tr -d ' ')
  if [ "$count" -gt 0 ]; then
    log_warn "TW03" "하드코딩 색상 ${count}개 → 의미론적 토큰 사용"
    SECTION_WARN=$((SECTION_WARN + count))
  fi

  TW_FAIL=$SECTION_FAIL
  TW_WARN=$SECTION_WARN
}

# ─── 다크모드 검사 ──────────────────────────────────
check_darkmode() {
  local SECTION_FAIL=0
  local SECTION_WARN=0

  # C08: color-scheme 속성
  count=$(grep -rn 'color-scheme' --include="*.css" --include="*.tsx" \
    "$PROJECT_DIR" 2>/dev/null | grep -v 'node_modules' | wc -l | tr -d ' ')
  if [ "$count" -eq 0 ]; then
    log_warn "C08" "color-scheme CSS 속성 미선언 → :root { color-scheme: light dark }"
    SECTION_WARN=$((SECTION_WARN + 1))
  fi

  # C04/C11: prefers-color-scheme 지원
  count=$(grep -rn 'prefers-color-scheme\|dark:' --include="*.css" --include="*.tsx" \
    "$PROJECT_DIR" 2>/dev/null | grep -v 'node_modules' | wc -l | tr -d ' ')
  if [ "$count" -eq 0 ]; then
    log_fail "C11" "다크모드 지원 없음 (prefers-color-scheme 또는 Tailwind dark: 없음)"
    SECTION_FAIL=$((SECTION_FAIL + 1))
  fi

  DM_FAIL=$SECTION_FAIL
  DM_WARN=$SECTION_WARN
}

# ─── RSC 경계 검사 ──────────────────────────────────
check_rsc() {
  local SECTION_FAIL=0
  local SECTION_WARN=0

  # R15: Server Component 내 브라우저 API
  count=$(grep -rln 'window\.\|document\.\|localStorage\.' \
    --include="*.tsx" "$PROJECT_DIR" 2>/dev/null \
    | grep -v 'node_modules\|\.test\.' \
    | while read -r f; do
        grep -q '"use client"' "$f" || echo "$f"
      done | wc -l | tr -d ' ')
  if [ "$count" -gt 0 ]; then
    log_fail "R15" "${count}개 파일에서 Server Component 내 브라우저 API 사용"
    SECTION_FAIL=$((SECTION_FAIL + count))
  fi

  RSC_FAIL=$SECTION_FAIL
  RSC_WARN=$SECTION_WARN
}
```

---

## CI/CD 통합

### GitHub Actions

```yaml
# .github/workflows/design-audit.yml
name: Design Guidelines Audit
on:
  pull_request:
    paths:
      - 'app/**'
      - 'components/**'
      - '**/*.css'

jobs:
  lint-a11y:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - name: ESLint (a11y + tailwind)
        run: pnpm eslint --format json --output-file eslint-report.json app/ components/ || true
      - name: Check violations
        run: |
          errors=$(jq '[.[] | .errorCount] | add // 0' eslint-report.json)
          echo "ESLint errors: $errors"
          if [ "$errors" -gt 0 ]; then
            jq '.[] | select(.errorCount > 0) | .filePath, .messages[].message' eslint-report.json
            exit 1
          fi

  grep-audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run grep audit
        run: bash scripts/audit.sh .
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: audit-report
          path: audit-report.md

  axe-audit:
    runs-on: ubuntu-latest
    needs: lint-a11y
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: pnpm install --frozen-lockfile
      - run: pnpm exec playwright install --with-deps chromium
      - run: pnpm build
      - run: pnpm exec playwright test e2e/audit.spec.ts
      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: playwright-report
          path: playwright-report/
```

### Pre-commit Hook

```bash
#!/bin/bash
# .husky/pre-commit

changed_files=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(tsx|jsx)$')

if [ -n "$changed_files" ]; then
  echo "Running accessibility quick check..."
  FAIL=0

  for file in $changed_files; do
    # img alt 누락
    if grep -q '<img\b' "$file" && ! grep -q 'alt=' "$file"; then
      echo "ERROR: $file - img에 alt 속성 누락 [A35]"
      FAIL=1
    fi

    # outline: none (대체 포커스 없음)
    if grep -q 'outline-none\|outline:\s*none' "$file" && \
       ! grep -q 'focus-visible\|ring-\|focus:ring' "$file"; then
      echo "ERROR: $file - outline:none 사용, 대체 포커스 스타일 필요 [A20]"
      FAIL=1
    fi

    # user-scalable=no
    if grep -q 'user-scalable.*no' "$file"; then
      echo "ERROR: $file - user-scalable=no 접근성 위반 [X01]"
      FAIL=1
    fi

    # 하드코딩 색상
    if grep -q 'bg-\[#\|text-\[#' "$file"; then
      echo "WARN: $file - 하드코딩 색상 감지 → 의미론적 토큰 사용 [TW03]"
    fi
  done

  [ $FAIL -eq 0 ] && echo "Accessibility check passed" || exit 1
fi
```

---

## ESLint 커스텀 규칙 작성

### 터치 타겟 크기 검증

```typescript
// eslint-rules/touch-target-size.ts
import { ESLintUtils } from '@typescript-eslint/utils';

export default ESLintUtils.RuleCreator.withoutDocs({
  meta: {
    type: 'problem',
    messages: {
      tooSmall: '터치 타겟이 44px 미만입니다. min-h-[44px] min-w-[44px] 추가하세요.',
    },
    schema: [],
  },
  defaultOptions: [],
  create(context) {
    return {
      JSXOpeningElement(node) {
        const tagName = node.name.type === 'JSXIdentifier' ? node.name.name : '';
        if (!['button', 'a', 'input'].includes(tagName)) return;

        const classAttr = node.attributes.find(
          (attr) => attr.type === 'JSXAttribute' && attr.name.name === 'className'
        );

        if (!classAttr) {
          context.report({ node, messageId: 'tooSmall' });
        }
      },
    };
  },
});
```

---

## 보고서 형식

### JSON 출력 (CI 파싱용)

```json
{
  "timestamp": "2026-02-28T10:00:00Z",
  "project": "my-app",
  "summary": {
    "total": 130,
    "pass": 105,
    "fail": 10,
    "warn": 15,
    "score": 86.5
  },
  "categories": {
    "accessibility": { "pass": 25, "fail": 2, "warn": 3 },
    "forms": { "pass": 12, "fail": 0, "warn": 1 },
    "animation": { "pass": 5, "fail": 0, "warn": 0 },
    "color-theme": { "pass": 8, "fail": 0, "warn": 2 },
    "performance": { "pass": 15, "fail": 2, "warn": 3 },
    "react": { "pass": 18, "fail": 1, "warn": 2 },
    "tailwind": { "pass": 10, "fail": 1, "warn": 4 },
    "anti-patterns": { "pass": 12, "fail": 4, "warn": 0 }
  },
  "violations": [
    {
      "rule": "A01",
      "severity": "error",
      "file": "src/components/Card.tsx",
      "line": 23,
      "message": "클릭 가능한 div → button 사용",
      "fix": "<button onClick={handleClick} type=\"button\">..."
    }
  ]
}
```

### Markdown 출력 (PR 코멘트용)

```markdown
## Design Guidelines Audit

| 카테고리 | FAIL | WARN | INFO | 점수 |
|----------|:----:|:----:|:----:|:----:|
| 접근성 (A) | 2 | 3 | 0 | 78% |
| 폼 (F) | 0 | 1 | 0 | 95% |
| 색상/테마 (C) | 0 | 2 | 0 | 90% |
| 성능 (P) | 2 | 3 | 1 | 75% |
| React/RSC (R) | 1 | 2 | 1 | 80% |
| Tailwind (TW) | 1 | 4 | 2 | 72% |
| 안티패턴 (X) | 0 | 1 | 0 | 95% |
| **총합** | **6** | **16** | **4** | **83%** |

점수 = (PASS + WARN×0.5) / 총 규칙 수 × 100

### Top Issues
1. [A01] Card.tsx:23 - 클릭 가능한 div → `<button>` 사용
2. [R15] utils/theme.ts:5 - Server Component 내 `window` 접근
3. [P24] components/index.ts - barrel file 직접 임포트로 변경 권장
```

---

## 점진적 도입 전략

### Phase 1: 모니터링만 (1주)

- `--warn-only` 모드로 실행
- PR에 리포트 코멘트만 추가
- 기존 위반사항 파악

### Phase 2: 신규 코드 차단 (2주)

- 변경된 파일만 검사
- 새 위반은 PR 차단
- 기존 위반은 허용

### Phase 3: 전체 적용 (4주)

- 모든 파일 검사
- 위반 시 PR 차단
- 기존 위반 백로그 생성

### Phase 4: 자동 수정 (8주)

- ESLint `--fix` 가능한 규칙 자동 수정
- Codemod 작성 (대량 변환)

---

## 성능 벤치마크

| 검사 방법 | 100 파일 | 500 파일 | 1000 파일 |
|----------|:--------:|:--------:|:---------:|
| grep 기반 | 2초 | 5초 | 10초 |
| ESLint (flat config) | 6초 | 20초 | 40초 |
| axe-core (5 페이지) | 15초 | 15초 | 15초 |
| 전체 (grep + ESLint + axe) | 23초 | 40초 | 65초 |
