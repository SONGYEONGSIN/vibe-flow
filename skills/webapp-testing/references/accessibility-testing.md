# Accessibility Testing Guide

Playwright + axe-core를 활용한 웹 접근성 자동 테스트 패턴.

---

## 1. axe-core 통합 설정

### 설치

```bash
pip install playwright axe-playwright-python
# 또는 axe-core를 직접 사용
```

### 기본 접근성 검사 스크립트

```python
from playwright.sync_api import sync_playwright
import json

def run_axe_audit(url: str, output_path: str = "/tmp/a11y_report.json"):
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        page.goto(url)
        page.wait_for_load_state("networkidle")

        # axe-core 주입 및 실행
        page.evaluate("""
          async () => {
            const script = document.createElement('script');
            script.src = 'https://cdnjs.cloudflare.com/ajax/libs/axe-core/4.9.1/axe.min.js';
            document.head.appendChild(script);
            await new Promise(resolve => script.onload = resolve);
          }
        """)

        # 분석 실행
        results = page.evaluate("""
          async () => {
            const results = await axe.run(document, {
              runOnly: {
                type: 'tag',
                values: ['wcag2a', 'wcag2aa', 'best-practice']
              }
            });
            return {
              violations: results.violations,
              passes: results.passes.length,
              incomplete: results.incomplete.length,
              inapplicable: results.inapplicable.length,
            };
          }
        """)

        # 결과 저장
        with open(output_path, "w") as f:
            json.dump(results, f, ensure_ascii=False, indent=2)

        # 요약 출력
        violations = results["violations"]
        print(f"\n=== Accessibility Report ===")
        print(f"Passes: {results['passes']}")
        print(f"Violations: {len(violations)}")
        print(f"Incomplete: {results['incomplete']}")

        for v in violations:
            impact = v.get("impact", "unknown")
            print(f"\n[{impact.upper()}] {v['id']}: {v['description']}")
            print(f"  Help: {v['helpUrl']}")
            for node in v.get("nodes", [])[:3]:
                target = node.get("target", ["unknown"])
                print(f"  Element: {target[0]}")

        browser.close()
        return violations

# 실행
violations = run_axe_audit("http://localhost:3000")
assert len([v for v in violations if v["impact"] in ("critical", "serious")]) == 0
```

---

## 2. WCAG 2.1 AA 자동 검증 패턴

### 페이지별 검증

```python
PAGES_TO_TEST = [
    "/",
    "/about",
    "/pricing",
    "/login",
    "/signup",
    "/dashboard",
    "/contact",
]

def audit_all_pages(base_url: str):
    all_violations = {}

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

        for path in PAGES_TO_TEST:
            url = f"{base_url}{path}"
            page.goto(url)
            page.wait_for_load_state("networkidle")

            # axe-core 주입 (매 페이지마다)
            inject_axe(page)

            results = page.evaluate("""
              async () => {
                const results = await axe.run(document, {
                  runOnly: ['wcag2a', 'wcag2aa']
                });
                return results.violations;
              }
            """)

            if results:
                all_violations[path] = results
                print(f"  {path}: {len(results)} violations")
            else:
                print(f"  {path}: PASS")

        browser.close()

    return all_violations

def inject_axe(page):
    page.evaluate("""
      async () => {
        if (typeof axe === 'undefined') {
          const script = document.createElement('script');
          script.src = 'https://cdnjs.cloudflare.com/ajax/libs/axe-core/4.9.1/axe.min.js';
          document.head.appendChild(script);
          await new Promise(resolve => script.onload = resolve);
        }
      }
    """)
```

### WCAG 레벨별 필터링

```python
# Level A만 검사 (최소 준수)
results = page.evaluate("""
  async () => await axe.run(document, { runOnly: ['wcag2a'] })
""")

# Level AA까지 검사 (권장)
results = page.evaluate("""
  async () => await axe.run(document, { runOnly: ['wcag2a', 'wcag2aa'] })
""")

# 특정 규칙만 검사
results = page.evaluate("""
  async () => await axe.run(document, {
    runOnly: {
      type: 'rule',
      values: ['color-contrast', 'image-alt', 'label', 'link-name']
    }
  })
""")
```

---

## 3. 키보드 네비게이션 테스트

### Tab 순서 검증

