# 디자인 가이드 템플릿

> **⚠️ 작성 지침**: 이 템플릿 외에 반드시 design-master 스킬의 4개 참조 파일을 읽고 해당 내용을 반영한다.
> - `~/.claude/skills/design-master/references/ux-psychology.md`
> - `~/.claude/skills/design-master/references/ux-guidelines.md`
> - `~/.claude/skills/design-master/references/design-system.md`
> - `~/.claude/skills/design-master/references/modern-patterns.md`

## 1. 디자인 원칙 및 UX 심리학

### 핵심 원칙
1. **명확성 (Clarity)**: 직관적이고 이해하기 쉬운 인터페이스
2. **일관성 (Consistency)**: 통일된 시각 언어와 패턴
3. **효율성 (Efficiency)**: 최소한의 단계로 목표 달성
4. **접근성 (Accessibility)**: 모든 사용자가 사용 가능

### 브랜드 키워드
| 키워드 | 시각적 표현 |
|--------|-------------|
| {키워드1} | {색상, 형태, 톤앤매너} |
| {키워드2} | {색상, 형태, 톤앤매너} |
| {키워드3} | {색상, 형태, 톤앤매너} |

### UX 심리학 7법칙 적용
> `ux-psychology.md` 참조. 각 법칙을 프로젝트에 구체적으로 어떻게 적용하는지 기술한다.

| 법칙 | 핵심 키워드 | 프로젝트 적용 |
|------|-------------|--------------|
| 힉스의 법칙 | 선택지 줄이기 | {메뉴 5~7개 이내, 점진적 공개} |
| 피츠의 법칙 | 크게, 가깝게 | {44x44pt 버튼, 하단 CTA} |
| 게슈탈트 원리 | 그룹화 | {근접성, 카드 UI, 공통 영역} |
| 제이콥의 법칙 | 익숙한 패턴 | {표준 UI 패턴 따르기} |
| 밀러의 법칙 | 7±2 개 | {청킹, 단계 분리} |
| 도허티 임계값 | 400ms | {즉각적 피드백, 스켈레톤} |
| 폰 레스토프 효과 | 시각적 강조 | {CTA 색상 차별화, 뱃지} |

### CRO 전략 및 다크패턴 방지
> `ux-guidelines.md` 참조

#### CRO (전환율 최적화)
- {프로젝트별 전환 목표 및 전략}

#### 다크패턴 방지 체크리스트
- [ ] 강제 지속 (Forced Continuity) 방지
- [ ] 숨겨진 비용 (Hidden Costs) 방지
- [ ] 수치심 유발 (Confirmshaming) 방지
- [ ] 미끼 전환 (Bait and Switch) 방지

---

## 2. 컬러 시스템

### 60-30-10 규칙
| 비율 | 역할 | 적용 |
|------|------|------|
| 60% | 주요 배경 | 배경, 카드 |
| 30% | 보조 색상 | 텍스트, 아이콘, 보조 요소 |
| 10% | 강조 색상 | CTA, 배지, 알림 |

### 2.1 Primary Colors (50-900 스케일)

| 단계 | Hex | HSL | 용도 |
|------|-----|-----|------|
| 50 | `#EFF6FF` | `214 100% 97%` | 배경 하이라이트 |
| 100 | `#DBEAFE` | `214 95% 93%` | 호버 배경 |
| 200 | `#BFDBFE` | `213 97% 87%` | 비활성 배경 |
| 300 | `#93C5FD` | `212 96% 78%` | 테두리 |
| 400 | `#60A5FA` | `213 94% 68%` | 아이콘 |
| 500 | `#3B82F6` | `217 91% 60%` | **Primary** - 주요 액션 |
| 600 | `#2563EB` | `217 91% 53%` | 호버 상태 |
| 700 | `#1D4ED8` | `224 76% 48%` | 액티브/포커스 |
| 800 | `#1E40AF` | `226 71% 40%` | 강조 텍스트 |
| 900 | `#1E3A8A` | `226 57% 33%` | 다크 배경 |

### 2.2 Neutral Colors (Gray 스케일)

