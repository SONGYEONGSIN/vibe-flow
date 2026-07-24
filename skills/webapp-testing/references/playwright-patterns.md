# Playwright Patterns

Playwright를 활용한 웹 앱 테스트 패턴 모음. 실전 시나리오별 코드와 안티패턴.

---

## 1. 셀렉터 우선순위

우선순위가 높은 것부터 사용:

| 우선순위 | 셀렉터 | 예시 | 이유 |
|:--------:|--------|------|------|
| 1 | Role | `page.getByRole('button', { name: '제출' })` | 접근성 기반, 구현 독립 |
| 2 | Text | `page.getByText('로그인')` | 사용자 관점 |
| 3 | Label | `page.getByLabel('이메일')` | 폼 요소에 적합 |
| 4 | Placeholder | `page.getByPlaceholder('검색어 입력')` | label 없을 때 |
| 5 | TestId | `page.getByTestId('submit-btn')` | 안정적이지만 구현 종속 |
| 6 | CSS | `page.locator('.btn-primary')` | 최후의 수단 |

### Before/After

```python
# Bad: CSS 셀렉터 의존
page.locator("div.form-container > button.btn-primary:nth-child(2)").click()

# Good: Role 기반 셀렉터
page.get_by_role("button", name="제출").click()
```

```python
# Bad: XPath
page.locator("//div[@class='modal']//input[@type='email']").fill("test@test.com")

# Good: Label 기반
page.get_by_label("이메일").fill("test@test.com")
```

---

## 2. 폼 테스트 패턴

### 기본 폼 입력 + 제출

```python
from playwright.sync_api import sync_playwright, expect

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page()
    page.goto("http://localhost:3000/signup")
    page.wait_for_load_state("networkidle")

    # 입력
    page.get_by_label("이름").fill("홍길동")
    page.get_by_label("이메일").fill("hong@example.com")
    page.get_by_label("비밀번호").fill("SecurePass123!")

    # 약관 동의
    page.get_by_role("checkbox", name="이용약관").check()

    # 제출
    page.get_by_role("button", name="가입하기").click()

    # 성공 확인
    page.wait_for_url("**/welcome")
    expect(page.get_by_text("가입을 환영합니다")).to_be_visible()

    browser.close()
```

### 유효성 검증 테스트

```python
# 빈 필드 제출 시 에러 메시지
page.get_by_role("button", name="제출").click()
expect(page.get_by_text("이메일을 입력해주세요")).to_be_visible()

# 잘못된 이메일 형식
page.get_by_label("이메일").fill("invalid-email")
page.get_by_role("button", name="제출").click()
expect(page.get_by_text("올바른 이메일 형식이 아닙니다")).to_be_visible()

# 비밀번호 강도 부족
page.get_by_label("비밀번호").fill("123")
expect(page.get_by_text("8자 이상")).to_be_visible()
```

### Select / Dropdown

```python
# <select> 요소
page.get_by_label("국가").select_option("KR")

# 커스텀 드롭다운 (Radix, shadcn 등)
page.get_by_role("combobox", name="국가").click()
page.get_by_role("option", name="대한민국").click()
```

---

## 3. 모달 / 다이얼로그 테스트

### 모달 열기 + 닫기

```python
# 모달 열기
page.get_by_role("button", name="삭제").click()

# 모달 내 요소 대기 + 검증
dialog = page.get_by_role("dialog")
expect(dialog).to_be_visible()
expect(dialog.get_by_text("정말 삭제하시겠습니까?")).to_be_visible()

# 확인 버튼 클릭
dialog.get_by_role("button", name="삭제 확인").click()

# 모달 닫힘 확인
expect(dialog).to_be_hidden()
```

### 브라우저 네이티브 다이얼로그

```python
# confirm 다이얼로그 자동 처리
page.on("dialog", lambda dialog: dialog.accept())
page.get_by_role("button", name="삭제").click()

# 또는 dismiss
page.on("dialog", lambda dialog: dialog.dismiss())
```

---

## 4. 파일 업로드 / 다운로드

### 파일 업로드

```python
# input[type="file"] 직접 설정
page.get_by_label("파일 선택").set_input_files("/tmp/test-image.png")

# 여러 파일
page.get_by_label("파일 선택").set_input_files([
    "/tmp/file1.png",
    "/tmp/file2.pdf",
])

# 드래그앤드롭 영역 (input이 숨겨진 경우)
file_input = page.locator("input[type='file']")
file_input.set_input_files("/tmp/test.png")
```

### 파일 다운로드

```python
# 다운로드 대기
with page.expect_download() as download_info:
    page.get_by_role("button", name="다운로드").click()

download = download_info.value
print(f"파일명: {download.suggested_filename}")

# 저장
download.save_as(f"/tmp/{download.suggested_filename}")

# 검증
import os
assert os.path.exists(f"/tmp/{download.suggested_filename}")
assert os.path.getsize(f"/tmp/{download.suggested_filename}") > 0
```

---

## 5. 네트워크 모킹

### route.fulfill - API 응답 모킹

```python
# API 응답 모킹
def mock_api(route):
    route.fulfill(
        status=200,
        content_type="application/json",
        body='[{"id": 1, "name": "테스트 상품", "price": 10000}]',
    )

page.route("**/api/products", mock_api)
page.goto("http://localhost:3000/products")

# 모킹된 데이터로 렌더링 확인
expect(page.get_by_text("테스트 상품")).to_be_visible()
expect(page.get_by_text("10,000원")).to_be_visible()
```

### route.abort - 리소스 차단

