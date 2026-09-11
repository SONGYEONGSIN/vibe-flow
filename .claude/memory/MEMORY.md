# vibe-flow Project Memory

> **2계층 메모리 분리 정책**:
> - **project-level (이 파일)** — repo 자체 메모. 다른 사용자/협업자도 봐야 할 정보. git tracked.
> - **user-level** (`~/.claude/projects/<프로젝트별 슬러그>/memory/MEMORY.md`) — 본인 작업 흐름, 개인 결정, session-specific. git untracked. 슬러그는 환경마다 다르므로 경로를 하드코딩하지 않는다.
>
> 200줄 cap. 인덱스만 작성, 상세는 leaf 파일에 분리 (Karpathy §5 leaves 원칙).

## Active Phase

**v2.3.2 출시 (2026-07-07)** — frontend-flow anti-slop/디자인 품질 라인 완성. anti-slop 검사가 em-dash·폰트·순수검정(FAIL) + radius·eyebrow·single-accent·low-saturation(WARN) 7종 + a11y 4-차원(정적 소스, 브라우저 불필요)으로 완비. 세션 흐름: a11y+anti-slop 이식(v2.3.0, #125) → 엣지 배터리로 결함 발굴·패치(v2.3.1, #126) → 문서 카운트 drift 정정(#127) → **문서 동기화 CI 게이트**(#128, `scripts/check-doc-counts.sh` — 문서 fix가 게이트 밖이라 반복되던 stale 차단) → 색상 WARN 2종(v2.3.2, #129, `color-utils.js`) → eval-regression Windows robustness(#130, jq CRLF + cp949). 내부 감사 R10(J) 13건 fixed→pending-verify. cloud-native auto-build cycle 본 목표는 v2.0.0(#106) 달성 완료.

**내부 감사 R11/K 종결 (2026-07-09~11)** — 감사가 처음으로 **자기 계기(instrument)** 를 겨눴다. harness 를 채점하는 두 장치(ledger `append`, 머지 게이트 `eval-regression`)가 **둘 다 fail-open** 이었고 실행으로 증명됐다. fix PR #132~#153 머지. 최종: F-K01~F-K21 중 **19 verified / 1 refuted(F-K07 오진) / 1 open(F-K03)** — R12 Phase 0 실측으로 종결.

**내부 감사 R12/L 종결 (2026-07-11)** — Phase 0 에서 K 라운드 pending-verify 19건 **전건 verified** + F-K07 refuted(격리 환경 측정 아티팩트, setup.sh 설치 플로우가 의도된 설계). 4-dim 재채점 **D1 3.9 / D2 4.2 / D3 4.3 / D4 4.2 (평균 4.15)**. 신규 F-L01~F-L12 등록 → fix 전건 #154~#158 머지 → **R13 Phase 0 에서 12건 전건 verified (종결)**.

**내부 감사 R13/M (2026-07-16)** — Phase 0: L 라운드 12건 전건 verified. 4-dim 재채점 **D1 3.8 / D2 4.3 / D3 4.2 / D4 4.3 (평균 4.15, R12 동률)** — D2/D4 상승은 L fix 홀딩 실증, D1/D3 하락은 인덱스 desync 재발 + telemetry per-skill 집계 死藏 발견. 신규 **F-M01~F-M10** (P1 1 / P2 6 / P3 3).

현재는 **신규 기능 개발보다 내부 감사(audit) 기반 self-improvement 루프**가 주 흐름.

## 내부 감사 (Active — `/audit` 스킬로 운영, 최근 Round AE)

4 dimension(D1 컨텍스트 / D2 아키텍처 / D3 dogfooding / D4 메타-검증) fresh-context agent 병렬 위임. **R8부터 `/audit` 스킬**(AHE evaluate→analyze→improve, 4-필드 finding, decision-observability ledger)로 운영. **round 별 finding/predicted_delta/actual_delta 의 정본은 `.claude/memory/audit-ledger.jsonl`** — `ledger.sh round <라벨>` / `pending-verify` 로 조회한다 (F-K08: 존재하지 않는 user-level 파일을 정본으로 가리키던 참조 제거).

- hook 규칙 등 프로젝트 패턴 → **[patterns.md](patterns.md)**.
- 라운드별 상세 서사(R1~AC, 26 라운드) → **[audit-rounds.md](audit-rounds.md)**. 4-필드 finding 원본은 `audit-ledger.jsonl`.
- **최근 = 라운드 AE (F-AE01~F-AE01)** — 08-29·08-30 발화가 연속으로 `phase0` 만 찍고 끊겼다(08-28 은 phase2-memory-start 까지 도달). **F-AE01** — Phase 1 은 pending-verify 3건 + reconcile 후보 13건(각각 PR 확인 요구)을 지는데 진입 heartbeat 가 없어, 그 안에서 죽는 것과 Phase 0 직후 죽는 것이 구별되지 않는다. F-AA03 fix 로 작업량만 늘리고 계기는 안 늘린 결과. fix: phase1-start/phase1 heartbeat + 확인 건수 firing 당 3건 상한. **F-AC01 fix 적용(2026-08-30)** — live 트리거 bootstrap 에서 거짓 단락("F-R01 미해결 — hook 이 막아주지 못하니 자제하라")을 제거하고 "안전 상태는 프롬프트가 아니라 원장·설정에서 조회하라"로 교체. 그 단락은 F-R01 이 08-09 verified 된 뒤에도 **3주 넘게 매일 밤 주입**됐다. 같은 조회에서 확인된 것 둘: 루프는 **`claude-sonnet-5`** 로 돌고(트리거 session_context), 08-30 실행이 조회 시점까지 **`ROUTINE_RUN_STATUS_PENDING`** 이었다 — 논리적 abort 가 아니라 **완료 보고 자체가 없는 형태**의 중단이다. phase0-only 두 밤의 성격을 시사하나 원인 단정은 보류.
- **`F-AC05` 인과 가설 반증 (2026-08-28)** — MEMORY 인덱스를 64KB→8KB 로 줄였는데도 08-28 발화가 **같은 `phase2-memory-start` 에서 멈췄다**. 인덱스 비대는 `phase2-memory` 중단의 원인이 아니다. 바이트 cap 자체는 유효(게이트 신설·인덱스 -87%)하나, 4회 연속(AB/AC/AC재시도/AD) 같은 지점 중단의 원인은 **미규명**으로 남는다 → F-AD09.

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
- **Surgical Change** (`core/rules/discipline.md`) — 무관한 dead code/comment 임의 수정 금지
- **Context Engineering** (`core/rules/karpathy-principles.md` §5) — tee 금지, 긴 출력 file redirect, 대형 조회 subagent 위임
- **core/ ↔ .claude/ sync** — `core/` 가 source, `.claude/` 는 런타임 미러(gitignore 다수). 양쪽 수정 필수. `bash .claude/validate.sh` (통과/경고/실패 카운트 출력) + `core/scripts/sync-drift.sh --check` 가 drift 검증.

## 다음 진입점

1. **frontend-flow 잔여 백로그** (우선) — (a) `editorial-warm-combo` 에이전트 리뷰 실배선(크림배경+serif+italic+테라코타 4신호 조합 탐지, 표면 분류가 기계화 불가라 에이전트 판단 필요, 스펙은 `references/anti-slop-preflight.md` deferred에 확정) (b) `docs/ARCHITECTURE.md` Self-Improving Loop 섹션 전면 재작성(현행 AHE/audit/ledger 반영, 지금은 legacy 배너만 — 카운트·dead-ref는 #127에서 정리됨)
2. **R14/N 종결 완료 (F-P01)** — nightly 폐루프 첫 firing 이 Phase 1 VERIFY 로 F-M01~M10 + F-N01~N03 전건(13) 실측 반증 → PR #170 머지(e2e4828). R14 라운드 닫힘. 재작업 불필요. 후속 라운드(O/P)는 위 R15 섹션.

3. **F-K03 refuted (F-O03)** — "CLAUDE.md 부재로 core/rules 미로드"는 오진이었다. 실제 메커니즘은 `.claude/rules/` 자동스캔 + frontmatter path-scoping(2026-07-24 규명). donts.md dormant scope 잔여이슈는 discipline.md 분리(PR #166)로 해소. 재작업 불필요.

4. 신규 기능 트랙 후보: `docs/character-system-spec-plan` 브랜치 (Phase 4 동적 캐릭터 시스템, spec/plan만 존재 미구현)

### R11 세션이 남긴 방법론 교훈

증거 없이 세운 가설은 그럴듯할수록 위험하다. 이번 세션에서 **최소 5건의 가설이 실행 검증에서 무너졌다** — `check-doc-counts` 게이트 미실행 / `28 hooks` 카운트 drift / `plugin.json` 에 `hooks` 키 추가 / `auto-build-safety` iteration cap fail-open / `ledger next_num` 파손. 전부 **코드로 굳히기 전에** RED 단계나 독립 검증이 잡았다. dimension agent 에 오염된 힌트를 심어도 D1·D2·D4 는 독립 증거로 기각했고, 반대로 D1 의 F-K09 예측(`resolve 실패 1→0`)은 측정 기준이 틀려 규약 확인 없이 실행했다면 정상 참조 6개를 깨뜨렸을 것이다. **finding 을 그대로 실행하지 말고 매번 재확인한다.**

## 참고

- 상세 audit round 별 finding/predicted_delta/actual_delta 는 `.claude/memory/audit-ledger.jsonl` (정본, git tracked). 조회: `bash core/skills/audit/scripts/ledger.sh round K`
- session-specific 결정 흐름은 user-level MEMORY.md 참조
- 이 파일은 협업자가 repo clone 후 바로 컨텍스트 잡을 수 있도록 작성
