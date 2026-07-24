---
name: dev-control-manual-run
description: "개발탭 수동 분석(웹→PC 폴러) 배포 완료 — 회사 PC 폴러 등록·라이브 e2e 잔여, 원서GEN은 회사망 외부에서 TCP 차단"
metadata: 
  node_type: memory
  type: project
  originSessionId: f36d7cf4-c643-43d5-b578-895e5c934acb
---

개발탭 '지금 분석'(웹→PC 폴러) 기능 — **PR #873 머지·프로덕션 배포 완료** (2026-07-15, main `79d0e53`). 설계/플랜: `docs/superpowers/specs·plans/2026-07-15-dev-control-manual-run*`.

**잔여 운영 단계 (회사 PC)**:
1. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev-control/register-poll-task.ps1 -Unattended` 1회 실행 (태스크 `OPS-Console-DevControl-Poll`, 5분 간격)
2. 라이브 e2e: 개발탭 '지금 분석' 클릭 → `schtasks /Run /TN OPS-Console-DevControl-Poll` → 배지 running→done + 분석 갱신 확인
3. 첫 재요청 대상: service 1130058 — 2026-07-15 자택 맥 검증 시도에서 failed로 남겨둠 (메시지에 사유 기록)

**Why:** 원서GEN(`generator.jinhakapply.com`)은 **회사망 외부(자택 맥)에서 TCP 연결 자체가 차단**(connect timeout) — 자격·코드 문제 아님. 분석 실행은 회사 PC에서만 가능하다는 것이 실측 확인됨 (버튼→적재→claim→실패보고 등 나머지 파이프라인은 자택에서 전부 검증 완료).

**How to apply:** 자택/Vercel에서 `dev-control-analyze.mjs` 실행 시도 금지 — 무조건 회사 PC 폴러 경로 사용. 같은 제약이 [[closing-automation]](Moa 스크래핑)에도 적용됨.
