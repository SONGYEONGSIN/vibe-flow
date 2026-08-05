---
name: ratio-setting-audit
description: "경쟁률 점검 자동화(세팅+페이지) — #926~#936 머지 완료, 회사 PC 폴러 등록·마이그레이션 적용 잔여"
metadata:
  node_type: memory
  type: project
  originSessionId: ce6e5ec9-1438-43a4-b00f-d55e0d5f9258
  modified: 2026-08-04T12:08:43.583Z
---

Moa 경쟁률 설정을 점검해 담당 운영자 Teams 개인 채팅으로 알린다. PR #926(2026-08-02) ~ #936(2026-08-04) 시리즈로 머지 완료.

**두 잡으로 분리됨(#935)**: 세팅 점검(TEST 서버, 스케줄↔안내문구 대조 + `claude -p` 판정)과 페이지 점검(REAL 서버, HTML 링크 404). 같은 큐 `ratio_audit_requests`를 `kind`로 구분하고 폴러가 `RATIO_AUDIT_KIND`로 `audit.py` 동작을 고른다. 둘 다 Moa 로그인을 타므로 동시 실행 금지(pending/running 1건, kind 무관).

구조: 로컬 `scripts/moa-ratio/audit.py`가 Moa 순회 → 판정 → `/api/ratio-audit/ingest` → `ratio_audit_runs` 적재 + Teams 발송. 자동화 메뉴 버튼은 큐에 적재만 하고 회사 PC 폴러가 수행(서비스마감 패턴 복제). 설계·셀렉터·함정은 `docs/superpowers/specs/2026-08-02-moa-ratio-setting-audit-design.md` 부록 A.

**예외(#936)**: `ratio_audit_exceptions` — 합의된 정상 건을 **발송에서만** 제외(payload에는 남긴다). `(service_id, seq)` 단위, seq null이면 전 차수. 등록은 DB 직접(관리 화면 없음). 첫 등록 대상은 연세대 서울 수시 1차(service_id 1108081, seq 1) — 접수 마감 17시라 마감 후 18시 공개는 내부 수동 진행 합의.

**셋업은 전부 완료 확인(2026-08-04, DB 실조회)**:
- 마이그레이션 적용됨 — `ratio_audit_requests.kind` 컬럼·`ratio_audit_exceptions` 테이블 존재
- 연세대 예외 1건 등록됨 (service_id 1108081, seq 1)
- 회사 PC 폴러 등록됨 — 8/3 07:37Z 요청을 37초 만에 claim한 기록이 증거

**남은 건 검증 1회**: #931(cp949 fix, 8/3 08:41Z) 이후 성공 실행이 0건이다. 마지막 성공 run은 8/2 두 건(43~44건 스캔, finding 5~6, notified). 8/3 유일한 요청은 fix 직전(07:37Z)이라 cp949 traceback으로 failed. 즉 **#931·#934·#935·#936은 실행으로 검증된 적이 없다** — 특히 #935 잡 분리는 폴러가 `RATIO_AUDIT_KIND`로 `audit.py`를 고르는 구조라 회사 PC 리포가 최신 pull 상태여야 한다. 자동화 페이지 [실행] 1회면 셋 다 확인된다(성공 run 생성 / 관리자 메시지 '예외 1건 제외' 표기 / 세팅·페이지 각각 실행).

**env는 막힌 게 아니다**: `TEAMS_RATIO_AUDIT_SENDER`는 `TEAMS_BRIEFING_SENDER`로 폴백, `TEAMS_RATIO_AUDIT_ADMIN_CHAT_ID`는 `48:notes`(발신자 본인 노트 채팅) 기본값이 있어 미설정이어도 동작한다. 과거 메모의 `TEAMS_RATIO_AUDIT_CHAT_ID`는 #928(개인 채팅 발송 전환) 이후 존재하지 않는 이름.

**알아둘 것**: 페이지 점검 대상은 `StartDate ≥ 올해 9월 1일` — 수시 경쟁률이 열리는 9월부터 대상이 생긴다. LLM 판정이라 경계선 사례는 실행 간 변동이 있고, 스케줄 미설정처럼 사실 판정 가능한 항목은 LLM을 거치지 않는다.

**Why:** 머지는 됐지만 폴러·마이그레이션 없이는 실제로 동작하지 않는다 — 코드만 봐서는 알 수 없다. **How to apply:** 이 자동화가 "안 돈다"는 말이 나오면 위 2건부터 확인한다. 관련: [[db-migration-apply]], [[closing-automation]]
