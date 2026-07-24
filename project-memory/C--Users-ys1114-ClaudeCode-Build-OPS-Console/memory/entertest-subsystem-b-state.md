---
name: entertest-subsystem-b-state
description: entertest 원서작성 자동완주(check_apply_write) 진행 상태 + 다음 블로커
metadata: 
  node_type: memory
  type: project
  originSessionId: fbde5872-232f-48f3-992e-704c796d6e5e
---

entertest 테스트 자동화 Subsystem A(도달성 스모크 5체크)는 PR #576로 main 머지·동작 완료. dev-test는 #577에서 표준 ListPattern+variant로 재설계됨.

**Subsystem B = 원서작성 폼 자동완주(결제직전까지)** — ✅ **1104069 완주 달성**, 브랜치 `feat/entertest-apply-write`(미머지/미커밋).
- 해독·진행상태 전부: `docs/entertest-apply-automation.md` ("5차 — 완주 달성" 섹션이 최신·결정판).
- PoC 타깃: service_id **1104069** (외국인 중문 편입 = worst-case). 계정 jt29005(ID=PW 동일).
- **`check_apply_write`가 결제목록 도달까지 `status: pass` (연속 2회 검증).** 5대 근본원인 수정:
  ① 검증 피드백 = 네이티브 `alert()`(not #globalAlert) → `_INSTALL_ALERT_CAPTURE_JS`로 캡처(삼키지 않음).
  ② 필드 매칭 = jw 컨테이너 `[requiredalert="<메시지>"]` 정확 일치 + jwtype별 처리(라디오는 checked/click, SEARCHFIELD는 `SEARCH:{id}` 신호).
  ③ 사진·서류 위조 불가 → 실제 업로드(`upload_photo`=#UpPic/DirectPhotoUpload iframe, `upload_documents`=btn{Name}Edit/JSFileUpload iframe, `<input type=file>` send_keys). 가짜 주입 시 /Error/CommonError.
  ④ 업로드 보존 = broad-fill 선행(라디오/select 클릭이 업로드 hidden 리셋 → 업로드 전 broad-fill 2회로 안정화, 이후 멱등).
  ⑤ 저장경로 = thenable alert/confirm(사이트가 Promise식, ExecuteSaveEvents가 .then/.catch/.finally 체이닝 → boolean 반환 시 저장 조용히 중단).
- 반복 안정화: 성공판정=결제목록 권위(`결제하기` 존재), 루프=`JWValidate()` 게이트, `delete_unpaid_applications()`(PayingPage 삭제하기→chkagree 클릭1회+passwd=계정→btnpasswdCheck→btnDelete)로 매 회 신규 경로. `enter_wonseo`는 신규(동의 iframe)/기존(편집 직행) 양경로. 드라이버 `unhandledPromptBehavior=accept`.
- ✅ **결제·접수완료까지 완주**(`ENTERTEST_PAY=true` opt-in, `complete_payment()`): 결제목록 결제하기→`/Payment/UnivPayBegin`→**테스트 결제** 버튼(`PayClick('btnPay','PayTest')`=테스트PG, 실과금 없음)→`/PayConfirm` "접수완료"→`/UnivPayResult` 수험번호. 검증: jt29001→`2026U14010851004` status:pass.
- ⚠️ **접수완료=계정 소진**: 같은 계정/학교 재작성 불가(ApplyFirst가 `/Notice/{sid}/A` 바운스, 동의 체크박스 0개). `enter_wonseo`가 체크박스 0개면 "접수완료 차단" RuntimeError. **1104069 소진: jt29005·jt29001. 클린: jt29002~29004.** 반복 결제직전 테스트는 클린 계정 사용.
- 검증 실행: 결제직전(기본) `ENTERTEST_APPLY_WRITE=true ENTERTEST_TARGET_URL=https://entertest.jinhakapply.com/Notice/1104069/A ENTERTEST_ACCOUNT=jt29002 python scripts/entertest/test_run.py` / 완주(결제+접수) `+ENTERTEST_PAY=true` + 클린 계정 ([[drive-autonomously-local-selenium]] 따라 직접 실행).
- **남은 확장(별도)**: 타 전형(학부/대학원) 폼 차이 대응, `check_apply_write`를 CHECKS/ingest 정식 편입 여부 결정. 변경 미커밋 상태(브랜치 `feat/entertest-apply-write`).

**2026-07-03 진단 — service_id 1210065(부산대 외국인 신입학) 전화필드 블로커 (미해결):**
- 폴러 스모크 5체크(run_checks: check_page_load/login/apply_entry/payment_page/pay_result)는 **페이지 도달만 확인**(폼 미작성·미제출) → "pass 5/5 done"은 실제 접수완료 아님. `ENTERTEST_PAY`는 run_checks와 무관(check_apply_write 전용).
- `check_apply_write`(APPLY_WRITE=true) 직접 실행 시 **전화번호(txtStuTel) 검증에서 무한루프 FAIL** ("결제목록 비어있음").
- **구조**: 전화=3분할 hidden `phoStuTel1/2/3` (⚠️ **id 아니라 `name` 기반** — getElementById 실패, getElementsByName 사용). 방문형 visible `txtStuTel`은 `maxLength=13` = **대시 형식 "010-1234-5678" 기대**. `_WONSEO_FILL_JS`/`_FORCE_FILL_JS`는 "01012345678"만 넣어 pho2/3 빈값→FAIL.
- **시도(모두 실패)**: ① JS로 pho1/2/3 직접세팅 → JWValidate 실행 시 리셋됨. ② send_keys 실타이핑 → pho 분할은 됨(010/1234/5678)이나 JWValidate가 unmasked txtStuTel에서 재파생해 깨짐. ③ txtStuTel을 대시형("010-1234-5678")+pho1/2/3=010/1234/5678 세팅 → **값은 모두 정확히 유지되는데도 JWValidate가 여전히 "전화번호를 입력해 주세요"로 거부**.
- **결론**: 이 폼 JWValidate의 전화 검증은 단순 값채움으로 안 풀림 — JS 데이터구조/검증플래그/특정 입력시퀀스 요구로 추정. **다음 세션에 사이트 JWValidate 전화 검증 로직 직접 리버스엔지니어링 필요.** 이번엔 계정 미소진(폼 저장 안 됨). 그 외 미충족 필수: 국적(SEARCHFIELD txtNationalityName/txtHiSchoolNationalityName), 동의(chkTempOK11·rdoRefundSelectY·rdoAwarenessSurvey1·rdoUnivAgreeY)도 남음.