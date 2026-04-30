# 평면 .claude/ → vibe-flow 마이그레이션 가이드

기존 평면 `.claude/` 구조 사용자가 vibe-flow (Core + Extensions 분할 + state 기반 추적) 으로 전환하는 절차.

## 한 줄 요약

```bash
cd /your/project && bash /path/to/vibe-flow/setup.sh
```

→ setup.sh가 자동 감지 + state 파일 생성 + extensions 추론 + Core 갱신.

## 변경된 점

| 항목 | 이전 | vibe-flow |
|------|------|-----------|
| 디렉토리 구조 | 평면 (skills/agents/hooks/rules/) | core/ + extensions/<name>/ 두 단계 |
| 기본 설치 | 모든 23 스킬 | Core 14만 |
| Extensions | 별도 개념 없음 | 5 카테고리 (meta-quality 등) |
| state 파일 | 없음 | `.claude/.vibe-flow.json` |
| setup.sh CLI | --with-orchestrators / --force | + --extensions / --all / --list / --info / --remove / --check |
| validate.sh | 9 stages | 10 stages |

## 변경 안 된 점 (호환)

- ✓ 모든 스킬 이름 동일 (`/commit`, `/verify`, `/brainstorm`, ...)
- ✓ settings.local.json hook 경로 그대로 유효 (모든 hook은 core)
- ✓ 메모리 (memory/), plans (plans/), 메시지 (messages/) 자동 보존
- ✓ events.jsonl, store.db 자동 보존
- ✓ 22 hooks 동작 동일

## 자동 감지 메커니즘

setup.sh가 다음 조건 검출:

```
.claude/ 존재 + .claude/.vibe-flow.json 부재 → 마이그레이션 시작
```

설치된 extensions 추론 (시그니처 디렉토리):

| 디렉토리 존재 | 추론 |
|--------------|------|
| `skills/eval-skill/` | meta-quality 설치됨 |
| `skills/design-sync/` | design-system 설치됨 |
| `skills/pair/` | deep-collaboration 설치됨 |
| `skills/metrics/` | learning-loop 설치됨 |
| `skills/feedback/` | code-feedback 설치됨 |

## 절차 (사용자 측)

### 1. setup.sh 한 번 실행

```bash
cd /your/project
bash /path/to/vibe-flow/setup.sh
```

출력 예시:
```
=== Migration: 평면 .claude/ → vibe-flow state 기반 감지 ===
  감지된 extensions: meta-quality design-system
  ✓ state 파일 생성: .claude/.vibe-flow.json
  → 감지된 extensions 재설치 진행...

[1/7] Agents...
  ↻ backup: .claude/agents/developer.md.bak.20260430-...
  ✓ 갱신
[2/7] Hooks...
  ✓ 22 갱신
...

=== Installing extensions ===
  Extension: meta-quality 설치...
  Extension: design-system 설치...

=== Setup complete ===
```

### 2. state 파일 검토

```bash
cat .claude/.vibe-flow.json | jq '.extensions | keys'
```

추론 결과 정확한지 확인. 잘못 추론된 경우:

### 3. 정정

```bash
# 잘못 감지된 extension 제거
bash /path/to/vibe-flow/setup.sh --remove-extension <name>

# 빠진 extension 추가
bash /path/to/vibe-flow/setup.sh --extensions <name>
```

### 4. 검증

```bash
bash /path/to/vibe-flow/setup.sh --check
# 또는
bash .claude/validate.sh
```

10 stages 모두 PASS / 0 FAIL이면 성공.

## 메이커 본인 (글로벌 활성 사용자)

### 1. 글로벌 심볼릭 갱신

```bash
# 기존 dead 심볼릭 제거
for link in skills agents rules; do
  [ -L "$HOME/.claude/$link" ] && rm "$HOME/.claude/$link"
done

# vibe-flow Core 가리키도록 재생성
ln -s /Users/yss/개발/build/vibe-flow/core/skills /Users/yss/.claude/skills
ln -s /Users/yss/개발/build/vibe-flow/core/agents /Users/yss/.claude/agents
ln -s /Users/yss/개발/build/vibe-flow/core/rules /Users/yss/.claude/rules
cp /Users/yss/개발/build/vibe-flow/core/agents.json /Users/yss/.claude/agents.json
```

### 2. Claude Code 재시작 후 확인

```
/skills    # 23 스킬 보이는지 (글로벌은 Core 14만)
@developer # 에이전트 호출 가능한지
```

## 트러블슈팅

### Q. orphan 파일 경고가 나옴

`validate.sh` Stage 9에서:
```
warn: orphan ext skill: feedback (state에 없음)
```

→ 추론 누락. 수동 명시:
```bash
bash setup.sh --extensions code-feedback
```

### Q. .vibe-flow.json이 손상됨

```bash
# state 파일 재생성
rm .claude/.vibe-flow.json
bash /path/to/vibe-flow/setup.sh
```

자동 감지가 다시 트리거됨.

### Q. GitHub URL 변경 (메이커 본인)

claude-builds → vibe-flow 리포 rename 후 GitHub auto-redirect 활성화로 git push/pull은 작동. 단:
- 새 컴퓨터에서 clone 시 새 URL 사용 권장
- 기존 클론은 `git remote set-url origin https://github.com/SONGYEONGSIN/vibe-flow.git`

### Q. settings.local.json hook 경로가 깨짐

새 setup.sh가 settings.local.json **있으면 보존** (재생성 안 함). 따라서 기존 hook 경로 그대로 유효 (hook 파일은 같은 위치 `.claude/hooks/`).

만약 강제로 재생성 원하면:
```bash
rm .claude/settings.local.json
bash /path/to/vibe-flow/setup.sh
```

## 롤백

문제 발생 시:
```bash
# git 롤백 (메이커)
cd /Users/yss/개발/build/vibe-flow
git reset --hard pre-vibe-flow-phase-1   # 사전 태그

# 또는 사용자 측 단순 복구
cp .claude/.bak.* .claude/    # safe_copy로 백업된 사용자 수정본 복구
```
