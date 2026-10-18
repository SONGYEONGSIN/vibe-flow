---
name: mail-cc-exclusion
description: 이이화(llh@jinhak.com) 계정은 팀 기반 자동 메일 CC에 절대 포함 금지 — operators.mail_cc_excluded 플래그로 관리
metadata: 
  node_type: memory
  type: project
  originSessionId: f21eb5b8-45d5-4143-9c0c-fd9cf17cdde8
---

이이화 계정(llh@jinhak.com, 운영1팀, active)은 **어떤 메일에도 참조(CC)로 들어가면 안 된다** (사용자 요구, 2026-07-13). 계정 자체는 active·운영1팀 소속을 유지해야 함.

- 구현: `operators.mail_cc_excluded boolean` 컬럼 (PR #852) + 백업요청 `fetchCcOperators`에 `.eq("mail_cc_excluded", false)` 필터. 조직권한 인스펙터에서 토글 가능.
- 운영 DB에 마이그 적용 + 이이화 플래그 true 설정 완료 (2026-07-13).
- 참고: 이이화 계정은 2개 — llh@jinhak.com(active, 제외 플래그 on) / llh@jinhakapply.com(deleted).

**Why:** 팀 기반 자동 CC는 현재 백업요청 메일뿐이지만, 새로 팀 단위 자동 메일 기능을 만들면 이 플래그를 반드시 존중해야 함.
**How to apply:** 운영자에게 자동 메일/CC를 보내는 신규 기능 구현 시 `mail_cc_excluded=true` 운영자를 제외하는 필터를 포함할 것.