```python
def test_tab_order(page, expected_order: list[str]):
    """Tab 키를 눌러 포커스 순서 검증"""
    actual_order = []

    for i in range(len(expected_order)):
        page.keyboard.press("Tab")

        # 현재 포커스된 요소 정보
        focused = page.evaluate("""
          () => {
            const el = document.activeElement;
            return {
              tag: el.tagName.toLowerCase(),
              text: el.textContent?.trim().substring(0, 50),
              role: el.getAttribute('role'),
              ariaLabel: el.getAttribute('aria-label'),
              testId: el.getAttribute('data-testid'),
            };
          }
        """)

        actual_order.append(focused)
        identifier = focused["ariaLabel"] or focused["text"] or focused["testId"]
        print(f"Tab {i+1}: {focused['tag']} - {identifier}")

    # 순서 검증
    for i, expected in enumerate(expected_order):
        actual = actual_order[i]
        actual_id = actual["ariaLabel"] or actual["text"] or actual["testId"]
        assert expected in (actual_id or ""), \
            f"Tab {i+1}: expected '{expected}', got '{actual_id}'"


# 사용 예시
page.goto("http://localhost:3000")
page.wait_for_load_state("networkidle")

test_tab_order(page, [
    "홈",              # 네비게이션 첫 번째 링크
    "서비스",          # 두 번째 링크
    "가격",            # 세 번째 링크
    "무료로 시작하기",  # CTA 버튼
])
```

### Enter/Space 동작 테스트

```python
def test_keyboard_activation(page):
    """버튼과 링크의 키보드 활성화 테스트"""

    # 버튼: Enter + Space 모두 동작
    page.get_by_role("button", name="메뉴 열기").focus()
    page.keyboard.press("Enter")
    expect(page.get_by_role("navigation")).to_be_visible()

    # 닫기
    page.keyboard.press("Escape")
    expect(page.get_by_role("navigation")).to_be_hidden()

    # Space로도 동작
    page.get_by_role("button", name="메뉴 열기").focus()
    page.keyboard.press("Space")
    expect(page.get_by_role("navigation")).to_be_visible()
```

### Focus Trap 테스트 (모달)

```python
def test_focus_trap_in_modal(page):
    """모달 내에서 Tab이 순환하는지 검증"""

    # 모달 열기
    page.get_by_role("button", name="설정").click()
    dialog = page.get_by_role("dialog")
    expect(dialog).to_be_visible()

    # 모달 내 포커스 가능 요소 수 확인
    focusable_count = dialog.evaluate("""
      (el) => el.querySelectorAll(
        'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
      ).length
    """)

    # Tab을 focusable_count + 1번 눌러 처음으로 돌아오는지 확인
    first_focused = None
    for i in range(focusable_count + 1):
        page.keyboard.press("Tab")
        current = page.evaluate("document.activeElement.textContent?.trim()")
        if i == 0:
            first_focused = current
        elif i == focusable_count:
            assert current == first_focused, "Focus should cycle back to first element"

    # Escape로 모달 닫기
    page.keyboard.press("Escape")
    expect(dialog).to_be_hidden()
```

---

## 4. 스크린리더 호환성 체크

### ARIA 속성 검증

