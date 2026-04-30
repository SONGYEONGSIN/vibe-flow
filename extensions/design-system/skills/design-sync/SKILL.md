---
name: design-sync
description: 참고 디자인 URL, 캡처 이미지, 또는 로컬 파일(readme.md/HTML)에서 CSS를 추출하여 현재 코드베이스와 비교/적용한다. 사용법: /design-sync <URL|이미지경로|--from-file [폴더]> [페이지경로]
effort: high
---

참고 디자인 URL 또는 캡처 이미지를 받아 체계적 워크플로우로 CSS를 추출·비교·적용하고, 정량적 싱크율로 검증한다.

**사용법:**
- `/design-sync <URL>` — URL 기반 전체 워크플로우 실행 (7단계)
- `/design-sync <URL> <페이지경로>` — 특정 페이지만
- `/design-sync --from-image <이미지경로>` — 캡처 이미지 기반 워크플로우 (5단계)
- `/design-sync --from-file [폴더경로]` — 로컬 파일(readme.md/HTML) 기반 워크플로우 (6단계)
- `/design-sync --verify-only` — 시각적 회귀 테스트만
- `/design-sync --tokens-only` — 토큰 추출만

## 사전 요구사항 (fail-closed 게이트)

워크플로우 시작 전에 **반드시** 의존성을 검증한다. 누락 시 즉시 종료하고 사용자에게 설치 명령을 안내한다.

```bash
# 모드별 필수 의존성
case "$MODE" in
  url|from-file|verify-only|tokens-only)
    node -e "require('playwright')" 2>/dev/null || MISSING="$MISSING playwright"
    node -e "require('pixelmatch')" 2>/dev/null || MISSING="$MISSING pixelmatch"
    node -e "require('pngjs')" 2>/dev/null || MISSING="$MISSING pngjs"
    ;;
  from-image)
    node -e "require('sharp')" 2>/dev/null || MISSING="$MISSING sharp"
    node -e "require('pixelmatch')" 2>/dev/null || MISSING="$MISSING pixelmatch"
    node -e "require('pngjs')" 2>/dev/null || MISSING="$MISSING pngjs"
    ;;
esac

if [ -n "$MISSING" ]; then
  echo "ERROR: design-sync 필수 의존성 누락:$MISSING" >&2
  echo "  설치: npm install -D$MISSING" >&2
  echo "  Playwright 브라우저: npx playwright install chromium" >&2
  exit 1
fi
```

→ silent fail 금지. 의존성이 없는 채로 일부만 진행하면 잘못된 싱크율이 보고되어 신뢰가 깨진다.

## 핵심 원칙

1. **모든 요소를 동일한 깊이로 추출한다.** 8개 요소 카테고리 전체를 대상으로 한다. → [references/element-detection.md](references/element-detection.md)
2. **21개 속성 카테고리를 빠짐없이 추출한다.** → [references/css-properties.md](references/css-properties.md)
3. **정량적 검증이 필수다.** 수정 전후 싱크율을 측정하여 개선을 숫자로 확인한다.
4. **보정 계수는 자동 산출한다.** 수동 계산 대신 통계적 최적화로 정확도를 높인다. → [references/correction-algorithm.md](references/correction-algorithm.md)

---

## 엔드투엔드 워크플로우

```
/design-sync https://example.site

Step 1 (Phase 1) → 토큰 추출      보정 계수 자동 산출 + 글로벌 토큰 JSON
Step 2 (Phase 2) → 인벤토리       전체 페이지 원패스 추출 → 영역/타입별 분류
Step 3 (Phase 3) → 기준 측정      참고 + 로컬 스크린샷 비교 → "싱크율: 72.3%"
Step 4 (Phase 4) → 매핑 + Diff    참고 요소 ↔ 코드베이스 매핑 → 변경 제안
Step 5            → 수정 적용      파일별 × 카테고리별 수정, tsc+test 검증
Step 6            → 최종 검증      다시 스크린샷 비교 (Phase 3 재실행) → "싱크율: 94.7%"
Step 7 (Phase 5) → 학습 + 정리    90%↑ 시 패턴 저장, 임시 파일 삭제
```

