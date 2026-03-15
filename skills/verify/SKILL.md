---
name: verify
description: 프로젝트 전체 검증 — lint, typecheck, unit test, E2E, 브라우저 콘솔 에러를 순차 실행한다
---

프로젝트 변경사항을 전체 검증한다.

## 절차

모든 명령은 프로젝트 루트에서 실행한다.

### 1. ESLint

```bash
npm run lint
```

### 2. TypeScript 타입 체크

```bash
npx tsc --noEmit
```

### 3. Vitest 단위 테스트

```bash
npm test
```

### 4. Playwright E2E 테스트

```bash
npm run e2e
```

E2E 실행 후 HTML 리포트가 `playwright-report/` 에 자동 생성된다 (`playwright.config.ts`의 `reporter: [["html"]]` 설정).

실패한 테스트가 있으면:
```bash
npx playwright show-report
```
로 브라우저에서 상세 리포트를 확인할 수 있다.

### 5. 브라우저 콘솔 에러 점검

1. 개발 서버 시작 (백그라운드):

   ```bash
   npm run dev &
   ```

   서버가 ready 될 때까지 대기 (최대 10초)

2. Playwright MCP 도구로 주요 페이지별 콘솔 에러 확인:
   - 각 페이지마다 `mcp__playwright__browser_navigate` → `mcp__playwright__browser_console_messages` 순서로 호출
   - 점검 대상: 프로젝트의 공개 접근 가능한 페이지 (인증 불필요한 페이지)
   - 기본 점검 페이지: `/` (루트). 프로젝트에 공개 페이지가 더 있으면 추가 점검
   - 보호된 경로는 미인증 리다이렉트되므로 제외

3. `mcp__playwright__browser_close`로 브라우저 종료

4. 개발 서버 종료:
   ```bash
   kill %1 2>/dev/null || true
   ```

## 출력 형식

모든 단계 완료 후 결과를 테이블로 출력:

```markdown
## 검증 결과

| 단계           | 상태      | 상세                |
| -------------- | --------- | ------------------- |
| ESLint         | PASS/FAIL | 에러 수             |
| TypeScript     | PASS/FAIL | 에러 수             |
| Vitest         | PASS/FAIL | N개 통과 / M개 실패 |
| Playwright E2E | PASS/FAIL | N개 통과 / M개 실패 |
| 콘솔 에러      | PASS/WARN | 에러 수             |

### 전체: PASS / FAIL

- E2E 리포트: `playwright-report/index.html`
```

실패한 항목이 있으면 상세 에러 메시지를 함께 출력한다.