```python
# 이미지/폰트 차단 (테스트 속도 향상)
page.route("**/*.{png,jpg,jpeg,gif,svg,woff,woff2}", lambda route: route.abort())

# 특정 API 에러 시뮬레이션
page.route("**/api/data", lambda route: route.fulfill(status=500, body="Server Error"))
page.goto("http://localhost:3000/dashboard")
expect(page.get_by_text("데이터를 불러올 수 없습니다")).to_be_visible()
```

### 요청 가로채기 + 수정

```python
def modify_request(route, request):
    # 요청 헤더 추가
    headers = {**request.headers, "X-Test-Mode": "true"}
    route.continue_(headers=headers)

page.route("**/api/**", modify_request)
```

---

## 6. 인증 상태 공유 (storageState)

### 인증 상태 저장

```python
# 로그인 수행 후 상태 저장
page.goto("http://localhost:3000/login")
page.get_by_label("이메일").fill("admin@example.com")
page.get_by_label("비밀번호").fill("password123")
page.get_by_role("button", name="로그인").click()
page.wait_for_url("**/dashboard")

# 쿠키 + localStorage 저장
context.storage_state(path="/tmp/auth_state.json")
browser.close()
```

### 인증 상태 재사용

```python
# 저장된 인증으로 새 컨텍스트 생성
browser = p.chromium.launch(headless=True)
context = browser.new_context(storage_state="/tmp/auth_state.json")
page = context.new_page()

# 이미 로그인된 상태
page.goto("http://localhost:3000/dashboard")
expect(page.get_by_text("관리자님")).to_be_visible()  # 로그인 없이 접근
```

### 여러 사용자 역할 테스트

```python
# 관리자 컨텍스트
admin_ctx = browser.new_context(storage_state="/tmp/admin_auth.json")
admin_page = admin_ctx.new_page()

# 일반 사용자 컨텍스트
user_ctx = browser.new_context(storage_state="/tmp/user_auth.json")
user_page = user_ctx.new_page()

# 동시에 다른 화면 확인
admin_page.goto("http://localhost:3000/admin")
user_page.goto("http://localhost:3000/admin")

expect(admin_page.get_by_text("관리자 패널")).to_be_visible()
expect(user_page.get_by_text("접근 권한이 없습니다")).to_be_visible()
```

---

## 7. 시각적 회귀 테스트

### 기본 스크린샷 비교

```python
# 스크린샷 캡처
page.goto("http://localhost:3000")
page.wait_for_load_state("networkidle")

# 전체 페이지
page.screenshot(path="/tmp/homepage.png", full_page=True)

# 특정 요소만
page.locator(".hero-section").screenshot(path="/tmp/hero.png")
```

### 동적 콘텐츠 마스킹

```python
# 날짜, 시간 등 동적 요소 숨기기
page.evaluate("""
  document.querySelectorAll('[data-dynamic]').forEach(el => {
    el.style.visibility = 'hidden';
  });
""")
page.screenshot(path="/tmp/stable-screenshot.png")
```

### 반응형 테스트

```python
# 다양한 뷰포트에서 스크린샷
viewports = [
    {"width": 375, "height": 812, "name": "mobile"},
    {"width": 768, "height": 1024, "name": "tablet"},
    {"width": 1440, "height": 900, "name": "desktop"},
]

for vp in viewports:
    page.set_viewport_size({"width": vp["width"], "height": vp["height"]})
    page.wait_for_timeout(500)  # 리사이즈 반영 대기
    page.screenshot(path=f"/tmp/screenshot_{vp['name']}.png", full_page=True)
```

---

## 8. 자주 발생하는 문제 해결

### Flaky 테스트 방지

```python
# Bad: 고정 대기
page.wait_for_timeout(3000)

# Good: 조건부 대기
page.wait_for_load_state("networkidle")
expect(page.get_by_text("로딩 완료")).to_be_visible(timeout=10000)
```

```python
# Bad: 즉시 클릭
page.locator(".btn").click()

# Good: 클릭 가능할 때까지 대기
page.get_by_role("button", name="제출").click(timeout=5000)
```

### 타임아웃 디버깅

```python
# 어떤 요소가 렌더링되었는지 확인
page.screenshot(path="/tmp/debug_state.png")

# 현재 URL 확인
print(f"Current URL: {page.url}")

# DOM 상태 확인
content = page.content()
with open("/tmp/debug_dom.html", "w") as f:
    f.write(content)
```

### 셀렉터 깨짐

```python
# Bad: 구조 의존 셀렉터
page.locator("div.container > div:nth-child(3) > button")

# Good: 의미 기반 셀렉터
page.get_by_role("button", name="다음")

# data-testid로 안정적 바인딩 (구조 변경에 강함)
page.get_by_test_id("next-button")
```

---

## 9. 성능 팁

```python
# 불필요한 리소스 차단으로 테스트 속도 향상
page.route("**/*.{png,jpg,gif,svg,woff,woff2}", lambda route: route.abort())

# 캐시 활용 - 동일 상태 재사용
context = browser.new_context(storage_state="/tmp/cached_state.json")

# 병렬 테스트 실행 시 별도 컨텍스트 사용
context1 = browser.new_context()
context2 = browser.new_context()
page1 = context1.new_page()
page2 = context2.new_page()
```

---

## 10. 콘솔 로그 캡처

```python
# 콘솔 메시지 수집
console_messages = []
page.on("console", lambda msg: console_messages.append({
    "type": msg.type,
    "text": msg.text,
}))

page.goto("http://localhost:3000")

# 에러 로그 확인
errors = [m for m in console_messages if m["type"] == "error"]
assert len(errors) == 0, f"Console errors found: {errors}"
```
