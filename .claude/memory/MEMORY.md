# vibe-flow Project Memory

> **2계층 메모리 분리 정책**:
> - **project-level (이 파일)** — repo 자체 메모. 다른 사용자/협업자도 봐야 할 정보. git tracked.
> - **user-level** (`~/.claude/projects/<프로젝트별 슬러그>/memory/MEMORY.md`) — 본인 작업 흐름, 개인 결정, session-specific. git untracked. 슬러그는 환경마다 다르므로 경로를 하드코딩하지 않는다.
>
> 200줄 cap. 인덱스만 작성, 상세는 leaf 파일에 분리 (Karpathy §5 leaves 원칙).

## Active Phase

**v2.3.2 출시 (2026-07-07)** — frontend-flow anti-slop/디자인 품질 라인 완성. anti-slop 검사가 em-dash·폰트·순수검정(FAIL) + radius·eyebrow·single-accent·low-saturation(WARN) 7종 + a11y 4-차원(정적 소스, 브라우저 불필요)으로 완비. 세션 흐름: a11y+anti-slop 이식(v2.3.0, #125) → 엣지 배터리로 결함 발굴·패치(v2.3.1, #126) → 문서 카운트 drift 정정(#127) → **문서 동기화 CI 게이트**(#128, `scripts/check-doc-counts.sh` — 문서 fix가 게이트 밖이라 반복되던 stale 차단) → 색상 WARN 2종(v2.3.2, #129, `color-utils.js`) → eval-regression Windows robustness(#130, jq CRLF + cp949). 내부 감사 R10(J) 13건 fixed→pending-verify. cloud-native auto-build cycle 본 목표는 v2.0.0(#106) 달성 완료.

**내부 감사 R11/K 종결 (2026-07-09)** — 감사가 처음으로 **자기 계기(instrument)** 를 겨눴다. harness 를 채점하는 두 장치(ledger `append`, 머지 게이트 `eval-regression`)가 **둘 다 fail-open** 이었고 실행으로 증명됐다. 7 PR(#132/#135/#134/#136/#137/#138/#139) 머지, 각각 main 에서 거동 재검증 완료. finding 16건 중 **11 fixed(pending-verify) / 5 open**.

현재는 **신규 기능 개발보다 내부 감사(audit) 기반 self-improvement 루프**가 주 흐름.

## 내부 감사 (Active — `/audit` 스킬로 운영, 최근 Round 10/J)

4 dimension(D1 컨텍스트 / D2 아키텍처 / D3 dogfooding / D4 메타-검증) fresh-context agent 병렬 위임. **R8부터 `/audit` 스킬**(AHE evaluate→analyze→improve, 4-필드 finding, decision-observability ledger)로 운영. **round 별 finding/predicted_delta/actual_delta 의 정본은 `.claude/memory/audit-ledger.jsonl`** — `ledger.sh round <라벨>` / `pending-verify` 로 조회한다 (F-K08: 존재하지 않는 user-level 파일을 정본으로 가리키던 참조 제거).

- **R1~R5 종결 (2026-06-01~06)** — 20 PR (#80~#99) 머지. 평균 점수 3.0 → ~4.47. 핵심: F-C1 sync drift 6범위 검증, R13 self-evolving closed-loop, settings hook 중복 fire 봉쇄.
- **R6 종결 (2026-06-10, #108/#109 머지)** — 평균 ~4.43 (R4 처럼 메타-검증 결함 노출 라운드). #108(F-F1 validate.sh drift no-op + F-F2 telemetry 오염 + F-D9 cycle over-count), #109(F-F3 본 MEMORY 갱신 + F-F4 inbox 10/12 정합 + F-F5 dead ref).
- **R7 종결 (2026-06-23, #110~#113 머지)** — D1~D3 + **D4 메타-검증 dimension 신설**, F-G01~F-G12 (3-dim 평균 4.30, D4 절대 3.6). drift 게이트 강화(F-G01 missing-dst / F-G03 agents.json / F-G02 CI), 계측 정확도(F-G04 telemetry from_entries 폴백), 문서 drift(F-G05/06/07).
- **AHE 정식화 (2026-06-23, #114/#115 머지)** — 감사를 실행 가능 계약으로: `core/rules/harness-evolution.md` + `/audit` 스킬 + `.claude/memory/audit-ledger.jsonl`(decision-observability: append→enqueue→mark-fixed→pending-verify→resolve).
- **R8 종결 (2026-07, `/audit` 첫 라이브 dogfooding, 3 PR #116~118)** — F-H01~F-H12 (11 fixed/1 defer). ledger.sh 자기결함 + Phase 3 중 octal 라이브 적발. R7 11건 verified.
- **R9/I (2026-07, `/audit` 2회차)** — R8 fix 실측 반증(폐루프 정상 종료, F-H07 준수). F-I01~F-I09 발굴 (3-dim 평균 4.37). F-H02 미완(락을 4 커맨드로 확장)·CI paths 사각(F-I05)·manifest 카운트(F-I02) 등. fix PR 순차 머지.
- **R10/J 종결 (2026-07-06~07)** — F-J01~F-J13. R11 Phase 0 에서 **11 verified / 2 refuted**. anti-slop 3종은 fixture 실행으로 확인. refuted 2건은 같은 유형 — **산문에 쓴 규칙을 집행 델타로 청구**: F-J07(orphan 체크가 `.vibe-flow.json` 게이트라 실행횟수 0) / F-J12(Gate C fail-closed 가 산문뿐, 집행 코드 0건).
- **R11/K 종결 (2026-07-09, 4 PR #132/#135/#134/#136)** — F-K01~F-K13, 4-dim 평균 3.98 (D1 4.2 / D2 4.5 / D3 3.6 / D4 3.6). 하락은 회귀가 아니라 **과대평가의 정정** — 해당 경로들은 내내 있었고 이번에 처음 실행으로 측정됐다.
  - **7 fixed**: F-K01(ledger append 4-필드 미강제, P0) · F-K10(eval-regression 이 evals.json 33개 전삭제 상태에서 exit 0, P0) · F-K02(resolve 종결상태 재기록) · F-K11(손상 라인 1개 → 중복 primary key) · F-K04(EXT_SIGNATURES 하드코딩, ext 10/12) · F-K05(reconciliation unexercised → orphan smoke 신설) · F-K06(setup.sh 가 CI paths 밖)
  - **공통 문법**: **"검사 대상 0건"을 "결함 0건"으로 렌더한다.** F-K01/K10/K11/K12 가 전부 같은 문장이고 R10 의 F-J02 도 그랬다. 결함을 발견한 자리만 고치고 **유형을 인접 진입점에 일반화하지 않은 것**이 반복 원인 — F-H08 은 `mark-fixed` 에만, `TEMPLATE_COUNT -gt 0` 가드는 templates 블록에만, 빈값 검사는 `resolve` 에만 있었다.
  - **잔여 open 6건**: F-K03(`CLAUDE.md` 부재 → `core/rules/` 미로드) · F-K07(hook 미배선 → `events.jsonl` 사용 이벤트 0) — 둘 다 "**vibe-flow 가 자기 자신에 설치되지 않았다**"는 한 뿌리, `/plan` 게이트. F-K08/K09/K12(본 PR) · F-K13(windows matrix).
  - **F-K13 근거**: CI 등가 스위트를 Windows 에서 돌리면 21개 중 5개 실패(`audit-ledger`/`persona-vote`/`queue-tests`/`schedule`/`statusline`)하는데 #134 의 ubuntu 로그는 **같은 5개가 전부 PASS**. 머지 게이트 플랫폼이 운용 플랫폼과 분리돼 있다.

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
2. **R11/K fix 실측 반증** — 다음 `/audit` Phase 0 가 `pending-verify` **11건**(F-K01/K02/K04/K05/K06/K08/K09/K10/K11/K12/K16)을 `resolve`. 각 `predicted_delta` 에 **실행 가능한 반증 명령**이 들어 있다 (예: `echo '{"round":"ZZ"}' | ledger.sh append; $?` 가 비-0). R10 의 두 refuted 가 산문 예측이었던 것에 대한 대응.

   ⚠️ **F-K13 은 그대로 반증하면 안 된다.** 기록된 `predicted_delta`("windows leg 이 최초 실행에서 red, green 이면 refuted")는 스코핑 이전의 것이다. 스코핑 결과 Windows 실패 5건은 **3개 뿌리**로 갈렸고 그중 A는 이미 고쳐졌다(F-K16, PR #139). B·C(F-K14/F-K15)를 마저 고치면 windows leg 은 **green 이 정상**이므로, 원 `predicted_delta` 를 곧이곧대로 적용하면 옳은 fix 를 refuted 로 오판한다. R12 Phase 0 은 F-K13 을 `refuted`(예측 지표 자체가 틀림 — 메타-학습)로 종결하고, matrix 켜기는 F-K14/K15 머지 후 새 finding 으로 다룬다.

3. **Windows 이식성 잔여 (F-K14 → F-K15 → matrix 순)**
   - **F-K14** [P2, 실 버그] `schedule-register.sh:109` 가 `uuidgen` 하드 의존(Windows 부재) + 그 가드가 `:178` claude CLI 검사보다 **앞서** 실행돼 진단이 도달 불가. 가짜 `uuidgen` 주입 시 27/2 로 회복. fix = `python3 -c "import uuid;print(uuid.uuid4())"` 폴백 + uuid 생성 블록을 claude 가드 뒤로 이동
   - **F-K15** [P3, 테스트 전용] `statusline-tests.sh:79-80` 의 astral-plane emoji(`🔧` U+1F527, `📋` U+1F4CB) grep 이 git-bash UTF-8 로케일에서 실패. `LC_ALL=C` 로 10/0. `statusline.sh` 자체는 정상
   - 둘 다 머지 후에야 windows matrix(1줄)를 green 으로 켤 수 있다

4. **`/plan` → 자기설치 (F-K03 + F-K07)** — 한 뿌리. F-K07 의 fix(plugin/settings hook 배선)는 **스키마 미검증 추론**이라 코드로 굳히지 않는다. 캐시의 어떤 플러그인도(공식 포함) `hooks` 키를 쓰지 않음을 확인했다. `/plan` 없이 착수 금지.

5. 신규 기능 트랙 후보: `docs/character-system-spec-plan` 브랜치 (Phase 4 동적 캐릭터 시스템, spec/plan만 존재 미구현)

### R11 세션이 남긴 방법론 교훈

증거 없이 세운 가설은 그럴듯할수록 위험하다. 이번 세션에서 **최소 5건의 가설이 실행 검증에서 무너졌다** — `check-doc-counts` 게이트 미실행 / `28 hooks` 카운트 drift / `plugin.json` 에 `hooks` 키 추가 / `auto-build-safety` iteration cap fail-open / `ledger next_num` 파손. 전부 **코드로 굳히기 전에** RED 단계나 독립 검증이 잡았다. dimension agent 에 오염된 힌트를 심어도 D1·D2·D4 는 독립 증거로 기각했고, 반대로 D1 의 F-K09 예측(`resolve 실패 1→0`)은 측정 기준이 틀려 규약 확인 없이 실행했다면 정상 참조 6개를 깨뜨렸을 것이다. **finding 을 그대로 실행하지 말고 매번 재확인한다.**

## 참고

- 상세 audit round 별 finding/predicted_delta/actual_delta 는 `.claude/memory/audit-ledger.jsonl` (정본, git tracked). 조회: `bash core/skills/audit/scripts/ledger.sh round K`
- session-specific 결정 흐름은 user-level MEMORY.md 참조
- 이 파일은 협업자가 repo clone 후 바로 컨텍스트 잡을 수 있도록 작성