| 단계 | Hex | 용도 |
|------|-----|------|
| 50 | `#F9FAFB` | 페이지 배경 |
| 100 | `#F3F4F6` | 카드 배경 (다크) |
| 200 | `#E5E7EB` | 구분선 |
| 300 | `#D1D5DB` | 테두리 |
| 400 | `#9CA3AF` | 플레이스홀더 |
| 500 | `#6B7280` | 보조 텍스트 |
| 600 | `#4B5563` | 부제목 |
| 700 | `#374151` | 본문 텍스트 |
| 800 | `#1F2937` | 제목 |
| 900 | `#111827` | 강조 텍스트 |
| 950 | `#030712` | 다크모드 배경 |

### 2.3 Semantic Colors

| 이름 | Light | Dark | 용도 |
|------|-------|------|------|
| Success | `#22C55E` | `#4ADE80` | 성공 메시지 |
| Success BG | `#F0FDF4` | `#14532D` | 성공 배경 |
| Warning | `#F59E0B` | `#FBBF24` | 경고 메시지 |
| Warning BG | `#FFFBEB` | `#78350F` | 경고 배경 |
| Error | `#EF4444` | `#F87171` | 에러 메시지 |
| Error BG | `#FEF2F2` | `#7F1D1D` | 에러 배경 |
| Info | `#3B82F6` | `#60A5FA` | 정보 메시지 |
| Info BG | `#EFF6FF` | `#1E3A8A` | 정보 배경 |

### 2.4 다크 모드 매핑

```css
/* Light → Dark 변환 규칙 */
:root {
  --background: 0 0% 100%;      /* White */
  --foreground: 222 47% 11%;    /* Gray 900 */
  --card: 0 0% 100%;            /* White */
  --card-foreground: 222 47% 11%;
  --muted: 210 40% 96%;         /* Gray 100 */
  --muted-foreground: 215 16% 47%; /* Gray 500 */
  --border: 214 32% 91%;        /* Gray 200 */
}

.dark {
  --background: 222 47% 5%;     /* Gray 950 */
  --foreground: 210 40% 98%;    /* Gray 50 */
  --card: 222 47% 11%;          /* Gray 900 */
  --card-foreground: 210 40% 98%;
  --muted: 217 33% 17%;         /* Gray 800 */
  --muted-foreground: 215 20% 65%; /* Gray 400 */
  --border: 217 33% 17%;        /* Gray 800 */
}
```

### 2.5 다크 모드 전환 애니메이션

```css
/* 부드러운 전환 */
*,
*::before,
*::after {
  transition: background-color 200ms ease,
              border-color 200ms ease,
              color 200ms ease;
}

/* 특정 요소 제외 (성능 최적화) */
img,
video,
.no-transition {
  transition: none;
}
```

### 2.6 디자인 토큰 체계
> `design-system.md` 참조. Primitive → Semantic 2계층 토큰 구조.

```
Primitive Tokens (원시)          Semantic Tokens (의미)
─────────────────────           ─────────────────────
blue-500: #3B82F6       →      primary: blue-500
gray-900: #111827       →      text-primary: gray-900
green-500: #22C55E      →      success: green-500
```

Tailwind v4 CSS-first 설정 예시:

```css
/* globals.css */
@import "tailwindcss";

@theme {
  --color-primary-50: oklch(0.97 0.01 250);
  --color-primary-500: oklch(0.6 0.2 250);
  --color-primary-600: oklch(0.53 0.21 250);
  /* ... 프로젝트별 색상 기입 */
}
```

---

## 3. 타이포그래피

### 3.1 폰트 패밀리

```css
--font-sans: 'Pretendard Variable', 'Pretendard', -apple-system,
             BlinkMacSystemFont, 'Segoe UI', sans-serif;
--font-mono: 'JetBrains Mono', 'Fira Code', 'Consolas', monospace;
```

### 3.2 타입 스케일

