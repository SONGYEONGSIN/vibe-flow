# 접근성 Audit (P4, 정적 소스 기반)

> WCAG AA 기준. **브라우저 불필요** — 소스(.tsx/.jsx/.css/.html)만 읽는 정적 audit이라
> Playwright가 없어도 실행된다(런타임 접근성 트리 검사와 상보적).
> **좋은 접근성 = 좋은 디자인.** 대비/시맨틱/포커스는 모두에게 이롭다.
> 출처: Trystan-SA/claude-design-system-prompt `accessibility-audit.md` (MIT) — 고정 스택에 맞춰 각색.

## 스택 전제 (오탐 감소)

Next.js + Tailwind v4 + shadcn/ui 고정. shadcn 프리미티브(Dialog/Button/Input 등)는
`aria-*`·`:focus-visible`·Escape 처리를 이미 내장한다. **shadcn 프리미티브를 그대로 쓴 부분은
통과로 간주**하고, 커스텀 `<div onClick>`·수동 색상·수동 포커스 처리만 지적한다.

## Phase 1: 대상 식별

방금 편집했거나 사용자가 지목한 화면; 없으면 이번 세션에서 수정된 화면; 불명확하면 질문.
파일을 끝까지 읽고 프레임워크·목표 레벨(기본 WCAG AA)·사용자 제약을 기록한다.

## Phase 2: 4개 에이전트 병렬 리뷰

`Agent` 도구로 4개를 **한 메시지에서 동시** 디스패치(각자 파일 전문을 받는다).
지시: 경계·저심각도 포함 **모든** 이슈를 confidence·severity 추정과 함께 보고.
커버리지가 에이전트의 일이고, 필터링은 Phase 3 집계에서 한다.

### Agent 1 — 대비/색상

1. **텍스트 대비**: 본문(<18px) 4.5:1, 큰 텍스트(18px+ bold 또는 24px+) 3:1, UI 요소(버튼/아이콘/포커스링) 3:1. 해석 가능한 색쌍은 실제 비율 계산 후 미달 쌍을 비율·최소치와 함께 지적.
2. **색상 단독 신호**: 색으로만 전달되는 상태(아이콘 없는 green/red, 밑줄 없는 링크, 범례 없는 차트) 지적.
3. **어려운 조합**: red+green(가장 흔한 색각), 명도 유사한 blue+yellow, 흰 배경 위 연회색, 유사 명도의 유색 텍스트/유색 배경.
4. **흰색/검정 톤**: 순수 `#FFFFFF`/`#000000` 지적, 미세 토닝(`#FAFAFA`/`#1A1A1A`) 권장. WCAG 아닌 스타일 권고 — **브랜드 토큰이 순수값을 명시하면 양보**(`references/anti-slop-preflight.md` 브랜드 우선).

### Agent 2 — 시맨틱 HTML/구조

1. **헤딩 위계**: `<h1>` 정확히 1개, 레벨 건너뜀 금지, 헤딩은 시각 크기가 아닌 내용을 기술.
2. **역할에 맞는 요소**: `<div onClick>`이 아닌 `<button>`, 스타일된 `<div>`가 아닌 `<a href>`, `<label htmlFor>`로 input 연결, `<nav>`/`<main>`/`<article>`/`<section>`/`<aside>` 랜드마크.
3. **의미 있는 이미지 alt**: 장식 이미지 `alt=""`, 의미 이미지는 전달 내용 기술(`alt="무선 헤드폰 측면"` — `alt="product"` 아님).
4. **폼 라벨**: 모든 input에 `<label>`(또는 `aria-label`). placeholder 단독은 라벨 아님.
5. **ARIA는 시맨틱 HTML로 안 될 때만**: `<button>`이면 될 자리의 `role="button"` on `<div>` 지적.

### Agent 3 — 키보드/포커스

1. **키보드 도달성**: 클릭 가능한 모든 것이 Tab 도달 가능. hover 전용 메뉴, 마우스 전용 드롭다운, 키보드 갇힌 모달은 실패.
2. **논리적 tab 순서**: 읽기 순서 준수, `tabindex > 0` 지적.
3. **인터랙션 패턴**: 모달 Escape 닫힘, 드롭다운 Enter/Space 열림·화살표 이동, 폼 필드에서 Enter 제출.
4. **가시 포커스 링**: 3:1 대비 대체 없는 `outline: none` 지적. `:focus`보다 `:focus-visible` 선호.
5. **스킵 링크**: 반복 내비가 많은 페이지에 "본문 바로가기" 권장.

### Agent 4 — 모션/폼/기타

1. **`prefers-reduced-motion` 존중**: 수백 ms 넘는 애니메이션은 `@media (prefers-reduced-motion: reduce)`로 단축/제거.
2. **깜빡임 금지**: 초당 3회 초과(광과민성 발작 위험) 지적·정지 컨트롤 요구.
3. **폼 에러**: 구체적("이메일 형식이 올바르지 않습니다" — "오류" 아님), 필드에 시각·`aria-describedby`로 연결.
4. **필수 필드**: 텍스트/아이콘 + `required` 속성으로 표시(색상 단독 금지).
5. **input type·autocomplete**: `type="email"`/`type="tel"`, autofill·모바일 키보드용 `autocomplete`.
6. **터치 타겟**: 터치 표면에서 최소 44×44px.

## Phase 3: 집계·수정

4개 에이전트 완료를 기다려 중복 제거 후 단일 리스트로 집계, 각 이슈를 직접 수정.
경계 케이스(예: 대비 4.4:1)도 적용 — 접근성은 바닥선이지 천장이 아니다.
명백한 오탐·범위 밖(수정 불가한 서드파티 임베드 등)은 사유 기록 후 skip.

**출력**: `{category, severity, confidence, status, detail}` 리스트를 카테고리별
(대비/시맨틱/키보드/모션-폼) 집계. 수정한 이슈, 사용자에게 남긴 항목 요약.
Gate C 리뷰 입력으로 전달. **skip은 `status:skipped`로 기록(≠pass)** — 도구 부재·오탐 skip을
성공으로 오기록 금지(`references/pipeline.md` P4 원칙).
