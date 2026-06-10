---
name: smileedi-automation
description: SmileEDI 세금계산서 자동화(스크래핑+조건부 메일) 이식 상태 + 운영 잔여 작업
metadata: 
  node_type: memory
  type: project
  originSessionId: dfd926da-c463-45e5-9e83-49ed1a4fb0f3
---

SmileEDI 세금계산서 파이프라인을 OPS-Console 자동화로 이식 (2026-06-07 완료, main 머지).

**코드 (머지 완료)**
- Phase 1 (#415): `smileedi-mail` 잡 — SharePoint 시트 read → 2조건 필터(이메일오류≠Y + 품목키워드, README의 4조건은 부정확이라 폐기) → 담당자 그룹핑 → Graph 본인 메일박스 발송 → 이메일오류='Y' PATCH → 이력 `smileedi_mail_sends`. `src/features/smileedi/`.
- Phase 2 (#416): `scripts/smileedi/tax_invoice.py`(시크릿 제거본) + `.github/workflows/smileedi-scrape.yml`. 스크래핑+업로드만(SKIP_MAIL=true), 메일은 Phase 1이 담당.
- 설계 문서: `.claude/plans/20260607-smileedi-automation-port.md`. DB 마이그 적용·검증 완료. 라이브 dry-run 검증 완료(99행 read 정상).
- dry-run 플래그는 전용 `SMILEEDI_DRY_RUN`(전역 MAIL_DRY_RUN 아님).
- **검색기간**: 회계연도 4/01~익년3/31 KST 동적(매년 +1). **발신**: 본인 메일박스(`SMILEEDI_SENDER_EMAIL`).
- **SharePoint item id 주의**: Python의 FIXED_FILE_ID는 stale. 실제 = `01TGOQVTUBJJEX7THCLBDLF265MTH2W6BX` (drive = `b!UDIYC522...`).

**운영 상태 (2026-06-07 풀 파이프라인 dry-run 검증 완료)**
- ✅ cron-job.org 잡 등록(평일 10:00 KST → workflow_dispatch, GitHub PAT Actions:write)
- ✅ GitHub Actions Secrets 전부 등록(SMILEEDI_USERNAME/PASSWORD/EXCEL_PASSWORD + SHAREPOINT_TENANT/CLIENT/SECRET/SITE/SMILEEDI_DRIVE_ID). 스크래퍼 인증 client_credentials 전환(#418) — **Q2 해결**(업로드 성공 확인).
- ✅ Vercel production env 8개 등록 + 재배포(ops-console-psi.vercel.app). preview는 cron 무관해 생략.
- ✅ 대시보드 토글 ON (`automation_settings.enabled=true` for smileedi-mail, DB upsert).
- ✅ 스크래퍼 workflow 성공(로그인→스크래핑→복호→SharePoint 업로드, 1m29s). 메일 잡 production dry-run 성공(109행→sendable 14→4 담당자, dryRun 4, 실발송 0).

**유일한 GO-LIVE 잔여**: `SMILEEDI_DRY_RUN`을 Vercel production에서 `true`→`false` 변경 + 재배포 → 실발송 시작. (현재 dry-run이라 실메일 안 나감)

**시트 업데이트 방식 (PR #442, 2026-06-08 — append 전환)**: `tax_invoice.py`가 '역발행 세금계산서.xlsx'를 **전체 파일 PUT(/content) → 신규행만 Excel workbook range API로 append**로 변경.
- 이유: 전체 PUT은 누가 엑셀을 **열어두면 HTTP 423 resourceLocked**로 실패 → 스크래퍼가 비치명(`[WARN]`)으로 넘겨 **데이터 조용히 누락**(워크플로는 "성공"). 실제로 6/8 이 잠금 때문에 19건 중 17 신규가 안 들어가던 것 확인·해결.
- 신규 `append_new_rows_via_workbook`(createSession persistChanges → usedRange 마지막행 → range PATCH append → closeSession). `smart_update_existing_file` 1줄 reroute.
- 중복판정 `compare_excel_files_with_dataframe`: existing_keys = **전체 기존행**(append는 드롭 없으므로 #441 Y-only 특례 흡수).
- **의미 변화**: append-only라 취소·삭제된 건은 시트에서 자동 제거 안 됨(수동 관리). 사용자 승인.
- **검증**: 라이브 통합 — 1행 삭제→스크래퍼 1회→재append, 113행·기간19건·중복0 확인. 잠금 시에도 동작(전체교체 아님).
- **텍스트 서식 수정 (PR #443)**: range PATCH가 긴 숫자형 ID(일련번호 20자리 등)를 Double로 강제변환→지수표기(2.2E+19)·정밀도손실. 값 기록 전에 `numberFormat='@'`(텍스트)를 먼저 PATCH해 기존 데이터(전부 String)와 동일 서식으로 적재. 검증: 일련번호 20자리 전체 보존·type String 확인.
- **운영 주의 잔존**: 스크래퍼가 append 실패해도 워크플로는 여전히 "성공" 표시 가능(비치명 처리) — 누락 가시화하려면 추가 개선 필요.

**권장(미완)**: 노출됐던 비번(SMILEEDI 로그인/Excel) 로테이션 — 현재 유출 기존값 사용 중, .env.local+GH Secrets에 보관.
- 구 delegated 헬퍼(generate_auth_url 등) 미사용 잔존 — 후속 정리 가능.

[[db-migration-apply]]
