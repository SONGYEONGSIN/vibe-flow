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

## 내부 감사 (Active — `/audit` 스킬로 운영, 최근 Round 13/M)

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
  - **후속 확장 (07-10~11, #141~#153)**: F-K13~K21 — windows 2-leg 머지 게이트(최초 run red 로 잔여 결함 적발 후 green, 게이트 유효성 실증) · uuidgen 폴백+LC_ALL=C(#146) · runner 저비용 agent 신설+tdd-enforce 스코프(#142) · doc-counts BSD sed(#144) · hook stdin drain 전수 계약화(#150/#152, hooks-stdin-drain-smoke 27/27).
  - **종결 (R12 Phase 0, 2026-07-11)**: 19 verified / F-K07 refuted(오진 — 원 증거가 gitignored 런타임 미상속 격리 환경 측정) / F-K03 만 open 잔존.
- **R12/L 종결 (2026-07-11, fix #154~#158)** — F-L01~F-L12 등록·fix·**R13 Phase 0 전건 verified**. 주제 반복 확인: **"게이트가 있으나 검증 축이 빗나감"** — L04(문자열만 대조, 배열 길이 미대조) / L08(디렉토리 수만 대조, 파일 존재 미대조) / L09(가드 형제 섹션 미일반화) / L10(스모크 러너 자신이 실행-건수 플로어 없음) / L11(피검 파일이 CI paths 밖). 상세는 ledger `round L` 조회.
- **R13/M (2026-07-16)** — F-M01~F-M10 등록 (P1 1 / P2 6 / P3 3). 신규 주제: **"기록은 되나 소비/집행이 안 따라옴"** — M01/M02(ledger 는 갱신되나 MEMORY 산문 desync + 정합 게이트 부재) / M03(runner manifest 등재됐으나 라우팅 문서 미배선 — 비용절감 dead-letter) / M05(hook 이 `.skill`/`.agent` 기록하나 telemetry 소비자 미참조 dead write). D4 계보 지속: M08(F-L11 형제 게이트 스크립트 2개 CI paths 사각, /tmp 재현 실증) / M09(스모크 플로어 26 zero-headroom) / M10(REQUIRED_HOOKS 하드코딩 잔존). fix 는 ledger `round M` 조회.
- **R14/N 종결 (2026-07-24)** — 세션 현장 발굴 3건(F-N01~N03) fix·머지(#167/#168/#169) 후, **폐루프 nightly routine 첫 firing 이 Phase 1 VERIFY 로 F-M01~M10 + F-N01~N03 전건(13) 실측 반증**(PR #170, e2e4828 머지). plan T3 firing-DoD 종결. 라이브 routine `trig_01FZz2Na6WULE2ZSUU1cjKt4`(cron `0 21 * * *`, sonnet-5)이 매일 21:00 UTC 폐루프 1라운드(PR-only). 상세는 아래. **F-N01** (D4 / P2 / fixed): `setup.sh:226` `remove_extension()` 의 `jq -r ... | while read -r f` 가 CR 미제거 → Windows 에서 `--remove-extension` 이 `✓ 제거됨` 을 출력하며 exit 0 인데 파일은 남고 state 만 삭제된다(무증상 orphan). 근인은 F-K14 의 CRLF 모델이 `$(...)` 다중 라인 캡처 기준이라 **파이프-while 소비처를 지점 열거에서 통째로 누락**한 것 — R11 "유형 미일반화" + R12/L "게이트는 있으나 축이 빗나감" 이 겹친 자리. 같은 세션에서 `setup.sh` 경로 치환 결함 가설은 **오진으로 기각**(격리 환경 인용 계층 아티팩트, F-K07 과 동형)이라 등록하지 않음. fix 는 `tr -d '\r'` + else 경고 + `jq-crlf-smoke.sh` 케이스 2개(RED 4/2실패 → GREEN 6/0). **원안에서 축소**: else 를 비-zero 로 하면 이미 지워진 파일이 있는 재실행이 실패해 idempotency 가 깨지므로 stderr 경고 + exit 코드 유지로 좁혔다 — R15 Phase 0 반증은 이 축소분 기준. R13/M pending-verify 10건 반증은 미실행.
- **F-N02** (D2 / P2 / fixed): ② cloud routine 발화 preflight 에서 발굴. `schedule-register.sh:131` `ALLOWED_TOOLS_JSON` 이 6개(`Bash/Read/Write/Edit/Glob/Grep`)뿐이라, T3 가 재작성한 5-phase 템플릿 **Phase 2 AUDIT(`/audit` skill + dimension agent 병렬 dispatch, audit/SKILL.md:5 `Agent` 요구)** 가 firing 시 툴 부재로 죽는다. `cloud-loop-prompt-smoke.sh` 는 "/audit 배선"(L2.5)·스크립트 존재(L3)만 게이트하고 **호출 능력(tool grant)은 미대조** — R12/L "게이트는 있으나 축이 빗나감"의 재발(배선=prompt, 권한=payload 가 다른 파일이라 한쪽만 갱신). fix: `Agent`,`Task` 추가(검증된 활성 routine `prompt-evolve` 셋과 정합) + smoke L5(템플릿 /audit 배선 ↔ payload allowed_tools Agent 대조, RED 16/1→GREEN 17/0). **②는 이 fix 머지 후 등록** — plan T3 firing-DoD 는 여전히 미종결(런타임).
- **F-N03** (D3 / P2 / fixed): `/budget --tokens` 사용량 조회 중 발굴. `budget/SKILL.md:332` `.cwd == $cwd` exact-match 가 Windows 에서 상시 0건 — `git rev-parse`(슬래시 `C:/...`) vs Claude Code 로그 `.cwd`(백슬래시 `C:\...`) 구분자 불일치. F-K13/K14(jq CRLF)와 같은 뿌리 클래스("POSIX 가정 vs Windows 실환경")의 **경로구분자 축**이 미탐지로 남아, dogfooding 관찰 도구 자신이 Windows 에서 자기 사용량을 못 봄(死藏). fix: `.cwd | gsub("\\\\";"/")` 정규화 후 비교(非Win no-op) + `budget-cwd-smoke.sh` 신규(백슬래시 fixture 에서 bare 0건/정규화 1건 + SKILL.md 원문 절 추출 검증, RED 3/3→GREEN 6/0) + EXPECTED_SMOKE 31→32. 실측: 이 프로젝트 30일 opus $82.25+fable $2.00(≈$84).

- **R15/O 개시 (2026-07-24, cloud 폐루프 Phase 2 산출)** — 첫 nightly firing 의 AUDIT 단계가 신규 5건(**F-O01~O05**, 전건 open) 발굴 — 폐루프 generative 트랙의 첫 자율 산출. F-O01(ledger.sh append 가 component/dimension 미강제 → enqueue null/null 오염, F-K01 4-필드 계약의 사각) / F-O02(MEMORY "Surgical Change" 참조가 T1 후 donts.md→discipline.md 미갱신) / F-O03(MEMORY 의 F-K03 자기설치 오도 지시 잔존) / F-O04(orchestrator run-log.sh 경로) / F-O05(budget per-skill count, F-M05/N03 인접). 다음 라운드(또는 후속 firing)의 enqueue→improve 대상. 상세·반증커맨드는 ledger `round O`.

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
- **core/ ↔ .claude/ sync** — `core/` 가 source, `.claude/` 는 런타임 미러(gitignore 다수). 양쪽 수정 필수. `bash .claude/validate.sh` (통과/경고/실패 카운트 출력) + `core/scripts/sync-drift.sh --check` 가 drift 검증.

## 다음 진입점

1. **frontend-flow 잔여 백로그** (우선) — (a) `editorial-warm-combo` 에이전트 리뷰 실배선(크림배경+serif+italic+테라코타 4신호 조합 탐지, 표면 분류가 기계화 불가라 에이전트 판단 필요, 스펙은 `references/anti-slop-preflight.md` deferred에 확정) (b) `docs/ARCHITECTURE.md` Self-Improving Loop 섹션 전면 재작성(현행 AHE/audit/ledger 반영, 지금은 legacy 배너만 — 카운트·dead-ref는 #127에서 정리됨)
2. **R14 감사 라운드** — R13/M fix 는 완료됨 (#159 M01 / #160 M02·04·08·09·10 / #161 M05·06·07 / #162 M03 머지 + #163 mark-fixed). F-M01~F-M10 전건 `fixed` 상태 — **R14 Phase 0 이 pending-verify 로 predicted_delta 실측 반증**하면 라운드가 닫힌다. 반증 커맨드는 ledger `round M` 의 predicted_delta 필드 참조. 참고: M07 fix 는 ledger 제안(assertionerror 키워드)을 그대로 쓰지 않고 traceback 한정으로 축소(vitest test_error 탈취 방지) — R14 는 이 축소분 기준으로 반증할 것.

3. **`/plan` → 자기설치 (F-K03 단독)** — repo 루트 `CLAUDE.md` 부재로 `core/rules/` 미로드. F-K07(hook 배선)은 R12 에서 refuted(오진) — 로컬 배선은 setup.sh 로 이미 성립, 짝이 아니다. `/plan` 없이 착수 금지는 유지.

4. 신규 기능 트랙 후보: `docs/character-system-spec-plan` 브랜치 (Phase 4 동적 캐릭터 시스템, spec/plan만 존재 미구현)

### R11 세션이 남긴 방법론 교훈

증거 없이 세운 가설은 그럴듯할수록 위험하다. 이번 세션에서 **최소 5건의 가설이 실행 검증에서 무너졌다** — `check-doc-counts` 게이트 미실행 / `28 hooks` 카운트 drift / `plugin.json` 에 `hooks` 키 추가 / `auto-build-safety` iteration cap fail-open / `ledger next_num` 파손. 전부 **코드로 굳히기 전에** RED 단계나 독립 검증이 잡았다. dimension agent 에 오염된 힌트를 심어도 D1·D2·D4 는 독립 증거로 기각했고, 반대로 D1 의 F-K09 예측(`resolve 실패 1→0`)은 측정 기준이 틀려 규약 확인 없이 실행했다면 정상 참조 6개를 깨뜨렸을 것이다. **finding 을 그대로 실행하지 말고 매번 재확인한다.**

## 참고

- 상세 audit round 별 finding/predicted_delta/actual_delta 는 `.claude/memory/audit-ledger.jsonl` (정본, git tracked). 조회: `bash core/skills/audit/scripts/ledger.sh round K`
- session-specific 결정 흐름은 user-level MEMORY.md 참조
- 이 파일은 협업자가 repo clone 후 바로 컨텍스트 잡을 수 있도록 작성
