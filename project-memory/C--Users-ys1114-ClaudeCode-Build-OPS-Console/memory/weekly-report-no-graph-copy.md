---
name: weekly-report-no-graph-copy
description: 본부차주보고(weekly-report-rollover) 시트복제 실패 — Graph Excel에 worksheet copy API 없음
metadata: 
  node_type: memory
  type: project
  originSessionId: fbde5872-232f-48f3-992e-704c796d6e5e
---

본부차주보고 자동화(`src/features/automations/jobs/weekly-report/`)가 2026-06-17 cron 실행에서 `copy sheet 400: "Resource not found for the segment 'copy'"`로 실패했다.

**근본 원인**: `graph-ops.ts`의 `copyWorksheet`가 존재하지 않는 Graph 엔드포인트 `POST .../workbook/worksheets/{name}/copy`를 호출. context7 공식 문서 확인 결과 workbookWorksheet는 list/add/get/update/delete만 지원하고 **copy 액션이 없다**. 원본 `docs/buseobogo.py:962`는 Graph가 아니라 openpyxl로 셀 단위 복제(서식/병합/행높이)를 했는데 포팅 시 없는 API로 잘못 치환됨.

**왜 06-10엔 통과**: `newSheet === sourceSheet`면 copy 분기를 skip(index.ts:116) → 버그 잠복. 실제 복제가 필요한 주에 표면화.

**리스크**: ① copyItemAndWait(파일복제)는 먼저 성공 → 차주 파일이 빈 껍데기로 SharePoint에 남으면 멱등 가드(index.ts:81 siblings에 nextName 존재 시 skip)때문에 재실행해도 skip. 수정 시 고아 파일 정리 필요. ② 실패가 weekly_report_runs엔 기록 안 됨(예외가 record 분기를 안 거침), automation_runs에만 남음.

**해결(검증 완료)**: PR #546(머지·배포 2026-06-17) — graph-ops에서 없는 Graph 호출 제거 + downloadItemContent/uploadItemContent 추가, sheet-rollover.ts 신설(exceljs로 시트 서식 복제 + B2/B3/C3 갱신), index 단계5를 다운로드→롤오버→재업로드로 교체. exceljs 의존성 추가. typecheck 0 + 41 tests. **프로덕션 end-to-end 검증 완료** — 고아 파일(`..._6월3주차.xlsx`) 사용자 수동 삭제 후, 자동화 메뉴(`/dashboard/automations`) 수동 실행 → 06-17 11:57 ok=true(14.2s), 6월3주차.xlsx 생성·시트 복제·Teams 발송(teams_sent=true) 성공.

**후속 (2026-07-14, PR #866)**: 복제된 파일을 열면 이전 주차 시트가 기본 선택돼 잘못 작성하는 문제 수정 — sheet-rollover가 복제 후 새 시트에만 `tabSelected` 부여 + 워크북 `activeTab=0` 기록. exceljs는 `tabSelected`/`activeTab` **쓰기는 지원하지만 파싱에서 tabSelected를 버림**(sheet-view-xform parseClose) → 재로드 검증 불가, 테스트는 jszip으로 xlsx 내부 XML 직접 단언.

**Why:** 외부 API 가정 오류 — 포팅 시 원본 라이브러리(openpyxl) 동작을 Graph 동등 API가 있다고 가정.
**How to apply:** 프로덕션 cron 수정은 [[supabase-migration-apply-before-merge]] 정신으로 배포 후 실제 Graph 검증 필수. exceljs는 worksheet 깊은 복제 단일 API가 없어 셀/스타일/병합/치수 수동 복사 + orderNo/tabSelected는 d.ts 누락이라 좁은 타입 shim 사용.
