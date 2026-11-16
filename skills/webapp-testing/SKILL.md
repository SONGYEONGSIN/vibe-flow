---
name: webapp-testing
description: 로컬 웹앱의 UI 동작을 확인하거나 Playwright로 화면·로그를 검증할 때 사용.
license: Complete terms in LICENSE.txt
---

# Web Application Testing

To test local web applications, write native Python Playwright scripts.

**Helper Scripts Available**:
- `scripts/with_server.py` - Manages server lifecycle (supports multiple servers)

**Always run scripts with `--help` first** to see usage. DO NOT read the source until you try running the script first and find that a customized solution is abslutely necessary. These scripts can be very large and thus pollute your context window. They exist to be called directly as black-box scripts rather than ingested into your context window.

## Decision Tree: Choosing Your Approach

```
User task → Is it static HTML?
    ├─ Yes → Read HTML file directly to identify selectors
    │         ├─ Success → Write Playwright script using selectors
    │         └─ Fails/Incomplete → Treat as dynamic (below)
    │
    └─ No (dynamic webapp) → Is the server already running?
        ├─ No → Run: python scripts/with_server.py --help
        │        Then use the helper + write simplified Playwright script
        │
        └─ Yes → Reconnaissance-then-action:
            1. Navigate and wait for networkidle
            2. Take screenshot or inspect DOM
            3. Identify selectors from rendered state
            4. Execute actions with discovered selectors
```

## Example: Using with_server.py

To start a server, run `--help` first, then use the helper:

**Single server:**
```bash
python scripts/with_server.py --server "npm run dev" --port 5173 -- python your_automation.py
```

**Multiple servers (e.g., backend + frontend):**
```bash
python scripts/with_server.py \
  --server "cd backend && python server.py" --port 3000 \
  --server "cd frontend && npm run dev" --port 5173 \
  -- python your_automation.py
```

To create an automation script, include only Playwright logic (servers are managed automatically):
```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True) # Always launch chromium in headless mode
    page = browser.new_page()
    page.goto('http://localhost:5173') # Server already running and ready
    page.wait_for_load_state('networkidle') # CRITICAL: Wait for JS to execute
    # ... your automation logic
    browser.close()
```

## Reconnaissance-Then-Action Pattern

1. **Inspect rendered DOM**:
   ```python
   page.screenshot(path='/tmp/inspect.png', full_page=True)
   content = page.content()
   page.locator('button').all()
   ```

2. **Identify selectors** from inspection results

3. **Execute actions** using discovered selectors

## Common Pitfall

❌ **Don't** inspect the DOM before waiting for `networkidle` on dynamic apps
✅ **Do** wait for `page.wait_for_load_state('networkidle')` before inspection

## Best Practices

- **Use bundled scripts as black boxes** - To accomplish a task, consider whether one of the scripts available in `scripts/` can help. These scripts handle common, complex workflows reliably without cluttering the context window. Use `--help` to see usage, then invoke directly. 
- Use `sync_playwright()` for synchronous scripts
- Always close the browser when done
- Use descriptive selectors: `text=`, `role=`, CSS selectors, or IDs
- Add appropriate waits: `page.wait_for_selector()` or `page.wait_for_timeout()`

## Test Strategy by Type

| 유형 | 용도 | 비중 | 도구 |
|------|------|:----:|------|
| Smoke | 핵심 경로만 빠르게 확인 | 10% | Playwright |
| Regression | 기존 기능 깨짐 방지 | 30% | Playwright |
| E2E | 사용자 시나리오 전체 | 40% | Playwright |
| Visual | UI 시각적 변화 감지 | 10% | Playwright screenshot |
| Accessibility | 접근성 자동 검증 | 10% | axe-core + Playwright |

---

## Troubleshooting

### Flaky 테스트 (간헐적 실패)
- **원인:** 고정 타임아웃, 네트워크 의존, 전역 상태 공유
- **해결:** `wait_for_selector()` 또는 `wait_for_load_state('networkidle')` 사용. `wait_for_timeout()` 제거

### 타임아웃 (30초 초과)
- **원인:** 서버 미응답, 무한 로딩, 잘못된 URL
- **해결:** 서버 상태 먼저 확인. `page.screenshot(path='/tmp/debug.png')` 으로 현재 상태 캡처

### 셀렉터 깨짐
- **원인:** CSS 클래스 변경, DOM 구조 변경
- **해결:** Role/Text 기반 셀렉터 사용 (CSS 의존 최소화). `page.get_by_role('button', name='제출')` 권장

### 서버 시작 실패 (with_server.py)
- **원인:** 포트 충돌, 의존성 미설치, 빌드 에러
- **해결:** `lsof -i :3000` 으로 포트 점유 확인. `npm install` 재실행

### 스크린샷 빈 화면
- **원인:** 페이지 로드 전 캡처, headless 렌더링 문제
- **해결:** `page.wait_for_load_state('networkidle')` 후 캡처. viewport 크기 지정

---

## Anti-patterns

| 안티패턴 | 문제 | 해결 |
|----------|------|------|
| `sleep(3000)` 남용 | 느리고 불안정 | 조건부 대기 사용 |
| 구현 세부사항 테스트 | 리팩터링 시 깨짐 | 동작(behavior) 테스트 |
| 과도한 E2E (100개+) | 느림, 유지보수 비용 | 핵심 경로만 E2E, 나머지 단위 |
| CSS 셀렉터 의존 | 스타일 변경 시 깨짐 | Role/TestId 기반 |
| 전역 상태 공유 | 테스트 간 의존성 | 각 테스트 독립 실행 |
| 스크린샷 없는 디버깅 | 원인 파악 어려움 | 실패 시 항상 스크린샷 캡처 |

---

## Reference Files

- **examples/** - Examples showing common patterns:
  - `element_discovery.py` - Discovering buttons, links, and inputs on a page
  - `static_html_automation.py` - Using file:// URLs for local HTML
  - `console_logging.py` - Capturing console logs during automation
- **references/playwright-patterns.md** - 셀렉터, 폼, 모달, 네트워크 모킹 등 상세 패턴
- **references/accessibility-testing.md** - axe-core 접근성 자동 테스트