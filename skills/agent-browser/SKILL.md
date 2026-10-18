---
name: agent-browser
description: Headless browser automation using agent-browser CLI. This skill should be used when performing headless/background web scraping, parallel multi-site operations, or simple page queries that don't require login. Triggers on requests like "크롤링", "스크래핑", "페이지 정보", "헤드리스", "병렬로 웹 작업", "여러 사이트 동시에".
---

# Agent Browser

## Overview

Headless browser automation tool for AI agents. Use agent-browser CLI instead of Claude in Chrome when:
- Headless/background operation is needed (no visible browser)
- Parallel multi-site scraping or monitoring
- Simple page queries without login requirements
- Batch automation tasks

## Prerequisites

Ensure agent-browser is installed before use:

```bash
# Check installation
which agent-browser || npm install -g agent-browser

# Install Chromium if not present
agent-browser install
```

## Quick Start

### Basic Page Access

```bash
# Open a page
agent-browser open https://example.com

# Get page snapshot (accessibility tree - AI optimized)
agent-browser snapshot

# Interactive elements only (compact)
agent-browser snapshot -i

# Screenshot
agent-browser screenshot ./capture.png
```

### Element Interaction

```bash
# Click by selector
agent-browser click "#submit-button"

# Click by text (semantic)
agent-browser find text "Login" click

# Fill input field
agent-browser fill "#email" "test@example.com"

# Get text content
agent-browser get text ".price"
```

## Parallel Operations

Use sessions for independent browser instances:

```bash
# Create multiple sessions
agent-browser --session site1 open https://site-a.com
agent-browser --session site2 open https://site-b.com
agent-browser --session site3 open https://site-c.com

# Work in each session
agent-browser --session site1 snapshot -i
agent-browser --session site2 get text ".product-price"
agent-browser --session site3 screenshot ./site3.png

# List active sessions
agent-browser session list
```

## Common Workflows

### Web Scraping

```bash
agent-browser open https://example.com/products
agent-browser snapshot -i -c  # Compact interactive elements
agent-browser get text ".product-title"
agent-browser get text ".product-price"
```

### Form Automation

```bash
agent-browser open https://example.com/contact
agent-browser fill "#name" "John Doe"
agent-browser fill "#email" "john@example.com"
agent-browser fill "#message" "Hello world"
agent-browser click "button[type='submit']"
agent-browser wait --text "Thank you"
```

### Multi-Page Navigation

```bash
agent-browser open https://example.com
agent-browser find text "Products" click
agent-browser wait --load networkidle
agent-browser snapshot -i
```

## When to Use agent-browser vs Claude in Chrome

| Scenario | Use agent-browser | Use Claude in Chrome |
|----------|-------------------|---------------------|
| Need to see browser | No | Yes |
| Logged-in sites | No (fresh browser) | Yes (existing session) |
| Parallel operations | Yes (multi-session) | Limited |
| CI/CD automation | Yes | No |
| Speed priority | Yes (headless) | No |

## Troubleshooting

### 타임아웃 - 페이지 로딩 실패
- **원인:** 느린 네트워크, SPA 렌더링 지연, 잘못된 URL
- **해결:** `agent-browser wait --load networkidle --timeout 15000` (타임아웃 늘리기). URL이 올바른지 확인

### 셀렉터 실패 - 요소 못 찾음
- **원인:** SPA가 아직 렌더링 안됨, 셀렉터 변경, 동적 class명
- **해결:** `agent-browser wait --selector ".target"` 으로 대기 후 조작. `agent-browser snapshot -i` 로 현재 인터랙티브 요소 확인

### 세션 충돌
- **원인:** 이전 세션이 정리 안됨
- **해결:** `agent-browser session list` 로 확인 후 `agent-browser --session name close`

### Chromium 실행 실패
- **원인:** Chromium 미설치, 의존성 부족 (특히 Linux)
- **해결:** `agent-browser install` 재실행. Linux: `apt install libnss3 libatk-bridge2.0-0`

### 메모리 부족 (대량 크롤링)
- **원인:** 세션을 닫지 않고 계속 생성
- **해결:** 작업 완료 후 반드시 `agent-browser --session name close`. 세션 수 5개 이하 유지

---

## Anti-patterns

| 안티패턴 | 문제 | 해결 |
|----------|------|------|
| 로그인 필요 사이트에 headless 사용 | 인증 불가 | Claude in Chrome 사용 |
| 대기 없이 즉시 데이터 추출 | SPA 빈 데이터 | networkidle 대기 |
| 과도한 병렬 세션 (10+) | 메모리/CPU 폭증 | 3~5 세션으로 제한 |
| robots.txt 무시 | 법적 문제 | robots.txt 먼저 확인 |
| 고정 sleep 사용 | 불안정, 느림 | 조건부 대기 (wait --selector) |

---

## Decision Matrix: agent-browser vs Claude in Chrome

| 기준 | agent-browser | Claude in Chrome |
|------|:------------:|:----------------:|
| 로그인 필요 | X | O |
| 병렬 크롤링 | O | X |
| CI/CD 자동화 | O | X |
| 실시간 화면 확인 | X | O |
| 쿠키/세션 유지 | X | O |
| 속도 | 빠름 (headless) | 보통 |
| 복잡한 인터랙션 | 제한적 | O |

---

## Resources

- `references/commands.md` - 전체 명령어 레퍼런스
- `references/scraping-patterns.md` - 실전 스크래핑 패턴
- `references/ci-integration.md` - CI/CD 통합 가이드
