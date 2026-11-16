---
name: pantograph-entity-limitation
description: "Pantograph 의 I4a 가 지금 초록인 이유는 우연이며, 어떤 픽스처를 넣으면 정당하게 깨지는지"
metadata: 
  node_type: memory
  type: project
  originSessionId: 6dbd8e7a-e22e-4c50-99a0-b95482a61797
  modified: 2026-08-07T17:20:06.786Z
---

Pantograph 의 문자 참조 인코딩 왕복 한계(스펙 §13)는 **해결된 게 아니라 아직 발동하지 않았다.**
2026-08-08 머지(`9509495`) 시점 기준.

`tmpl.Values` 는 디코딩된 텍스트를 읽고 `patch.setText` 는 `&`, `<`, `>` 만 재이스케이프한다.
`testdata/real/form-*.docx` 의 `비고` 필드에 `&` 를 일부러 넣었고 그게 가변 키 `k3` 인데도
I4a 가 통과했다 — Word 가 `&amp;` 로 쓰고 재인코더도 `&amp;` 를 내서 **양쪽이 우연히 일치**했기 때문이다.

**깨뜨리려면**: 원본이 같은 문자를 다른(동등한) 인코딩으로 쓴 문서가 필요하다 —
숫자 문자 참조 `&#38;`, 또는 `&quot;` / `&apos;`. Word 는 이렇게 쓰지 않지만
다른 생산자(LibreOffice, 문서 생성 라이브러리, 손편집 XML)는 쓸 수 있다.
그런 픽스처가 들어오면 I4a 가 **정당하게** 실패한다 — 그건 결함 보고가 아니라 설계가 예고한 지점이다.

지금의 초록불이 이 항목을 덮어주지 않는다는 점을 누구에게든 먼저 말할 것.

관련: [[word-fixture-generation]]