```python
def check_aria_attributes(page):
    """필수 ARIA 속성 존재 여부 확인"""

    issues = []

    # 이미지 alt 속성
    images_without_alt = page.evaluate("""
      () => Array.from(document.querySelectorAll('img'))
        .filter(img => !img.alt && !img.getAttribute('aria-hidden'))
        .map(img => img.src.split('/').pop())
    """)
    if images_without_alt:
        issues.append(f"Images without alt: {images_without_alt}")

    # 버튼 접근성 이름
    buttons_without_name = page.evaluate("""
      () => Array.from(document.querySelectorAll('button'))
        .filter(btn => {
          const text = btn.textContent?.trim();
          const ariaLabel = btn.getAttribute('aria-label');
          const ariaLabelledby = btn.getAttribute('aria-labelledby');
          return !text && !ariaLabel && !ariaLabelledby;
        })
        .map(btn => btn.outerHTML.substring(0, 100))
    """)
    if buttons_without_name:
        issues.append(f"Buttons without accessible name: {buttons_without_name}")

    # 폼 필드 레이블
    inputs_without_label = page.evaluate("""
      () => Array.from(document.querySelectorAll('input, select, textarea'))
        .filter(input => {
          if (input.type === 'hidden') return false;
          const id = input.id;
          const label = id ? document.querySelector(`label[for="${id}"]`) : null;
          const ariaLabel = input.getAttribute('aria-label');
          const ariaLabelledby = input.getAttribute('aria-labelledby');
          return !label && !ariaLabel && !ariaLabelledby;
        })
        .map(input => `${input.type || input.tagName}#${input.id || input.name || 'unnamed'}`)
    """)
    if inputs_without_label:
        issues.append(f"Inputs without label: {inputs_without_label}")

    # 링크 텍스트
    vague_links = page.evaluate("""
      () => Array.from(document.querySelectorAll('a'))
        .filter(a => {
          const text = (a.textContent?.trim() || a.getAttribute('aria-label') || '').toLowerCase();
          return ['click here', 'here', 'more', 'read more', '더보기', '여기'].includes(text);
        })
        .map(a => `"${a.textContent?.trim()}" → ${a.href}`)
    """)
    if vague_links:
        issues.append(f"Vague link text: {vague_links}")

    return issues
```

### Live Region 테스트

```python
def test_live_region_announcements(page):
    """동적 콘텐츠 변경 시 aria-live 영역 확인"""

    # aria-live 영역 존재 확인
    live_regions = page.evaluate("""
      () => Array.from(document.querySelectorAll('[aria-live]')).map(el => ({
        role: el.getAttribute('role'),
        ariaLive: el.getAttribute('aria-live'),
        text: el.textContent?.trim().substring(0, 50),
      }))
    """)
    print(f"Live regions found: {len(live_regions)}")

    # 알림 발생 시 live region 업데이트 확인
    page.get_by_role("button", name="저장").click()

    # 성공 메시지가 live region에 나타나는지 확인
    page.wait_for_timeout(500)
    alert = page.locator("[role='alert'], [aria-live='assertive'], [aria-live='polite']")
    expect(alert.first).to_contain_text("저장")
```

---

## 5. 색상 대비 검증

### axe-core 색상 대비 검사

```python
def check_color_contrast(page):
    """WCAG AA 기준 색상 대비 검사 (4.5:1)"""

    inject_axe(page)

    contrast_results = page.evaluate("""
      async () => {
        const results = await axe.run(document, {
          runOnly: { type: 'rule', values: ['color-contrast'] }
        });
        return {
          violations: results.violations.flatMap(v =>
            v.nodes.map(n => ({
              element: n.target[0],
              message: n.failureSummary,
              html: n.html.substring(0, 200),
            }))
          ),
          passes: results.passes.length,
        };
      }
    """)

    print(f"\n=== Color Contrast Report ===")
    print(f"Passing elements: {contrast_results['passes']}")
    print(f"Failing elements: {len(contrast_results['violations'])}")

    for v in contrast_results["violations"]:
        print(f"\n  Element: {v['element']}")
        print(f"  Issue: {v['message']}")

    return contrast_results["violations"]
```

### 다크모드 대비 검사

```python
def check_dark_mode_contrast(page, base_url):
    """라이트/다크 모드 모두에서 대비 검사"""

    results = {}

    for theme in ["light", "dark"]:
        # 테마 전환
        page.goto(base_url)
        page.wait_for_load_state("networkidle")

        if theme == "dark":
            page.evaluate("""
              () => document.documentElement.classList.add('dark')
            """)
            page.wait_for_timeout(300)

        violations = check_color_contrast(page)
        results[theme] = violations
        print(f"\n{theme.upper()} mode: {len(violations)} contrast issues")

    return results
```

---

## 6. 종합 접근성 리포트

```python
def full_accessibility_audit(base_url: str, pages: list[str]):
    """전체 사이트 접근성 감사"""

    report = {"pages": {}, "summary": {"total_violations": 0, "critical": 0, "serious": 0}}

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

        for path in pages:
            url = f"{base_url}{path}"
            page.goto(url)
            page.wait_for_load_state("networkidle")

            inject_axe(page)

            results = page.evaluate("""
              async () => {
                const r = await axe.run(document, { runOnly: ['wcag2a', 'wcag2aa'] });
                return r.violations.map(v => ({
                  id: v.id,
                  impact: v.impact,
                  description: v.description,
                  helpUrl: v.helpUrl,
                  nodes: v.nodes.length,
                }));
              }
            """)

            report["pages"][path] = results
            report["summary"]["total_violations"] += len(results)

            for v in results:
                if v["impact"] == "critical":
                    report["summary"]["critical"] += 1
                elif v["impact"] == "serious":
                    report["summary"]["serious"] += 1

        browser.close()

    # 리포트 출력
    print("\n" + "=" * 60)
    print("ACCESSIBILITY AUDIT REPORT")
    print("=" * 60)
    print(f"Pages tested: {len(pages)}")
    print(f"Total violations: {report['summary']['total_violations']}")
    print(f"Critical: {report['summary']['critical']}")
    print(f"Serious: {report['summary']['serious']}")

    for path, violations in report["pages"].items():
        if violations:
            print(f"\n--- {path} ({len(violations)} issues) ---")
            for v in violations:
                print(f"  [{v['impact']}] {v['id']}: {v['description']} ({v['nodes']} elements)")

    return report
```

---

## 7. 체크리스트

### 자동 검증 가능

- [ ] 모든 이미지에 alt 속성 존재
- [ ] 모든 폼 필드에 label 연결
- [ ] 색상 대비 4.5:1 이상
- [ ] 버튼에 접근성 이름 존재
- [ ] 링크에 의미 있는 텍스트 존재
- [ ] heading 계층 순서 올바름
- [ ] 랜드마크 요소 존재 (main, nav, header, footer)

### 수동 검증 필요

- [ ] Tab 순서가 논리적
- [ ] 키보드만으로 모든 기능 사용 가능
- [ ] 모달에 Focus trap 동작
- [ ] Escape로 모달/드롭다운 닫힘
- [ ] 스크린리더로 읽을 때 내용이 이해 가능
- [ ] 동적 콘텐츠 변경 시 스크린리더 알림
- [ ] 애니메이션이 prefers-reduced-motion 존중
