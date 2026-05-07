# Performance Checker 상세 체크리스트

우선순위(Critical → High → Medium) 기반 배포 전 점검 체크리스트

---

## Critical — 즉시 수정 필요

### 빌드

- [ ] `npm run build` 성공 (exit code 0)
- [ ] TypeScript 컴파일 오류 없음
- [ ] ESLint 에러 없음
- [ ] 정적 페이지 생성 중 오류 없음

```bash
npm run build 2>&1 | tee /tmp/perf_build.txt
echo "종료 코드: $?"
grep -iE "^(error|Error TS|Type error|Failed)" /tmp/perf_build.txt | head -20
```

### 번들 크기

- [ ] First Load JS (공유 번들 포함) < 100KB
- [ ] 개별 청크 gzip 크기 < 200KB
- [ ] 대형 라이브러리(moment, lodash 전체) 번들 미포함

```bash
# 빌드 출력에서 First Load JS 직접 확인 (가장 신뢰할 수 있는 방법)
grep "First Load JS\| kB\| MB" /tmp/perf_build.txt

# 청크별 gzip 실측 상위 10개
for f in .next/static/chunks/*.js; do
  [ -f "$f" ] && echo "$(gzip -c "$f" | wc -c) $(basename $f)"
done 2>/dev/null | sort -rn | head -10 | awk '{printf "%6d KB  %s\n", $1/1024, $2}'
```

---

## High — 이번 배포 전 처리

### Server/Client Component 경계 (App Router)

- [ ] 'use client' 파일이 최소화되어 있음 (불필요한 클라이언트 번들 없음)
- [ ] Client-only API(useState, useEffect, window)를 'use client' 없이 사용하는 파일 없음
- [ ] Server Component에서 불필요한 데이터 직렬화 없음
- [ ] 레이아웃/페이지 컴포넌트가 Server Component로 유지됨

```bash
# 'use client' 파일 수
grep -rln "'use client'" --include="*.tsx" app/ components/ src/ 2>/dev/null | grep -v node_modules | wc -l

# 'use client' 없이 Hook 사용 파일 (빌드 통과해도 런타임 에러 가능성)
grep -rln "useState\|useEffect\|useRef\|useContext" --include="*.tsx" \
  app/ components/ src/ 2>/dev/null | \
  xargs grep -rL "'use client'" 2>/dev/null | grep -v node_modules | head -10
```

### 이미지 최적화

- [ ] `<img>` 대신 `next/image` 사용
- [ ] LCP 이미지에 `priority` 속성 적용
- [ ] LCP 이미지에 `loading="lazy"` 미사용
- [ ] 모든 이미지에 `width` / `height` 또는 `sizes` 지정 (CLS 방지)
- [ ] `unoptimized` 속성 최소화
- [ ] public 폴더의 PNG/JPG 이미지 WebP/AVIF 대체 고려

```bash
# raw <img> 태그 수
grep -rn "<img " --include="*.tsx" | grep -v node_modules | grep -v "// " | wc -l

# unoptimized 사용 현황
grep -rn "unoptimized" --include="*.tsx" --include="*.ts" | grep -v node_modules

# 이미지 포맷 비율
echo "PNG/JPG: $(find public -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) 2>/dev/null | wc -l)개"
echo "WebP/AVIF: $(find public -type f \( -name "*.webp" -o -name "*.avif" \) 2>/dev/null | wc -l)개"
```

### 폰트 최적화

- [ ] `next/font`로 폰트 로드 (Google Fonts 직접 link 대체)
- [ ] 폴백 폰트 지정으로 CLS 최소화
- [ ] 한국어 폰트의 경우 서브셋(subset) 적용
- [ ] 직접 @font-face 사용 시 `font-display: optional` 또는 `swap` 설정

```bash
# next/font 사용 여부
grep -rn "from 'next/font" --include="*.tsx" --include="*.ts" \
  app/ components/ src/ 2>/dev/null | grep -v node_modules | head -5

# Google Fonts 직접 link 사용 (next/font 미사용)
grep -rn "fonts.googleapis.com" --include="*.tsx" --include="*.ts" --include="*.html" \
  2>/dev/null | grep -v node_modules

# font-display 설정 여부
grep -rn "font-display" --include="*.css" --include="*.scss" | grep -v node_modules
```

### 코드 품질

- [ ] `console.log` 프로덕션 코드에서 제거
- [ ] 민감 정보(password, token, secret) 콘솔 출력 없음
- [ ] Pages Router 전용 패턴(`getInitialProps`, `UNSAFE_*`) App Router에 혼재 없음
- [ ] alt 속성 누락 없음

```bash
# console.log 수
grep -rn "console\.log" --include="*.tsx" --include="*.ts" \
  app/ components/ src/ lib/ 2>/dev/null | grep -v node_modules | grep -v "// " | wc -l

# 민감 정보 콘솔 출력
grep -rn "console\.\(log\|error\).*\(password\|token\|secret\|key\)" \
  --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules

# deprecated 패턴
grep -rn "getInitialProps\|UNSAFE_componentWill" \
  --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | head -10

# alt 속성 누락 <img> 태그
grep -rn "<img" --include="*.tsx" | grep -v node_modules | grep -v 'alt='
```

