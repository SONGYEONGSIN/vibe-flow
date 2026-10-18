# Scraping Patterns

agent-browser를 사용한 실전 웹 스크래핑 패턴 모음.

---

## 1. 페이지네이션 크롤링

### 페이지 번호 기반

```bash
# 1. 첫 페이지 열기
agent-browser open "https://example.com/products?page=1"
agent-browser snapshot -i

# 2. 총 페이지 수 확인
agent-browser get text ".pagination .total"

# 3. 각 페이지 순회
for page in $(seq 1 10); do
  agent-browser open "https://example.com/products?page=${page}"
  agent-browser wait --load networkidle
  agent-browser get text ".product-card .title" >> /tmp/products.txt
  agent-browser get text ".product-card .price" >> /tmp/prices.txt
  sleep 1  # Rate limiting
done
```

### 무한 스크롤

```bash
# 1. 페이지 열기
agent-browser open "https://example.com/feed"
agent-browser wait --load networkidle

# 2. 현재 아이템 수 확인
agent-browser execute "document.querySelectorAll('.feed-item').length"

# 3. 스크롤 + 대기 반복
for i in $(seq 1 5); do
  agent-browser execute "window.scrollTo(0, document.body.scrollHeight)"
  agent-browser wait --timeout 2000
  agent-browser execute "document.querySelectorAll('.feed-item').length"
done

# 4. 모든 데이터 추출
agent-browser get text ".feed-item .title"
```

### Cursor 기반 (API 연동)

```bash
# 1. 첫 번째 요청
agent-browser open "https://example.com/api/items?cursor="
CURSOR=$(agent-browser get text "pre" | python3 -c "import json,sys; print(json.load(sys.stdin)['nextCursor'])")

# 2. 다음 페이지
while [ -n "$CURSOR" ]; do
  agent-browser open "https://example.com/api/items?cursor=${CURSOR}"
  # 데이터 처리...
  CURSOR=$(agent-browser get text "pre" | python3 -c "
import json,sys
data = json.load(sys.stdin)
print(data.get('nextCursor', ''))
")
  sleep 1
done
```

---

## 2. 동적 콘텐츠 대기 전략

### waitForSelector - 특정 요소 대기

```bash
# Before: 페이지 로드 즉시 스냅샷 → 빈 데이터
agent-browser open "https://example.com/dashboard"
agent-browser snapshot  # SPA가 아직 렌더링 안됨

# After: 데이터 렌더링 대기
agent-browser open "https://example.com/dashboard"
agent-browser wait --selector ".dashboard-card"
agent-browser snapshot  # 완전히 렌더링된 상태
```

### networkIdle - 네트워크 요청 완료 대기

```bash
# API 호출이 완료될 때까지 대기
agent-browser open "https://example.com/search?q=keyword"
agent-browser wait --load networkidle
agent-browser get text ".search-results .item"
```

### 텍스트 기반 대기

```bash
# 특정 텍스트가 나타날 때까지 대기
agent-browser open "https://example.com/slow-page"
agent-browser wait --text "로딩 완료"
agent-browser snapshot
```

### 복합 대기 전략

```bash
# 1. 네트워크 안정화 대기
agent-browser wait --load networkidle

# 2. 핵심 요소 대기
agent-browser wait --selector "[data-loaded='true']"

# 3. 추가 안정화 시간
agent-browser wait --timeout 500
```

---

## 3. 병렬 멀티사이트 패턴

### 기본 병렬 크롤링

```bash
# 세션별 사이트 할당
agent-browser --session s1 open "https://site-a.com/products"
agent-browser --session s2 open "https://site-b.com/products"
agent-browser --session s3 open "https://site-c.com/products"

# 각 세션에서 데이터 추출 (병렬 실행 가능)
agent-browser --session s1 wait --load networkidle
agent-browser --session s2 wait --load networkidle
agent-browser --session s3 wait --load networkidle

# 데이터 수집
agent-browser --session s1 get text ".product .price" > /tmp/site-a-prices.txt
agent-browser --session s2 get text ".product .price" > /tmp/site-b-prices.txt
agent-browser --session s3 get text ".product .price" > /tmp/site-c-prices.txt

# 결과 병합
cat /tmp/site-*-prices.txt > /tmp/all-prices.txt

# 세션 정리
agent-browser --session s1 close
agent-browser --session s2 close
agent-browser --session s3 close
```

