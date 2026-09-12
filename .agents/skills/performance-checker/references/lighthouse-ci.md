# Lighthouse CI 파이프라인 통합 가이드

CI/CD에 성능 검사를 통합하여 모든 커밋의 성능 영향을 자동으로 추적

---

## 1. GitHub Actions 워크플로우

```yaml
# .github/workflows/lighthouse.yml
name: Lighthouse CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lighthouse:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Use Node.js 20.x
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build project
        run: npm run build

      - name: Install Lighthouse CI
        run: npm install -g @lhci/cli@latest

      - name: Run Lighthouse CI
        run: lhci autorun
        env:
          LHCI_GITHUB_APP_TOKEN: ${{ secrets.LHCI_GITHUB_APP_TOKEN }}
```

---

## 2. lighthouserc.json 상세 설정

### 기본 구조
```json
{
  "ci": {
    "collect": {},
    "assert": {},
    "upload": {}
  }
}
```

### 전체 설정 예시
```json
{
  "ci": {
    "collect": {
      "startServerCommand": "npm run start",
      "startServerReadyPattern": "ready on|started server on",
      "startServerReadyTimeout": 30000,
      "url": [
        "http://localhost:3000",
        "http://localhost:3000/about",
        "http://localhost:3000/products"
      ],
      "numberOfRuns": 3
    },
    "assert": {
      "preset": "lighthouse:recommended",
      "assertions": {
        "categories:performance": ["warn", { "minScore": 0.9 }],
        "categories:accessibility": ["error", { "minScore": 1 }],
        "categories:best-practices": ["warn", { "minScore": 0.9 }],
        "categories:seo": ["warn", { "minScore": 0.9 }],
        "first-contentful-paint": ["warn", { "maxNumericValue": 2000 }],
        "largest-contentful-paint": ["error", { "maxNumericValue": 2500 }],
        "cumulative-layout-shift": ["error", { "maxNumericValue": 0.1 }],
        "interaction-to-next-paint": ["warn", { "maxNumericValue": 200 }]
      }
    },
    "upload": {
      "target": "temporary-public-storage"
    }
  }
}
```

### 성능 예산 설정
```json
{
  "ci": {
    "assert": {
      "budgets": [
        {
          "path": "/*",
          "resourceSizes": [
            { "resourceType": "document", "budget": 20 },
            { "resourceType": "script", "budget": 150 },
            { "resourceType": "stylesheet", "budget": 50 },
            { "resourceType": "image", "budget": 300 },
            { "resourceType": "total", "budget": 500 }
          ],
          "resourceCounts": [
            { "resourceType": "script", "budget": 10 },
            { "resourceType": "third-party", "budget": 5 }
          ]
        }
      ]
    }
  }
}
```

---

## 3. Assertion 레벨

| 레벨 | 동작 |
|------|------|
| `off` | 무시 |
| `warn` | 경고만 표시, 빌드 통과 |
| `error` | 빌드 실패 |

```json
{
  "assertions": {
    "categories:performance": ["warn", { "minScore": 0.9 }],
    "categories:accessibility": ["error", { "minScore": 1 }],
    "largest-contentful-paint": ["error", { "maxNumericValue": 2500 }],
    "interaction-to-next-paint": ["warn", { "maxNumericValue": 200 }]
  }
}
```

---

## 4. 정적 결과물 테스트

서버 없이 빌드된 정적 파일을 직접 테스트

```json
{
  "ci": {
    "collect": {
      "staticDistDir": "./out"
    }
  }
}
```

### Next.js 정적 내보내기
```javascript
// next.config.js
module.exports = {
  output: 'export'
};
```

```bash
npm run build
# ./out 폴더에 정적 파일 생성됨
```

---

## 5. 변경된 페이지만 테스트

PR에서 변경된 파일과 관련된 페이지만 테스트하여 CI 시간 단축

### 워크플로우 예시
```yaml
jobs:
  lighthouse:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Get changed files
        id: changed-files
        uses: tj-actions/changed-files@v44

      - name: Generate test URLs
        id: urls
        run: |
          node scripts/generate-lighthouse-urls.js \
            "${{ steps.changed-files.outputs.all_changed_files }}"

      - name: Run Lighthouse CI
        run: |
          lhci collect --url=${{ steps.urls.outputs.urls }}
          lhci assert
```

---

## 6. 결과 저장 옵션

### temporary-public-storage (기본)
```json
{
  "upload": {
    "target": "temporary-public-storage"
  }
}
```
- 무료, 7일간 보관
- PR 코멘트로 링크 제공

### Lighthouse CI Server (자체 호스팅)
```json
{
  "upload": {
    "target": "lhci",
    "serverBaseUrl": "https://your-lhci-server.com"
  }
}
```
- 무제한 보관
- 시간별 추세 분석 가능

---

## 7. GitHub PR 코멘트 설정

### GitHub App 설치
1. [Lighthouse CI GitHub App](https://github.com/apps/lighthouse-ci) 설치
2. 리포지토리 Settings → Secrets에 `LHCI_GITHUB_APP_TOKEN` 추가

### 환경 변수 설정
```yaml
env:
  LHCI_GITHUB_APP_TOKEN: ${{ secrets.LHCI_GITHUB_APP_TOKEN }}
```

---

## 8. 로컬 테스트

```bash
# Lighthouse CI CLI 설치 (최신 버전)
npm install -g @lhci/cli

# 수집 (서버 자동 시작)
lhci collect --config=lighthouserc.json

# 단언 검증
lhci assert --config=lighthouserc.json

# 또는 autorun으로 한 번에
lhci autorun --config=lighthouserc.json
```

---

## 9. 일반적인 문제 해결

| 문제 | 해결 방법 |
|------|----------|
| 서버 시작 타임아웃 | `startServerReadyTimeout` 증가 (60000ms) |
| 불안정한 점수 | `numberOfRuns: 5`로 평균 사용 |
| 메모리 부족 | GitHub Actions runner 업그레이드 |
| HTTPS 필요 | `--chrome-flags="--ignore-certificate-errors"` |
| INP assertion 미지원 | `@lhci/cli` 0.13+ 버전 확인 |
