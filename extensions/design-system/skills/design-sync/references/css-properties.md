# CSS 속성 카테고리 및 Tailwind 매핑 레퍼런스

## 21개 속성 카테고리

| # | 카테고리 | 속성 |
|---|---------|------|
| 1 | 셀렉터/클래스 | `tag.className` |
| 2 | 크기 | `width`, `height`, `minWidth`, `maxWidth`, `minHeight`, `maxHeight`, `aspectRatio` |
| 3 | 색상 | `color`, `backgroundColor`, `opacity` |
| 4 | 서체 | `fontFamily`, `fontSize`, `fontWeight`, `fontStyle`, `lineHeight`, `letterSpacing` |
| 5 | 텍스트 | `textAlign`, `textTransform`, `textDecoration`, `whiteSpace`, `verticalAlign`, `textOverflow`, `wordBreak`, `overflowWrap`, `textShadow` |
| 6 | 패딩 | `padding` (4방향 축약) |
| 7 | 마진 | `margin` (4방향 축약) |
| 8 | 보더 | `border`, `borderColor`, `borderWidth`, `borderRadius`, `outline`, `outlineOffset` |
| 9 | 시각효과 | `boxShadow`, `backgroundImage`(그라데이션), `filter`, `backdropFilter`, `mixBlendMode`, `clipPath` |
| 10 | 레이아웃 | `display`, `flexDirection`, `flexWrap`, `flexGrow/Shrink/Basis`, `alignItems`, `justifyContent`, `gridTemplateColumns/Rows`, `gridColumn/Row`, `placeItems`, `order`, `gap`, `position`, `overflow`, `zIndex`, `isolation`, `columns` |
| 11 | 포지셔닝 | `top`, `right`, `bottom`, `left`, `inset` |
| 12 | 트랜스폼 | `transform`, `transformOrigin` |
| 13 | 인터랙션 | `cursor`, `transition`, `transitionDuration`, `transitionTimingFunction`, `pointerEvents`, `userSelect`, `resize`, `scrollBehavior`, `scrollSnapType`, `scrollSnapAlign` |
| 14 | 이미지/미디어 | `objectFit`, `objectPosition` |
| 15 | 폼 스타일 | `appearance`, `accentColor`, `caretColor` |
| 16 | 접근성 | Contrast ratio, accessible name, ARIA role, keyboard-focusable, `visibility` |
| 17 | CSS 변수 | `--background`, `--foreground`, `--sidebar`, `--primary` 등 custom properties |
| 18 | 의사 요소 | `::before`, `::after` — content, 크기, 색상, 위치 |
| 19 | 선택 스타일 | `::selection` — color, backgroundColor |
| 20 | 아이콘 | `width`, `height`, `color`/`stroke`, `strokeWidth`, `fill` |
| 21 | 애니메이션 | `animationName`, `animationDuration`, `animationTimingFunction`, `animationIterationCount`, `listStyleType` |

## Tailwind CSS 4 값 매핑 테이블

### 폰트 크기
| CSS | Tailwind |
|-----|----------|
| 12px | text-xs |
| 14px | text-sm |
| 16px | text-base |
| 18px | text-lg |
| 20px | text-xl |
| 24px | text-2xl |
| 30px | text-3xl |
| 36px | text-4xl |

### 폰트 굵기
| CSS | Tailwind |
|-----|----------|
| 100 | font-thin |
| 200 | font-extralight |
| 300 | font-light |
| 400 | font-normal |
| 500 | font-medium |
| 600 | font-semibold |
| 700 | font-bold |
| 800 | font-extrabold |
| 900 | font-black |

### 행간 (lineHeight)
| CSS | Tailwind |
|-----|----------|
| 16px | leading-4 |
| 20px | leading-5 |
| 24px | leading-6 |
| 28px | leading-7 |
| 32px | leading-8 |
| 36px | leading-9 |
| 40px | leading-10 |
| 1 | leading-none |
| 1.25 | leading-tight |
| 1.375 | leading-snug |
| 1.5 | leading-normal |
| 1.625 | leading-relaxed |
| 2 | leading-loose |

### 자간 (letterSpacing)
| CSS | Tailwind |
|-----|----------|
| -0.05em | tracking-tighter |
| -0.025em | tracking-tight |
| 0em / normal | tracking-normal |
| 0.025em | tracking-wide |
| 0.05em | tracking-wider |
| 0.1em | tracking-widest |

### 폰트 패밀리
| 패턴 | Tailwind |
|------|----------|
| sans-serif 계열 (Geist, Inter, Pretendard 등) | font-sans |
| serif 계열 (Georgia, Times 등) | font-serif |
| monospace 계열 (Geist Mono, JetBrains Mono 등) | font-mono |
| 커스텀 폰트 | font-[폰트명] |