### 가격 비교 패턴

```bash
#!/bin/bash
PRODUCT="MacBook Pro 16"
SITES=("coupang.com" "11st.co.kr" "gmarket.co.kr")

for i in "${!SITES[@]}"; do
  SESSION="price_${i}"
  SITE="${SITES[$i]}"
  agent-browser --session "$SESSION" open "https://${SITE}/search?q=${PRODUCT}"
  agent-browser --session "$SESSION" wait --load networkidle
done

# 각 사이트에서 첫 번째 결과 가격 추출
for i in "${!SITES[@]}"; do
  SESSION="price_${i}"
  echo "${SITES[$i]}:"
  agent-browser --session "$SESSION" get text ".price:first-of-type"
done
```

---

## 4. 에러 복구 워크플로우

### Retry with Backoff

```bash
#!/bin/bash
MAX_RETRIES=3
RETRY_DELAY=2

fetch_with_retry() {
  local url="$1"
  local attempt=1

  while [ $attempt -le $MAX_RETRIES ]; do
    agent-browser open "$url" 2>/dev/null
    if [ $? -eq 0 ]; then
      agent-browser wait --load networkidle --timeout 10000 2>/dev/null
      if [ $? -eq 0 ]; then
        return 0
      fi
    fi

    echo "Attempt ${attempt} failed for ${url}. Retrying in ${RETRY_DELAY}s..."
    sleep $((RETRY_DELAY * attempt))
    attempt=$((attempt + 1))
  done

  echo "FAILED: ${url} after ${MAX_RETRIES} attempts"
  return 1
}

fetch_with_retry "https://flaky-site.com/data"
```

### Fallback Selector 패턴

```bash
# 1차 시도: 정확한 셀렉터
RESULT=$(agent-browser get text ".product-price" 2>/dev/null)

if [ -z "$RESULT" ]; then
  # 2차 시도: 대체 셀렉터
  RESULT=$(agent-browser get text "[data-testid='price']" 2>/dev/null)
fi

if [ -z "$RESULT" ]; then
  # 3차 시도: 텍스트 기반 검색
  RESULT=$(agent-browser find text "₩" get text 2>/dev/null)
fi

echo "Price: ${RESULT:-NOT_FOUND}"
```

### 세션 복구

```bash
# 세션 상태 확인
agent-browser session list

# 세션이 죽었으면 재생성
if ! agent-browser --session worker1 snapshot 2>/dev/null; then
  echo "Session worker1 dead, recreating..."
  agent-browser --session worker1 open "$LAST_URL"
fi
```

---

## 5. 데이터 추출 + 정제 파이프라인

### HTML → 구조화 데이터

```bash
# 1. 페이지 열기
agent-browser open "https://example.com/products"
agent-browser wait --load networkidle

# 2. JavaScript로 구조화 데이터 추출
agent-browser execute "
  JSON.stringify(
    Array.from(document.querySelectorAll('.product-card')).map(card => ({
      title: card.querySelector('.title')?.textContent?.trim(),
      price: card.querySelector('.price')?.textContent?.trim(),
      rating: card.querySelector('.rating')?.textContent?.trim(),
      url: card.querySelector('a')?.href,
    }))
  )
" > /tmp/products.json

# 3. Python으로 정제
python3 -c "
import json
data = json.loads(open('/tmp/products.json').read())
# 가격 숫자 변환
for item in data:
    if item.get('price'):
        item['price_num'] = int(''.join(filter(str.isdigit, item['price'])))
# 정렬 후 저장
data.sort(key=lambda x: x.get('price_num', 0))
print(json.dumps(data, ensure_ascii=False, indent=2))
"
```