| 이름 | Size | Line Height | Weight | Letter Spacing | 용도 |
|------|------|-------------|--------|----------------|------|
| Display XL | 60px | 1.1 | 700 | -0.03em | 랜딩 히어로 |
| Display | 48px | 1.15 | 700 | -0.02em | 히어로 제목 |
| H1 | 36px | 1.2 | 700 | -0.02em | 페이지 제목 |
| H2 | 30px | 1.3 | 600 | -0.01em | 섹션 제목 |
| H3 | 24px | 1.4 | 600 | -0.01em | 서브섹션 |
| H4 | 20px | 1.4 | 600 | 0 | 카드 제목 |
| Body LG | 18px | 1.6 | 400 | 0 | 강조 본문 |
| Body | 16px | 1.6 | 400 | 0 | 본문 |
| Body SM | 14px | 1.5 | 400 | 0 | 보조 텍스트 |
| Caption | 12px | 1.4 | 400 | 0.01em | 캡션, 라벨 |
| Overline | 12px | 1.4 | 600 | 0.05em | 오버라인 |

### 3.3 반응형 타입 스케일

```css
/* clamp(최소, 선호, 최대) 사용 */
.display {
  font-size: clamp(2rem, 5vw, 3.75rem);  /* 32px → 60px */
}

.h1 {
  font-size: clamp(1.75rem, 4vw, 2.25rem); /* 28px → 36px */
}

.h2 {
  font-size: clamp(1.5rem, 3vw, 1.875rem); /* 24px → 30px */
}
```

---

## 4. 스페이싱

### 4.1 베이스 스케일 (4px 기반)

| Token | Value | Tailwind | 용도 |
|-------|-------|----------|------|
| space-0.5 | 2px | 0.5 | 미세 조정 |
| space-1 | 4px | 1 | 아이콘 간격 |
| space-2 | 8px | 2 | 인라인 요소 |
| space-3 | 12px | 3 | 작은 간격 |
| space-4 | 16px | 4 | 기본 간격 |
| space-5 | 20px | 5 | 중간 간격 |
| space-6 | 24px | 6 | 컴포넌트 내부 |
| space-8 | 32px | 8 | 섹션 간격 |
| space-10 | 40px | 10 | 큰 간격 |
| space-12 | 48px | 12 | 섹션 분리 |
| space-16 | 64px | 16 | 페이지 섹션 |
| space-20 | 80px | 20 | 히어로 섹션 |
| space-24 | 96px | 24 | 대형 섹션 |

### 4.2 컨테이너

| 이름 | Max Width | Padding (Mobile) | Padding (Desktop) |
|------|-----------|------------------|-------------------|
| xs | 480px | 16px | 24px |
| sm | 640px | 16px | 24px |
| md | 768px | 24px | 32px |
| lg | 1024px | 24px | 32px |
| xl | 1280px | 32px | 48px |
| 2xl | 1536px | 32px | 64px |

---

## 5. 그림자 시스템 (Shadow)

### 5.1 Elevation 레벨

| 이름 | CSS | 용도 |
|------|-----|------|
| shadow-xs | `0 1px 2px rgba(0,0,0,0.05)` | 입력 필드 |
| shadow-sm | `0 1px 3px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.06)` | 카드 기본 |
| shadow-md | `0 4px 6px -1px rgba(0,0,0,0.1), 0 2px 4px -1px rgba(0,0,0,0.06)` | 호버 상태 |
| shadow-lg | `0 10px 15px -3px rgba(0,0,0,0.1), 0 4px 6px -2px rgba(0,0,0,0.05)` | 드롭다운 |
| shadow-xl | `0 20px 25px -5px rgba(0,0,0,0.1), 0 10px 10px -5px rgba(0,0,0,0.04)` | 모달 |
| shadow-2xl | `0 25px 50px -12px rgba(0,0,0,0.25)` | 오버레이 |
| shadow-inner | `inset 0 2px 4px rgba(0,0,0,0.06)` | 눌림 효과 |

### 5.2 컬러 그림자

```css
/* Primary 컬러 그림자 */
.shadow-primary {
  box-shadow: 0 4px 14px rgba(59, 130, 246, 0.4);
}

/* 다크모드 그림자 */
.dark .shadow-sm {
  box-shadow: 0 1px 3px rgba(0,0,0,0.3), 0 1px 2px rgba(0,0,0,0.2);
}
```

---

## 6. Border Radius