### 폰트 스타일
| CSS | Tailwind |
|-----|----------|
| italic | italic |
| normal | not-italic |

### 텍스트 정렬
| CSS | Tailwind |
|-----|----------|
| left | text-left |
| center | text-center |
| right | text-right |
| justify | text-justify |
| start | text-start |
| end | text-end |

### 텍스트 변환
| CSS | Tailwind |
|-----|----------|
| uppercase | uppercase |
| lowercase | lowercase |
| capitalize | capitalize |
| none | normal-case |

### 공백 처리 (whiteSpace)
| CSS | Tailwind |
|-----|----------|
| nowrap | whitespace-nowrap |
| pre | whitespace-pre |
| pre-line | whitespace-pre-line |
| pre-wrap | whitespace-pre-wrap |
| break-spaces | whitespace-break-spaces |
| normal | whitespace-normal |

### 단어 줄바꿈
| CSS | Tailwind |
|-----|----------|
| word-break: break-all | break-all |
| word-break: keep-all | break-keep |
| overflow-wrap: break-word | break-words |

### Flex 방향
| CSS | Tailwind |
|-----|----------|
| row | flex-row |
| row-reverse | flex-row-reverse |
| column | flex-col |
| column-reverse | flex-col-reverse |

### Flex 줄바꿈
| CSS | Tailwind |
|-----|----------|
| nowrap | flex-nowrap |
| wrap | flex-wrap |
| wrap-reverse | flex-wrap-reverse |

### 정렬 (alignItems)
| CSS | Tailwind |
|-----|----------|
| flex-start | items-start |
| flex-end | items-end |
| center | items-center |
| baseline | items-baseline |
| stretch | items-stretch |

### 배치 (justifyContent)
| CSS | Tailwind |
|-----|----------|
| flex-start | justify-start |
| flex-end | justify-end |
| center | justify-center |
| space-between | justify-between |
| space-around | justify-around |
| space-evenly | justify-evenly |

### Grid 컬럼
| CSS | Tailwind |
|-----|----------|
| repeat(1, minmax(0, 1fr)) | grid-cols-1 |
| repeat(2, minmax(0, 1fr)) | grid-cols-2 |
| repeat(3, minmax(0, 1fr)) | grid-cols-3 |
| repeat(4, minmax(0, 1fr)) | grid-cols-4 |
| repeat(6, minmax(0, 1fr)) | grid-cols-6 |
| repeat(12, minmax(0, 1fr)) | grid-cols-12 |
| 커스텀 | grid-cols-[값] |

### Grid Span
| CSS | Tailwind |
|-----|----------|
| span 1 / span 1 | col-span-1 |
| span 2 / span 2 | col-span-2 |
| span 3 / span 3 | col-span-3 |
| 1 / -1 | col-span-full |

### 아이콘 크기
| CSS (width/height) | Tailwind |
|-----|----------|
| 12px | w-3 h-3 |
| 16px | w-4 h-4 |
| 20px | w-5 h-5 |
| 24px | w-6 h-6 |
| 32px | w-8 h-8 |
| 40px | w-10 h-10 |
| 48px | w-12 h-12 |

### 텍스트 꾸밈 (textDecoration)
| CSS | Tailwind |
|-----|----------|
| underline | underline |
| overline | overline |
| line-through | line-through |
| none | no-underline |

### 텍스트 오버플로우
| CSS | Tailwind |
|-----|----------|
| text-overflow: ellipsis + overflow: hidden + white-space: nowrap | truncate |
| overflow: hidden + -webkit-line-clamp: N | line-clamp-N |

### 오버플로우
| CSS | Tailwind |
|-----|----------|
| hidden | overflow-hidden |
| auto | overflow-auto |
| scroll | overflow-scroll |
| visible | overflow-visible |

### 보더 너비
| CSS | Tailwind |
|-----|----------|
| 0px | border-0 |
| 1px | border |
| 2px | border-2 |
| 4px | border-4 |
| 8px | border-8 |

### z-index
| CSS | Tailwind |
|-----|----------|
| 0 | z-0 |
| 10 | z-10 |
| 20 | z-20 |
| 30 | z-30 |
| 40 | z-40 |
| 50 | z-50 |

### 커스텀 스크롤바
| 스타일 | Tailwind / CSS |
|--------|----------------|
| 스크롤바 숨김 | `scrollbar-hide` 또는 `::-webkit-scrollbar { display: none }` |
| 얇은 스크롤바 | `scrollbar-thin` 또는 `scrollbar-width: thin` |
| 스크롤바 색상 | `scrollbar-thumb-gray-300 scrollbar-track-transparent` |