### 테이블 데이터 추출

```bash
agent-browser open "https://example.com/table-page"
agent-browser wait --selector "table"

# 테이블을 CSV로 변환
agent-browser execute "
  const table = document.querySelector('table');
  const rows = Array.from(table.querySelectorAll('tr'));
  const csv = rows.map(row =>
    Array.from(row.querySelectorAll('th, td'))
      .map(cell => '\"' + cell.textContent.trim().replace(/\"/g, '\"\"') + '\"')
      .join(',')
  ).join('\n');
  csv;
" > /tmp/table.csv
```

---

## 6. Rate Limiting & 예의 바른 크롤링

### robots.txt 존중

```bash
# robots.txt 확인
agent-browser open "https://example.com/robots.txt"
agent-browser get text "body"

# Disallow 경로 확인 후 해당 경로 크롤링 금지
```

### 요청 간격 지키기

```bash
# 최소 1초 간격
MIN_DELAY=1

crawl_page() {
  local url="$1"
  agent-browser open "$url"
  agent-browser wait --load networkidle
  agent-browser get text ".content"
  sleep $MIN_DELAY
}

# URL 목록 순회
while IFS= read -r url; do
  crawl_page "$url"
done < urls.txt
```

### User-Agent 설정

```bash
# agent-browser에서 User-Agent 변경 불가 시 API 직접 사용
# agent-browser는 기본 Chromium UA 사용
```

### 크롤링 매너 체크리스트

- [ ] robots.txt Disallow 경로 크롤링 안함
- [ ] 요청 간격 최소 1초 유지
- [ ] 동일 호스트 동시 요청 3개 이하
- [ ] 서버 에러(5xx) 시 크롤링 중단 + 대기
- [ ] 사이트 이용약관에서 크롤링 금지 여부 확인
- [ ] 불필요한 리소스(이미지, CSS) 로딩 최소화

---

## 7. 일반적 안티패턴

### Before/After 비교

```bash
# Bad: 대기 없이 즉시 데이터 추출
agent-browser open "https://spa-site.com"
agent-browser get text ".data"  # 빈 결과

# Good: SPA 렌더링 대기
agent-browser open "https://spa-site.com"
agent-browser wait --load networkidle
agent-browser wait --selector ".data"
agent-browser get text ".data"  # 정상 결과
```

```bash
# Bad: 모든 페이지를 순차 처리
for url in "${URLS[@]}"; do
  agent-browser open "$url"
  # ... 처리
done
# 소요: N * 평균_로딩_시간

# Good: 세션으로 병렬 처리
for i in "${!URLS[@]}"; do
  agent-browser --session "s${i}" open "${URLS[$i]}" &
done
wait
# 소요: 최대_로딩_시간
```

```bash
# Bad: 하드코딩된 timeout
agent-browser wait --timeout 5000  # 페이지마다 다름

# Good: 조건부 대기
agent-browser wait --selector ".content-loaded"  # 렌더링 완료 시그널
```

---

## 8. 스크래핑 결과 저장 패턴

### JSON 파일 저장

```bash
# 결과를 JSON으로 구조화하여 저장
agent-browser execute "JSON.stringify(extractedData)" > /tmp/result.json
```

### CSV 변환 저장

```bash
# Python으로 JSON → CSV 변환
python3 -c "
import json, csv, sys
data = json.load(open('/tmp/result.json'))
writer = csv.DictWriter(sys.stdout, fieldnames=data[0].keys())
writer.writeheader()
writer.writerows(data)
" > /tmp/result.csv
```

### 증분 저장 (Append)

```bash
# 페이지별로 결과 추가
for page in $(seq 1 10); do
  agent-browser open "https://example.com/data?page=${page}"
  agent-browser wait --load networkidle
  agent-browser execute "JSON.stringify(extractPageData())" >> /tmp/all_data.jsonl
done
```
