---
name: slide-presenter
description: |
  순수 HTML, CSS, JavaScript로 웹 기반 슬라이드 프레젠테이션을 생성하는 스킬.
  사용자의 자연어 요청, 마크다운 파일(.md), 또는 기존 PPT/PPTX 파일을 단일 HTML 슬라이드로 변환한다.
  "프레젠테이션 만들어줘", "발표자료", "슬라이드", "PPT", "slide", "presentation",
  "PPT를 웹으로 변환", "PPTX 재구성", "파워포인트를 HTML로" 등
  프레젠테이션 관련 요청이 있을 때 자동으로 트리거한다.
  마크다운 파일(.md)이나 PPT/PPTX 파일을 슬라이드로 변환해달라는 요청에도 트리거한다.
---

# Slide Presenter

순수 HTML/CSS/JS 단일 파일 프레젠테이션 생성기.
외부 라이브러리 없이 브라우저에서 바로 실행되는 슬라이드를 만든다.

## 핵심 기능

- 방향키(← →)로 슬라이드 이동
- F 키로 전체화면 토글
- 슬라이드 번호 표시 (01 / 10 형식)
- Space/↓ 키로 프래그먼트(빌드 효과) 진행
- 터치 스와이프 지원
- URL 해시 딥링크 (#slide-3)
- GPU 가속 전환 애니메이션 (fade/slide/zoom, T키로 전환)
- 화자 노트 (N키 토글)
- 프로그레스 바

## 입력 처리

### 자연어 요청
사용자가 "5장짜리 발표자료 만들어줘" 같은 요청을 하면, 주제에 맞는 콘텐츠를 구성하여 슬라이드를 생성한다.

### 마크다운 변환
사용자가 .md 파일을 지정하면:
1. 파일을 읽어 `---` 또는 `# 제목` 단위로 슬라이드를 분리
2. 각 섹션의 마크다운을 HTML로 변환
3. 리스트 항목은 프래그먼트(빌드 효과)로 자동 변환

### PPT/PPTX 재구성
사용자가 기존 PPT/PPTX 파일을 웹 프레젠테이션으로 변환해달라고 요청하면:

**텍스트 추출 방법 (우선순위):**
1. `python-pptx`가 설치되어 있으면 Python 스크립트로 텍스트/구조 추출
2. 없으면 사용자에게 PPT 내용을 텍스트로 복사해달라고 요청
3. 또는 PPT를 PDF로 내보낸 후 PDF에서 텍스트 추출

```python
# python-pptx 추출 스크립트 예시
from pptx import Presentation
import json

prs = Presentation('input.pptx')
slides = []
for slide in prs.slides:
    content = {'title': '', 'body': [], 'notes': ''}
    for shape in slide.shapes:
        if shape.has_text_frame:
            if shape.shape_id == slide.shapes.title.shape_id if slide.shapes.title else False:
                content['title'] = shape.text_frame.text
            else:
                for para in shape.text_frame.paragraphs:
                    if para.text.strip():
                        content['body'].append(para.text.strip())
    if slide.has_notes_slide:
        content['notes'] = slide.notes_slide.notes_text_frame.text
    slides.append(content)

print(json.dumps(slides, ensure_ascii=False, indent=2))
```

**변환 원칙:**
- PPT의 슬라이드 순서와 제목/본문 구조를 유지
- 원본 텍스트 콘텐츠를 최대한 보존하되, 웹에 맞게 재구성
- 이미지는 직접 변환할 수 없으므로, 이미지 설명이나 대체 텍스트로 표시
- PPT의 화자 노트가 있으면 `<aside class="speaker-notes">`로 매핑
- 표(table)는 def-grid 또는 card-grid 컴포넌트로 재구성
- 차트/그래프는 핵심 수치를 feature-list로 재구성

## 출력 형식

반드시 **단일 .html 파일**로 생성한다. CSS와 JS는 모두 인라인.
파일명: 사용자가 지정하지 않으면 `presentation.html`

## HTML 구조

이 구조를 정확히 따른다:

```html
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>프레젠테이션 제목</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&family=JetBrains+Mono:wght@400;700&family=Noto+Sans+KR:wght@400;700&display=swap" rel="stylesheet">
<style>/* 인라인 CSS */</style>
</head>
<body>
<div class="slide-frame">
  <section class="slide active">
    <div class="slide-inner">
      <!-- 콘텐츠 -->
    </div>
    <aside class="speaker-notes">화자 노트</aside>
  </section>
  <!-- 추가 슬라이드들 -->

  <!-- UI 오버레이 -->
  <div class="progress-container"><div class="progress-fill"></div></div>
  <div class="slide-counter"><span class="current-num">01</span> / <span class="total-num">10</span></div>
  <nav class="slide-controls">
    <button class="prev-btn">&#8249;</button>
    <button class="next-btn">&#8250;</button>
  </nav>
  <div id="notes-overlay"><div id="notes-content"></div></div>
</div>
<script>/* 인라인 JS */</script>
</body>
</html>
```

## CSS 디자인 시스템

사용자가 커스텀 컬러/폰트를 요청하면 CSS 변수만 교체한다.
요청이 없으면 아래 기본값을 사용한다.

```css
:root {
  /* === 사용자 커스텀 가능 영역 === */
  --bg:       #050507;       /* 배경 */
  --bg-card:  rgba(255,255,255,0.03); /* 카드/블록 배경 */
  --border:   rgba(255,255,255,0.07); /* 테두리 */
  --accent:   #C6A55C;       /* 액센트 (골드) */
  --accent-dim: rgba(198,165,92,0.15);
  --text:     #F2EDE4;       /* 본문 텍스트 */
  --text-sub: #9E9688;       /* 보조 텍스트 */
  --text-mute: #5C574E;      /* 뮤트 텍스트 */
  --code-bg:  #0A0A0E;       /* 코드 블록 배경 */
  --font-body: 'Noto Sans KR', 'Inter', sans-serif;
  --font-code: 'JetBrains Mono', 'Consolas', monospace;
}
```

### 테마 예시

사용자가 "밝은 테마", "라이트 모드" 등을 요청하면:
```css
:root {
  --bg: #FAFAF8; --bg-card: rgba(0,0,0,0.03); --border: rgba(0,0,0,0.08);
  --accent: #2563EB; --text: #1A1A1A; --text-sub: #666; --text-mute: #999;
  --code-bg: #F5F5F0;
}
```

## 슬라이드 콘텐츠 컴포넌트

슬라이드 내부에서 사용할 수 있는 컴포넌트들. 콘텐츠 성격에 맞게 조합한다.

### 1. 타이틀 슬라이드
```html
<p class="slide-label">&gt; CATEGORY</p>
<h1>메인 제목</h1>
<p>부제목 또는 설명</p>
<div class="accent-bar"></div>
<p class="hint">안내 텍스트</p>
```

### 2. 구분선 리스트 (feature-list)
항목 사이에 얇은 구분선, → 골드 화살표 마커.
프래그먼트 빌드가 필요하면 `class="fragment stagger" data-step="N" style="--i:N"` 추가.
```html
<ul class="feature-list">
  <li class="fragment stagger" data-step="0" style="--i:0">항목 1</li>
  <li class="fragment stagger" data-step="0" style="--i:1">항목 2</li>
</ul>
```

### 3. 정의 그리드 (def-grid, 2x2)
용어 + 설명 쌍을 2열로 배치. 카드 형태.
```html
<dl class="def-grid">
  <div class="def-item"><dt>용어</dt><dd>설명</dd></div>
  <div class="def-item"><dt>용어</dt><dd>설명</dd></div>
  <div class="def-item"><dt>용어</dt><dd>설명</dd></div>
  <div class="def-item"><dt>용어</dt><dd>설명</dd></div>
</dl>
```

### 4. 정보 카드 (info-card)
`//` 주석 스타일 헤더 + 설명.
```html
<div class="info-card">
  <p class="card-comment">// 카드 제목</p>
  <p>설명 텍스트</p>
</div>
```

### 5. 코드 블록 (code-block)
라인 하이라이트 지원. `data-highlight-steps`로 순차 하이라이트.
```html
<div class="code-block" data-highlight-steps='["1-2", "4-5"]'>
  <span class="code-lang">JavaScript</span>
  <div class="code-lines">
    <code class="line" data-line="1"><span class="line-num">1</span>코드 내용</code>
  </div>
</div>
```

### 6. 2컬럼 카드 (card-grid)
```html
<div class="card-grid">
  <div class="card"><h3>제목</h3><ul><li>항목</li></ul></div>
  <div class="card"><h3>제목</h3><ul><li>항목</li></ul></div>
</div>
```

## JavaScript 엔진

아래 기능을 모두 포함해야 한다. `references/engine.md`에 전체 코드가 있으니 그대로 사용한다.

### 필수 기능
- **슬라이드 이동**: ← → (슬라이드 단위), Space/↓ (프래그먼트 진행), ↑ (프래그먼트 역순)
- **전체화면**: F 키 → `document.documentElement.requestFullscreen()`
- **전환 효과**: Web Animations API, fade/slide/zoom (T키로 전환)
- **입력 잠금**: `isAnimating` 플래그 + `await animation.finished`
- **URL 해시**: `replaceState` + `popstate`/`hashchange` 리스너
- **터치 스와이프**: 50px 최소, 500ms 최대, 방향 비율 1.5x
- **프로그레스 바**: 현재 슬라이드 / 전체 비율
- **슬라이드 카운터**: `01 / 10` 형식 (padStart)
- **화자 노트**: N키 토글
- **도움말**: ? 키 토글

### 전체화면 구현
```javascript
document.addEventListener('keydown', (e) => {
  if (e.key === 'f' || e.key === 'F') {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen();
    } else {
      document.exitFullscreen();
    }
  }
});
```

## CSS 필수 규칙

자세한 CSS는 `references/styles.md`에 있다. 핵심 규칙:

1. **풀스크린**: `.slide-frame { position: fixed; inset: 0; }`
2. **슬라이드 스태킹**: `.slide { position: absolute; inset: 0; }`
3. **중앙 배치**: `.slide { display: flex; justify-content: center; align-items: center; }`
4. **콘텐츠 폭**: `.slide-inner { max-width: 680px; }`
5. **프래그먼트**: `.fragment { opacity: 0; transform: translateY(14px); transition: 0.4s; }`
6. **speaker-notes**: `.speaker-notes { display: none; }`
7. **반응형 타이포**: `clamp()` + `vmin` 사용
8. **GPU 가속**: `translate3d()` / `scale3d()` 사용, `will-change`는 애니메이션 전후에만

## 슬라이드 구성 가이드

- 첫 슬라이드는 항상 타이틀 (라벨 + 대제목 + 부제목 + 골드 바)
- 마지막 슬라이드는 요약 또는 감사 페이지
- 리스트 슬라이드는 4~6개 항목이 적당
- 코드 슬라이드는 8줄 이하로 핵심만
- 한 슬라이드에 컴포넌트 2개 이하 (정보 과밀 방지)
- 라벨은 영문 대문자 (`> ARCHITECTURE`, `FEATURES` 등)

## 체크리스트

생성 완료 전 확인:
- [ ] ← → 키로 슬라이드 이동 동작
- [ ] F 키로 전체화면 토글 동작
- [ ] 슬라이드 번호 (01 / NN) 표시
- [ ] Space 키로 프래그먼트 빌드 진행
- [ ] 터치 스와이프 동작
- [ ] 프로그레스 바 표시
- [ ] speaker-notes가 화면에 노출되지 않음
- [ ] 단일 .html 파일로 완결