### 트랜지션
| CSS | Tailwind |
|-----|----------|
| 150ms | duration-150 |
| 200ms | duration-200 |
| 300ms | duration-300 |
| 500ms | duration-500 |
| ease | ease-[cubic-bezier(0.25,0.1,0.25,1)] |
| ease-in | ease-in |
| ease-out | ease-out |
| ease-in-out | ease-in-out |
| linear | ease-linear |

### 간격 (padding/margin/gap)
| CSS | Tailwind |
|-----|----------|
| 0px | 0 |
| 4px | 1 |
| 8px | 2 |
| 12px | 3 |
| 16px | 4 |
| 20px | 5 |
| 24px | 6 |
| 32px | 8 |
| 40px | 10 |
| 48px | 12 |
| 64px | 16 |
| 96px | 24 |

### 보더 라운딩
| CSS | Tailwind |
|-----|----------|
| 0px | rounded-none |
| 2px | rounded-sm |
| 6px | rounded-md |
| 8px | rounded-lg |
| 12px | rounded-xl |
| 16px | rounded-2xl |
| 9999px | rounded-full |

### 색상 (gray 스케일 기준)
| CSS (oklch 근사) | Tailwind |
|-----------------|----------|
| oklch(0.985 0 0) | gray-50 |
| oklch(0.97 0 0) | gray-100 |
| oklch(0.922 0 0) | gray-200 |
| oklch(0.870 0 0) | gray-300 |
| oklch(0.707 0 0) | gray-400 |
| oklch(0.556 0 0) | gray-500 |
| oklch(0.439 0 0) | gray-600 |
| oklch(0.371 0 0) | gray-700 |
| oklch(0.269 0 0) | gray-800 |
| oklch(0.205 0 0) | gray-900 |
| oklch(0.145 0 0) | gray-950 |

### 비율 (aspectRatio)
| CSS | Tailwind |
|-----|----------|
| auto | aspect-auto |
| 1 / 1 | aspect-square |
| 16 / 9 | aspect-video |
| 4 / 3 | aspect-[4/3] |

### 이미지 맞춤 (objectFit)
| CSS | Tailwind |
|-----|----------|
| contain | object-contain |
| cover | object-cover |
| fill | object-fill |
| none | object-none |
| scale-down | object-scale-down |

### 이미지 위치 (objectPosition)
| CSS | Tailwind |
|-----|----------|
| 50% 50% (center) | object-center |
| 50% 0% (top) | object-top |
| 50% 100% (bottom) | object-bottom |
| 0% 50% (left) | object-left |
| 100% 50% (right) | object-right |

### 최대 너비 (maxWidth)
| CSS | Tailwind |
|-----|----------|
| 320px | max-w-xs |
| 384px | max-w-sm |
| 448px | max-w-md |
| 512px | max-w-lg |
| 576px | max-w-xl |
| 672px | max-w-2xl |
| 768px | max-w-3xl |
| 896px | max-w-4xl |
| 1024px | max-w-5xl |
| 1152px | max-w-6xl |
| 1280px | max-w-7xl |
| 100% | max-w-full |
| none | max-w-none |

### 최소 높이 (minHeight)
| CSS | Tailwind |
|-----|----------|
| 0px | min-h-0 |
| 100% | min-h-full |
| 100vh | min-h-screen |
| 100dvh | min-h-dvh |

### 블렌드 모드 (mixBlendMode)
| CSS | Tailwind |
|-----|----------|
| multiply | mix-blend-multiply |
| screen | mix-blend-screen |
| overlay | mix-blend-overlay |
| darken | mix-blend-darken |
| lighten | mix-blend-lighten |
| color-dodge | mix-blend-color-dodge |
| difference | mix-blend-difference |
| exclusion | mix-blend-exclusion |

### 필터 (filter)
| CSS | Tailwind |
|-----|----------|
| blur(0px) | blur-none |
| blur(4px) | blur-sm |
| blur(8px) | blur |
| blur(12px) | blur-md |
| blur(16px) | blur-lg |
| blur(24px) | blur-xl |
| grayscale(1) | grayscale |
| invert(1) | invert |
| sepia(1) | sepia |
| brightness(0.5) | brightness-50 |
| brightness(0.75) | brightness-75 |
| brightness(1.5) | brightness-150 |
| contrast(0.5) | contrast-50 |
| contrast(1.5) | contrast-150 |
| saturate(0.5) | saturate-50 |
| saturate(1.5) | saturate-150 |

