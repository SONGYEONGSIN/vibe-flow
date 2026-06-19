---
name: entertest-test-run
description: 개발·테스트(entertest) 실행 파이프라인 현황 + 실제 원서작성 자동화 v2 진행 맥락
metadata: 
  node_type: memory
  type: project
  originSessionId: 86163e16-5b15-41f6-b6a1-a31619f412ea
---

`/dashboard/dev-test` → entertest 원서접수 테스트 실행.

**파이프라인(코드 완성·실가동 검증됨)**: 인스펙터 "테스트 실행" → `requestEntertestRun`이
`entertest_test_runs` pending 적재(중복 방지) → **회사 PC 폴러**(`scripts/entertest/poll-local.ps1`,
작업 스케줄러 등록됨·가동 중) claim → `run-local.ps1` → `test_run.py`(Selenium) → `/api/entertest/ingest`.
GitHub Actions 아님(회사 IP 게이트 필요). **폴러 등록은 완료** — 증거: 6/18 `done` 1건이 5/5 통과로 정상 인제스트.

**현재 CHECKS = v1 도달성 스모크 5단계**: page_load/login/apply_entry/payment_page/pay_result.
전부 "페이지 뜨고 예상 텍스트 보이나"만 확인 — **실제 폼 작성 안 함**.

