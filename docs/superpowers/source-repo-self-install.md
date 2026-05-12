# vibe-flow source repo self-install 가이드

vibe-flow source repo 자체에서 `/auto-build` 자율 사이클을 trigger하기 위한 self-install 절차.

## 언제 필요한가

- 산출물 위치가 vibe-flow source repo인 task (예: `core/hooks/`, `core/skills/`, `core/agents/` 변경)
- 그 task를 자율 사이클로 dogfooding하고 싶을 때
- 외부 deploy 환경(auto-build-test-1 등)에서 trigger 시 multi-repo abort (F6 finding) 우회 목적

일반 task(deploy 환경에서 사용자 프로젝트 변경)는 self-install 불필요 — 사용자 프로젝트에 `bash setup.sh` 한 번 실행.

## 절차

```bash
cd /path/to/vibe-flow      # source repo cwd
bash setup.sh --upgrade    # 자기 자신에 install + .gitignore 자동 패턴 추가
git status                 # working tree clean 확인
```

### 동작

`setup.sh`는 `SCRIPT_DIR == PROJECT_DIR` 감지 시 self-install 모드로 진입한다:

1. **카피**: `core/hooks/`, `core/skills/`, `core/agents/`, `core/rules/`, `core/scripts/` → `.claude/` (deploy 환경 install과 동일)
2. **settings.local.json 생성**: 절대 경로 hook 등록 (PreToolUse safety hook 등)
3. **.gitignore 자동 패턴 추가**:
   ```
   .claude/hooks/
   .claude/skills/
   .claude/scripts/
   .claude/agents/
   .claude/rules/
   .claude/validate.sh
   .claude/agents.json
   .claude/budget.json
   .claude/.vibe-flow.json
   .claude/settings.local.json
   .claude/settings.template.json
   ```
   → install 결과 파일이 untracked로 유지, source repo 더러워짐 방지

## self-install 후 dogfooding

```bash
cd /path/to/vibe-flow                                # source repo cwd 유지
# main 또는 base branch에서 시작 — auto-build가 feat/sleep-* branch 자동 생성
git checkout main
git status                                           # working tree clean 필수

# /auto-build 트리거 (Claude Code 세션에서)
/auto-build "<4문항 형식 task description>"
```

orchestrator가 P0.1에서 `.claude/hooks/auto-build-safety.sh` 등을 확인 — self-install 완료 상태면 통과.

## 주의 사항

- **branch 자동 격리**: orchestrator가 `feat/sleep-<timestamp>-<slug>` 신규 branch를 만들어 main 직접 수정을 차단. 사이클 완료 후 PR review로 통합 결정.
- **settings.local.json은 머신별**: self-install 시 생성된 settings.local.json은 절대 경로를 가짐. 다른 머신에서는 재실행 필요. .gitignore에 자동 포함.
- **core/와 .claude/ 중복**: self-install 후 source repo는 `core/`(원본)과 `.claude/`(install 카피)를 모두 가진다. 원본 수정 시 `.claude/`도 재카피 필요 — `bash setup.sh --upgrade` 재실행.
- **.gitignore 패턴은 영구**: self-install 한 번 실행하면 .gitignore에 패턴 추가됨. 추후 source repo에서 .claude/hooks/ 등을 추적하고 싶다면 수동 제거 필요.

## 관련

- `docs/superpowers/specs/2026-05-09-commit-pushed-event-pairing-design.md` Section 5 — cwd 가정 표 + 선행 조건 명시
- F6 finding (run_id `20260512T104326Z-3b07`) — multi-repo task abort 사례
- `core/skills/auto-build/orchestrator.md` P0.1 — 배포 검증 fail-fast 로직