| 이름 | Value | 용도 |
|------|-------|------|
| rounded-none | 0 | 직각 요소 |
| rounded-sm | 4px | 태그, 배지 |
| rounded | 6px | 입력 필드 |
| rounded-md | 8px | 버튼 |
| rounded-lg | 12px | 카드 |
| rounded-xl | 16px | 모달, 다이얼로그 |
| rounded-2xl | 24px | 대형 카드 |
| rounded-full | 9999px | 원형 요소 |

---

## 7. 컴포넌트 상태

### 7.1 버튼 상태

| 상태 | Primary | Secondary | Ghost | Destructive |
|------|---------|-----------|-------|-------------|
| **Default** | bg-primary-500 text-white | bg-gray-100 text-gray-900 | bg-transparent text-gray-700 | bg-red-500 text-white |
| **Hover** | bg-primary-600 | bg-gray-200 | bg-gray-100 | bg-red-600 |
| **Focus** | ring-2 ring-primary-500 ring-offset-2 | ring-2 ring-gray-400 ring-offset-2 | ring-2 ring-gray-400 ring-offset-2 | ring-2 ring-red-500 ring-offset-2 |
| **Active** | bg-primary-700 | bg-gray-300 | bg-gray-200 | bg-red-700 |
| **Disabled** | bg-primary-300 cursor-not-allowed | bg-gray-50 text-gray-400 | text-gray-300 | bg-red-300 |
| **Loading** | bg-primary-500 + spinner | bg-gray-100 + spinner | spinner only | bg-red-500 + spinner |

### 7.2 입력 필드 상태

| 상태 | 테두리 | 배경 | 링 | 아이콘 |
|------|--------|------|-----|--------|
| Default | gray-300 | white | - | gray-400 |
| Hover | gray-400 | white | - | gray-500 |
| Focus | primary-500 | white | ring-4 ring-primary-100 | primary-500 |
| Filled | gray-300 | white | - | gray-600 |
| Error | red-500 | red-50 | ring-4 ring-red-100 | red-500 |
| Success | green-500 | green-50 | - | green-500 |
| Disabled | gray-200 | gray-100 | - | gray-300 |

### 7.3 카드 상태

```css
/* 기본 카드 */
.card {
  background: white;
  border: 1px solid var(--gray-200);
  border-radius: 12px;
  padding: 24px;
  box-shadow: var(--shadow-sm);
  transition: all 200ms ease;
}

/* 호버 (인터랙티브 카드) */
.card-interactive:hover {
  border-color: var(--gray-300);
  box-shadow: var(--shadow-md);
  transform: translateY(-2px);
}

/* 선택됨 */
.card-selected {
  border-color: var(--primary-500);
  box-shadow: 0 0 0 3px var(--primary-100);
}

/* 비활성화 */
.card-disabled {
  opacity: 0.6;
  pointer-events: none;
}
```

### 7.4 컴포넌트 계층 구조
> `design-system.md` 참조. 3계층 컴포넌트 아키텍처.

| 계층 | 설명 | 예시 |
|------|------|------|
| Primitive | 단일 기능, 최소 단위 | Button, Input, Badge |
| Composite | Primitive 조합 | SearchBar, FormField |
| Pattern | 비즈니스 로직 포함 | ProjectCard, TaskList |

cva (class-variance-authority) 패턴 예시:

```tsx
import { cva, type VariantProps } from "class-variance-authority";

const buttonVariants = cva(
  "inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground hover:bg-primary/90",
        destructive: "bg-destructive text-destructive-foreground hover:bg-destructive/90",
        outline: "border border-input bg-background hover:bg-accent",
        ghost: "hover:bg-accent hover:text-accent-foreground",
      },
      size: {
        default: "h-10 px-4 py-2",
        sm: "h-9 rounded-md px-3",
        lg: "h-11 rounded-md px-8",
        icon: "h-10 w-10",
      },
    },
    defaultVariants: { variant: "default", size: "default" },
  }
);
```

---

## 8. 이미지 처리 규칙

### 8.1 가로세로비 (Aspect Ratio)

| 용도 | 비율 | Tailwind | 설명 |
|------|------|----------|------|
| 히어로 배너 | 21:9 | aspect-[21/9] | 와이드 배너 |
| 카드 썸네일 | 16:9 | aspect-video | 블로그, 포트폴리오 |
| 프로필 | 1:1 | aspect-square | 아바타, 프로필 |
| 상품 이미지 | 4:3 | aspect-[4/3] | 제품, 갤러리 |
| 세로 이미지 | 3:4 | aspect-[3/4] | 인물 사진 |
| OG 이미지 | 1.91:1 | aspect-[1.91/1] | 소셜 미리보기 |