**v2(B) = 실제 원서작성 자동완주, 사용자 결정 "결제 직전까지"** (작성→전형료 결제 '수단 선택'
화면 도달, 결제 버튼 안 누름 → 실제 결제/접수완료 레코드 안 남김). 폼은 **서비스별 상이**.
- DISCOVER에 필드/버튼 인벤토리(`{단계}.fields.json`) 덤프 추가됨(#588). `discovery/`는 gitignore.

**중요: entertest 게이트는 IP가 아니라 UA(브라우저) 체크 — 집/어느 Mac에서도 plain Selenium으로 동작.**
회사 PC 불필요. 로컬에 python3.14+selenium+Chrome+uc 다 있음. 6/19 새벽 집에서 전체 흐름 검증 완료.

**원서작성 진입 전체 경로 (해독 완료, 6/19)**:
1. 로그인(jt29005, ID=PW) — `/Login`, JS로 `ContentPlaceHolderPage_txtUserName/txtPassword` 주입 후 `Login()`.
2. `GET /Notice/{sid}/A` (유의사항). **실제 콘텐츠는 iframe `#frmNotice`(src=`/Noti/{sid}/{tab}`) 안에 있다** —
   바깥 문서엔 nav/footer뿐. 필드 카운트하려면 `switch_to.frame(frmNotice)` 필수.
3. nav "원서작성" = `RedirectURL('/ApplyFirst/{sid}/A')` → 외부는 `/Notice/{sid}/T`로, iframe은 `/Noti/{sid}/T`(원서작성 동의서).
4. 동의서 iframe: 체크박스 `c0`(모두동의)+`chkNotice1~5`, 버튼 `开始填报志愿` onclick=`onApply()`.
5. 모두 체크 → `onApply()` → confirm **"원서를 작성하시겠습니까?"** accept → `/Wonseo/{sid}/{N}/A` = **실제 원서 폼**.
6. Wonseo 폼: 보이는 입력 ~65개(예: txtStuHanFullName/txtStuEnglishNameL·F, 외국인등록번호 txtEMemSsn_1/_2,
   국적, 학력 rdoGraduation*, txtSchool*, 성적 txtTotal, 연락처 txtStuMobile/txtStuEmail, 사진 업로드, 저장(保存)).
   **폼은 전형별로 크게 상이**(이 케이스는 외국인 중문 특별전형 — 중국어 라벨/외국인등록번호). 수시/정시/대학원은 다른 폼.

**남은 v2 작업**: Wonseo 폼을 유효 테스트 데이터로 채움(전형별 분기 필요) → 저장 →
`/Payment/UnivWritingList`(결제 수단 선택) **직전까지**. 검증 못 한 회사PC 의존 없음 — 로컬에서 반복 가능.
탐색 스크립트는 `/tmp/probe_*.py`, `/tmp/fill_v1.py`(커밋 안 함), 산출물 `scripts/entertest/discovery/`(gitignore).

**이터레이션 1 결과 (6/19, fill_v1.py)**:
- Wonseo 폼은 **iframe 아님 — `/Wonseo/{sid}/4/A` 본문(default content)**. txtStuHanFullName 등 직접 접근.
- JS로 텍스트 47개 + 라디오 6그룹 + select 자동 채움 성공(전형구분 편입학·지원학과 정상 렌더 확인).
- **저장 = `__doPostBack('ctl00$ContentPlaceHolderPage$srvSave','')`**. XPath "저장" 텍스트 클릭은
  오답("저장시 이벤트" 등) — srvSave 포스트백을 직접 호출해야 함.
- **필수 업로드가 진짜 난관**: `F_UploadFile`(여권 사진면), `F_UploadFile1`(외국인등록증 앞뒤) +
  3x4 증명사진. 모두 `jwtype=FILEFIELD` **커스텀 AJAX 업로더**(JX/jw 프레임워크), optional="required".
  단순 `<input type=file>` send_keys로 안 될 가능성 — 실제 파일 input 찾기 + AJAX 업로드 성공 필요.
- 지원학과(`hdnMajor`)·주소(우편번호)는 팝업 검색 의존. PIL 미설치(더미 jpg는 raw/base64로 생성).
- **다음**: ① 더미 jpg 준비 → FILEFIELD 실제 input에 업로드 ② hdnMajor/주소 JS 직접 세팅
  ③ srvSave 포스트백 → 서버 검증 알림 수집 → 반복. 전형마다 필수 업로드 종류 다름(외국인=등록증/여권).

**이터레이션 2~3 (6/19, 서비스 비교 + 8108005 시도)**:
- 현재(6월) 열린 전형은 전부 대학원/외국인/학위취득/기타 — **학부 수시·정시 미오픈**. PoC 난이도 다 높음.
- 서비스별 Wonseo 폼 부담 조사(`/tmp/survey.py`): 대부분 FILEFIELD 2개(거의 optional)+주소 팝업.
  8108005(서경대 뮤지컬 경연대회)가 가장 가벼움(텍스트 7, 필수업로드 0).
- **검증/모달은 네이티브 alert이 아니라 in-page `div.layer_cont` 커스텀 모달**. 확인버튼 `a.btn3.st2`,
  저장버튼 `a.btn1.st1`(onclick 없음, jQuery 핸들러). 셀렉터 정밀 타겟 필수(broad 텍스트매칭은 footer 클릭→이탈).
- **8108005 막힘**: 채움 후 "참가자격: 고등학교 2학년 이상…(2001년생 이하)" 모달이 뜨고, 확인 클릭 시
  `/Notice/8108005/A`로 튕김 = **자격 미달 거부 게이트**. 학력/생년 바꿔도 동일 → 폼 입력이 아니라
  **테스트 계정(남29005) 등록정보/전형 자격조건** 의존. 더 시도 = 찍어맞추기라 중단.

**★ 해독 문서: `docs/entertest-apply-automation.md` (#589 머지)** — 아래 기법 전체가 repo에 박제됨.

**★ 돌파 기법 (6/19, fill1104.py — 1104069 외국인 폼, 두 난관 다 해결)**:
- **업로드 우회(다이얼로그 불필요)**: jw FILEFIELD는 static `<input type=file>` 없음(동적 생성). 하지만
  업로드 콜백이 hidden 필드만 세팅하므로 **JS로 직접 주입하면 검증 통과**:
  · 사진: `PhotoRegist({storageUrl,FileName,Ext,Size})` 호출 또는 `txtPhotoFileName/Ext/Size` 세팅.
    (`PhotoLoad(true)`=계정 최근사진 AJAX 로드도 가능). 콜백 소스: 폼 인라인 JS.
  · 서류: hidden `hdnUploadFileName/OrgFile/Size/Type` (F_UploadFile=여권), `hdnUploadFile1*`(외국인등록증) 세팅.
- **팝업 SEARCHFIELD 우회**: 국적·학과·학교 등 18개 필수 팝업필드는 hidden `hdn{searchid}Code`(예 hdnNationalityCode,
  hdnNationality2Code, hdnUnivMajorCode …)만 채우면 통과. **검증은 "비어있지 않음"만 봄 — 'CN'/'1' 등 아무 값 OK**(증명됨).
- **저장**: `a.btn1.st1` text "저장 (保存)" 클릭(정확매칭 startsWith). 클라 검증이 in-page `div.layer_cont`
  모달로 **첫 미충족 1건씩** 표시 → 채우고 재저장 반복. 숨김 필수필드는 가시성 무시 force-set 필요(txtPassport 등).
- **진척**: 업로드·여권번호·국적/거주국/응시국 등 코드 20종 통과 → "학교 영문명"까지 도달. 남은 건
  학력 텍스트(학교 한/영/중문명)·생년월일 포맷 등 텍스트 필드뿐(블랭킷 채움은 날짜포맷 오류 유발 → 명명 필드별로).

**v2 결론**: **전 과정 자동화 가능 입증**(진입·채움·업로드우회·팝업코드우회·검증루프).

**★ #590 (머지됨) — v2 자동완주 구현·검증 완료**: `scripts/entertest/test_run.py`에 `check_apply_write`
(+678줄) — broad-fill + 저장 검증루프 + 검증메시지→force-fill 수렴 + **SEARCHFIELD 팝업 결과선택**
(`select_search_result`) + 결제목록 판정(결제직전) + `complete_payment`(테스트 결제→접수완료, 수험번호).
우리가 막혔던 **1104069 worst-case long-tail(영문/중문 페어·학기'42'·팝업)까지 해결, 5·6차 로그로 ✅ 검증**.
**계정 대역 순환**(`expand_accounts`, 접수완료 소진 계정 스킵)도 구현.
- 실행: `ENTERTEST_APPLY_WRITE=true`(결제직전까지, 인제스트X 검증모드) / `+ENTERTEST_PAY=true`(접수완료까지).
- ⚠️ **프로덕션 기본 흐름 미연결**: 기본 CHECKS(폴러→run_checks)는 **여전히 v1 5체크 스모크**.
  자동완주는 검증 모드 전용(인제스트 안 함). 문서에 "남은 과제: 전체 폼 수렴 — 별도" 명시.
- 해독 문서 `docs/entertest-apply-automation.md`(#589→#590에서 +140줄 보강).

**남은 것(있다면)**: ① 자동완주를 프로덕션 테스트 흐름으로 전환할지(CHECKS 등록/폴러 ingest) — 단,
접수완료는 계정 소진+실제 접수레코드 생성이라 자동 디폴트는 신중(현 검증모드 게이팅이 의도적일 수 있음).
② 전형별 전체 폼 수렴(문서 "별도" 과제). 즉 **자동완주 자체는 완료, 프로덕션 디폴트 전환은 미결(설계 결정 필요)**.

**v1 CHECKS false-positive 주의**: `apply_entry`는 nav에 항상 있는 "원서작성" 글자만 봐서, 폼 없는 빈
서비스도 통과시킴. 14개 서비스 ApplyFirst 직접 GET은 전부 `/Notice/{sid}/T`(동의서)로 리다이렉트됨(정상).

**미결 후속**: 대역(범위) 계정 순환 — 범위 `jt29001~jt29005` 등록돼도 러너는 시작 계정만 사용
(`test_run.py` ACCOUNT=split("~")[0]). 매 실행 다른 계정 순환은 미구현(v2 다음 우선순위).

관련: [[standard-list-inspector-design]] (dev-test가 이 표준 적용), [[db-migration-apply]].