---

## Phase 1: 디자인 토큰 자동 추출

보정 계수를 자동 산출한 뒤, Playwright로 색상·타이포·간격·보더·그림자·그라데이션·필터·트랜스폼·애니메이션·CSS 변수를 한 번에 수집한다.

- **알고리즘 상세**: [references/correction-algorithm.md](references/correction-algorithm.md)
- **스크립트**: [scripts/extract-tokens.js](scripts/extract-tokens.js)
- **출력**: `tokens.json`

---

## Phase 2: 전체 페이지 컴포넌트 인벤토리

한 번의 Playwright 실행으로 모든 페이지를 순회하며 **모든 가시 요소**를 추출한다.
8 카테고리 × 21 속성 포맷으로 영역(sidebar/header/content)과 컴포넌트 타입을 자동 분류.

- **요소 감지 로직**: [references/element-detection.md](references/element-detection.md)
- **스크립트**: [scripts/extract-inventory.js](scripts/extract-inventory.js)
- **출력**: `inventory.json`

### 영역 자동 분류

```
x < sidebarRight                    → sidebar
y < headerBottom && x ≥ sidebarRight → header
그 외                                → content
```

---

## Phase 3: 시각적 회귀 테스트

참고 사이트와 로컬 개발 서버를 동일 뷰포트(1366×900)로 캡처 → pixelmatch 비교.

- **스크립트**: [scripts/visual-regression.js](scripts/visual-regression.js)
- **출력**: `diff-*.png` + 싱크율 리포트

**비교 항목:**
1. 기본 비교 (`threshold: 0.15`) + 정밀 비교 (`threshold: 0.05`)
2. 컴포넌트 단위 비교 (sidebar, header, main-content 영역 크롭)
3. Hover 상태 비교 (메뉴, 버튼, 테이블 행, 카드, 드롭다운 아이템)
4. 텍스트 마스킹 비교 (레이아웃/스타일만)
5. 멀티 뷰포트 (375×812, 768×1024, 1366×900, 1920×1080)
6. 다크 모드 비교

**싱크율 계산**: `(1 - 불일치픽셀수 / 전체픽셀수) × 100`

---

## Phase 4: 컴포넌트 매핑 + 자동 Diff

inventory.json의 참고 요소를 코드베이스 파일에 다중 시그널(영역 위치 0.4, tag/role 0.3, Tailwind 겹침 0.2, 텍스트 유사도 0.1)로 매핑한 뒤, CSS computed value → Tailwind 클래스 변환.

- **Tailwind 매핑 테이블**: [references/css-properties.md](references/css-properties.md)
- **스크립트**: [scripts/component-map.js](scripts/component-map.js)
- **출력**: `mapping.json` + 콘솔 변경 제안

### 변경 제안 형식

```
┌─── src/components/layout/sidebar.tsx ───────────────────────┐
│ Line 40: className="...w-52..."                             │
│   width: 208px → 224px                                      │
│   제안: w-52 → w-56                                         │
└──────────────────────────────────────────────────────────────┘
```

---

## Phase 5: 다중 사이트 학습

싱크율 90% 이상 달성 시 결과를 저장하여 향후 재사용:

```
.claude/skills/design-sync/learned/
  {site-hash}/
    meta.json          # 사이트 메타 (URL, 날짜, 프레임워크, 싱크율)
    tokens.json        # 디자인 토큰
    inventory.json     # 컴포넌트 인벤토리
    mapping.json       # 컴포넌트 매핑
```

### 프레임워크 자동 감지

