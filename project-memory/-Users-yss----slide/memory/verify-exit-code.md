---
name: verify-exit-code
description: "slide 레포 검증 — npm test는 \"N passed\"여도 Unhandled Rejection이면 exit 1. 통과 줄만 grep하지 말 것"
metadata:
  node_type: memory
  type: feedback
  originSessionId: b93db18f-8d8f-4238-ab03-9d8d2dc50701
  modified: 2026-10-25T06:30:45.085Z
---

`npm test`(vitest)는 테스트가 전부 통과해도 처리되지 않은 오류(Unhandled Rejection)가 있으면 `Errors N errors`를 찍고 exit 1로 끝난다. 2026-10-25 Codex UI r8에서 이 때문에 "1,784건 통과"라고 보고한 커밋이 실제로는 실패였던 것이 드러났다(모의 콜백이 `Promise<boolean>` 계약을 안 지킴).

**Why:** 통과 건수 줄만 grep해서 종료 코드와 `Unhandled`/`Errors` 줄을 놓쳤다. Codex 리뷰 기준은 "전체 테스트 exit 0".

**How to apply:** 검증할 때 `cmd > log 2>&1; echo "exit $?"` 형태로 종료 코드를 같이 보고, `grep -E "Test Files|Tests |Errors|Unhandled"`로 확인한다. 전체 unit과 e2e를 동시에 돌리지 않는다(e2e 임시 덱이 덱 목록 보존 검사와 간섭). 관련: [[reply-in-korean]]
