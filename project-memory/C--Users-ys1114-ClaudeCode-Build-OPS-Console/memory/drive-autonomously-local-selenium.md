---
name: drive-autonomously-local-selenium
description: 사용자는 계획·검증을 내가 자율로 진행하길 원함 — entertest Selenium은 이 PC에서 내가 직접 실행
metadata: 
  node_type: memory
  type: feedback
  originSessionId: fbde5872-232f-48f3-992e-704c796d6e5e
---

사용자가 "앞으로도 계획 알아서 확인해줘"라고 명시 — entertest 같은 반복 검증 작업에서 **수동 단계로 넘기지 말고 내가 직접 돌려 확인**하길 원한다.

**Why:** 이 세션은 사용자 Windows PC 그 자체라, Bash 툴로 `python scripts/entertest/test_run.py`(Selenium+Chrome)·discovery·DB REST 검증을 내가 직접 실행할 수 있다(브라우저 창은 사용자 화면에 뜸). 디스커버리 산출물(`scripts/entertest/discovery/`)도 내가 직접 읽을 수 있다.

**How to apply:** entertest/원서작성 자동화 반복 시 — 사용자에게 명령을 시키지 말고 내가 `ENTERTEST_APPLY_WRITE=true ...`/`ENTERTEST_DISCOVER=true ...`로 실행→결과/스크린샷/모달 확인→수정→재실행. 단, 컨텍스트가 길어지면(50% 규칙) 진척을 커밋·문서화해 체크포인트하고 신규 세션 권유. 반복 "한 번 더" 시도(Ralph loop)는 금지 — 막히면 진단→커밋→핸드오프. 관련 작업 상태는 [[entertest-subsystem-b-state]].