---

## Medium — 다음 스프린트

### 네트워크 & 캐싱

- [ ] API Routes에 적절한 `Cache-Control` 헤더 설정
- [ ] App Router fetch에 `cache` 옵션 명시 (`'no-store'` 또는 `next: { revalidate: N }`)
- [ ] 정적 자산 경로(`.next/static/`)는 Next.js 자동 immutable 처리 확인
- [ ] next.config의 `headers()` 설정에 보안 + 캐시 헤더 포함

```bash
# App Router fetch 캐싱 옵션 현황
grep -rn "cache:\|revalidate:" --include="*.tsx" --include="*.ts" \
  app/ lib/ 2>/dev/null | grep -v node_modules | head -15

# Cache-Control 헤더 설정 현황
grep -rn "Cache-Control" --include="*.tsx" --include="*.ts" \
  app/ 2>/dev/null | grep -v node_modules | head -10
```

### 파일 무결성

- [ ] 이미지 파일 유효성 (깨진 파일 없음)
- [ ] 0바이트 파일 없음
- [ ] 모든 import 경로 유효함

```bash
# 깨진 이미지
find public -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \
  -o -name "*.gif" -o -name "*.webp" \) 2>/dev/null | \
  xargs file 2>/dev/null | grep -v "image\|SVG\|Web/P\|JPEG\|GIF\|PNG" | head -10

# 0바이트 파일
find . -type f -size 0 \
  -not -path "./node_modules/*" \
  -not -path "./.git/*" \
  -not -path "./.next/*" | head -10
```

### 접근성 기초

- [ ] `alt` 속성 누락 없음 (High에서 중복 확인)
- [ ] 인터랙티브 요소에 ARIA 라벨 적용

```bash
# role/aria 속성 없는 버튼 패턴
grep -rn "<button\b" --include="*.tsx" | grep -v "aria-\|title=" | grep -v node_modules | head -10
```

### 보안 기초

- [ ] `.env` 파일 `.gitignore`에 포함
- [ ] 클라이언트 노출 환경변수에 `NEXT_PUBLIC_` 접두사
- [ ] 민감한 키가 서버 사이드에서만 참조됨

```bash
# .env gitignore 확인
grep "\.env" .gitignore 2>/dev/null

# 클라이언트에서 비공개 환경변수 접근 가능성
grep -rn "process\.env\." --include="*.tsx" | grep -v "NEXT_PUBLIC" | grep -v node_modules | head -10
```

---

## CWV 코드 패턴 정적 분석 (런타임 측정 아님)

> 아래는 코드 패턴으로 확인 가능한 CWV 관련 항목이다. 실제 측정값(LCP 몇 초 등)은 `references/lighthouse-ci.md`를 참조한다.

### LCP 관련 패턴

- [ ] 히어로/배너 이미지에 `priority` 또는 `fetchpriority="high"` 적용
- [ ] LCP 이미지에 `loading="lazy"` 미사용
- [ ] 중요 이미지 `<link rel="preload">` 또는 `next/image priority` 적용

### CLS 관련 패턴

- [ ] 이미지/영상에 `width` + `height` 또는 `aspect-ratio` 지정
- [ ] 폰트 FOUT/FOIT 최소화 (`font-display` 또는 `next/font` 사용)
- [ ] 동적 삽입 콘텐츠(광고, 배너, 알림)에 `min-height` 지정

### INP 관련 패턴

- [ ] 이벤트 핸들러에서 Long Task(50ms+) 가능성 검토
- [ ] 불필요한 동기 연산을 `useTransition` 또는 `startTransition`으로 분리
- [ ] React.memo, useCallback, useMemo 과도 사용 여부 검토 (오히려 역효과 가능)

```bash
# useTransition 사용 현황
grep -rn "useTransition\|startTransition" --include="*.tsx" --include="*.ts" \
  2>/dev/null | grep -v node_modules | wc -l
```

---

## 점검 결과 템플릿

```
Performance Check Report
========================
프로젝트: [프로젝트명]
점검일: [날짜]
점검자: Claude Code

요약
----
| 항목                | 상태   | 우선순위 | 발견 사항           |
|---------------------|--------|----------|---------------------|
| 빌드                | PASS   | Critical |                     |
| 번들 크기           | WARN   | Critical | 홈 130kB > 100kB    |
| Server/Client 경계  | PASS   | High     |                     |
| 이미지/폰트         | WARN   | High     | img 태그 3개        |
| 코드 품질           | WARN   | High     | console.log 7개     |
| 네트워크/캐싱       | WARN   | Medium   | Cache-Control 미설정|
| 파일 무결성         | PASS   | Medium   |                     |

CWV 코드 패턴
-------------
| 항목              | 상태 |
|-------------------|------|
| LCP priority 적용 | PASS |
| 이미지 width/height | WARN |
| font-display 설정 | PASS |

권장 조치
---------
[Critical]
1. 홈 번들 크기 축소: moment → day.js 교체로 ~60KB 절감 예상

[High]
1. console.log 7개 제거 (프로덕션 노이즈)
2. <img> 태그 3개 → next/image로 교체

[Medium]
1. Route Handler에 Cache-Control 헤더 추가
```
