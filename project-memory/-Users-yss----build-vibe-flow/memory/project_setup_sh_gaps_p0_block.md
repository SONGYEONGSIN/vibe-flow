---
name: setup.sh 갭 — auto-build P0 차단 (RESOLVED PR #49)
description: setup.sh skill 루트 .md 스킵 + working tree dirty 안내 부재로 첫 dogfooding P0 abort. PR #49로 fix됨. 본 메모리는 history 보존용
type: project
status: resolved
resolved_pr: 49
originSessionId: ded670e3-5091-423e-a9e5-8ae90b707796
---
**발견 시점 (2026-05-09)**: 첫 `/auto-build` dogfooding 시도 — sandbox `/Users/yss/개발/test/auto-build-test-1/`에서 P0(선행 조건 검증) 단계에서 abort. 사이클 본체 진입 0회.

**Calibration 데이터 (cycle 실행 전 수집)**:
- token cap / iter cap / vote 데이터: **수집 0** (사이클 미시작)
- 대신 수집된 것: **setup.sh 갭 3개** (vibe-flow 자체 인프라 issue)

## 3 갭

### 1. skills 카피 logic — 루트 .md 파일 스킵 (critical)

`setup.sh` 라인 ~463-472:

```bash
for skill_dir in "$SCRIPT_DIR/core/skills"/*/; do
  safe_copy "$skill_dir/SKILL.md" "..."
  for sub_dir in "$skill_dir"*/; do  # ← trailing / 으로 디렉토리만
    ...
  done
done
```

`SKILL.md` + 하위 디렉토리(`scripts/`, `data/`, `evals/`, `references/`)는 카피되지만 **skill 루트의 추가 `.md` 파일은 스킵**. 영향:
- `core/skills/auto-build/orchestrator.md` → target에 카피 안 됨
- 결과: `/auto-build` 호출 시 P0가 `❌ orchestrator.md 미존재` → abort `deployment_missing`

**해결**: `safe_copy "$skill_dir"*.md` 같은 추가 라인 또는 `find -maxdepth 1 -name "*.md"` 패턴 카피.

### 2. .gitignore 적용 부재

setup.sh는 `.claude/` 안에 다수 파일을 만들지만 `.gitignore` 갱신 안 함. fresh repo에서 setup 실행 시 `?? .claude/`, `?? CLAUDE.md`, `?? playwright.config.ts`, `?? .worktreeinclude` 등이 untracked로 남음. auto-build의 "working tree clean" 안전 계약 위반.

**해결**: setup.sh가 `.gitignore.template` 카피 또는 `.gitignore`에 패턴 자동 append.

### 3. P0 `verify_unspecified` 조건이 fresh task에 과민

`/auto-build`의 P0가 `package.json scripts.test|build|lint|typecheck` 1개 이상 또는 `/verify` 스킬 부재 시 abort. 그런데 task 자체가 `npm init`을 포함하는 신규 프로젝트는 사전 검증 시점에 package.json이 없어 abort. fresh sandbox dogfooding 불가.

**해결**: P0 검증을 "task에 npm init / 기타 init 포함 시 패스" graceful fallback. 또는 task description에 명시 필드 (예: `--init`)로 우회.

## How to apply (다음 세션)

위 3 갭 모두 별 PR로 fix 후 재시도:
- PR (a): setup.sh skills 카피에 루트 .md 파일 포함 (1줄 fix)
- PR (b): setup.sh가 .gitignore.template 카피 또는 패턴 append
- PR (c): /auto-build P0 graceful fallback (init 포함 task 인지)

3 PR 머지 후 sandbox 재setup → 재dogfooding. 또는 vibe-flow 자체 또는 Folio처럼 이미 npm 프로젝트인 곳에서 dogfooding이면 (a)만 fix하면 즉시 가능.

**메타 finding**: vibe-flow는 self-dogfooding 인프라가 미완성. dogfooding 자체가 첫 calibration 입력으로 setup.sh 갭을 드러냄 — 이게 dogfooding의 가치.
