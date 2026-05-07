---
name: performance-checker
description: '"성능 점검", "빌드 체크", "사이트 검증", "배포 전 점검" 요청 시 사용.'
user-invocable: false
---

# Performance Checker

Next.js/React 프로젝트의 배포 전 성능 품질을 종합 점검하는 스킬

## Overview

**대상**: Next.js (App Router 우선), React
**전제**: 프로덕션 빌드 가능한 상태

**점검 영역 및 우선순위:**

| 영역 | 우선순위 | 근거 |
|------|----------|------|
| 빌드 성공 여부 | Critical | 실패 시 배포 불가 |
| First Load JS / gzip 번들 크기 | Critical | 사용자 체감 로딩 직결 |
| Server/Client Component 경계 | High | 불필요한 클라이언트 번들 증가 |
| 이미지 최적화 | High | LCP 직접 영향 |
| 폰트 최적화 | High | CLS, LCP 영향 |
| 코드 품질 (console.log, deprecated) | High | 프로덕션 노이즈 |
| 네트워크 & 캐싱 헤더 | Medium | 반복 방문자 성능 |
| 파일 무결성 | Medium | 런타임 404 방지 |

> **CWV 런타임 측정**: LCP, INP, CLS 실측은 실행 중인 서버가 필요하다. 이 스킬은 코드 패턴 기반 정적 분석(LCP 이미지 `priority` 속성, CLS 방지 `width/height` 등)만 다룬다. 런타임 CWV는 `references/lighthouse-ci.md`의 CI 파이프라인을 참조하라.

---

## 프레임워크 감지

점검 시작 전 프레임워크를 확인하고, 해당하지 않는 명령어는 건너뛴다.

```bash
# 프레임워크 확인
if [ -d "app" ] && [ -f "next.config.js" -o -f "next.config.mjs" -o -f "next.config.ts" ]; then
  echo "Next.js App Router"
elif [ -d "pages" ] && [ -f "next.config.js" -o -f "next.config.mjs" ]; then
  echo "Next.js Pages Router"
elif [ -f "vite.config.ts" ] || [ -f "vite.config.js" ]; then
  echo "Vite 프로젝트 — .next 관련 단계 건너뜀"
else
  echo "기타 프레임워크 — 적용 가능한 단계만 실행"
fi
```

---

## Workflow

### Step 1: 빌드 점검 [Critical]

```bash
npm run build 2>&1 | tee /tmp/perf_build.txt
echo "빌드 종료 코드: $?"
```

**판단 분기:**
- exit code != 0 → **즉시 중단**. 이후 단계 진행 불가. 오류 수정 후 재점검 필요
- TypeScript 오류 발견 → Critical 문제로 보고
- ESLint 에러 발견 → High 문제로 보고
- ESLint 경고만 발견 → Medium으로 기록 후 계속 진행

```bash
# 오류/경고 분류 추출
grep -iE "^(error|Error TS|Type error)" /tmp/perf_build.txt | head -20
grep -i "warning" /tmp/perf_build.txt | grep -v "^>" | head -10

# First Load JS 요약 (App Router 빌드 출력)
grep -E "First Load JS|kB|MB" /tmp/perf_build.txt | tail -20
```

---

### Step 2: 번들 크기 분석 [Critical]

> `du -sh`는 디스크 크기(압축 전)다. 실제 전송 크기는 gzip 기준으로 측정해야 한다.
> 빌드 출력의 "First Load JS" 열이 가장 신뢰할 수 있는 기준이다.

```bash
# 방법 1: 빌드 출력에서 직접 확인 (권장)
grep "First Load JS\| kB\| MB" /tmp/perf_build.txt

# 방법 2: 청크별 gzip 실측
echo "=== 청크별 gzip 크기 상위 10개 ==="
for f in .next/static/chunks/*.js; do
  [ -f "$f" ] || continue
  gz=$(gzip -c "$f" | wc -c)
  echo "$gz $(basename $f)"
done 2>/dev/null | sort -rn | head -10 | \
  awk '{printf "%8d KB  %s\n", $1/1024, $2}'

# 총 gzip 크기
echo "=== 전체 청크 총 gzip 크기 ==="
total=0
for f in .next/static/chunks/*.js; do
  [ -f "$f" ] && total=$((total + $(gzip -c "$f" | wc -c)))
done
echo "$((total/1024)) KB (총 gzip)"
```

**기준:**
- First Load JS (공유 번들 포함): < 100KB — Good, 100-200KB — Warning, > 200KB — Critical
- 개별 청크: < 200KB (gzip)

```bash
# bundle-analyzer 실행 (설치된 경우)
ANALYZE=true npm run build 2>/dev/null || \
  echo "bundle-analyzer 미설치: npm install @next/bundle-analyzer"
```

---

### Step 3: Server/Client Component 경계 분석 [High]

App Router에서 'use client' 남용은 불필요한 클라이언트 번들 증가로 직결된다.

