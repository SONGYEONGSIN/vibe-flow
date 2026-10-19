# CI Integration Guide

agent-browser를 CI/CD 파이프라인에서 활용하는 패턴.

---

## 1. GitHub Actions 기본 설정

### Workflow 파일

```yaml
# .github/workflows/scrape.yml
name: Scheduled Data Collection

on:
  schedule:
    - cron: '0 9 * * 1-5'  # 평일 오전 9시 (UTC)
  workflow_dispatch:          # 수동 실행 가능

jobs:
  scrape:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install agent-browser
        run: npm install -g agent-browser && agent-browser install

      - name: Run scraping script
        run: bash scripts/scrape.sh
        timeout-minutes: 10

      - name: Upload results
        uses: actions/upload-artifact@v4
        with:
          name: scrape-results-${{ github.run_number }}
          path: results/
          retention-days: 30
```

### 스크래핑 스크립트 예시

```bash
#!/bin/bash
# scripts/scrape.sh
set -euo pipefail

RESULTS_DIR="results"
mkdir -p "$RESULTS_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "Starting data collection at ${TIMESTAMP}"

# 1. 사이트 접근
agent-browser open "https://example.com/data"
agent-browser wait --load networkidle

# 2. 데이터 추출
agent-browser execute "
  JSON.stringify(
    Array.from(document.querySelectorAll('.data-row')).map(row => ({
      name: row.querySelector('.name')?.textContent?.trim(),
      value: row.querySelector('.value')?.textContent?.trim(),
      updated: row.querySelector('.date')?.textContent?.trim(),
    }))
  )
" > "${RESULTS_DIR}/data_${TIMESTAMP}.json"

# 3. 검증
COUNT=$(python3 -c "import json; print(len(json.load(open('${RESULTS_DIR}/data_${TIMESTAMP}.json'))))")
echo "Collected ${COUNT} records"

if [ "$COUNT" -lt 1 ]; then
  echo "ERROR: No data collected!"
  exit 1
fi

echo "Collection complete: ${RESULTS_DIR}/data_${TIMESTAMP}.json"
```

---

## 2. 스케줄링 패턴

### 시간대별 스케줄

```yaml
# 한국 시간 기준 (UTC+9)
on:
  schedule:
    # KST 오전 9시 = UTC 자정
    - cron: '0 0 * * 1-5'
    # KST 오후 6시 = UTC 오전 9시
    - cron: '0 9 * * 1-5'
```

### 조건부 실행

```yaml
jobs:
  check-and-scrape:
    runs-on: ubuntu-latest
    steps:
      - name: Check if site is accessible
        id: health
        run: |
          STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://example.com)
          echo "status=${STATUS}" >> $GITHUB_OUTPUT

      - name: Run scraper
        if: steps.health.outputs.status == '200'
        run: bash scripts/scrape.sh
```

---

## 3. 결과 저장 전략

### GitHub Artifacts

```yaml
- name: Upload artifacts
  uses: actions/upload-artifact@v4
  with:
    name: data-${{ github.run_number }}
    path: results/*.json
    retention-days: 90
```

### Git 커밋 (데이터 저장소)

```yaml
- name: Commit results to data branch
  run: |
    git config user.name "github-actions[bot]"
    git config user.email "github-actions[bot]@users.noreply.github.com"
    git checkout -B data
    cp results/*.json data/
    git add data/
    git commit -m "data: update $(date +%Y-%m-%d)" || echo "No changes"
    git push origin data --force
```

### 외부 저장소 (Supabase)

```yaml
- name: Save to Supabase
  env:
    SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
    SUPABASE_KEY: ${{ secrets.SUPABASE_SERVICE_KEY }}
  run: |
    python3 scripts/save_to_supabase.py results/data.json
```

```python
# scripts/save_to_supabase.py
import json, os, sys, urllib.request

def save_to_supabase(filepath):
    url = os.environ['SUPABASE_URL'] + '/rest/v1/scraped_data'
    key = os.environ['SUPABASE_KEY']

    with open(filepath) as f:
        data = json.load(f)

    req = urllib.request.Request(
        url,
        data=json.dumps(data).encode(),
        headers={
            'apikey': key,
            'Authorization': f'Bearer {key}',
            'Content-Type': 'application/json',
            'Prefer': 'resolution=merge-duplicates',
        },
        method='POST',
    )
    urllib.request.urlopen(req)
    print(f"Saved {len(data)} records to Supabase")

if __name__ == '__main__':
    save_to_supabase(sys.argv[1])
```

### S3/R2 업로드

```yaml
- name: Upload to R2
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.R2_ACCESS_KEY }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.R2_SECRET_KEY }}
    AWS_ENDPOINT_URL: ${{ secrets.R2_ENDPOINT }}
  run: |
    aws s3 cp results/ s3://my-bucket/scrape/$(date +%Y/%m/%d)/ \
      --recursive --endpoint-url "$AWS_ENDPOINT_URL"
```

