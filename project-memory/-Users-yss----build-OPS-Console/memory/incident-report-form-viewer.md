---
name: incident-report-form-viewer
description: 경위서 전용 편집 워크스페이스 기능 — 진행 브랜치/구조/남은 작업
metadata: 
  node_type: memory
  type: project
  originSessionId: 15dfa71d-856b-42bd-ae4b-749e69f7bd3a
---

경위서(incident report)를 실제 Word 공문 양식 그대로 화면에서 보고 편집하는 기능.

- **브랜치**: `feat/incident-report-form-viewer` (main +37 커밋, 미머지). 작업 재개 시 이 브랜치로.
- **라우트**: `/dashboard/incident-reports/[id]` — 메인 큰 Word 뷰어(공문 1면 + 경위서 2면, ◀ 1/2 ▶ 페이지 넘기기) + 우측 편집 패널. 진입: 사고보고 인스펙터 경위서 탭 "양식으로 보기".
- **핵심 단일 소스**: `src/features/incident-reports/form-content.ts` `deriveFormModel` — HTML 미리보기(`.../list-variants/incident-reports/FormPage.tsx`)와 PDF(`src/lib/pdf/incident-report-pdf.tsx`)가 공유. 양식 디테일 바꿀 땐 이 셋을 같이 본다.
- **로고**: `public/brand/jinhakapply-logo-v2.png`(HTML) / `.jpg`(PDF). @react-pdf가 그 PNG를 검은박스로 디코딩 → PDF는 JPEG 사용. 라벨 제외 크롭은 sharp로.
- **직인**: `public/brand/incident-report-seal.png` (.doc에서 carve 추출). 글자 뒤(겹침).
- **시행번호**: `운영{YY}{MM}-{DD}{순번2}` — SharePoint 공문관리대장 `(발신){연도}년` 시트에서 채번(`gongmun-ledger.ts`). 발송 시 확정, **작성 시엔 미리보기만**(B 방식, `previewNextDocNumber`). env `SHAREPOINT_GONGMUN_ITEM_ID`=`SHAREPOINT_DOCUMENTS_ITEM_ID`와 동일 값(공문관리대장.xlsx). **운영(Vercel)에도 이 env 추가 필요** — 현재 `.env.local`(로컬)만.
- **결재라인**: `approver_role`/`director_role`/`ceo_role` 컬럼에 실제 직책 스냅샷(마이그 적용 완료). 담당자=고정라벨, 작성자가 팀장이면 담당자 칸 생략.
- **승인 취소**: `revokeApproval` (approved→draft, 승인자/admin). "승인 완료" 칩(`?report=approved`).
- **3.처리**: `handling_rows jsonb`(마이그 적용) 시간/내용 2열 표 + 행 편집기.
- **검증 방법**: PDF는 임시 vitest로 `renderIncidentReportPdf` → /tmp 파일 → Read(PDF)로 시각 확인(poppler 없음, 텍스트+이미지 추출됨).

**남은 작업/주의**: 운영 env에 GONGMUN id 추가, dev 서버 재시작해야 시행번호 미리보기 동작. operators role enum에 이사/부사장 없음(필요시 추가). 미머지 — 마무리 시 `/finish`.
