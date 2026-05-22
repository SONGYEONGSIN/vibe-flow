---
name: services-import-mjs-service-id
description: "[CLOSED 2026-05-15 PR #107] import 스크립트가 CSV 원본 service_id를 그대로 upsert해 마이그레이션 재부여 효과 사라짐 위험. 옵션 A 채택 — Folio가 source-of-truth, 스크립트 DEPRECATED. 정책 결정 절차의 historical 기록"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8a18890a-c371-4590-bb5c-6cf1f23166ac
---

## 발견 시점

2026-05-15. services 도메인 service_id 재부여 마이그레이션(`20260522_services_service_id_renumber.sql`) 적용 후. 학교키(앞 4자리) 유지 + 학교별 write_start_at asc로 시퀀스 001부터 재부여.

## 위험

`scripts/services-import.mjs` 코드:

```js
service_id: Number(r["service_id"] ?? 0),
```

CSV의 `service_id` 컬럼을 그대로 사용. `upsert({ onConflict: 'service_id' })`로 동일 service_id row 갱신. 즉:

- 마이그레이션으로 재부여된 새 service_id 1002001~1002007 (가천대학교(대학원))
- 재import 시 CSV 원본 100266 / 1002005 등으로 `INSERT` 또는 `UPDATE`
- 결과: 재부여 효과 사라지고 원본 service_id 일부 row가 *새로 생기거나* 옛 값으로 *덮어쓰여짐*

## How to apply

### 채택 — 옵션 A: 재import 안 함 (2026-05-15 결정, PR #107)

Folio DB가 services source-of-truth. Sheets는 더 이상 Folio와 동기 안 함. 신규 services row는 `/dashboard/services` UI로 등록. `scripts/services-import.mjs` 헤더에 DEPRECATED 표기 + 본 정책 명시. 스크립트 자체는 historical 기록으로 보존 (재실행 X).

### 기각된 대안

- **옵션 B (재부여 CSV export 후 import)**: 운영부 Sheets 동기 메리트가 없어 의미 약함
- **옵션 C (--ignore-service-id 모드)**: 스크립트 수정 + 자연키 onConflict 도입 — 복잡도 vs 가치 비효율

## 관련

- [[project_next_session_seed]] — 다음 세션 시드에 SharePoint 계약 epic + 대학 연락처 epic 함께 명시
