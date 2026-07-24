---
name: receivables-milestone-gap-wontfix
description: 학교담당자 미수 자동화의 마일스톤 놓침 문제는 고치지 않고 수동 발송으로 대응한다 (2026-07-09 결정)
metadata: 
  node_type: memory
  type: project
  originSessionId: 62f8d3c0-f1f7-4e03-aedf-92ca0674b57b
---

`receivables-mail-school` 자동화는 경과일수가 `SCHOOL_TARGET_DAYS`(10·15·20·25…)에 **정확히 일치**하는 행만 발송한다(`school-mail-grouping.ts`). 마일스톤 당일 10시 스냅샷에 조건이 안 맞거나 마일스톤이 주말·공휴일이면 그 회차는 catch-up 없이 영구히 건너뛴다(`mail-schedule.ts`의 `canSendOn` — "보정 없음").

2026-07-09 사용자 결정: **이 구멍은 고치지 않는다.** 놓친 건은 수동 발송으로 대응한다.

**Why:** 수동 발송은 `경과 >= MAIL_REMINDER_THRESHOLD_DAYS`(기본 10일) 규칙이라 놓친 건을 언제든 커버할 수 있다. 자동화 규칙을 임계값 방식으로 바꾸면 발송 빈도가 올라가는 부작용이 있다.

**How to apply:** 미수채권 자동화 미발송 사례를 발견해도 임계값 전환·영업일 이월 보정을 먼저 제안하지 말 것. 원인만 보고하고, 대응은 수동 발송을 안내한다. 사용자가 명시적으로 요청할 때만 구조 변경에 착수한다.

관련: [[ops-console-dev-workflow]]
