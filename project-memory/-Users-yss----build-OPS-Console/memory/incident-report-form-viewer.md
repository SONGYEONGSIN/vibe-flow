---
name: incident-report-form-viewer
description: 경위서 전용 편집 워크스페이스 기능 — 진행 브랜치/구조/남은 작업
metadata: 
  node_type: memory
  type: project
  originSessionId: 15dfa71d-856b-42bd-ae4b-749e69f7bd3a
---

경위서(incident report)를 실제 Word 공문 양식 그대로 화면에서 보고 편집하는 기능.

- **상태**: **main에 머지 완료**(2026-06 기준 prod 라이브). 미머지 아님.
- **라우트**: `/dashboard/incident-reports/[id]` — 메인 큰 Word 뷰어(공문 1면 + 경위서 2면, ◀ 1/2 ▶ 페이지 넘기기) + 우측 편집 패널. 진입: 사고보고 인스펙터 경위서 탭 "양식으로 보기".
- **핵심 단일 소스**: `src/features/incident-reports/form-content.ts` `deriveFormModel` — HTML 미리보기(`.../list-variants/incident-reports/FormPage.tsx`)와 PDF(`src/lib/pdf/incident-report-pdf.tsx`)가 공유. 양식 디테일 바꿀 땐 이 셋을 같이 본다.
- **로고**: `public/brand/jinhakapply-logo-v2.png`(HTML) / `.jpg`(PDF). @react-pdf가 그 PNG를 검은박스로 디코딩 → PDF는 JPEG 사용. 라벨 제외 크롭은 sharp로.
- **직인**: `public/brand/incident-report-seal.png` (.doc에서 carve 추출). 글자 뒤(겹침).
- **시행번호 발번 흐름 (2026-06-08 변경, PR #431)**: `운영{YY}{MM}-{DD}{순번2}`. **발번 = PDF 버튼 클릭 시점**(approved+미발번 1회, 멱등). 액션 `issueIncidentReportDocNumber(id)`. draft/대기/반려는 `previewNextDocNumber` 미리보기만.
  - `registerIncidentReportToSharePoint` → **분리**: `assignDocNumber`(채번+공문관리대장 행기록, **F열 빈칸**) / `uploadAndLinkReportFile`(docx 렌더+업로드+F링크 채움). `gongmun-ledger.updateSenderRowLink`(기존 행 F PATCH) 신규.
  - **파일 업로드는 발송(send) 시점** — 본인 MS 위임 계정 우선(`getDelegatedGraphToken`), 없으면 서비스 계정. 업로드 후 대장 F열 링크 채움.
  - PDF 버튼 = `PdfButton`(client) — 발번 액션 먼저 → PDF 새 탭.
- **SharePoint env (운영 Vercel 반영 완료)**: `sharePointConfig()` 3종 필요 — `SHAREPOINT_DRIVE_ID` + `SHAREPOINT_GONGMUN_ITEM_ID`(=DOCUMENTS와 동일, 공문관리대장.xlsx) + `SHAREPOINT_INCIDENT_REPORT_FOLDER_ID`(=`/06. 경위서` 폴더 `01TGOQVTXYXPVN6FVGH5F37SY2CMWMROXN`). **셋 다 Vercel prod + .env.local 설정 완료**. 하나라도 없으면 발번/대장/업로드 전부 no-op.
- **승인 동결 snapshot에 title 포함**(PR #430) — 과거 title 누락 버그 수정됨.
- **결재라인**: `approver_role`/`director_role`/`ceo_role` 컬럼에 실제 직책 스냅샷(마이그 적용 완료). 담당자=고정라벨, 작성자가 팀장이면 담당자 칸 생략.
- **승인 취소**: `revokeApproval` (approved→draft, 승인자/admin). "승인 완료" 칩(`?report=approved`).
- **3.처리**: `handling_rows jsonb`(마이그 적용) 시간/내용 2열 표 + 행 편집기.
- **검증 방법**: PDF는 임시 vitest로 `renderIncidentReportPdf` → /tmp 파일 → Read(PDF)로 시각 확인(poppler 없음, 텍스트+이미지 추출됨).

**주의**: dev 서버 재시작해야 시행번호 미리보기 동작. operators role enum에 이사/부사장 없음(필요시 추가). 운영 검증 권장: 승인된 경위서 PDF 클릭 → 공문관리대장 새 행+PDF 번호 → 재클릭 번호 동일 → 발송 시 F링크.
