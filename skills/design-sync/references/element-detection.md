# 요소 감지 레퍼런스

## 8개 요소 카테고리

| # | 카테고리 | 대상 요소 |
|---|---------|----------|
| 1 | **레이아웃** | `aside`, `header`, `main`, `nav`, 사이드바 전체 |
| 2 | **헤딩** | `h1`~`h6` — 페이지 제목, 카드 제목, 섹션 제목 |
| 3 | **텍스트/문단** | `p`, `span`, `label`, `li`, `a` — 부제, 설명, 배지, 링크 |
| 4 | **카드/컨테이너** | `div`(border/bg/rounded), `section` — stat card, 카드 래퍼 |
| 5 | **폼** | `input`, `select`, `button`, `textarea` — 검색, 필터, 액션 버튼 |
| 6 | **검색/필터/드롭다운** | 검색 컨테이너(relative wrapper + 아이콘), 필터 바/칩, 커스텀 드롭다운 패널/아이템 |
| 7 | **테이블** | `table`, `thead`, `tbody`, `tr`, `th`, `td` — 행·셀 단위 |
| 8 | **아이콘** | `svg`, `img[src*=".svg"]`, Lucide/Heroicons 컴포넌트 — 크기, 색상, strokeWidth |

## 컴포넌트 타입 감지 시그널

| 신호 | 타입 |
|------|------|
| `svg`, `img[src*=".svg"]` | icon |
| `table`, `thead`, `th`, `td` | table |
| `input[type="search"]`, `input` + 부모 `relative` + 형제 `svg` | search |
| `div`/`ul` + `position:absolute` + `z-index≥10` + `boxShadow` + 내부 아이템 목록 | dropdown |
| `div`/`span` + `inline-flex` + `rounded-full`/`rounded-md` + bgColor + 작은 크기 | chip/filter |
| `div` + `display:flex` + `gap` + 내부 `button`/`select` 다수 | filter-bar |
| `input`, `select`, `textarea` | form |
| `button` | button |
| `h1`~`h6` | heading |
| `nav` | navigation |
| `div`/`section` + border + bg + radius | card |
| `span`/`div` + inline + bgColor | badge |
| 그 외 `p`, `span`, `a`, `label` | text |

## 검색/필터/드롭다운 상세 감지

### 검색 컨테이너

```
감지 조건:
1. div[position:relative] 내부에 input + svg(아이콘)이 있는 구조
2. input[type="search"] 또는 input[placeholder*="검색"|"Search"|"찾기"]
3. 아이콘이 absolute로 input 좌/우측에 배치

추출 대상:
- 컨테이너: position, width, border, borderRadius, bgColor
- 인풋: padding(아이콘 공간 확보용 pl-10 등), fontSize, placeholder
- 아이콘: position(absolute), top/left, width/height, color
- focus 상태: borderColor, ring/outline, boxShadow 변화
- ::placeholder: color, fontSize, opacity
```

### 필터 바 / 필터 칩

```
감지 조건:
1. div[display:flex][gap] + 내부에 button/select 2개 이상 → filter-bar
2. span/div[inline-flex][rounded-full] + 작은 padding + bgColor → chip
3. button[bgColor≠transparent] + 작은 크기 → active filter

추출 대상:
- 필터 바: display, flexDirection, flexWrap, gap, alignItems, padding
- 필터 칩(비활성): bgColor, color, border, borderRadius, padding, fontSize
- 필터 칩(활성): bgColor(진한), color(흰/다른색), fontWeight, border 변화
- 필터 카운트 뱃지: bgColor, color, borderRadius(full), fontSize, minWidth
- 필터 구분선: borderRight/borderLeft, height, margin
```

### 커스텀 드롭다운