---

## 4. 실패 알림

### Slack Webhook

```yaml
- name: Notify on failure
  if: failure()
  run: |
    curl -X POST "${{ secrets.SLACK_WEBHOOK }}" \
      -H 'Content-Type: application/json' \
      -d "{
        \"text\": \"Scraping failed\",
        \"blocks\": [{
          \"type\": \"section\",
          \"text\": {
            \"type\": \"mrkdwn\",
            \"text\": \"*Scraping Job Failed*\nRepo: ${{ github.repository }}\nRun: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}\nTime: $(date -u +%Y-%m-%dT%H:%M:%SZ)\"
          }
        }]
      }"
```

### GitHub Issue 자동 생성

```yaml
- name: Create issue on failure
  if: failure()
  uses: actions/github-script@v7
  with:
    script: |
      const title = `Scraping failed: ${new Date().toISOString().split('T')[0]}`;
      const body = `
      ## Scraping Job Failed

      - **Run**: ${context.serverUrl}/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}
      - **Time**: ${new Date().toISOString()}

      Please check the workflow logs for details.
      `;

      await github.rest.issues.create({
        owner: context.repo.owner,
        repo: context.repo.repo,
        title,
        body,
        labels: ['bug', 'automation'],
      });
```

### 성공 시 요약 알림

```yaml
- name: Notify success
  if: success()
  run: |
    COUNT=$(cat results/summary.txt | wc -l)
    curl -X POST "${{ secrets.SLACK_WEBHOOK }}" \
      -H 'Content-Type: application/json' \
      -d "{\"text\": \"Scraping complete: ${COUNT} records collected\"}"
```

---

## 5. 모니터링 패턴

### 변경 감지 + 알림

```yaml
name: Price Monitor

on:
  schedule:
    - cron: '0 */6 * * *'  # 6시간마다

jobs:
  monitor:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install tools
        run: npm install -g agent-browser && agent-browser install

      - name: Fetch current prices
        run: bash scripts/fetch_prices.sh > /tmp/current.json

      - name: Compare with previous
        id: diff
        run: |
          if [ -f data/latest.json ]; then
            CHANGES=$(python3 scripts/compare.py data/latest.json /tmp/current.json)
            echo "changes=${CHANGES}" >> $GITHUB_OUTPUT
          else
            echo "changes=first_run" >> $GITHUB_OUTPUT
          fi

      - name: Notify if changed
        if: steps.diff.outputs.changes != '0' && steps.diff.outputs.changes != 'first_run'
        run: |
          curl -X POST "${{ secrets.SLACK_WEBHOOK }}" \
            -H 'Content-Type: application/json' \
            -d "{\"text\": \"Price changes detected: ${{ steps.diff.outputs.changes }} items updated\"}"

      - name: Save current as latest
        run: |
          cp /tmp/current.json data/latest.json
          git add data/latest.json
          git commit -m "data: price update $(date +%Y-%m-%d)" || true
          git push || true
```

---

## 6. 디버깅

### 스크린샷 캡처 (실패 시)

```yaml
- name: Capture debug screenshot
  if: failure()
  run: |
    agent-browser screenshot /tmp/debug_screenshot.png 2>/dev/null || true

- name: Upload debug artifacts
  if: failure()
  uses: actions/upload-artifact@v4
  with:
    name: debug-${{ github.run_number }}
    path: /tmp/debug_screenshot.png
    retention-days: 7
```

### 상세 로깅

```bash
#!/bin/bash
# scripts/scrape.sh (디버그 모드)
set -euxo pipefail  # -x 로 모든 명령 출력

# 환경 정보
echo "=== Environment ==="
agent-browser --version
node --version
which chromium-browser || which chromium || echo "No system chromium"

# 각 단계별 상태 확인
echo "=== Opening page ==="
agent-browser open "https://example.com"
echo "=== Waiting ==="
agent-browser wait --load networkidle --timeout 15000
echo "=== Taking snapshot ==="
agent-browser snapshot | head -50
echo "=== Extracting data ==="
agent-browser get text ".data"
```

---

## 7. 보안 고려사항

```yaml
# secrets 관리
env:
  # API 키는 항상 secrets로 관리
  API_KEY: ${{ secrets.API_KEY }}
  # 절대 하드코딩 금지

# 최소 권한 원칙
permissions:
  contents: read
  issues: write  # 실패 시 이슈 생성 필요할 때만
```

### 체크리스트

- [ ] API 키/토큰을 GitHub Secrets에 저장
- [ ] workflow 파일에 비밀값 하드코딩 안함
- [ ] 필요한 최소 권한만 설정
- [ ] 수집 데이터에 개인정보 포함 여부 확인
- [ ] 저장소가 public이면 artifacts에 민감정보 없는지 확인
