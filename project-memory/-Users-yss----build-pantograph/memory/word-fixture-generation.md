---
name: word-fixture-generation
description: "이 머신에서 Word .docx 픽스처를 스크립트로 만드는 유일하게 통하는 경로와, 막혔을 때 관찰이 안 되는 이유"
metadata: 
  node_type: memory
  type: project
  originSessionId: 6dbd8e7a-e22e-4c50-99a0-b95482a61797
  modified: 2026-08-07T17:19:51.849Z
---

Pantograph 는 실제 Word 가 저장한 `.docx` 픽스처가 계속 필요하다 (스펙 §10 이 요구하고,
없으면 `*Real` 테스트가 skip 이 아니라 FAIL 한다). 2026-08-08 에 이 머신에서 확인한 것:

**통하는 경로** — Word 에게 **자기 샌드박스 컨테이너 안에** 저장시키고 복사해 온다.

```applescript
tell application "Microsoft Word"
	set d to make new document
	set content of text object of d to "줄1" & return & "줄2" & return
	save as d file name (POSIX path of (path to documents folder)) & "x.docx" file format format document
	close d saving no
end tell
```

`path to documents folder` 는 샌드박스 안에서 `~/Documents` 가 아니라
`~/Library/Containers/com.microsoft.Word/Data/Documents/` 로 리다이렉트된다. 거기서 `cp` 한다.

**주의**: 문서 여러 개를 한 osascript 안에서 연속 생성하면 두 번째부터 `-1728`
(object does not exist) 이 난다 — 파일은 저장된 뒤 `close` 에서 나므로 산출물은 온전하다.
안전하게 하려면 osascript 호출을 문서당 하나로 쪼갠다.

**막혔을 때 화면을 볼 수 없다.** 두 관찰 경로가 모두 권한 부족이다:
- System Events 로 창 조회 → `-1728` 보조 접근 미허용
- `screencapture` → `could not create image from display` (화면 기록 미허용)

그래서 Word 자동화가 멈추면 **명령을 하나씩 짧은 제한시간으로 던져 이분**하는 수밖에 없다
(`return name` → `count of documents` → `make new document` → `set content` → `save as`).
macOS 에 `timeout` 이 없으므로 백그라운드 + `kill` 패턴을 쓴다.

관련: [[pantograph-entity-limitation]]