| 프레임워크 | 식별 패턴 |
|-----------|----------|
| **Shadcn UI** | `bg-background`, `text-foreground`, `border-border`, `ring-ring` |
| **Figma Sites** | `css-` 접두사, 뷰포트 스케일링 |
| **Tailwind UI** | `divide-y`, `group-hover`, `focus-within` 조합 |
| **Plain Tailwind** | `text-gray-`, `bg-white`, `rounded-` (범용) |

### 크로스 사이트 패턴 재사용

동일 프레임워크의 이전 학습 데이터가 있으면:
- 보정 계수 초기값으로 사용 (계산 시간 단축)
- 컴포넌트 타입 감지 정확도 향상
- 알려진 quirk 자동 적용 (예: Figma Sites의 48px 상단 툴바)

---

## 로컬 파일 모드 (`--from-file`)

`design-ref/` 폴더의 readme.md 또는 HTML 파일을 디자인 기준으로 사용하는 모드.

### 폴더 탐색 순서

```
1. 인자로 지정된 경로        예: /design-sync --from-file ./my-refs/
2. 프로젝트 루트 design-ref/  예: <project-root>/design-ref/
3. .claude/design-ref/        예: <project-root>/.claude/design-ref/
```

### 지원 파일 유형

| 파일 | 역할 | 처리 방식 |
|------|------|----------|
| `readme.md` | 디자인 스펙 문서 (의도, 색상, 레이아웃, 컴포넌트 명세) | 텍스트 파싱 → 토큰/구조 추출 |
| `*.html` | 시각적 레퍼런스 코드 | 로컬 렌더링 → Playwright 추출 |
| 둘 다 존재 | readme.md = 의도(why), HTML = 기준(what) | 병합하여 사용 |

### 워크플로우 (6단계)

```
/design-sync --from-file design-ref/

Step F-1 → 파일 탐색        design-ref/ 폴더에서 readme.md, *.html 파일 감지
Step F-2 → 스펙 파싱        readme.md에서 색상/타이포/레이아웃/컴포넌트 명세 추출
Step F-3 → HTML 렌더링      *.html을 임시 로컬 서버로 렌더링 → Playwright 토큰 + 인벤토리 추출
Step F-4 → 기준 측정        렌더링된 HTML vs 로컬 개발 서버 비주얼 비교 → 싱크율
Step F-5 → 매핑 + 적용      스펙 + 시각 기준 병합하여 매핑 → 코드 수정 → tsc + test 검증
Step F-6 → 최종 검증        싱크율 재측정 + readme.md 체크리스트 대조
```

### readme.md만 있는 경우 (HTML 없음)

HTML이 없으면 시각적 비교(Step F-3, F-4)를 건너뛰고, 스펙 기반으로만 작업한다.

```
Step F-1 → 파일 탐색        readme.md 감지 (HTML 없음)
Step F-2 → 스펙 파싱        색상/타이포/레이아웃/컴포넌트 명세 추출
Step F-5 → 매핑 + 적용      스펙 기반 토큰 생성 → 컴포넌트 설계 → 코드 적용
Step F-6 → 검증             readme.md 체크리스트 대조 (시각적 비교 생략)
```

### readme.md 스펙 포맷 (권장)

```markdown
# Design Spec

## 색상
- Primary: #3B82F6 (blue-500)
- Background: #F9FAFB (gray-50)
- Text: #111827 (gray-900)

## 타이포그래피
- Display: Inter / Body: Inter
- 제목: text-2xl font-bold
- 본문: text-sm text-gray-600

## 레이아웃
- 유형: SaaS Dashboard
- 사이드바: w-64 fixed
- 메인: ml-64 p-6

## 컴포넌트
- [ ] Header: 로고 + 네비게이션 + 프로필
- [ ] Sidebar: 메뉴 리스트 + 접기 버튼
- [ ] DataTable: 정렬 + 필터 + 페이지네이션
```

### 비교 테이블