```bash
echo "=== 'use client' 파일 수 ==="
grep -rln "'use client'" --include="*.tsx" --include="*.ts" \
  app/ components/ src/ 2>/dev/null | grep -v node_modules | wc -l

echo "=== 'use client' 파일 목록 ==="
grep -rln "'use client'" --include="*.tsx" --include="*.ts" \
  app/ components/ src/ 2>/dev/null | grep -v node_modules

# Client-only API(useState 등)를 'use client' 없이 사용하는 파일 탐지
# (빌드는 통과하나 hydration mismatch 또는 런타임 에러 원인)
echo "=== 'use client' 없이 Hook 사용 가능성 ==="
grep -rln "useState\|useEffect\|useRef\|useContext" --include="*.tsx" \
  app/ components/ src/ 2>/dev/null | \
  xargs grep -rL "'use client'" 2>/dev/null | \
  grep -v node_modules | head -10

# Server Component에서 클라이언트로 직렬화 비용이 큰 데이터 전달 패턴
echo "=== 대용량 직렬화 패턴 ==="
grep -rn "JSON.stringify" --include="*.tsx" --include="*.ts" \
  app/ components/ 2>/dev/null | grep -v node_modules | head -10
```

---

### Step 4: 이미지 & 폰트 최적화 [High]

**이미지 점검:**
```bash
echo "=== next/image 미사용 <img> 태그 ==="
grep -rn "<img " --include="*.tsx" | grep -v node_modules | grep -v "// " | wc -l
grep -rn "<img " --include="*.tsx" | grep -v node_modules | grep -v "// " | head -5

echo "=== unoptimized 속성 사용 현황 ==="
grep -rn "unoptimized" --include="*.tsx" --include="*.ts" | grep -v node_modules

echo "=== LCP 이미지 priority 적용 현황 ==="
grep -rn "priority" --include="*.tsx" | grep -v node_modules | grep -v "// " | wc -l

echo "=== public 폴더 이미지 포맷 현황 ==="
echo "PNG/JPG: $(find public -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) 2>/dev/null | wc -l)개"
echo "WebP/AVIF: $(find public -type f \( -name "*.webp" -o -name "*.avif" \) 2>/dev/null | wc -l)개"
```

**폰트 점검:**
```bash
echo "=== next/font 사용 여부 (권장) ==="
grep -rn "from 'next/font" --include="*.tsx" --include="*.ts" \
  app/ components/ src/ 2>/dev/null | grep -v node_modules | head -5

echo "=== Google Fonts 직접 link 사용 여부 (next/font로 대체 권장) ==="
grep -rn "fonts.googleapis.com\|fonts.gstatic.com" \
  --include="*.tsx" --include="*.ts" --include="*.html" | grep -v node_modules

echo "=== 직접 @font-face 사용 여부 ==="
grep -rn "@font-face" --include="*.css" --include="*.scss" | grep -v node_modules | head -5

echo "=== font-display 설정 ==="
grep -rn "font-display" --include="*.css" --include="*.scss" | grep -v node_modules
```

---

### Step 5: 코드 품질 점검 [High]

```bash
echo "=== console.log 잔존 수 ==="
grep -rn "console\.log" --include="*.tsx" --include="*.ts" \
  app/ components/ src/ lib/ 2>/dev/null | grep -v node_modules | grep -v "// " | wc -l

echo "=== console.error/warn (의도적 사용 — 내용 확인 권장) ==="
grep -rn "console\.\(error\|warn\)" --include="*.tsx" --include="*.ts" \
  2>/dev/null | grep -v node_modules | head -10

echo "=== 민감 정보 콘솔 출력 가능성 ==="
grep -rn "console\.\(log\|error\).*\(password\|token\|secret\|key\)" \
  --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules

echo "=== Pages Router 패턴 혼재 (App Router 프로젝트) ==="
grep -rn "getInitialProps\|UNSAFE_componentWillMount\|UNSAFE_componentWillReceiveProps" \
  --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | head -10
```

---

### Step 6: 네트워크 & 캐싱 점검 [Medium]

```bash
echo "=== next.config 캐시 헤더 설정 ==="
grep -A10 "headers\b" next.config.js next.config.mjs next.config.ts 2>/dev/null | head -30

echo "=== App Router fetch 캐싱 옵션 ==="
grep -rn "cache:\|revalidate:" --include="*.tsx" --include="*.ts" \
  app/ lib/ 2>/dev/null | grep -v node_modules | grep "fetch\|next:" | head -15

echo "=== no-store 사용 현황 (캐싱 비활성화) ==="
grep -rn "cache: 'no-store'\|cache: \"no-store\"" --include="*.tsx" --include="*.ts" \
  2>/dev/null | grep -v node_modules | head -10

echo "=== Route Handler Cache-Control 헤더 ==="
grep -rn "Cache-Control" --include="*.tsx" --include="*.ts" \
  app/ 2>/dev/null | grep -v node_modules | head -10
```

---

### Step 7: 파일 무결성 [Medium]

