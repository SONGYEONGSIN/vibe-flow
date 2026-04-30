# Claude Code 공식 스펙 레퍼런스

vibe-flow 개발 시 이 문서를 참고하여 공식 문서에 어긋나지 않도록 한다.

> 기준: 2026년 3월 공식 문서 (https://code.claude.com/docs)

---

## 1. Agents (.claude/agents/*.md)

### Frontmatter 필드

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `name` | string | No | 소문자, 하이픈만 사용 |
| `description` | string | 권장 | 위임 판단 기준 |
| `tools` | string[] | No | 허용 도구 (allowlist) |
| `disallowedTools` | string[] | No | 거부 도구 (denylist) |
| `model` | string | No | `sonnet`, `opus`, `haiku`, full ID, `inherit` |
| `permissionMode` | string | No | `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan` |
| `maxTurns` | number | No | 에이전트 턴 제한 |
| `skills` | array | No | 사전로드 스킬 |
| `mcpServers` | object | No | MCP 서버 (inline 또는 참조) |
| `hooks` | object | No | 에이전트 라이프사이클 훅 |
| `memory` | string | No | `user`, `project`, `local` |
| `background` | boolean | No | `true`면 백그라운드 실행 |
| `effort` | string | No | `low`, `medium`, `high`, `max` |
| `isolation` | string | No | `worktree`로 설정 시 임시 git worktree에서 실행 |

### 파일 위치
- `.claude/agents/<name>.md` — 프로젝트 스코프
- `~/.claude/agents/<name>.md` — 개인 스코프

### 주의
- 위 표에 없는 필드는 사용 금지
- 플러그인 서브에이전트는 `hooks`, `mcpServers`, `permissionMode` 미지원

---

## 2. Skills (.claude/skills/\<name\>/SKILL.md)

### Frontmatter 필드

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `name` | string | No | 슬래시 커맨드명 (디렉토리명 기본) |
| `description` | string | 권장 | 사용 시점 및 목적 |
| `argument-hint` | string | No | 자동완성 힌트 (예: `[issue-number]`) |
| `disable-model-invocation` | boolean | No | `true`면 사용자만 호출 가능 |
| `user-invocable` | boolean | No | `false`면 Claude만 호출 가능 |
| `allowed-tools` | string[] | No | 이 스킬 활성 시 사용 가능 도구 |
| `model` | string | No | 모델 선택 |
| `effort` | string | No | `low`, `medium`, `high`, `max` |
| `context` | string | No | `fork`로 설정 시 서브에이전트에서 실행 |
| `agent` | string | No | `context: fork` 사용 시 에이전트 타입 |
| `hooks` | object | No | 스킬 라이프사이클 훅 |

### 문자열 치환
- `$ARGUMENTS` — 모든 인자
- `$0`, `$1` 등 — 특정 인자
- `${CLAUDE_SESSION_ID}` — 세션 ID
- `${CLAUDE_SKILL_DIR}` — 스킬 디렉토리
- `` !`command` `` — 셸 명령어 전처리

### 파일 위치
- `.claude/skills/<skill-name>/SKILL.md` — 프로젝트 스코프
- `~/.claude/skills/<skill-name>/SKILL.md` — 개인 스코프

---

## 3. Rules (.claude/rules/*.md)

### Frontmatter 필드

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `paths` | string[] | No | glob 패턴 — 경로별 조건부 로드 |

### 로드 방식
- `paths` 없음 → 세션 시작 시 무조건 로드
- `paths` 있음 → 해당 파일을 읽을 때 동적 로드

### 예시
```markdown
---
paths:
  - "src/api/**/*.ts"
  - "src/**/*.{ts,tsx}"
---

# API Rules
...
```

### 파일 위치
- `.claude/rules/*.md` — 프로젝트 스코프 (재귀 발견)
- `~/.claude/rules/*.md` — 개인 스코프

---

## 4. Settings (settings.json / settings.local.json)

### 파일 우선순위 (높음 → 낮음)
1. 관리형 정책 (Managed policy)
2. `.claude/settings.local.json` — 로컬 (gitignore)
3. `.claude/settings.json` — 프로젝트 (공유)
4. `~/.claude/settings.json` — 사용자
5. 기본값

### 주요 필드
```json
{
  "permissions": {
    "allow": [],
    "deny": [],
    "defaultMode": "default"
  },
  "hooks": {},
  "env": {},
  "mcpServers": {},
  "model": "claude-opus-4-6",
  "effortLevel": "medium",
  "autoMemoryEnabled": true,
  "claudeMdExcludes": [],
  "disableAllHooks": false
}
```

### defaultMode 옵션
- `default` — 기본 권한 프롬프트
- `acceptEdits` — 파일 편집 자동 승인
- `dontAsk` — 모든 도구 자동 승인
- `bypassPermissions` — 권한 우회
- `plan` — 계획 모드만

---

## 5. Hooks

### 지원 이벤트 타입

| 이벤트 | matcher 지원 | 설명 |
|--------|-------------|------|
| `SessionStart` | ✓ | 세션 시작/재개 |
| `SessionEnd` | ✓ | 세션 종료 |
| `UserPromptSubmit` | ✗ | 프롬프트 제출 |
| `PreToolUse` | ✓ (도구명 regex) | 도구 실행 전 |
| `PostToolUse` | ✓ (도구명 regex) | 도구 실행 후 |
| `PostToolUseFailure` | ✓ | 도구 실행 실패 |
| `PermissionRequest` | ✓ | 권한 다이얼로그 |
| `Notification` | ✓ | 알림 표시 |
| `SubagentStart` | ✓ | 서브에이전트 시작 |
| `SubagentStop` | ✓ | 서브에이전트 종료 |
| `Stop` | ✗ | Claude 응답 완료 |
| `StopFailure` | ✗ | API 에러로 턴 종료 |
| `TaskCompleted` | ✓ | 태스크 완료 |
| `ConfigChange` | ✓ | 설정 변경 |
| `InstructionsLoaded` | ✓ | CLAUDE.md/rules 로드 |
| `PreCompact` | ✗ | 컨텍스트 압축 전 |
| `PostCompact` | ✗ | 컨텍스트 압축 후 |

### Hook 타입
- `command` — 셸 명령어 실행
- `prompt` — Haiku 모델로 단일 턴 검증
- `agent` — 서브에이전트로 다중 턴 검증
- `http` — HTTP POST로 외부 서비스 호출

### Hook 응답
- Exit code 0 = 허용
- Exit code 2 = 거부
- JSON stdout으로 구조화된 제어 가능

### 설정 구조
```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "regex_pattern",
        "hooks": [
          {
            "type": "command",
            "command": "script.sh",
            "timeout": 10000
          }
        ]
      }
    ]
  }
}
```

---

## 6. CLAUDE.md

### 위치 옵션
| 위치 | 스코프 | 로드 |
|------|--------|------|
| `./CLAUDE.md` 또는 `./.claude/CLAUDE.md` | 프로젝트 | 세션 시작 |
| `~/.claude/CLAUDE.md` | 개인 | 세션 시작 |
| `.claude/rules/*.md` | 프로젝트 | 시작 + 동적 |

### Import 문법
```markdown
@path/to/file        — 파일 참조 및 확장
@~/.claude/personal  — 홈 디렉토리
```
- 최대 5 레벨 깊이
- 중첩 import 가능

### 권장사항
- 파일당 200줄 기준, 길면 adherence 감소
- Auto memory (MEMORY.md)는 세션마다 첫 200줄 로드

---

## 7. vibe-flow 체크리스트

새 파일 추가 시 아래를 확인:

- [ ] agents/*.md — 위 표의 공식 필드만 사용했는가
- [ ] skills/*/SKILL.md — 위 표의 공식 필드만 사용했는가
- [ ] rules/*.md — `paths` 외 frontmatter 없는가
- [ ] hooks — 공식 이벤트 타입 + type만 사용했는가
- [ ] settings.json — 공식 필드만 사용했는가
- [ ] setup.sh — 절대 경로로 훅 커맨드를 치환했는가
