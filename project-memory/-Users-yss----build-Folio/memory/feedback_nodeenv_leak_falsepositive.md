---
name: ""
metadata: 
  node_type: memory
  originSessionId: 25b0a44e-fed8-45b1-a59e-84141e808fce
---

메모리에 "main에서도 발생, 배포 시 문제 가능" 같은 백로그 주장을 만나면 **CI 실제 상태부터 검증**한 뒤 작업 진입한다.

**Why**: 2026-05-12 세션에서 "/_global-error Next.js 16 빌드 실패" 항목이 백로그에 있어 hotfix 시도. 4단계 디버깅 후 NODE_ENV=development shell leak 시에만 재현되는 false positive 확인. CI 빌드는 항상 통과중이었음 (PR #74 이후 모든 PR CI SUCCESS). 매몰비용 회피 + 메모리 정정으로 종료.

**How to apply**:
- 빌드 실패 류 백로그 진입 전: 최근 main CI 상태 확인 (`gh run list --branch main --limit 3`). 모두 SUCCESS면 로컬 환경 문제 우선 의심
- 로컬 빌드 실패 시 `env | grep NODE_ENV` 확인. unset 또는 production 아니면 leak. `unset NODE_ENV` 후 재시도
- 4단계 디버깅 권장: webpack vs Turbopack / --debug-prerender / env 변수 / 산출물 추적
- 비싼 우회 코드 작성 전에 위 셋업 확인. 본 케이스는 우회로 시도(custom global-error)했으나 그 자체가 UX 가치라 유지. 다음엔 진단 먼저
