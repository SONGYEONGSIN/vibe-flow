# Memory Index

- [NODE_ENV=development가 셸에 전역 설정됨](node-env-development-in-shell.md) — Next.js 프로덕션 빌드 깨짐, 빌드 시 NODE_ENV=production 강제 필요
- [개발서버는 무조건 포트 3200](dev-server-port-3200.md) — app/package.json dev 스크립트가 `next dev -p 3200`으로 고정됨
- [매일 03:00 KST 자동 진화 루틴](daily-evolve-routine.md) — 클라우드 루틴이 backlog 타깃으로 1라운드 돌고 PR 생성. **루틴은 검증 실패를 무시하고 PR을 만든다** (CI + 브랜치 보호가 게이트), 열린 `evolve/*` PR 방치 = 다음 라운드 스킵
