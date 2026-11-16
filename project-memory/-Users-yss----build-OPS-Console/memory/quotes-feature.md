---
name: quotes-feature
description: 견적서(자료 보관 > 견적서) — Phase1 목록 + Phase2 문서양식 전부 머지·가동
metadata: 
  node_type: memory
  type: project
  originSessionId: c638331c-95e2-4cb8-8774-151ddce704b8
---

사이드바 '자료 보관 > 견적서'(slug `quotes`). **Phase 1(목록)·Phase 2(문서양식 SP1~4) 전부 머지 완료(2026-06-25)**.

**Phase 1 (PR #703, 머지)**: incidents 동형 표준 list 도메인. `quotes` 테이블(customer·quote_date·valid_until·amount·owner_email·status(draft/sent/won/lost)·note) + RLS(read 전원/insert·update admin·member·active/delete admin). `features/quotes/`(schemas·queries·actions) + list-variant `quotes/` + page + 카운트. 마이그 `20260624c/d` 적용 완료.

**Phase 2 — 견적서 문서 양식 (SP1~4, PR #704~707 머지)**:
- 저장: `quotes`에 `quote_type`(dev/fee/platform/labor) + `document`(jsonb) 컬럼(마이그 `20260625_quotes_document`, 적용 완료). 문서 = {header(머리말6필드)+발신자상수+sections+totals+terms}.
- **SP1(#704)**: document-schema(zod) + `sender.ts`(QUOTE_SENDER 진학어플라이 상수, bizNo/tel/email은 TODO 미상) + **calc 엔진**(`calc/index.ts`: sectionSubtotal·quoteTotals(공급가/VAT10%/합계)·recomputeDocument·koreanAmount) + saveQuoteDocument(서버 recompute→amount 동기화, **createClient RLS**) + 상세 에디터 `/dashboard/quotes/[id]`(meetings [id] 동형). dev/fee.
- **SP2(#705)**: 에디터 유형 선택기 + platform 섹션(기능나열 6열, multiline). 유형 변경 시 행 있으면 confirm(머리말·약관 보존).
- **SP3(#706)**: `kosa-2026.ts`(한국SW산업협회 2026 적용 17등급 일평균임금 상수) + 적산 calc(`laborRollup`: 제경비=직접×1.1, 기술료=(직접+제경비)×0.2, 합계 / `laborRowDirect`=인원×단가×투입일×참여율) + sectionSubtotal labor 분기 + labor 에디터(등급 드롭다운→단가 자동, direct 읽기전용, 요율 입력).
- **SP4(#707)**: `lib/pdf/quote-pdf.tsx`(handover-pdf 패턴, 4유형 동적 표 + labor 적산 블록 + 한글금액) + `/api/quotes/[id]/pdf` 라우트 + 에디터 PDF 버튼.

**핵심 설계**: 공통 셸 + 유형별 섹션(section.kind: simple/labor + columns 동적). 금액은 **서버 recomputeDocument 단일 경로**(클라이언트 값 불신). 표준 샘플 5종은 `design-ref/quotes/`(gitignore 로컬).

**잔여/후속(미반영)**: sender 상수 실제값(사업자번호·전화·이메일) 운영 확인 후 채움. 노임단가 비고 "제경비 120%"는 샘플 셀(1.1)과 불일치—셀 1.1 채택. LaborRollupBlock 공식 중복(후속 단일화), labor 등급 select uncontrolled(재오픈 시 표시), platform 별도청구는 terms 재사용.

구현: superpowers SDD(태스크 TDD + 태스크별/opus 최종 리뷰). 관련: [[standard-list-inspector-design]], [[meetings-html-form-migration]], [[db-migration-apply]].
