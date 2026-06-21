---
name: meetings-html-form-migration
description: 회의록을 BlockNote→운영팀 HTML 양식으로 전면 전환하는 6단계 작업 진행상황
metadata: 
  node_type: memory
  type: project
  originSessionId: 86163e16-5b15-41f6-b6a1-a31619f412ea
---

회의록(meetings) 기능을 BlockNote 에디터 → **운영팀 HTML 양식 통째 채택**으로 전환. 대공사(planner 설계).

**확정 결정**:
- 방식: HTML(vanilla JS)을 **React 컴포넌트로 포팅**(임베드 기각). CSS 13KB는 도입하되 색만 앱톤 매핑.
- 데이터: `meetings.content`(jsonb) 재사용 + `formVersion:2` 구조화 스키마. **DB 마이그레이션 없음**.
- 기존 데이터 1건뿐(field, draft, 미발송=테스트) → **폐기, 레거시 v1 경로 불필요**.
- 색: **앱톤(cream/ink/vermilion/washi)으로 매핑** (원본 navy #0f2647 안 씀). status 4색 토큰 매핑.
- 타입 매핑: HTML kickoff→project / oneonone→memo / incident→urgent (DB enum 유지).
- 원본: `docs/meeting-templates.html` (TYPES 데이터 + 6 렌더함수). 5개 동일 파일.

**섹션 종류**: ledger(station+Q&A thread)/table(idx·status옵션)/kv/notes/list/banner.
**상태배지 4종**: talk(진행중)/done(완료)/follow(후속필요)/hold(보류).

**6단계 PR 계획**:
1. ✅ **#646** 데이터 모델 — `form-model.ts`(MeetingDoc zod+isMeetingDoc), `form-templates.ts`(buildSeedDoc). 순수추가.
2. ✅ **#647** 읽기전용 렌더러 — `MeetingFormDoc.tsx` + `meeting-form.css`(.meeting-form 스코프, 색 앱톤매핑). 라우트 미연결.
3. ✅ **#648** PDF v2 — meeting-pdf.tsx에 isMeetingDoc 분기 + renderMeetingFormPdf(섹션 react-pdf flex). 메일 자동호환.
4. ✅ **#649** 양식 에디터 `MeetingForm.tsx`(비제어 contentEditable blur커밋 + 섹션 편집/추가/상태토글, 불변 onChange). 라우트 미연결.
5. ✅ **#650** 편집화면 통합 — createMeeting/save v2, MeetingEditorWorkspace=MeetingForm 단일뷰(masthead 메타편집+자동저장), 인스펙터 View v2분기, ListRow.meetingContent unknown.
6. ✅ **#651** 레거시 정리 — MeetingEditor·MeetingDocument·meeting-editor.css·templates.ts 삭제 + @blocknote 의존성 제거. pdf-model/pdf-numbering은 v1폴백(기존 1건)용 보존.

**★ 마이그레이션 6/6 완료 (PR #646~#651).** 회의록은 이제 v2 HTML 양식(MeetingForm 에디터 + MeetingFormDoc 읽기 + form-pdf). 신규 회의록=v2. 기존 v1 1건은 편집불가 안내 + v1 PDF/View 폴백 유지.
남은 정리(선택): 그 v1 1건 삭제 시 pdf-model/pdf-numbering/v1폴백 완전 제거 가능.

**현 SSOT**: `pdf-model.ts`의 blocksToPdfModel → PdfNode → 4소비처(MeetingDocument/View/meeting-pdf). v2는 이 추상화 대체/병존.
**기존 BlockNote 흐름 파일**: MeetingEditor.tsx, MeetingDocument.tsx, meeting-editor.css, templates.ts, pdf-model.ts, pdf-numbering.ts, meeting-pdf.tsx.

관련: [[standard-list-inspector-design]].
