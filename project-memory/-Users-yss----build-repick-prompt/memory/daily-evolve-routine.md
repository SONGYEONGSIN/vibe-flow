---
name: daily-evolve-routine
description: 매일 03:00 KST 클라우드 루틴이 prompt-evolve 1라운드를 자동 실행해 PR 생성 — 무인 경로 검증 완료(R21~R31), 열린 evolve PR을 방치하면 다음 라운드가 스킵된다
metadata: 
  node_type: memory
  type: project
  originSessionId: 8e423dd7-140d-4ae8-9f12-bb5e8fb09af7
  modified: 2026-08-10T21:32:10.054Z
---

repick-prompt는 2026-07-15부터 자동 자기진화 체제로 전환됨.

- GitHub 원격: https://github.com/SONGYEONGSIN/repick-prompt (private, 2026-07-14 최초 푸시)
- 클라우드 루틴: `prompt-evolve 일일 자동 라운드` (id `trig_01C7e66nxxHq8ELBMj5syCty`, cron `0 18 * * *` UTC = 매일 03:00 KST, 모델 claude-sonnet-5)
  - 관리: https://claude.ai/code/routines/trig_01C7e66nxxHq8ELBMj5syCty
- 동작: `vault/backlog.md` 대기열의 첫 미완료 항목을 타깃으로 `/prompt-evolve --auto` 1라운드 → `evolve/r<n>-<slug>` 브랜치 + PR 생성. main 직커밋 금지, 백로그 소진 시 no-op.
- 사람 게이트는 PR 리뷰로 대체됨 — DNA(prompt-principles.md) 변경분은 PR에서 검토 후 머지 (드리프트 방지).
- LEARN에 지식 정제 게이트 있음 (f0a4c2e): 새 규칙을 기존 DNA와 대조해 신규/강화/충돌/애매 4판정. 충돌·애매면 DNA 동결 + PR `## 지식 정제 질문`으로 사람에게 질문 — 답변의 판단 기준 자체를 다음 원칙으로 축적.
- 백로그 시드 10개 (2026-07-14 기준) — 소진 전에 새 타깃을 backlog.md 맨 아래에 추가해야 함.

## 2026-07-30 — 정지 해제, 재개 완료 (닷새 정지 후)

2026-07-25 S1 작업 중 `enabled: false`로 정지시켰던 루틴을 재개했다. 재개 조건 3단계 모두 이행:

1. S1 머지 — PR #8, main `9b42274` (2026-07-25)
2. R20 수동 1회 완주 — PR #9, main `c76480c` (2026-07-30). 승자 a, DNA v1.18, 라이브러리 29종. 새 승격 경로(후보 md → `vault/50-library/`)가 직렬화기 왕복 deep-equal로 작동 확인
3. `enabled: true` 복구 — 다음 실행 2026-07-31 03:04 KST

재개 시 **트리거 프롬프트도 갱신**했다 (2026-07-14 작성분이라 S1 이전 상태였음):
- 0번 **선행 가드 신설** — 열린 `evolve/*` PR 있으면 중단. backlog.md 소비 규칙에만 있고 프롬프트엔 없었다
- 5번 **검증 4단계 고정** — `build-library` → `wiki-lint` → `node --test` → app lint/build. 기존엔 app lint/build만 있어서, 승격 단계 frontmatter 손편집 실수를 잡는 wiki-lint가 빠져 있었다

루틴은 실패해도 알림이 없다 — 조용히 멈춘다. PR이 안 올라오면 그게 실패 신호다. 설계 근거는 `docs/superpowers/specs/2026-07-25-vault-as-library-source-design.md` "자율 루틴 안전".

## 2026-08-11 — 무인 경로 검증 완료 (12발화 / 11라운드)

07-30 재개 시점의 미검증 항목("루틴 프롬프트 → SKILL `--auto` → PR 생성 전 구간")은 해소됐다. 첫 무인 PR은 예고대로 #15 `evolve/r21-user-persona` (07-31 03:25 KST), 이후 R31까지 매일 돌았다 — PR #15·22·25·29·31·32·34·36·39·41·43.

- **1회 no-op은 실패가 아니라 가드 작동**: 08-04 03:00 KST 발화는 PR을 안 냈는데, 그 시각 R24 PR(#29)이 아직 열려 있었다(08-02T18:30Z 생성 → 08-03T21:36Z 머지). 0번 선행 가드가 설계대로 중단시킨 것. → **열린 `evolve/*` PR을 리뷰 안 하고 두면 다음 날 라운드가 통째로 스킵된다.** 이게 실질적인 일일 운영 부담이다.
- **사람 리뷰가 실제로 결함을 잡고 있다**: 무인 라운드 산출물의 후속 fix PR — #37(SCORES 내부 정합), #40(v1.26 반증 관찰 표시 + ledger 필수 필드), #42(소비된 방향 가설 체크박스). 즉 `--auto` 는 완주하지만 무검토 머지는 안 된다.
- 소요 시간은 발화~PR 25~46분.