### 8.2 이미지 핏 규칙

```css
/* 컨테이너에 맞춤 (크롭 허용) */
.img-cover {
  object-fit: cover;
  object-position: center;
}

/* 전체 표시 (여백 허용) */
.img-contain {
  object-fit: contain;
  background: var(--gray-100);
}

/* 상단 정렬 (인물 사진) */
.img-portrait {
  object-fit: cover;
  object-position: top;
}
```

### 8.3 이미지 최적화

| 용도 | 포맷 | 품질 | 최대 크기 |
|------|------|------|----------|
| 사진 | WebP/AVIF | 80-85% | 1920px |
| 아이콘/로고 | SVG | - | - |
| 그래픽 | PNG | lossless | 1280px |
| 썸네일 | WebP | 75% | 400px |
| OG 이미지 | JPG | 85% | 1200x630px |

### 8.4 플레이스홀더

```tsx
// blur 플레이스홀더
<Image
  src="/photo.jpg"
  placeholder="blur"
  blurDataURL="data:image/jpeg;base64,..."
/>

// 색상 플레이스홀더
<div className="bg-gray-200 animate-pulse aspect-video rounded-lg" />
```

---

## 9. 아이콘

### 9.1 아이콘 시스템
- **라이브러리**: Lucide Icons (권장)
- **대체**: Heroicons, Phosphor Icons
- **기본 크기**: 24px
- **스트로크**: 1.5px ~ 2px

### 9.2 아이콘 크기

| 크기 | Value | Stroke | 용도 |
|------|-------|--------|------|
| xs | 14px | 2px | 배지 내부 |
| sm | 16px | 2px | 인라인, 작은 버튼 |
| md | 20px | 1.75px | 버튼 내부 |
| lg | 24px | 1.5px | 기본, 네비게이션 |
| xl | 32px | 1.5px | 강조, 빈 상태 |
| 2xl | 48px | 1.25px | 일러스트레이션 |

### 9.3 아이콘 + 텍스트 조합

```tsx
// 버튼 내 아이콘 (왼쪽)
<Button>
  <Icon className="w-4 h-4 mr-2" />
  라벨
</Button>

// 버튼 내 아이콘 (오른쪽)
<Button>
  라벨
  <Icon className="w-4 h-4 ml-2" />
</Button>

// 아이콘만
<Button variant="ghost" size="icon">
  <Icon className="w-5 h-5" />
  <span className="sr-only">메뉴</span>
</Button>
```

---

## 10. 반응형 브레이크포인트

| 이름 | Min Width | 용도 | 레이아웃 변화 |
|------|-----------|------|---------------|
| (default) | 0px | 모바일 세로 | 단일 컬럼 |
| sm | 640px | 모바일 가로 | 2컬럼 가능 |
| md | 768px | 태블릿 | 사이드바 표시 |
| lg | 1024px | 데스크톱 | 전체 레이아웃 |
| xl | 1280px | 와이드 스크린 | 여백 증가 |
| 2xl | 1536px | 대형 모니터 | 최대 너비 고정 |

### 모바일 퍼스트 접근

```css
/* 모바일 기본 */
.component {
  flex-direction: column;
  padding: 16px;
}

/* 태블릿 이상 */
@media (min-width: 768px) {
  .component {
    flex-direction: row;
    padding: 24px;
  }
}
```

---

## 11. 애니메이션

### 11.1 Duration

| 이름 | Value | 용도 |
|------|-------|------|
| instant | 0ms | 즉시 반응 |
| fast | 100ms | 색상 변화 |
| normal | 150ms | 기본 전환 |
| moderate | 200ms | 크기/위치 변화 |
| slow | 300ms | 모달/드로어 |
| slower | 500ms | 페이지 전환 |

### 11.2 Easing

