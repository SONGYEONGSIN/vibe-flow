# Plan: commit_pushed 이벤트 emit + telemetry 매핑

plan_id: 20260512-195937-commit-pushed-event
run_id: 20260512T105812Z-6c90
brainstorm: .claude/memory/brainstorms/20260512-195837-vibe-flow-claude-events-jsonl-.md
hard_gate: brief

## 결정 요약 (brainstorm 추천 B)

emit 위치: **git post-commit hook** (`.git/hooks/post-commit` via `core/hooks/git-post-commit.sh`)

## 단계

### T1. core/hooks/git-post-commit.sh 신규 — emit 스크립트

**상태**: pending

**산출**:
- `core/hooks/git-post-commit.sh` — git commit 직후 실행, `.claude/events.jsonl`에 commit_pushed 1 라인 append

**스펙**:
- payload 4 필드: `type=commit_pushed`, `ts` (ISO 8601 UTC, `date -u +%Y-%m-%dT%H:%M:%SZ`), `branch` (`git rev-parse --abbrev-ref HEAD`), `subject` (`git log -1 --pretty=%s`)
- subject 처리: `python3 -c "import sys, unicodedata; print(unicodedata.normalize('NFC', sys.stdin.read()))" | head -c 80` (NFC + 80자 truncate)
- jsonl format: `{"type":"commit_pushed","ts":"...","branch":"...","subject":"..."}`
- jq escaping: `jq -nc --arg type "$T" --arg ts "$TS" --arg branch "$B" --arg subject "$S" '{type:$type, ts:$ts, branch:$branch, subject:$subject}'`
- `.claude/events.jsonl` 부재 시 touch 후 append
- emit 실패해도 commit 자체는 성공 (`set +e` 또는 `|| true`)

**RED**:
- `tests/git-post-commit.test.sh` 신규 — 임시 git repo에서 commit 1회 → jsonl 1 라인 검증 + jq 통과 + 4 필드 모두 존재 + NFC 확인 (한글 subject 케이스)

**GREEN**:
- `bash -n core/hooks/git-post-commit.sh` PASS
- `bash tests/git-post-commit.test.sh` PASS

### T2. setup.sh — post-commit hook 자동 배포

**상태**: pending

**산출**:
- setup.sh의 Hooks 단계(현 `[2/$TOTAL_STEPS] Hooks...` 부근)에 `.git/hooks/post-commit` 카피 추가
- `core/hooks/git-post-commit.sh` → `${PROJECT_DIR}/.git/hooks/post-commit` (실행 권한 부여)
- `.git/hooks/`가 git tracked 디렉토리가 아니므로 .gitignore 처리 불필요

**RED**:
- `tests/setup-post-commit-deploy.test.sh` 신규 — setup.sh 실행 후 `.git/hooks/post-commit`이 실행 가능 파일로 존재 + `core/hooks/git-post-commit.sh`와 동일 내용 확인

**GREEN**:
- `bash tests/setup-post-commit-deploy.test.sh` PASS

### T3. core/skills/telemetry/SKILL.md — type→label 매핑 추가

**상태**: pending

**산출**:
- 기존 type→label 매핑 표(SKILL.md 내)에 `commit_pushed | 커밋` 행 추가

**RED**:
- `grep -q "commit_pushed.*커밋" core/skills/telemetry/SKILL.md` PASS 시 GREEN

**GREEN**:
- 매핑 표 1행 추가 commit

### T4. evals — commit_pushed 케이스 추가 (skip 가능)

**상태**: pending (조건부)

**조건**: `evals/auto-build/evals.json` 또는 동등 파일 존재 시. 부재 시 skip.

**산출**: 새 케이스 — `bash -n core/hooks/git-post-commit.sh` + jsonl 라인 jq 검증 통과를 evals.json에 행 추가.

**GREEN**: `bash scripts/eval-regression-check.sh` PASS (있다면)

### T5. P5 사이클 종료 commit + PR

**상태**: pending

**산출**:
- 단일 conventional commit: `feat(hooks): commit_pushed 이벤트 emit + telemetry 매핑`
- PR 생성 — `/finish --path pr` 자동

## DoD (전체)

- 임의 git commit 1회 → `.claude/events.jsonl`에 commit_pushed 1 라인 append
- `/telemetry` 출력 label 매핑 표에 commit_pushed 행 (실 카운트는 본 commit으로 ≥1)
- 모든 신규 .sh `bash -n` 통과
- 모든 신규 jsonl `jq empty` 통과
- (eval-regression 존재 시) CI PASS
