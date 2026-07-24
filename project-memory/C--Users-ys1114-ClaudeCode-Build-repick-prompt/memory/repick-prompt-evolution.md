---
name: repick-prompt-evolution
description: "RE:PROMPT를 메타프롬프팅 플러그인으로 진화하는 다단계 로드맵 — 스코프 A 완료, C·D 남음"
metadata: 
  node_type: memory
  type: project
  originSessionId: ac99310c-e123-4689-a6fb-45c92295863c
  modified: 2026-07-23T09:36:07.065Z
---

RE:PROMPT(repick-prompt, GitHub SONGYEONGSIN/repick-prompt)를 "메타프롬프팅 런타임 + 배포 가능한 Claude Code 플러그인"으로 진화시키는 작업. 4개 참조 이미지(핵심 3단계 덤핑→깎기→점검 / 질문 유도 / 성공조건 명시 / 실행환경 변환)를 기반으로 시작.

로드맵 (스코프 분해):
- **A. 메타프롬프팅 런타임** = `reprompt` 스킬 (`.claude/skills/reprompt/`). ✅ **완료·main 머지(2026-07-21, ~5e0bbd8).** 6단계 인라인 파이프라인, 산출 `.reprompt/<날짜>-<slug>/` 6파일, 4타깃 변환(general/coding/image/research), 번들 DNA로 이식성. 헬퍼 `scripts/reprompt-init.mjs`(slugify+initRun, 12테스트).
- **B. 실행환경 변환기** = A에 포함 완료 (coding=Goal 중지요건+Ultracode 제약 / image=구도·조명·카메라 / research=출처·검증).
- **C. 플러그인 패키징** ✅ **완료·main 머지(2026-07-21, ~543da61).** `reprompt`를 `skills/reprompt/`로 이동(git mv), `.claude-plugin/plugin.json`(name:reprompt v1.0.0) + `marketplace.json`(name:repick-prompt, owner.name, source:"./"). SKILL.md는 `$CLAUDE_SKILL_DIR`(폴백:주입 Base directory)로 경로 해석. `claude plugin validate .` 0/0, 실설치 도그푸드 성공. **주의: 이 레포에서 reprompt는 이제 project-skill로 자동로드 안 됨(skills/로 이동) — 쓰려면 `claude plugin marketplace add ./` + `claude plugin install reprompt@repick-prompt`.**
- **D. 릴리즈 워크플로우 + 좁히기** ✅ **완료·main 머지(2026-07-21, ~549b0bd).** Narrow-2로 bloat 해결: 플러그인 본체를 `plugin/`로 이동(plugin.json→`plugin/.claude-plugin/`, skills→`plugin/skills/reprompt/`), 마켓플레이스는 레포 루트 유지 + `source:"./plugin"`(install 시 캐시에 plugin/만, 프로토타입 실증). `scripts/release-version.mjs`(readVersion/bumpVersion/writeVersion +테스트), `CHANGELOG.md`(v1.0.0), `RELEASING.md` 런북. v1.0.0은 `claude plugin tag ./plugin --dry-run`으로 준비만(reprompt--v1.0.0) — **실제 push·공개는 사용자 몫(미실행)**.

**설치(현재 구조)**: `claude plugin marketplace add ./`(로컬) 또는 `add https://github.com/SONGYEONGSIN/repick-prompt`(공개 후) → `claude plugin install reprompt@repick-prompt`. **릴리즈 발행**: RELEASING.md 참조 — 버전 범프 → CHANGELOG → `claude plugin tag ./plugin --push -m "reprompt %s"` + `git push origin main`.

**공개 완료(2026-07-21)**: `git push origin main`(→549b0bd) + `claude plugin tag ./plugin --push`로 **`reprompt--v1.0.0` 태그 발행·origin push 완료**. GitHub(SONGYEONGSIN/repick-prompt)에서 설치 가능. **GitHub Release 발행 완료(2026-07-23)**: `gh release create reprompt--v1.0.0`("reprompt v1.0.0", Latest, CHANGELOG 노트) — 릴리즈 파이프라인(코드 병합/태그/CHANGELOG/Release) 전부 종료. **후속 아이디어**: 웹앱 메타프롬프팅 UI(스코프 A 웹 표면), 메타프롬프팅 세션→DNA 역류 학습.

**참고 — 브랜치 전략**: reprompt 스코프 A~D는 전부 브랜치 없이 `main` 직접 커밋으로 landing(PR 없음). PR로 되돌릴 수 없으니(main 대비 diff 0), PR 리뷰가 필요하면 다음 작업부터 feature 브랜치를 파야 함. 반면 `prompt-evolve` 진화 라운드(R9·R11·R14·R15·R17)는 `evolve/rNN-*` 브랜치 + PR(#1~5)로 진행 — squash 머지 관례.

설계·계획 문서: `docs/superpowers/specs/2026-07-21-reprompt-meta-prompting-design.md`, `docs/superpowers/plans/2026-07-21-reprompt-meta-prompting.md`.

기존 본체는 `prompt-evolve` 진화 루프(템플릿 공장) + DNA `vault/00-principles/prompt-principles.md`(v1.15, R17까지 반영 — 2026-07-23 PR #5 머지) + Next.js 뷰어 `app/`(포트 3200). reprompt는 이 DNA를 품질 기준으로 재사용한다. 웹앱에 메타프롬프팅 UI 얹는 것은 별도 후속 spec. 관련: [[repick-prompt-stack]]
