---
name: perf-audit
description: Lighthouse CLI 래핑 — URL 성능 측정. Performance score + 5 Web Vitals (FCP/LCP/CLS/TBT/Speed Index) 추출, pass/warn/fail 판정, events.jsonl 이력 저장. on-demand only (~30s).
model: claude-sonnet-4-6
---

# /perf-audit

URL을 Lighthouse CLI로 측정하여 핵심 Web Vitals를 출력하고 events.jsonl에 이력을 누적한다. stack-agnostic — Next.js 한정 X, 어떤 URL이든 동작.

## 트리거

- `/perf-audit <url>` — 인간 친화 출력 (점수 + 지표 + 판정)
- `/perf-audit <url> --json` — JSON 출력 (CI 통합용)

## 절차

### 1. 인자 파싱

```bash
URL="${1:-}"
MODE="text"
shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    --json) MODE="json" ;;
  esac
  shift
done

if [ -z "$URL" ]; then
  echo "Usage: /perf-audit <url> [--json]" >&2
  echo "예: /perf-audit http://localhost:3000" >&2
  echo "예: /perf-audit https://example.com --json" >&2
  exit 1
fi

# 기본 검증 — http(s) prefix
case "$URL" in
  http://*|https://*) ;;
  *) echo "warn: URL은 http:// 또는 https:// 로 시작해야 합니다" >&2; exit 1 ;;
esac
```

### 2. Lighthouse 실행

```bash
# npx -y lighthouse — 미설치면 자동 다운로드 (첫 실행 ~150MB)
# stdout으로 JSON 받음, stderr 억제
TMP_OUT=$(mktemp)
trap 'rm -f "$TMP_OUT"' EXIT

if ! npx -y lighthouse "$URL" \
  --quiet \
  --chrome-flags="--headless --no-sandbox --disable-gpu" \
  --output=json \
  --output-path="$TMP_OUT" \
  2>/dev/null; then
  echo "✗ lighthouse 실행 실패 — URL 접근 불가 또는 Chrome 다운로드 실패" >&2
  echo "  네트워크/방화벽/URL 접근성 확인" >&2
  exit 1
fi

if [ ! -s "$TMP_OUT" ]; then
  echo "✗ lighthouse 결과 비어있음" >&2
  exit 1
fi
```

### 3. 핵심 지표 추출

```bash
# performance score (0~1) → 0~100
SCORE=$(jq -r '.categories.performance.score * 100 | floor' "$TMP_OUT" 2>/dev/null)
SCORE="${SCORE:-0}"

# Web Vitals (numericValue)
FCP=$(jq -r '.audits["first-contentful-paint"].numericValue // 0 | floor' "$TMP_OUT")
LCP=$(jq -r '.audits["largest-contentful-paint"].numericValue // 0 | floor' "$TMP_OUT")
CLS=$(jq -r '.audits["cumulative-layout-shift"].numericValue // 0' "$TMP_OUT")
TBT=$(jq -r '.audits["total-blocking-time"].numericValue // 0 | floor' "$TMP_OUT")
SI=$(jq -r '.audits["speed-index"].numericValue // 0 | floor' "$TMP_OUT")

# 판정
if [ "$SCORE" -ge 90 ]; then VERDICT="PASS"
elif [ "$SCORE" -ge 50 ]; then VERDICT="WARN"
else VERDICT="FAIL"
fi
```

### 4. 출력

```bash
print_text() {
  echo "📊 Lighthouse Performance Audit"
  echo "   URL: $URL"
  echo ""
  printf "  %-25s %s\n" "Performance Score" "${SCORE}/100  [${VERDICT}]"
  echo ""
  echo "  ━━━ Web Vitals ━━━"
  printf "  %-25s %s ms\n" "First Contentful Paint" "$FCP"
  printf "  %-25s %s ms\n" "Largest Contentful Paint" "$LCP"
  printf "  %-25s %s\n"    "Cumulative Layout Shift" "$CLS"
  printf "  %-25s %s ms\n" "Total Blocking Time" "$TBT"
  printf "  %-25s %s ms\n" "Speed Index" "$SI"
  echo ""
  case "$VERDICT" in
    PASS) echo "  ✓ 양호 (≥ 90)" ;;
    WARN) echo "  ⚠ 개선 필요 (50~89)" ;;
    FAIL) echo "  ✗ 즉시 조치 (< 50)" ;;
  esac
  echo ""
  echo "이력: .claude/events.jsonl (type=perf_audit)"
}

print_json() {
  jq -nc \
    --arg url "$URL" \
    --argjson score "$SCORE" \
    --argjson fcp "$FCP" \
    --argjson lcp "$LCP" \
    --arg cls "$CLS" \
    --argjson tbt "$TBT" \
    --argjson si "$SI" \
    --arg verdict "$VERDICT" \
    '{
      url: $url,
      score: $score,
      verdict: $verdict,
      vitals: {
        fcp_ms: $fcp,
        lcp_ms: $lcp,
        cls: ($cls | tonumber),
        tbt_ms: $tbt,
        speed_index_ms: $si
      }
    }'
}

case "$MODE" in
  json) print_json ;;
  *) print_text ;;
esac
```

### 5. Events 발생

```bash
NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
mkdir -p .claude
jq -nc \
  --arg ts "$NOW_ISO" \
  --arg url "$URL" \
  --argjson score "$SCORE" \
  --argjson lcp "$LCP" \
  --arg cls "$CLS" \
  --argjson tbt "$TBT" \
  --argjson fcp "$FCP" \
  --arg verdict "$VERDICT" \
  '{type:"perf_audit", ts:$ts, url:$url, score:$score, lcp_ms:$lcp, cls:($cls | tonumber), tbt_ms:$tbt, fcp_ms:$fcp, verdict:$verdict}' \
  >> .claude/events.jsonl
```

## 주의

- **첫 실행 ~30s+ + Chrome 다운로드 ~150MB** (npx 캐시 후 재사용 빨라짐)
- URL이 인증 필요한 페이지면 Lighthouse 헤드리스 Chrome이 접근 못 함 — 공개 URL 또는 로컬 dev 서버 권장
- CI에서 사용하려면 별도 워크플로우 (`templates/.github/workflows/perf.yml` 후속 추가 예정)
- 정확도: localhost는 네트워크 조건 무시 (실제 사용자 환경과 차이) — 상대 비교 위주로 활용

## 후속

`/telemetry`로 `type=perf_audit` 이벤트 추세 확인 — score 회귀 감지.
