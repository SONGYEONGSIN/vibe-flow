---
name: closing-automation
description: 서비스 마감(closing) 자동화 — Moa 스크랩 → 인제스트. 실운영 가동 중이며 2026-09-12부터 갱신+이력을 남긴다
metadata: 
  node_type: memory
  type: project
  originSessionId: d4e408f0-fbc3-4552-ad3e-5eb1ff9b999a
  modified: 2026-09-17T21:32:46.582Z
---

Moa 마감 목록을 회사 PC 폴러가 스크랩(`scripts/moa-closing/scrape.py`)해
`POST /api/closing/ingest` 로 넣는다. **평일 09:00 스케줄로 실운영 가동 중**(#841~#843, 2026-07-15 확인).

## 2026-09-12 — 갱신이 켜졌다 (#1187)

그 전까지 `ignoreDuplicates: true` 라 **한 번 적재된 `service_id` 는 값이 바뀌어도 영영 안 고쳐졌다.**
국립군산대 수시(`1035061`)가 실제로는 단독인데 `solo=false` 로 석 달째 굳어 있던 게 발단.

이제 바뀐 칸만 갱신하고 이전 값을 `closing_service_changes` 에 남긴다.
**`detected_at` 이지 `changed_at` 이 아니다** — 언제 바뀌었는지는 모르고 언제 발견했는지만 안다.

**실측 (첫 실행이 석 달치를 한꺼번에 잡았다)**:

- 933 서비스 중 **529건 / 1,135 칸**이 갱신됨 — 절반 넘게 낡아 있었다
- 이후 평일 실행은 **15 · 15 · 12건**으로 조용 → **시각 비교 오탐 없음**
  (`+09:00` vs `+00:00` 을 문자열로 비교했다면 매 실행 933행 전부가 쏟아진다)
- 군산대 `solo: false → true` 이력으로 확인. `solo` 분포 706/227 → **802/169**
- 건국대(`1008038`) `write_end_at 2027-09-11 → 2026-09-11` — CLAUDE.md 오픈안내 절이
  경고하는 "종료 연도가 1년 뒤로 적힌" 바로 그 건이 자동 교정됐다

**갱신을 켜도 됐던 근거 4가지** (다시 조사하지 말 것):
`closing_services` 에 쓰는 곳은 인제스트 하나뿐(나머지는 전부 select — 사람이 고친 값 없음) /
스크래퍼가 14칸 전부 보냄(비워질 칸 없음) / 헤더 누락은 `scrape.py:444` 가 `RuntimeError` 로 죽임 /
빈 배열은 `rows.min(1)` 이 거부.

**이력 조회 화면은 없다** — DB 직접. 첫 실행 규모는 run-log 에만 찍힌다.

## 주의

- `closing_services` 는 Moa **스크랩 미러지 원장이 아니다** — 이력 테이블에 FK 를 걸지 않는다
  (`open_notice_sends` 와 같은 이유)
- 스크랩에서 빠진 건은 **남는다**(지우지 않는다). 갱신이 켜져도 이 성질은 그대로
- 사람이 만든 `services` 테이블과는 별개 — 둘이 어긋날 수 있다

관련: [[company-pc-pending-tasks]] · [[open-notice-auto-mail]] · [[db-migration-apply]]