```
감지 조건:
1. div/ul[position:absolute][z-index≥10] + boxShadow + border → dropdown panel
2. 내부 li/div/a 반복 요소 → dropdown items
3. 트리거: button/div + 셰브론 아이콘(svg rotate)

추출 대상:
- 트리거 버튼: border, borderRadius, padding, bgColor, fontSize, gap(텍스트↔아이콘)
- 셰브론 아이콘: width/height, transform(rotate), transition
- 패널: position(absolute), top/left/right, width(min-w), maxHeight, overflow-y
         bgColor, border, borderRadius, boxShadow, zIndex, padding(py)
- 아이템: padding(px, py), fontSize, color, cursor
          hover: bgColor, color 변화
          active/selected: bgColor, fontWeight, 체크 아이콘 유무
- 구분선: border-t/divide-y, margin(my)
- 그룹 헤더: fontSize(작음), fontWeight(semibold), color(muted), padding, textTransform
- 열림 트랜지션: opacity, transform(scale), transition-duration
```

## 영역 자동 분류

레이아웃 랜드마크(sidebar, header)를 먼저 감지하고, 각 요소의 좌표로 영역을 분류:

```
x < sidebarRight                    → sidebar
y < headerBottom && x ≥ sidebarRight → header
그 외                                → content
```

랜드마크 감지: `position:fixed` + 좌측 200~280px 너비 → sidebar, 상단 40~80px 높이 → header

## 인터랙션 상태 캡처

| 상태 | 대상 요소 | 캡처 방법 |
|------|----------|----------|
| **hover** | 메뉴 아이템, 버튼, 테이블 행, 카드, 링크, 드롭다운 아이템 | `element.hover()` → 스크린샷 |
| **active** | 현재 선택된 메뉴, 활성 탭, 활성 필터 칩 | 네비게이션 클릭 후 스크린샷 |
| **focus** | 검색 인풋, 입력 필드, 셀렉트 | `element.focus()` → 스크린샷 |
| **open** | 드롭다운 메뉴, 셀렉트 박스, 콤보박스 | 트리거 `click()` → 패널 스크린샷 |

### 추출 속성

- hover 시: `backgroundColor`, `color`, `borderColor`, `boxShadow`, `transform`, `opacity` 변화
- active 시: 인디케이터 스타일 (좌측 바, 배경색, 폰트 굵기)
- focus 시: `outline`, `ring`, `borderColor`, `boxShadow` 변화
- open 시: 드롭다운 패널 전체 스타일

### 검색/필터/드롭다운 전용 인터랙션

| 컴포넌트 | 상태 | 캡처 속성 |
|----------|------|----------|
| **검색 인풋** | focus | `borderColor`, `boxShadow`(ring), `outline`, `outlineOffset`, 아이콘 `color` 변화 |
| **검색 인풋** | ::placeholder | `color`, `opacity`, `fontSize` (기본 vs focus 시 변화) |
| **필터 칩** | inactive | `bgColor`, `color`, `border`, `fontWeight` |
| **필터 칩** | active/selected | `bgColor`(진함), `color`(변경), `fontWeight`(볼드), `border` 변화 |
| **필터 칩** | hover | `bgColor`, `borderColor` 변화 |
| **드롭다운 트리거** | closed | `border`, `bgColor`, `padding`, 셰브론 `transform`(rotate 0) |
| **드롭다운 트리거** | open | `border` 변화, 셰브론 `transform`(rotate 180deg) |
| **드롭다운 패널** | open | `position`, `top/bottom`, `width`, `maxHeight`, `overflowY`, `bgColor`, `border`, `borderRadius`, `boxShadow`, `zIndex`, `padding` |
| **드롭다운 아이템** | default | `padding`, `fontSize`, `color`, `bgColor`, `cursor` |
| **드롭다운 아이템** | hover | `bgColor`, `color` 변화 |
| **드롭다운 아이템** | selected | `bgColor`, `fontWeight`, 체크 아이콘 유무, `color` |
| **드롭다운 구분선** | — | `borderTop`/`borderBottom`, `margin` |
| **드롭다운 그룹헤더** | — | `fontSize`(작음), `fontWeight`, `color`(muted), `padding`, `textTransform` |
