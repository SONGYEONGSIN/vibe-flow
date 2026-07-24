---
name: dev-server-oom-jest-worker
description: "회사 PC 메모리 압박(16GB, 가용 1~2GB)으로 Next dev 'Jest worker' 에러 반복 — 재시작 절차와 회피 수칙"
metadata: 
  node_type: memory
  type: project
  originSessionId: aaf4daf8-61a0-4fe6-b932-f91c6d930bbb
---

회사 PC(16GB)에서 Next 16 Turbopack dev 서버가 "Jest worker encountered 2 child process exceptions" 런타임 에러를 반복한다 (2026-07 3회). 원인은 코드가 아니라 **가용 메모리 1~2GB 상태에서 워커 자식 프로세스 OOM**. dev 서버 + claude 세션들 + 5분 폴러/08:30 cron(claude -p) + 브라우저가 경합.

**복구 절차**: 포트 3000 PID 확인(netstat) → taskkill //F → `npm run dev` 재시작. 강제 종료 후 **동적 라우트([id]류)만 전부 404**가 나면 `.next` 캐시 파손 — `rm -rf .next` 후 재시작 (2026-07-16 실측: 정적 200/동적 404 패턴이 진단 신호).

**Why:** 강제 종료가 잦으면 Turbopack 캐시 파손까지 겹쳐 2차 장애(동적 라우트 404)가 됨.
**How to apply:** ① dev 서버 떠 있는 동안 전체 vitest 스위트 실행 금지 — 대상 스위트만 돌리거나 `--maxWorkers=2` 캡 ② "Jest worker" 에러 보고받으면 코드 원인 찾기 전에 가용 메모리부터 확인 ③ 404 증상은 [[dev-server-oom-jest-worker]] 복구 절차의 캐시 삭제로. 관련: [[dev-control-analysis-pipeline]] (claude -p 프로세스가 메모리 스파이크 유발)
