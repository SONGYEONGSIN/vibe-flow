---
name: ysong2526@gmail.com = dev/admin 계정 (운영부 멤버 아님)
description: Folio 시스템에서 사용자 본인 메일은 OPERATORS 17명 화이트리스트에 없음. 내부 메일 발송 송신자로 사용 중.
type: project
originSessionId: f1dae096-5cba-4988-9e0e-8dc18bebf09f
---
`ysong2526@gmail.com`은 사용자 송영석 본인 dev/admin 계정. Folio 시스템에서 운영부 운영자 17명(`src/features/auth/operators.ts`)에는 포함되지 않는다. 시스템 내부 메일 발송용 송신자로 활용 중.

**Why**: brainstorm 단계에서 chrome 사용자 정보 표시 설계 중 확인됨. ALLOWED_EMAILS는 운영부 가입 화이트리스트라 본인 계정은 거기 없음. signUp이 아닌 직접 supabase admin으로 추가됐거나 dev 환경 한정.

**How to apply**:
- 사용자 정보 lookup 시 OPERATORS 매칭 안 되면 fallback 처리(예: email username 또는 admin 라벨) 필수
- production OPERATORS UI 표시 = OPERATORS lookup으로 풀네임/팀/직급 표시
- dev/admin 계정 = email username 또는 "관리자" 표시
- 본인 계정으로 dashboard 진입 시 OPERATORS 통계에서 빠지더라도 정상 (17명 합계는 그대로)
