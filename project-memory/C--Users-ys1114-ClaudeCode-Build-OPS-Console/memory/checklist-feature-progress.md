---
name: checklist-feature-progress
description: "원서접수점검 체크리스트 — Plan 1·2·3 머지 + UI폴리시/AI보고리포트(#904 진행중). 메뉴명 '원서접수점검'"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1d49f8cc-9d93-47c1-bba1-5961f11b999a
  modified: 2026-07-23T09:22:34.508Z
---

**원서접수 점검 체크리스트** — 회차별 부서 협업 점검 문서를 OPS-Console 기능으로 구현 (SharePoint 엑셀 `General/원서접수 점검사항 체크리스트.xlsx` 협업 대체, **엑셀 미연동 — 구조 참고용만**). 3단계 분할.

문서: 스펙 `docs/superpowers/specs/2026-07-22-checklist-design.md` · Plan1 `docs/superpowers/plans/2026-07-22-checklist-plan1-foundation.md`.

**설계 핵심**:
- 부서(기획파트·운영부·고객지원팀·개발부·영업부 5고정) → 분야 → 항목 → 상태(done/in_progress/todo/na)+메모. 완료율 = done/(전체−na).
- 부서는 **로그인 없이 추측불가 토큰 링크**로 작성 (`/r/checklist/[token]`, kind=dept-fill 쓰기 / report 읽기). 관리(회차생성·항목편집·토큰발급)는 **admin 전용**.
- 기존 운영리포트(reports) 골격 이식. 상태=칩+메모(엑셀 자유텍스트 구조화).

**Plan 1 완료 (2026-07-22, PR #894 머지)** — Subagent-Driven 실행:
- DB 3테이블(`checklist_rounds`/`checklist_items`/`checklist_share_tokens`) Supabase 적용됨. `src/features/checklist/`(schemas·completion·template·queries·actions), `/dashboard/checklist` 목록·상세 관리 UI. 메뉴 admin 전용(ADMIN_ONLY_MENU_SLUGS + adminOnly:true). 184 테스트·tsc0·lint0. opus 리뷰 반영 완료.

**Plan 2 완료 (2026-07-23)**: 공개 `/r/checklist/[token]` 부서 작성 폼 + 토큰 스코프 자동저장(#896). `fill-actions.ts`/`fill-scope.ts` 신규. proxy PUBLIC_PATHS `/r` 커버.
**Plan 3 완료 (2026-07-23)**: `checklist-pdf.tsx` + `/api/checklist/[id]/pdf`로 A4 PDF 저장(#897).
**추가 리팩터 (2026-07-23)**: 회차 목록 카드→표준 테이블(#898), 라벨 '모집시기' 통일(#900), 메뉴/제목 '원서접수점검'(#901), **공유 링크 통합 재설계 — 작성 1 + 확인 1, 전 부서 작성 폼(#902)**, 작성폼 이미지 붙여넣기 첨부(#903). 신규 마이그레이션 `20260723_checklist_unified_share.sql`·`20260723b_checklist_attachments.sql` (Supabase 적용 여부 확인 필요).
→ #902에서 **부서별 토큰이 아닌 통합 작성 링크(전 부서 한 폼)로 재설계**됨 — Plan 1의 부서별 dept-fill 토큰 모델은 이걸로 대체됨. 재개 시 최신 `fill-actions.ts`/`page.tsx` 확인 우선.

**UI 폴리시 + AI 보고리포트 (2026-07-23, PR #904 머지 완료 = main `f652968`)**:
- **메모 리치에디터 표 보존**: `note-html.ts` sanitizer를 "전부 이스케이프 → 화이트리스트 태그만 선별 복원"으로 확장 (표/목록/제목/기본서식 허용, td/th는 colspan/rowspan 숫자만, 위험속성 전부 제거 → mXSS·속성주입 불가). 작성폼·확인폼·관리자 메모 렌더에 표/목록 CSS. 붙여넣은 HTML 표가 저장 후에도 유지됨.
- **보고리포트: PDF 완전 폐기·삭제 → AI 임원 보고형(개조식) HTML**. '보고리포트' 버튼(빨강) → `/dashboard/checklist/[id]/report`. 작성된 전체 내용을 `claude -p`가 **부서별 개조식**(최상위 항목 + 하위 `분류 : 내용` 불릿 + 표)으로 정리 → sanitize 후 `checklist_rounds.report_html`/`report_generated_at`(마이그 `20260723c` **적용됨**) 저장 → 어디서나 렌더. 생성=로컬 CLI 패턴(execFileSync stdin·도구차단·tmpdir·timeout 300s, team-briefing/mailbox 동일). **Vercel 프로덕션은 생성 불가(조회는 OK)**. `report-prompt.ts`(빌더·파서, few-shot 개조식 예시)+`report-actions.ts`(생성)+`ReportDocument.tsx`(문서렌더+생성/재생성, 개조식 CSS `–`/`·`). **end-to-end 실측 성공**(실회차 34항목 129s, 사용자 예시 구조 정확 재현). claude -p 소요 ~130s(변동 있음).
- **PDF 삭제 완료**: `/api/checklist/[id]/pdf` route + `lib/pdf/checklist-pdf.tsx`(+test) 제거(HTML 보고리포트로 대체). 다른 도메인 PDF(incident/meeting/quote/report)는 유지.
- **이미지 멀티모달 판독**: 메모 첨부 이미지를 임시파일로 내려받아 프롬프트에 경로 참조 → `claude -p`가 Read로 이미지(표·수치) 읽어 반영(이미지 자체는 출력 안 함). timeout 360s. 실측: 매출 스크린샷의 진학사/유웨이 수치 반영 성공.
- **임원 공유 링크**: 공개 `/r/checklist/[token]` report 토큰이 `round.reportHtml` 있으면 AI 보고리포트를 로그인 없이 렌더(없으면 ReportView 폴백). 렌더 본문은 공용 `src/components/checklist/ReportBody.tsx`(관리자 ReportDocument·공개 라우트 공용, REPORT_CLASS+h3 SVG 구분자). '보고용 링크' 버튼이 곧 임원 공유 링크.
- **UI 디테일**: h3 카테고리 앞 vermilion SVG 삼각형 구분자 + 밝은 그레이 배경밴드(bg-line-soft), 표 w-full 통일(넓은 표 가로 오버플로우 클리핑 해소), extractReportHtml이 claude 프리앰블("Here is the report:") 제거.

**(해소됨) Plan 1 리뷰 이관 이슈**: 빈 회차 dead-end·상태해제·삭제확인 등은 Plan 2/리팩터에서 처리된 것으로 보임 — 최신 코드 확인 요.

**빌드 교훈 (Plan 1 CI에서 잡힘)**: `"use server"` 파일(actions.ts)은 **모든 export가 async 서버액션이어야 함**. 순수 동기 헬퍼(`buildSeedItems`)를 export하면 tsc·vitest·eslint는 통과하지만 **Turbopack 프로덕션 빌드만 "Server Actions must be async functions"로 실패**. 해결: 헬퍼를 별 모듈(`seed.ts`)로 분리. **Plan 2 `fill-actions.ts`에도 동일 적용** — 순수 헬퍼는 actions 파일 밖에 둘 것.

연계: [[supabase-migration-apply-before-merge]] (직접 PG 6543 차단 → 대시보드 적용) · [[ops-console-dev-workflow]]