```bash
echo "=== 깨진 이미지 탐지 ==="
find public -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \
  -o -name "*.gif" -o -name "*.webp" \) 2>/dev/null | \
  xargs file 2>/dev/null | grep -v "image\|SVG\|Web/P\|JPEG\|GIF\|PNG" | head -10

echo "=== 0바이트 파일 ==="
find . -type f -size 0 \
  -not -path "./node_modules/*" \
  -not -path "./.git/*" \
  -not -path "./.next/*" | head -10

echo "=== import 경로 샘플 (alias 오류 감지) ==="
grep -rn "from ['\"]@/" --include="*.tsx" --include="*.ts" \
  2>/dev/null | grep -v node_modules | head -10
```

---

## Report Format

```
Performance Check Report
========================
프로젝트: [프로젝트명]
점검일: [날짜]
프레임워크: Next.js App Router / Pages Router

요약
----
| 영역                  | 상태        | 우선순위 | 주요 발견             |
|-----------------------|-------------|----------|-----------------------|
| 빌드                  | PASS/FAIL   | Critical | 오류 N개, 경고 N개    |
| 번들 크기             | PASS/WARN   | Critical | First Load JS: XkB   |
| Server/Client 경계    | PASS/WARN   | High     | 'use client' N개 파일 |
| 이미지/폰트           | PASS/WARN   | High     | 미최적화 N개          |
| 코드 품질             | PASS/WARN   | High     | console.log N개       |
| 네트워크/캐싱         | PASS/WARN   | Medium   | 캐시 헤더 N개 미설정  |
| 파일 무결성           | PASS/WARN   | Medium   | 깨진 파일 N개         |

번들 크기 상세
--------------
| 페이지 | First Load JS | 상태      |
|--------|---------------|-----------|
| /      | XkB           | PASS/WARN |

권장 조치
---------
[Critical — 즉시 처리]
1. ...

[High — 이번 배포 전 처리]
1. ...

[Medium — 다음 스프린트]
1. ...
```

---

## Quick Commands

```bash
# 1. 빌드 + First Load JS 확인
npm run build 2>&1 | tee /tmp/perf_build.txt
grep "First Load JS\| kB\| MB" /tmp/perf_build.txt

# 2. gzip 크기 상위 10개 청크
for f in .next/static/chunks/*.js; do
  [ -f "$f" ] && echo "$(gzip -c "$f" | wc -c) $(basename $f)"
done 2>/dev/null | sort -rn | head -10 | awk '{printf "%6d KB  %s\n", $1/1024, $2}'

# 3. 'use client' 현황
grep -rln "'use client'" --include="*.tsx" app/ components/ src/ 2>/dev/null | grep -v node_modules | wc -l

# 4. console.log 잔존 수
grep -rn "console\.log" --include="*.tsx" --include="*.ts" | grep -v node_modules | wc -l

# 5. next/font 사용 여부
grep -rn "from 'next/font" --include="*.tsx" | grep -v node_modules | head -3
```

---

## Troubleshooting

| 문제 | 원인 | 해결 |
|------|------|------|
| 빌드 성공인데 성능 낮음 | 번들 크기, 이미지 미최적화 | bundle-optimization.md 참조 |
| gzip 크기와 du 크기 불일치 | du는 디스크 크기(압축 전) | gzip -c 명령어로 실측 |
| .next 캐시로 측정 오염 | 이전 빌드 잔존 | rm -rf .next 후 재빌드 |
| Vite 프로젝트에서 .next 명령어 실패 | 잘못된 프레임워크 가정 | 프레임워크 감지 후 건너뜀 |
| 의존성 분석 오차 | 동적 import, 조건부 사용 | depcheck --ignores로 예외 설정 |

## Anti-patterns

| 패턴 | 문제 | 대안 |
|------|------|------|
| `du -sh`로 번들 크기 판단 | 압축 전 크기, 실제 전송과 다름 | First Load JS + gzip -c 실측 |
| 모든 컴포넌트에 'use client' | 서버 렌더링 포기, 번들 증가 | Server Component 유지, 필요 시만 분리 |
| Google Fonts link 직접 사용 | FOIT/FOUT, CLS 발생 | next/font로 대체 |
| 모든 이미지 eager 로딩 | LCP 외 이미지도 즉시 로드 | LCP만 priority, 나머지 lazy |
| 성능 점검 배포 직전만 수행 | 문제 누적 후 발견 | CI에 Lighthouse CI 통합 |

## References

| 문서 | 경로 | 내용 |
|------|------|------|
| 체크리스트 | `references/checklist.md` | 우선순위별 상세 체크리스트 |
| Core Web Vitals | `references/core-web-vitals.md` | LCP/INP/CLS 기준과 최적화 |
| 번들 최적화 | `references/bundle-optimization.md` | 트리쉐이킹, dynamic import, gzip 측정 |
| Lighthouse CI | `references/lighthouse-ci.md` | GitHub Actions 통합, 임계값 설정 |
| 네트워크/캐싱 | `references/network-caching.md` | Cache-Control, CDN, fetch 옵션 |
| 런타임 성능 | `references/runtime-performance.md` | React Profiler, 메모리 누수 분석 |