```css
/* 기본 이징 */
--ease-linear: linear;
--ease-in: cubic-bezier(0.4, 0, 1, 1);
--ease-out: cubic-bezier(0, 0, 0.2, 1);
--ease-in-out: cubic-bezier(0.4, 0, 0.2, 1);

/* 스프링 효과 */
--ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1);
--ease-bounce: cubic-bezier(0.68, -0.55, 0.265, 1.55);
```

### 11.3 공통 애니메이션

```css
/* 페이드 인 */
@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

/* 슬라이드 업 + 페이드 */
@keyframes slideUp {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* 스케일 업 */
@keyframes scaleUp {
  from {
    opacity: 0;
    transform: scale(0.95);
  }
  to {
    opacity: 1;
    transform: scale(1);
  }
}

/* 스피너 */
@keyframes spin {
  to { transform: rotate(360deg); }
}

/* 펄스 (스켈레톤) */
@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}
```

### 11.4 Reduced Motion

```css
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

### 11.5 Framer Motion 레시피
> `modern-patterns.md` 참조

```tsx
// 등장 애니메이션
<motion.div
  initial={{ opacity: 0, y: 20 }}
  whileInView={{ opacity: 1, y: 0 }}
  viewport={{ once: true, margin: "-100px" }}
  transition={{ duration: 0.5, ease: "easeOut" }}
/>

// 버튼 인터랙션
<motion.button
  whileHover={{ scale: 1.05 }}
  whileTap={{ scale: 0.95 }}
  transition={{ type: "spring", stiffness: 400, damping: 17 }}
/>

// 리스트 Stagger
const container = {
  hidden: { opacity: 0 },
  show: { opacity: 1, transition: { staggerChildren: 0.1 } },
};
const item = {
  hidden: { opacity: 0, y: 20 },
  show: { opacity: 1, y: 0 },
};

// 퇴장 애니메이션
<AnimatePresence>
  {isVisible && (
    <motion.div
      initial={{ opacity: 0, scale: 0.9 }}
      animate={{ opacity: 1, scale: 1 }}
      exit={{ opacity: 0, scale: 0.9 }}
    />
  )}
</AnimatePresence>

// 접근성 존중
const shouldReduceMotion = useReducedMotion();
<motion.div animate={shouldReduceMotion ? {} : { y: scrollY * 0.5 }} />
```

---

## 12. 모바일 UX 패턴
> `modern-patterns.md` 참조

### 12.1 Thumb Zone 최적화

```
     +-------------+
     |    어려움   |  ← 상단: 자주 사용 안 하는 기능
     |             |
     |    보통     |
     |             |
     |    쉬움     |  ← 하단: 핵심 CTA
     +-------------+
```

핵심 CTA는 화면 하단에 배치. 고정 하단 버튼 패턴 활용.

### 12.2 하단 시트 (Bottom Sheet)

적합한 사용처: 공유하기, 필터 설정, 항목 수정/삭제, 보조 액션.
shadcn/ui의 `Drawer` 컴포넌트 활용.

### 12.3 터치 타겟

| 플랫폼 | 최소 크기 | 최소 간격 |
|--------|----------|----------|
| iOS | 44x44pt | 8pt |
| Android | 48x48dp | 8dp |

### 12.4 모바일 폼 최적화

```html
<!-- inputmode로 적절한 키패드 표시 -->
<input type="text" inputmode="numeric" />  <!-- 숫자 키패드 -->
<input type="email" inputmode="email" />   <!-- 이메일 키보드 -->
<input type="tel" inputmode="tel" />       <!-- 전화번호 키패드 -->

