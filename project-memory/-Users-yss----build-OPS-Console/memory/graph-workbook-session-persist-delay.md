---
name: graph-workbook-session-persist-delay
description: Graph 워크북 세션 쓰기는 파일 반영까지 1~2분 걸린다 — PATCH 직후 재조회로 성공/실패를 판정하면 오진한다
metadata: 
  node_type: memory
  type: project
  originSessionId: ec85b534-6819-4191-82d9-815a5d99874c
  modified: 2026-08-14T07:46:08.555Z
---

Microsoft Graph Excel(`workbook/createSession` + range PATCH)로 SharePoint 엑셀에 쓰면
**세션 안에서는 즉시 보이지만 실제 파일에 반영되기까지 1~2분 걸린다.** `persistChanges: true`여도 그렇다.

**Why**: 2026-08-14 공문관리대장 디버깅에서 이걸 몰라 두 번 오진했다.
PATCH 200 직후 세션 밖에서 읽어 비어 있는 것을 보고 "파일이 잠겨 저장이 안 된다"고 결론냈으나,
실제로는 이미 성공한 쓰기가 아직 flush되지 않은 것이었다. 사용자에게 엑셀을 닫게 하는 헛수고까지 했다.
(같은 라운드에서 내 확인용 probe가 A·B열을 덮었다 지워 복구된 행을 다시 깨뜨리기도 했다 —
운영 파일에 테스트 쓰기를 하지 말 것.)

**How to apply**:
- **PATCH 직후 세션 밖 재조회로 성공/실패를 판정하지 마라.** 무효한 계기다.
- 검증이 필요하면 세션을 닫고 **40초 이상 대기 후** 재조회하거나, `/versions`의 크기 변화로 본다.
- 코드에서 "실제 저장됐는지"를 확인하는 로직은 만들 수 없다 — 감지 가능한 건 `updateSenderRowLink`처럼
  **대상 행이 없는 경우**까지다. 나중에 유실되는 경우는 잡을 방법이 없다.
- 사용자가 "발송했는데 대장이 비었다"고 하면 먼저 **1~2분 뒤 다시 보라**고 안내한다.

사용처: `lib/microsoft/workbook-session.ts` (공문관리대장 [[incident-report-form-viewer]], 미수채권 K/J열 PATCH 공용).