### 배경 필터 (backdropFilter)
| CSS | Tailwind |
|-----|----------|
| blur(4px) | backdrop-blur-sm |
| blur(8px) | backdrop-blur |
| blur(12px) | backdrop-blur-md |
| blur(16px) | backdrop-blur-lg |
| blur(24px) | backdrop-blur-xl |
| blur(40px) | backdrop-blur-2xl |
| blur(64px) | backdrop-blur-3xl |

### 트랜스폼 원점 (transformOrigin)
| CSS | Tailwind |
|-----|----------|
| center | origin-center |
| top | origin-top |
| top right | origin-top-right |
| right | origin-right |
| bottom right | origin-bottom-right |
| bottom | origin-bottom |
| bottom left | origin-bottom-left |
| left | origin-left |
| top left | origin-top-left |

### 가시성 (visibility)
| CSS | Tailwind |
|-----|----------|
| visible | visible |
| hidden | invisible |
| collapse | collapse |

### 포인터 이벤트 (pointerEvents)
| CSS | Tailwind |
|-----|----------|
| none | pointer-events-none |
| auto | pointer-events-auto |

### 텍스트 선택 (userSelect)
| CSS | Tailwind |
|-----|----------|
| none | select-none |
| text | select-text |
| all | select-all |
| auto | select-auto |

### 리사이즈 (resize)
| CSS | Tailwind |
|-----|----------|
| both | resize |
| horizontal | resize-x |
| vertical | resize-y |
| none | resize-none |

### 스크롤 동작 (scrollBehavior)
| CSS | Tailwind |
|-----|----------|
| smooth | scroll-smooth |
| auto | scroll-auto |

### 스크롤 스냅
| CSS | Tailwind |
|-----|----------|
| scroll-snap-type: x mandatory | snap-x snap-mandatory |
| scroll-snap-type: y mandatory | snap-y snap-mandatory |
| scroll-snap-type: both mandatory | snap-both snap-mandatory |
| scroll-snap-align: start | snap-start |
| scroll-snap-align: end | snap-end |
| scroll-snap-align: center | snap-center |

### 외형 (appearance)
| CSS | Tailwind |
|-----|----------|
| none | appearance-none |
| auto | appearance-auto |

### 리스트 스타일 (listStyleType)
| CSS | Tailwind |
|-----|----------|
| disc | list-disc |
| decimal | list-decimal |
| none | list-none |

### 컬럼 (columns)
| CSS | Tailwind |
|-----|----------|
| 1 | columns-1 |
| 2 | columns-2 |
| 3 | columns-3 |
| 4 | columns-4 |

### 격리 (isolation)
| CSS | Tailwind |
|-----|----------|
| isolate | isolate |
| auto | isolation-auto |

### 박스 그림자 (boxShadow)
| CSS 패턴 | Tailwind |
|----------|----------|
| none | shadow-none |
| 0 1px 2px 0 rgba(0,0,0,0.05) | shadow-sm |
| 0 1px 3px 0 rgba(0,0,0,0.1) | shadow |
| 0 4px 6px -1px rgba(0,0,0,0.1) | shadow-md |
| 0 10px 15px -3px rgba(0,0,0,0.1) | shadow-lg |
| 0 20px 25px -5px rgba(0,0,0,0.1) | shadow-xl |
| 0 25px 50px -12px rgba(0,0,0,0.25) | shadow-2xl |

### 커서 (cursor)
| CSS | Tailwind |
|-----|----------|
| pointer | cursor-pointer |
| default | cursor-default |
| wait | cursor-wait |
| text | cursor-text |
| move | cursor-move |
| not-allowed | cursor-not-allowed |
| grab | cursor-grab |
| grabbing | cursor-grabbing |

### 불투명도 (opacity)
| CSS | Tailwind |
|-----|----------|
| 0 | opacity-0 |
| 0.05 | opacity-5 |
| 0.1 | opacity-10 |
| 0.25 | opacity-25 |
| 0.5 | opacity-50 |
| 0.75 | opacity-75 |
| 1 | opacity-100 |

### 수직 정렬 (verticalAlign)
| CSS | Tailwind |
|-----|----------|
| baseline | align-baseline |
| top | align-top |
| middle | align-middle |
| bottom | align-bottom |
| text-top | align-text-top |
| text-bottom | align-text-bottom |

### 강조 색상 (accentColor)
| CSS | Tailwind |
|-----|----------|
| auto | accent-auto |
| (색상값) | accent-{color} (커스텀) |

### 캐럿 색상 (caretColor)
| CSS | Tailwind |
|-----|----------|
| auto | caret-auto |
| (색상값) | caret-{color} (커스텀) |

### 최소 너비 (minWidth)
| CSS | Tailwind |
|-----|----------|
| 0px | min-w-0 |
| 100% | min-w-full |
| min-content | min-w-min |
| max-content | min-w-max |
| fit-content | min-w-fit |