<!-- autocomplete로 자동완성 지원 -->
<input autocomplete="name" />
<input autocomplete="email" />
```

### 12.5 제스처 인터랙션

| 제스처 | 동작 | 주의사항 |
|--------|------|---------|
| 왼쪽 스와이프 | 삭제 | 항상 버튼 대안 제공 |
| 오른쪽 스와이프 | 이전 화면 | 시각적 힌트 필요 |
| 아래로 당기기 | Pull-to-Refresh | 표준 패턴 |
| 롱 프레스 | 컨텍스트 메뉴 | 발견성 낮음 |

---

## 13. 모던 시각 패턴
> `modern-patterns.md` 참조

### 13.1 Bento Grid

대시보드, 포트폴리오, 랜딩 페이지에 적합한 비대칭 그리드 레이아웃.

```css
.bento-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 1rem;
}
.bento-item-large { grid-column: span 2; grid-row: span 2; }
.bento-item-wide { grid-column: span 2; }
```

### 13.2 대형 타이포그래피

```css
.hero-title {
  font-size: clamp(2.5rem, 8vw, 6rem);
  font-weight: 800;
  line-height: 1.1;
  letter-spacing: -0.02em;
}
```

### 13.3 CSS View Transitions

```css
.card-image { view-transition-name: hero-image; }
::view-transition-old(hero-image),
::view-transition-new(hero-image) {
  animation-duration: 0.3s;
  animation-timing-function: ease-in-out;
}
```

---

## 14. 접근성

### 14.1 색상 대비

| 요소 | 최소 대비 | 권장 대비 |
|------|----------|----------|
| 일반 텍스트 (< 18px) | 4.5:1 | 7:1 |
| 큰 텍스트 (≥ 18px) | 3:1 | 4.5:1 |
| UI 컴포넌트 | 3:1 | 4.5:1 |
| 비활성 요소 | 없음 | 3:1 |

### 14.2 포커스 스타일

```css
/* 기본 포커스 링 */
:focus-visible {
  outline: 2px solid var(--primary-500);
  outline-offset: 2px;
}

/* 다크 배경에서 */
.dark :focus-visible {
  outline-color: var(--primary-400);
}

/* 포커스 링 커스텀 */
.focus-ring {
  @apply focus:outline-none focus-visible:ring-2
         focus-visible:ring-primary-500 focus-visible:ring-offset-2;
}
```

### 14.3 터치 타겟

- 최소 크기: 44px × 44px
- 권장 크기: 48px × 48px
- 타겟 간 간격: 최소 8px

---

## 15. 디자인 토큰 (JSON)

```json
{
  "color": {
    "primary": {
      "50": { "value": "#EFF6FF" },
      "100": { "value": "#DBEAFE" },
      "500": { "value": "#3B82F6" },
      "600": { "value": "#2563EB" },
      "700": { "value": "#1D4ED8" }
    },
    "gray": {
      "50": { "value": "#F9FAFB" },
      "100": { "value": "#F3F4F6" },
      "500": { "value": "#6B7280" },
      "900": { "value": "#111827" }
    },
    "semantic": {
      "success": { "value": "#22C55E" },
      "warning": { "value": "#F59E0B" },
      "error": { "value": "#EF4444" },
      "info": { "value": "#3B82F6" }
    }
  },
  "spacing": {
    "1": { "value": "4px" },
    "2": { "value": "8px" },
    "4": { "value": "16px" },
    "6": { "value": "24px" },
    "8": { "value": "32px" }
  },
  "typography": {
    "fontFamily": {
      "sans": { "value": "'Pretendard', sans-serif" },
      "mono": { "value": "'JetBrains Mono', monospace" }
    },
    "fontSize": {
      "xs": { "value": "12px" },
      "sm": { "value": "14px" },
      "base": { "value": "16px" },
      "lg": { "value": "18px" },
      "xl": { "value": "20px" },
      "2xl": { "value": "24px" }
    }
  },
  "shadow": {
    "sm": { "value": "0 1px 3px rgba(0,0,0,0.1)" },
    "md": { "value": "0 4px 6px -1px rgba(0,0,0,0.1)" },
    "lg": { "value": "0 10px 15px -3px rgba(0,0,0,0.1)" }
  },
  "borderRadius": {
    "sm": { "value": "4px" },
    "md": { "value": "8px" },
    "lg": { "value": "12px" },
    "full": { "value": "9999px" }
  }
}
```

---

## 16. 관련 도구

| 도구 | 용도 | URL |
|------|------|-----|
| Figma | UI 디자인 | figma.com |
| Contrast Checker | 대비 검사 | webaim.org/resources/contrastchecker |
| Realtime Colors | 컬러 시뮬레이션 | realtimecolors.com |
| Coolors | 팔레트 생성 | coolors.co |
| Type Scale | 타이포그래피 스케일 | typescale.com |
| Easing Functions | 이징 커브 | easings.net |

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| 1.0 | {date} | 최초 작성 | {author} |
