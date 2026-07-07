# vibe-flow Project Memory

> **2계층 메모리 분리 정책**:
> - **project-level (이 파일)** — repo 자체 메모. 다른 사용자/협업자도 봐야 할 정보. git tracked.
> - **user-level** (`~/.claude/projects/-Users-yss----build-vibe-flow/memory/MEMORY.md`) — 본인 작업 흐름, 개인 결정, session-specific. git untracked.
>
> 200줄 cap. 인덱스만 작성, 상세는 leaf 파일에 분리 (Karpathy §5 leaves 원칙).

## Active Phase

**v2.3.2 출시 (2026-07-07)** — frontend-flow anti-slop/디자인 품질 라인 완성. anti-slop 검사가 em-dash·폰트·순수검정(FAIL) + radius·eyebrow·single-accent·low-saturation(WARN) 7종 + a11y 4-차원(정적 소스, 브라우저 불필요)으로 완비. 세션 흐름: a11y+anti-slop 이식(v2.3.0, #125) → 엣지 배터리로 결함 발굴·패치(v2.3.1, #126) → 문서 카운트 drift 정정(#127) → **문서 동기화 CI 게이트**(#128, `scripts/check-doc-counts.sh` — 문서 fix가 게이트 밖이라 반복되던 stale 차단) → 색상 WARN 2종(v2.3.2, #129, `color-utils.js`) → eval-regression Windows robustness(#130, jq CRLF + cp949). 내부 감사 R10(J) 13건 fixed→pending-verify. cloud-native auto-build cycle 본 목표는 v2.0.0(#106) 달성 완료.

현재는 **신규 기능 개발보다 내부 감사(audit) 기반 self-improvement 루프**가 주 흐름.

## 내부 감사 (Active — `/audit` 스킬로 운영, 최근 Round 10/J)

4 dimension(D1 컨텍스트 / D2 아키텍처 / D3 dogfooding / D4 메타-검증) fresh-context agent 병렬 위임. **R8부터 `/audit` 스킬**(AHE evaluate→analyze→improve, 4-필드 finding, decision-observability ledger)로 운영. 상세 round 별 finding/점수는 user-level memory `project_audit_20260601.md` 참조.

- **R1~R5 종결 (2026-06-01~06)** — 20 PR (#80~#99) 머지. 평균 점수 3.0 → ~4.47. 핵심: F-C1 sync drift 6범위 검증, R13 self-evolving closed-loop, settings hook 중복 fire 봉쇄.
- **R6 종결 (2026-06-10, #108/#109 머지)** — 평균 ~4.43 (R4 처럼 메타-검증 결함 노출 라운드). #108(F-F1 validate.sh drift no-op + F-F2 telemetry 오염 + F-D9 cycle over-count), #109(F-F3 본 MEMORY 갱신 + F-F4 inbox 10/12 정합 + F-F5 dead ref).
- **R7 종결 (2026-06-23, #110~#113 머지)** — D1~D3 + **D4 메타-검증 dimension 신설**, F-G01~F-G12 (3-dim 평균 4.30, D4 절대 3.6). drift 게이트 강화(F-G01 missing-dst / F-G03 agents.json / F-G02 CI), 계측 정확도(F-G04 telemetry from_entries 폴백), 문서 drift(F-G05/06/07).
- **AHE 정식화 (2026-06-23, #114/#115 머지)** — 감사를 실행 가능 계약으로: `core/rules/harness-evolution.md` + `/audit` 스킬 + `.claude/memory/audit-ledger.jsonl`(decision-observability: append→enqueue→mark-fixed→pending-verify→resolve).
- **R8 종결 (2026-07, `/audit` 첫 라이브 dogfooding, 3 PR #116~118)** — F-H01~F-H12 (11 fixed/1 defer). ledger.sh 자기결함 + Phase 3 중 octal 라이브 적발. R7 11건 verified.
- **R9/I (2026-07, `/audit` 2회차)** — R8 fix 실측 반증(폐루프 정상 종료, F-H07 준수). F-I01~F-I09 발굴 (3-dim 평균 4.37). F-H02 미완(락을 4 커맨드로 확장)·CI paths 사각(F-I05)·manifest 카운트(F-I02) 등. fix PR 순차 머지.
- **R10/J 종결 (2026-07-06~07)** — F-J01~F-J13 (13 fixed → pending-verify). frontend-flow 13개 결함(P0 경로 버그·anti-slop 거짓통과 3종·CI 신규 스크립트 사각) + manifest/문서 카운트 현행화. 다음 라운드가 실측 반증 대기.

## Brainstorm 인덱스 (최근)

cloud cycle 관련 (Phase 3.1/4):
- `brainstorms/20260523-092812-vibe-flow-phase3-1-cloud-native-redesign.md` — Phase 3.1 Path A 채택
- `brainstorms/20260525-094106-vibe-flow-phase3-1-r10-task-selection.md` — R10 task 선정
- `brainstorms/20260526-012144-f16-cloud-hook-wire-mechanism.md` — F16 4 대안 비교, 대안 B 선택

Phase 2 / Phase 3.0:
- `brainstorms/20260507-212317-sleep-build-phase2-ralph-loop-persona-vote.md` — Phase 2 설계
- `brainstorms/20260512-202958-vibe-flow-phase3-cron-scheduler.md` — Phase 3 cron 결정

전체 목록은 `ls .claude/memory/brainstorms/`로 확인 (카운트 하드코딩 제거 — F-I08 drift 방지).

## 머지된 PR 인덱스

- #69~#79 — Phase 3.1 cloud-native 본 구현 + Karpathy 5원칙(#76) + F16 cloud-init(#79)
- #80~#99 — 내부 감사 Round 1~5 (sync drift 검증 / telemetry tracker / 도메인 라우팅 / self-evolving cloud cycle)
- #100~#106 — v2.0.0 릴리즈 (MIT 라이선스 / README 영문화 / model right-sizing / marketplace publish / audit closure)
- #107 — README 데모 섹션 / #108 — 감사 R6 계측 정확도 trio / #109 — 감사 R6 P3 cleanup

## 운영 정책 (이 repo 협업 시 알아야 할 것)

- **Conventional Commits 강제** (`core/rules/git.md`)
- **HARD-GATE 등급** (`core/rules/git.md`): 1~5 인라인 / 6~19 brief plan / 20+ 전체 설계
- **TDD RED-GREEN-REFACTOR Iron Law** (`core/rules/tdd.md`) — `*.test.*` 또는 `tests/*-smoke.sh` 부재 시 commit 금지
- **Surgical Change** (`core/rules/donts.md`) — 무관한 dead code/comment 임의 수정 금지
- **Context Engineering** (`core/rules/karpathy-principles.md` §5) — tee 금지, 긴 출력 file redirect, 대형 조회 subagent 위임
- **core/ ↔ .claude/ sync** — `core/` 가 source, `.claude/` 는 런타임 미러(gitignore 다수). 양쪽 수정 필수. `bash .claude/validate.sh` [4.5/10] + `core/scripts/sync-drift.sh --check` 가 drift 검증.

## 다음 진입점

1. **frontend-flow 잔여 백로그** (우선) — (a) `editorial-warm-combo` 에이전트 리뷰 실배선(크림배경+serif+italic+테라코타 4신호 조합 탐지, 표면 분류가 기계화 불가라 에이전트 판단 필요, 스펙은 `references/anti-slop-preflight.md` deferred에 확정) (b) `docs/ARCHITECTURE.md` Self-Improving Loop 섹션 전면 재작성(현행 AHE/audit/ledger 반영, 지금은 legacy 배너만 — 카운트·dead-ref는 #127에서 정리됨)
2. **R10/J fix 실측 반증** — 다음 `/audit` 라운드에서 F-J01~F-J13 `pending-verify`→`resolve` (폐루프 종결)
3. 신규 기능 트랙 후보: `docs/character-system-spec-plan` 브랜치 (Phase 4 동적 캐릭터 시스템, spec/plan만 존재 미구현)

## 참고

- 상세 audit round 별 finding/점수는 user-level memory `project_audit_20260601.md` 참조
- session-specific 결정 흐름은 user-level MEMORY.md 참조
- 이 파일은 협업자가 repo clone 후 바로 컨텍스트 잡을 수 있도록 작성
