# core/hooks/ — Hook 인벤토리

vibe-flow의 모든 hook script source. `setup.sh` 실행 시 사용자 머신의 `.claude/hooks/` 로 install된다 (skip-if-exists 정책).

## 두 install 메커니즘 (audit F-B2 해소)

**대부분의 hook** — `.claude/hooks/` 경로:
- `setup.sh`가 `core/hooks/*.sh` → `.claude/hooks/*.sh` 로 copy
- `.claude/settings.json` PostToolUse/PreToolUse/SessionStart matcher가 wire
- Claude Code agent가 매 도구 호출에서 실행
- `validate.sh REQUIRED_HOOKS` 가 install 검증

**예외 — `git-post-commit.sh`** — `.git/hooks/post-commit` 경로:
- `setup.sh`가 `core/hooks/git-post-commit.sh` → `.git/hooks/post-commit` 로 copy
- Claude Code hook 시스템이 아닌 **git 자체 hook** 인터페이스 사용
- git commit 명령 후 git가 직접 실행 (Claude Code agent 무관)
- `.claude/hooks/` 에는 일부러 install 안 함 — 두 hook 시스템 충돌 회피

## 신규 hook 추가 시 체크리스트

1. `core/hooks/<name>.sh` 작성 + `chmod +x`
2. `settings/settings.template.json` 에 matcher + command 등록 (Claude Code hook인 경우)
3. **`.claude/validate.sh` 와 `validate.sh` (root) 의 `REQUIRED_HOOKS` 변수에 이름 추가** ← F-B8 자기 모순 회피
4. `docs/architecture.html` hook count 갱신 (sync-readme.sh가 자동 처리 가능)
5. smoke test 신설 (`scripts/tests/<name>-smoke.sh`)

## git-post-commit 추가 시 (드물지만)

- `core/hooks/git-post-commit.sh` 수정 후 사용자가 `setup.sh --upgrade` 또는 `cp core/hooks/git-post-commit.sh .git/hooks/post-commit` 수동 sync 필요
- `.claude/hooks/` 에 같은 이름 파일 두지 말 것 — Claude Code가 git hook을 PostToolUse로 wire하려 시도하면 충돌