| 항목 | URL 모드 | 이미지 모드 | 로컬 파일 모드 |
|------|---------|------------|---------------|
| 입력 | 라이브 URL | 이미지 파일 | readme.md / HTML |
| 추출 도구 | Playwright | AI Vision + Sharp | 텍스트 파싱 + Playwright |
| 정밀도 | 정확 (CSS 직접) | 높음~중간 (추정치) | HTML=정확 / md=명세 의존 |
| 싱크율 목표 | 95%+ | 85~90% | HTML 포함: 92%+ / md만: 체크리스트 |
| 오프라인 | 불가 | 가능 | 가능 |

---

## 이미지 모드 (`--from-image`)

URL 없이 캡처 이미지(PNG/JPG/WebP)만으로 디자인을 추출·비교·적용하는 모드.

- **전체 워크플로우**: [references/image-mode.md](references/image-mode.md)

```
Step I-1 → AI Vision + Sharp 토큰 추출
Step I-2 → AI Vision 컴포넌트 인벤토리
Step I-3 → 비주얼 비교 (원본 이미지 vs 로컬 pixelmatch)
Step I-4 → 매핑 + 수정 적용 (기존 Phase 4 + Step 5)
Step I-5 → 최종 검증 + 정리 (Phase 3 재실행 + Phase 5)
```

| 항목 | URL 모드 | 이미지 모드 |
|------|---------|------------|
| 입력 | 라이브 URL | 이미지 파일 |
| 추출 도구 | Playwright | AI Vision + Sharp |
| 정밀도 | 정확 (CSS 직접) | 높음~중간 (추정치) |
| 싱크율 목표 | 95%+ | 85~90% |

---

## 규칙

- Playwright가 설치되어 있어야 한다 (`npx playwright install chromium`)
- `pixelmatch`와 `pngjs`가 devDependencies에 있어야 한다
- 이미지 모드 사용 시 `sharp`도 devDependencies에 있어야 한다
- 추출 스크립트는 `scripts/` 에 임시 작성 → 완료 후 삭제
- 스크린샷/diff 이미지도 완료 후 삭제
- `tokens.json`, `inventory.json`, `mapping.json`은 작업 중 프로젝트 루트에 생성 → 완료 후 삭제 (학습 저장 시 `learned/`로 복사)
- 수정 후 반드시 `npx tsc --noEmit && npm test` 검증
- **8 카테고리 × 21 속성** 모두 동일 깊이로 추출·비교
- 시각적 회귀 테스트는 **수정 전후** 두 번 실행하여 개선을 정량화
- 로컬 개발 서버(`localhost:3000`)가 실행 중이어야 시각적 회귀 테스트 가능

---

## events.jsonl 기록

워크플로우 완료(또는 부분 완료) 후 기록 — retrospective의 디자인 시스템 추이(섹션 3-1) 입력:
```bash
echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"type\":\"design_sync\",\"mode\":\"$MODE\",\"sync_rate_initial\":$INIT,\"sync_rate_final\":$FINAL,\"target_rate\":$TARGET}" >> .claude/events.jsonl
```

`mode`: `url` | `image` | `file` | `verify-only` | `tokens-only`. 싱크율 회귀 추적용 핵심 이벤트.

---

## 파일 구조

```
skills/design-sync/
  SKILL.md                              ← 이 파일 (핵심 워크플로우)
  references/
    css-properties.md                   ← 21개 속성 카테고리 + Tailwind 매핑 테이블
    element-detection.md                ← 8개 요소 카테고리 + 감지 로직
    correction-algorithm.md             ← 보정 계수 알고리즘 + 토큰 포맷
    image-mode.md                       ← --from-image 5단계 워크플로우
  scripts/
    extract-tokens.js                   ← Phase 1 토큰 추출
    extract-inventory.js                ← Phase 2 인벤토리 추출
    visual-regression.js                ← Phase 3 시각적 회귀 테스트
    component-map.js                    ← Phase 4 매핑 + Tailwind Diff
```
