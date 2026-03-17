# 보정 계수 자동 산출 알고리즘

## Phase 1.1: 보정 계수

Figma Sites 등 뷰포트 스케일링이 적용된 사이트에서 정확한 CSS 값을 얻기 위한 자동 보정.

### 알고리즘

1. 모든 텍스트 요소의 `fontSize`를 수집
2. Tailwind 스케일 `[12, 14, 16, 18, 20, 24, 30, 36, 48, 60, 72, 96]`과 대조
3. 보정 계수 1.00~1.30을 0.01 단위로 시도
4. 보정 후 Tailwind 스케일과의 편차 합이 **최소**인 계수 선택
5. 계수가 0.98~1.02이면 "보정 불필요", 그 외 계수와 신뢰도 출력

## Phase 1.2: 글로벌 토큰 추출

| 토큰 | 추출 방법 |
|------|----------|
| **색상 팔레트** | 모든 고유 `color`/`bgColor` 수집 → 빈도순 정렬 → Tailwind 컬러 매칭 |
| **타이포그래피** | `fontFamily`/`fontSize`/`fontWeight`/`fontStyle`/`lineHeight`/`letterSpacing` 조합별 사용 빈도 |
| **간격 체계** | `padding`/`margin`/`gap` 값 분포 → 베이스 유닛(보통 4px) 감지 |
| **보더** | `borderRadius` 패턴 (sm/md/lg/full), `outline` 스타일 정리 |
| **그림자** | `boxShadow`, `textShadow` 고유 값 목록 |
| **그라데이션** | `backgroundImage`에서 `linear-gradient`/`radial-gradient` 추출 → 빈도순 |
| **필터/효과** | `filter`, `backdropFilter` 고유 값 목록 (blur, brightness 등) |
| **트랜스폼** | `transform` 고유 패턴 (scale, rotate, translate) 수집 |
| **애니메이션** | `animationName`/`animationDuration`/`animationTimingFunction` 수집, `@keyframes` 규칙 추출 |
| **CSS 변수** | `:root`/`.dark`에 정의된 `--` custom properties 전체 수집 → 용도별 분류 |

## Phase 1.3: 토큰 출력 포맷

```json
{
  "meta": {
    "url": "https://example.site",
    "extractedAt": "2026-03-15T10:00:00Z",
    "viewport": { "width": 1366, "height": 900 },
    "correctionFactor": 1.14,
    "confidence": "HIGH",
    "framework": "shadcn-ui"
  },
  "tokens": {
    "colors": [
      { "value": "oklch(0.145 0 0)", "tailwind": "gray-900", "count": 42, "usage": "headings, body" },
      { "value": "oklch(0.556 0 0)", "tailwind": "gray-500", "count": 28, "usage": "descriptions" }
    ],
    "typography": {
      "h1": { "fontFamily": "Geist Sans", "fontSize": "24px", "fontWeight": "500", "lineHeight": "32px", "letterSpacing": "normal" },
      "body": { "fontFamily": "Geist Sans", "fontSize": "14px", "fontWeight": "400", "lineHeight": "20px", "letterSpacing": "normal" }
    },
    "spacing": {
      "baseUnit": "4px",
      "scale": ["4px", "8px", "12px", "16px", "24px", "32px", "48px"],
      "dominant": ["16px", "24px", "8px"]
    },
    "borders": {
      "default": { "width": "1px", "style": "solid", "color": "oklch(0.878 0 0)" },
      "radius": { "sm": "6px", "md": "8px", "lg": "12px", "full": "9999px" }
    },
    "shadows": ["0 1px 2px 0 rgba(0,0,0,0.05)", "0 4px 6px -1px rgba(0,0,0,0.1)"],
    "gradients": [
      { "value": "linear-gradient(to right, #3b82f6, #8b5cf6)", "count": 3 }
    ],
    "filters": {
      "filter": ["blur(4px)", "brightness(0.95)"],
      "backdropFilter": ["blur(8px)", "blur(12px) saturate(180%)"]
    },
    "transforms": ["scale(1.05)", "translateY(-2px)", "rotate(45deg)"],
    "animations": [
      { "name": "spin", "duration": "1s", "timingFunction": "linear", "iterationCount": "infinite" }
    ],
    "cssVariables": {
      "light": { "--background": "oklch(1 0 0)", "--foreground": "oklch(0.145 0 0)" },
      "dark": { "--background": "oklch(0.145 0 0)", "--foreground": "oklch(0.985 0 0)" }
    }
  }
}
```

## 매핑 시그널 (Phase 4.1)

다중 시그널로 참고 요소 ↔ 코드베이스 매핑:

| 시그널 | 가중치 | 예시 |
|--------|--------|------|
| 영역 위치 | 0.4 | sidebar → `layout/sidebar.tsx` |
| 요소 tag/role | 0.3 | `table` → `ui/data-table.tsx` |
| Tailwind 클래스 겹침 | 0.2 | `rounded-lg border` → 특정 컴포넌트 |
| 텍스트 유사도 | 0.1 | "Dashboard" → NavItem |

2개 이상 시그널 매칭 시 자동 매핑. 모호하면 사용자에게 확인.

## 변경 제안 출력 포맷

```
┌─── src/components/layout/sidebar.tsx ───────────────────────┐
│ Line 40: className="...w-52..."                             │
│   width: 208px → 224px                                      │
│   제안: w-52 → w-56                                         │
│                                                              │
│ Line 41: className="...px-6..."                              │
│   padding-left: 24px → 16px                                  │
│   제안: px-6 → px-4                                          │
└──────────────────────────────────────────────────────────────┘
```

## 싱크율 계산 (Phase 3.10)

```
싱크율 = (1 - 불일치픽셀수 / 전체픽셀수) × 100
```

페이지별 싱크율 + 전체 평균 싱크율을 출력한다.

### 비교 방법론

- **정렬 검증**: 형제 요소 간 x/y 좌표 추출 → 수평/수직 정렬, gap 균일성(표준편차 2px 이하)
- **텍스트 마스킹**: 더미 vs 실제 데이터 차이 제거 → `color: transparent` → 순수 레이아웃 비교
- **스크롤 영역**: `fullPage: true` + 뷰포트 단위 분할 + overflow 컨테이너 내부 스크롤
- **반응형**: 4개 뷰포트 (375×812, 768×1024, 1366×900, 1920×1080) 개별 비교
- **다크 모드**: `colorScheme: 'dark'` + `classList.add('dark')` → 라이트/다크 양쪽 비교
