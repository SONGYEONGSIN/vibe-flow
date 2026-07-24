---
name: dev-server-port-3200
description: 이 프로젝트 개발서버는 무조건 포트 3200으로 실행
metadata: 
  node_type: memory
  type: feedback
  originSessionId: be26ecb5-1edb-4370-a3f7-d575813676dd
---

repick-prompt 개발서버(Next.js, `app/`)는 항상 포트 3200으로 실행한다. `app/package.json`의 dev 스크립트가 `next dev -p 3200`으로 고정돼 있음 (2026-07-12 적용).

**Why:** 사용자가 "개발서버는 무조건 3200으로 실행해줘"라고 지시함.

**How to apply:** `npm run dev` (app/ 디렉토리)를 그대로 쓰면 3200으로 뜬다. 임시로 다른 방식으로 띄우더라도 `-p 3200` 또는 `PORT=3200`을 유지할 것. 서버 접속 URL은 http://localhost:3200. 프로덕션 빌드 시엔 [[node-env-development-in-shell]] 참고.
