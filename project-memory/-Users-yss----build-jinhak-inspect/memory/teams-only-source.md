---
name: teams-only-source
description: jinhak-inspect 대학 자료·산출물은 팀즈(SharePoint)에서만 다룬다 — 코드의 C:\...\Desktop 로컬 경로는 안 쓴다
metadata:
  node_type: memory
  type: feedback
  originSessionId: 9600f213-331a-4475-a0e6-b9e79fbb803b
  modified: 2026-10-04T23:32:03.434Z
---

대학 자료(요강 PDF·전산자료·수시1차 산출 CSV)는 팀즈 `운영부/검수용 파일/<유형>/<학교>/<학년도 전형>/` 에서 받는다. 코드에 박힌 `C:\Users\ys1114\Desktop\조선대_2027수시_추출` 같은 로컬 경로는 더 이상 쓰지 않는다(2026-10-05 사용자: "로컬 경로는 이제 필요 없어. 팀즈 경로만 하고 있어").

**Why:** 파일이 없다고 할 때 사용자가 "팀즈 파일 경로에 있잖아"라고 바로잡았다. 이 Mac에는 바탕화면 자료가 없다.
**How to apply:** 입력 파일이 없으면 로컬을 찾지 말고 팀즈(Graph, `teams_watch.download`)에서 받는다. 키는 저장소 옆 `OPS-Console/.env.local`. hj2 는 `hj2_src.ensure()` 로 `_teams_cache/` 에 받아 쓴다(원격 e67eaa8, 2026-10-06).
