# Brainstorm: commit_pushed 이벤트 emit + telemetry 매핑

작성: 2026-05-12T19:58:37Z (filename에서 추출, retroactive F-A4 fix)

run_id: 20260512T105812Z-6c90
task_source: spec_line_76 (PR #54 + #55 + #56 + #57 후속 retry)

## 의도

**무엇을**: vibe-flow의 `.claude/events.jsonl`에 `commit_pushed` 신규 이벤트 타입 emit + `core/skills/telemetry/SKILL.md`의 type→label 매핑에 `commit_pushed→커밋` 행 추가. payload는 type/ts(ISO 8601)/branch/subject(80자 truncate, NFC 정규화) 4 필드. emit 위치(Stop hook / git post-commit / `/commit` 스킬 내부)는 본 brainstorm이 단일 선택.

**누가**: maker 본인 — vibe-flow Phase 2 머지 후 첫 실 task `/auto-build` dogfooding.

**왜 지금**: Ralph loop + persona vote 머지(PR #39, #40) 후 합성 evals만 검증되어 실 cycle 데이터(token/iter/vote) 미수집. 4 calibration 입력 회수가 Phase 3 진입 결정 선결 조건.

**성공**: 임의 git commit 1회 → `.claude/events.jsonl`에 `commit_pushed` 1 라인 append + `/telemetry` 출력 label 매핑 표에 `commit_pushed` 카운트 ≥1 표시 + `bash -n` / `jq empty` 신규 sh/json 통과 + eval-regression CI PASS.

## 제약

- **NFC 정규화 필수**: 한글 commit subject가 macOS git에서 NFD로 들어올 수 있음 (memory `feedback_macos_nfd_nfc.md`). emit 시 `python3 -c "import unicodedata; print(unicodedata.normalize('NFC', s))"` 등으로 NFC 강제.
- **subject 80자 truncate**: 긴 commit message가 jsonl 가독성 깨지지 않도록.
- **events.jsonl append-only**: 기존 파일에 1 라인 추가, 기존 데이터 보존.
- **telemetry SKILL.md 매핑 표**: 기존 type→label 표 구조 유지하며 1행만 추가.
- **single repo 가정**: 자율 사이클 cwd = vibe-flow source repo (PR #55 spec section 5 cwd 가정 표 1차 cycle).

## 대안 비교

| 위치 | 장점 | 단점 | capture 완전성 |
|------|------|------|--------------|
| **A. Stop hook** (Claude Code `.claude/settings.local.json` hooks) | Claude Code 세션 종료 시 자동 trigger. 다른 hook 인프라와 통일 | Stop ≠ commit. Claude Code 세션 외(터미널 `git commit`)에서 commit 시 누락. transcript 파싱 필요 (commit 발생 시점 추출) | ❌ 부분 |
| **B. git post-commit hook** (`.git/hooks/post-commit` + setup.sh 배포) | **모든 git commit** capture (CLI, Claude Code, IDE 등). native git 메커니즘 | `.git/hooks/`는 git이 추적 X — 머신별 설치 필요. setup.sh가 자동 배포해야 | ✅ 완전 |
| **C. `/commit` 슬래시 스킬 내부** (skill SKILL.md 변경) | `/commit` 호출 시점 명확. 슬래시 스킬과 자연 통합 | `/commit` 안 쓰고 `git commit` 직접 실행한 경우 누락. 사용자 패턴 의존 | ❌ 부분 |

## 추천 + 근거

**추천: B — git post-commit hook**

### 근거

1. **capture 완전성**: 사용자가 어떤 방식(CLI / Claude Code / IDE)으로 commit하든 동일하게 emit. telemetry "커밋" 카운트의 신뢰성 핵심.
2. **native 메커니즘**: git post-commit hook은 commit 트랜잭션 직후 항상 실행. 안정성 입증된 패턴.
3. **단순성**: 1 shell 스크립트(`core/hooks/git-post-commit.sh`) + setup.sh의 자동 배포(`cp core/hooks/git-post-commit.sh .git/hooks/post-commit`) — 추가 inframistry 0.
4. **transcript 파싱 불필요**: A 대안은 Stop hook의 transcript에서 commit 시점 추출이 fragile.

### 기각된 alternative

- **A 기각**: capture 누락 위험 — 사용자가 터미널에서 `git commit -m "..."` 직접 실행 시 emit 0. telemetry "커밋" 카운트 신뢰성 깨짐.
- **C 기각**: `/commit` 슬래시 스킬 사용은 권장이지만 강제 X. 사용자 워크플로우 의존.

### implementation 개요

1. `core/hooks/git-post-commit.sh` 신규 — `git log -1 --format=%H/%s/%D` + ISO 8601 ts + NFC subject + 80자 truncate → `.claude/events.jsonl` append.
2. `setup.sh` Hooks 단계(line 458 근처)에서 `cp core/hooks/git-post-commit.sh .git/hooks/post-commit` + `chmod +x` 배포. self-install/deploy 환경 양쪽 적용.
3. `core/skills/telemetry/SKILL.md` type→label 매핑 표에 `commit_pushed | 커밋` 행 추가 (정확한 위치는 P3 RED 단계 확인).
4. `evals/auto-build/evals.json` (또는 해당 위치)에 commit_pushed 케이스 추가 — `bash -n core/hooks/git-post-commit.sh` 통과 + emit 결과 jsonl 형식 검증.
5. `tests/git-post-commit.test.sh` 또는 동등 smoke 테스트 — 임시 git 디렉토리에서 commit 1회 → events.jsonl 라인 append 확인.

## 다음 단계

**hard_gate: brief** — 영향 파일 추정 5~7개 (post-commit.sh, setup.sh, telemetry SKILL.md, evals.json, 1 smoke test, 옵션 README/docs). brief = 6~19 파일.

P2 진입 → `/plan from-brainstorm` 호출하여 plan 생성. orchestrator P2가 plan 스킬 invoke.

### 검증 명령 (P4)

- `bash -n core/hooks/git-post-commit.sh`
- `bash core/hooks/git-post-commit.sh` (시뮬레이션 commit 환경)
- `jq empty .claude/events.jsonl`
- `bash scripts/eval-regression-check.sh` (있다면) 또는 evals/auto-build 검증
- `bash .claude/validate.sh`

### 후속

- Phase 3 진입 시 dashboard 짝 PR (spec 라인 82) — vibe-flow-dashboard repo cwd에서 별 cycle.
- events.jsonl 폭증 우려 (R2) — 1000+ commit 누적 후 jsonl 회전 별 task.
