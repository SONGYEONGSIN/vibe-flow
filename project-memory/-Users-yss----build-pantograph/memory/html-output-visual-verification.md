---
name: html-output-visual-verification
description: 생성한 HTML·PDF 를 화면으로 확인하는 법 — 브라우저 확장은 막혔지만 헤드리스 스크린샷은 된다
metadata: 
  node_type: memory
  type: project
  originSessionId: 525af7e5-2cde-4b87-be74-796546b2ccc9
  modified: 2026-08-14T05:45:44.678Z
---

2026-08-14 확인. 결과물이 HTML 이라 **눈으로 보는 검증**이 계속 필요한데, 경로가 갈린다.

**되는 것 — 헤드리스 크롬**

```bash
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
"$CHROME" --headless --disable-gpu --screenshot=out.png --window-size=1000,1250 "file:///…/x.html"
"$CHROME" --headless --disable-gpu --no-pdf-header-footer --print-to-pdf=out.pdf "file:///…/x.html"
```

찍은 PNG 를 Read 로 열면 실제로 보인다. **이 경로로 실제 결함을 여러 번 잡았다** — 다크모드 오버라이드가 남아 흰 배경 요청이 안 먹은 것, 슬라이드 표가 넘치는지 여부 등.

PDF 페이지 수 세기: `len(re.findall(rb'/Type\s*/Page[^s]', pdf_bytes))`

**안 되는 것 — 브라우저 확장(claude-in-chrome)**

`navigate` 에 `file://` 은 거부되고, `python3 -m http.server` 로 띄운 `http://localhost` 도 screenshot 이 `Frame with ID 0 is showing error page` 로 실패한다. 탭을 새로 만들어도, `127.0.0.1` 로 바꿔도, ASCII 파일명으로 바꿔도 같다. `curl -I` 는 200 이므로 서버가 아니라 확장 쪽 문제다. **세 번 시도했으면 그만두고 헤드리스로 간다.**

**주의 — vmin 기반 디자인은 창 비율에 민감하다**

덱 CSS 가 `vmin` 을 쓰면 세로로 긴 창(예: 1400×2400)에서 글자가 과대하게 렌더된다. 실제 시청 비율(`--window-size=1440,900`)로 찍어야 진짜 모습이 나온다. 스크롤 모드 덱은 슬라이드가 세로로 쌓이므로, 특정 슬라이드를 보려면 그 슬라이드만 단독 파일로 뽑아 찍는다.

**슬라이드 단독 추출 시 정규식 주의**: `<div class="snap">.*?</div></div>` 는 중첩 div 에서 일찍 끊긴다. div 깊이를 세어 잘라야 한다 — 이걸 안 해서 "슬라이드에 내용이 빠졌다"고 오진할 뻔했다.

관련: [[word-fixture-generation]] (Word 자동화가 멈추면 화면을 못 본다 — 그건 여전히 사람이 필요하다)
