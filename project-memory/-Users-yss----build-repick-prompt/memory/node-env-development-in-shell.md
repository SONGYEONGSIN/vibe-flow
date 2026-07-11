---
name: node-env-development-in-shell
description: 사용자 셸에 NODE_ENV=development가 전역 설정돼 있어 Next.js 프로덕션 빌드가 깨진다
metadata: 
  node_type: memory
  type: project
  originSessionId: 88f68ba8-271d-4a66-a558-aa4dea912a88
---

사용자의 zsh 환경에 `NODE_ENV=development`가 전역으로 export 되어 있다 (2026-07-12 확인).

**증상**: `next build`가 `/_global-error` 프리렌더에서 `Cannot read properties of null (reading 'useContext')`로 실패하고, 프로덕션 빌드인데 dev 전용 React key 경고가 출력된다. 로그 첫 줄에 "non-standard NODE_ENV" 경고가 뜬다.

**Why:** NODE_ENV=development 상태로 프로덕션 빌드를 하면 dev/prod React 빌드가 섞여 hook dispatcher가 깨진다.

**How to apply:** Next.js(또는 다른 Node 도구) 빌드가 이유 없이 깨지면 `echo $NODE_ENV`부터 확인. 빌드는 `NODE_ENV=production npm run build`로 실행하거나, package.json build 스크립트에 `NODE_ENV=production`을 명시한다 (repick-prompt에는 적용해 둠).
