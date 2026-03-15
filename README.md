# claude-builds

Claude Code 프로젝트 설정 킷. 에이전트, 스킬, 훅, 규칙을 새 프로젝트에 한 번에 적용한다.

## 빠른 시작

```bash
# 1. 클론
git clone https://github.com/YOUR_USERNAME/claude-builds.git

# 2. 새 프로젝트에 적용
cd /your/project
bash /path/to/claude-builds/setup.sh

# 2-1. 오케스트레이터 포함 설치 (선택)
bash /path/to/claude-builds/setup.sh --with-orchestrators

# 3. 프로젝트별 설정
# .claude/settings.local.json → env 섹션에 환경변수 추가
# CLAUDE.md → 플레이스홀더 채우기
```

## 아키텍처

![claude-builds Architecture](docs/architecture.png)

<details>
<summary>텍스트 다이어그램 보기</summary>

```
┌─────────────────────────────────────────────────────────────────────┐
│                   Orchestration Layer (선택)                         │
│                                                                     │
│  ┌──────────────────────────────┐ ┌──────────────────────────────┐  │
│  │   Claude Squad (로컬 병렬)    │ │ Agent Orchestrator (CI/CD)   │  │
│  │                               │ │                              │  │
│  │  tmux 세션 × N                │ │ GitHub 이슈 → 에이전트 할당  │  │
│  │  각 세션 = git worktree       │ │ CI 실패 → 자동 수정          │  │
│  │  프로필로 에이전트 선택        │ │ 리뷰 코멘트 → 자동 대응      │  │
│  │  cs → TUI 실행                │ │ ao spawn → 에이전트 생성     │  │
│  └──────────────────────────────┘ └──────────────────────────────┘  │
│              │                              │                        │
│              └──────────┬───────────────────┘                        │
│                         ▼                                            │
│              각 세션이 .claude/ 설정 상속                              │
└─────────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        Claude Code CLI                              │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                     CLAUDE.md (프로젝트 컨텍스트)               │  │
│  │            tech stack · structure · commands · rules            │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                │                                    │
│                    ┌───────────┴───────────┐                        │
│                    ▼                       ▼                        │
│  ┌──────────────────────┐   ┌──────────────────────────────────┐   │
│  │   settings.local.json │   │          Rules (3개)              │   │
│  │                       │   │  conventions · git · donts        │   │
│  │  permissions (allow)  │   │                                   │   │
│  │  permissions (deny)   │   │  + 프로젝트별 규칙 (supabase 등)  │   │
│  │  env variables        │   └──────────────────────────────────┘   │
│  │  hooks config         │                                          │
│  └──────────┬────────────┘                                          │
│             │                                                       │
│             ▼                                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                     Hooks Pipeline (7개)                      │   │
│  │                                                               │   │
│  │  ┌─ PreToolUse ──────────────────────────────────────────┐   │   │
│  │  │  command-guard.sh  ── 위험 명령 차단 (force push 등)   │   │   │
│  │  └────────────────────────────────────────────────────────┘   │   │
│  │                          │                                    │   │
│  │                    [도구 실행]                                 │   │
│  │                          │                                    │   │
│  │  ┌─ PostToolUse (Write|Edit) ────────────────────────────┐   │   │
│  │  │  prettier-format.sh  ── 코드 포맷팅                    │   │   │
│  │  │  eslint-fix.sh       ── 린트 자동 수정                 │   │   │
│  │  │  typecheck.sh        ── TypeScript 타입 체크           │   │   │
│  │  │  test-runner.sh      ── 관련 테스트 실행               │   │   │
│  │  └────────────────────────────────────────────────────────┘   │   │
│  │                                                               │   │
│  │  ┌─ Stop (세션 종료) ────────────────────────────────────┐   │   │
│  │  │  uncommitted-warn.sh ── 미커밋 변경 경고               │   │   │
│  │  │  session-log.sh      ── 세션 로그 저장                 │   │   │
│  │  └────────────────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    Skills (9개) — /명령어                      │   │
│  │                                                               │   │
│  │  ┌─ 개발 ────────┐  ┌─ 품질 ────────┐  ┌─ 운영 ────────┐   │   │
│  │  │ /commit        │  │ /verify       │  │ /status       │   │   │
│  │  │ /scaffold      │  │ /feedback     │  │ /security     │   │   │
│  │  │ /design-sync   │  │ /test         │  │ /review-pr    │   │   │
│  │  └────────────────┘  └───────────────┘  └───────────────┘   │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                │                                    │
│                                ▼                                    │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    Agents (6개) — 전문 위임                    │   │
│  │                                                               │   │
│  │   ┌──────────┐ ┌──────────┐ ┌──────────┐                    │   │
│  │   │ planner  │ │ designer │ │developer │                    │   │
│  │   │ 작업 분해 │ │ UI/UX    │ │ 구현     │                    │   │
│  │   └──────────┘ └──────────┘ └──────────┘                    │   │
│  │   ┌──────────┐ ┌──────────┐ ┌──────────┐                    │   │
│  │   │ feedback │ │    qa    │ │ security │                    │   │
│  │   │ 코드리뷰  │ │ 테스트   │ │ 보안스캔 │                    │   │
│  │   └──────────┘ └──────────┘ └──────────┘                    │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────┐
                    │    setup.sh          │
                    │                     │
                    │  claude-builds 에서  │
                    │  프로젝트로 복사     │
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              ▼                ▼                ▼
     ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
     │  Project A   │ │  Project B   │ │  Project C   │
     │  .claude/    │ │  .claude/    │ │  .claude/    │
     │  ├─agents/   │ │  ├─agents/   │ │  ├─agents/   │
     │  ├─hooks/    │ │  ├─hooks/    │ │  ├─hooks/    │
     │  ├─skills/   │ │  ├─skills/   │ │  ├─skills/   │
     │  └─rules/    │ │  └─rules/    │ │  └─rules/    │
     └──────────────┘ └──────────────┘ └──────────────┘
```

### 워크플로우

```
사용자 입력
    │
    ▼
┌─ Rules 참조 ──────────────────────────────────────────┐
│  conventions.md + git.md + donts.md                    │
└────────────────────────────────────────────────────────┘
    │
    ▼
┌─ 작업 유형 판별 ──────────────────────────────────────┐
│                                                        │
│  스킬 호출 (/commit 등)  →  Skill 실행                 │
│  복잡한 작업             →  Agent 위임 (planner 등)    │
│  일반 코딩               →  직접 수행                  │
│                                                        │
└────────────────────────────────────────────────────────┘
    │
    ▼
┌─ 코드 수정 (Write/Edit) ─────────────────────────────┐
│                                                        │
│  PreToolUse   → command-guard.sh (차단 여부 판별)      │
│  도구 실행    → 파일 생성/수정                         │
│  PostToolUse  → prettier → eslint → tsc → test        │
│                                                        │
└────────────────────────────────────────────────────────┘
    │
    ▼
┌─ 세션 종료 ──────────────────────────────────────────┐
│  uncommitted-warn.sh  →  session-log.sh               │
└────────────────────────────────────────────────────────┘
```

</details>

## 구성 요소

### Agents (6개)

| 에이전트 | 역할 | 모델 |
|---------|------|------|
| `designer` | UI/UX 디자인, Tailwind CSS 스타일링 | opus |
| `developer` | Server Actions, React 컴포넌트 구현 | opus |
| `feedback` | 코드 품질 분석, 개선 제안 | opus |
| `planner` | 작업 분해, 영향 분석, 구현 계획 | opus |
| `qa` | Vitest + Playwright 테스트 작성/실행 | opus |
| `security` | OWASP Top 10 보안 스캔 | opus |

### Skills (9개)

| 스킬 | 호출 | 설명 |
|------|------|------|
| `commit` | `/commit` | Conventional Commit 자동 생성 |
| `design-sync` | `/design-sync <URL>` | 디자인 URL에서 CSS 추출 → 코드 싱크 |
| `feedback` | `/feedback` | 최근 변경사항 품질 분석 |
| `review-pr` | `/review-pr [N]` | GitHub PR 코드 리뷰 |
| `scaffold` | `/scaffold [domain]` | 새 도메인 보일러플레이트 생성 |
| `security` | `/security` | 전체 코드 보안 스캔 |
| `status` | `/status` | 프로젝트 상태 대시보드 |
| `test` | `/test [file]` | 단위 테스트 자동 생성 |
| `verify` | `/verify` | lint → typecheck → test → e2e 검증 |

### Hooks (7개)

| 훅 | 트리거 | 역할 |
|----|--------|------|
| `command-guard.sh` | PreToolUse (Bash) | 위험 명령 차단 |
| `prettier-format.sh` | PostToolUse (Write/Edit) | 코드 포맷팅 |
| `eslint-fix.sh` | PostToolUse (Write/Edit) | 린트 자동 수정 |
| `typecheck.sh` | PostToolUse (Write/Edit) | TypeScript 타입 체크 |
| `test-runner.sh` | PostToolUse (Write/Edit) | 관련 테스트 실행 |
| `uncommitted-warn.sh` | Stop | 미커밋 변경 경고 |
| `session-log.sh` | Stop | 세션 로그 저장 |

### Rules (3개 공통 + 템플릿)

| 규칙 | 내용 |
|------|------|
| `conventions.md` | 코드 스타일, 파일 크기, Server Action 패턴 |
| `git.md` | Conventional Commits, PR 규칙 |
| `donts.md` | console.log, any 타입, 하드코딩 시크릿 금지 |
| `templates/rules/supabase.md` | Supabase 프로젝트용 규칙 (선택) |

## 디렉토리 구조

```
claude-builds/
├── README.md
├── setup.sh                       # 원클릭 설치 스크립트 (--with-orchestrators)
├── settings/
│   └── settings.template.json     # 권한, 훅, env 템플릿
├── agents/                        # 6개 전문 에이전트
├── hooks/                         # 7개 자동화 훅
├── skills/                        # 9개 CLI 스킬
├── rules/                         # 3개 공통 규칙
├── orchestrators/                 # 오케스트레이터 설정 (선택)
│   ├── README.md
│   ├── claude-squad/
│   │   └── config.template.json
│   └── agent-orchestrator/
│       └── agent-orchestrator.template.yaml
└── templates/                     # 프로젝트별 템플릿
    ├── CLAUDE.md.template
    └── rules/
        └── supabase.md
```

## 프로젝트별 커스텀

setup 후 추가할 수 있는 항목:

- `.claude/rules/` — 프로젝트 고유 규칙 추가 (예: `supabase.md`, `prisma.md`)
- `.claude/settings.local.json` — `env`에 환경변수, `deny`에 위험 명령 추가
- `.claude/agents/` — 프로젝트 특화 에이전트 추가
- `.claude/skills/` — 프로젝트 특화 스킬 추가

## 오케스트레이터 (선택)

멀티 에이전트 세션을 관리하는 도구. `setup.sh --with-orchestrators`로 설정.

### Claude Squad — 로컬 병렬 작업

```bash
brew install claude-squad
cs                          # TUI 실행, 프로필로 에이전트 지정
```

6개 에이전트가 프로필로 매핑. 각 세션은 독립 git worktree에서 실행되어 충돌 없이 병렬 작업 가능.

| 프로필 | 에이전트 | 역할 |
|--------|----------|------|
| `planner` | planner.md | 작업 분해, 영향 분석 |
| `designer` | designer.md | UI/UX 설계 |
| `developer` | developer.md | 코드 구현 |
| `feedback` | feedback.md | 코드 품질 리뷰 |
| `qa` | qa.md | 테스트 작성/실행 |
| `security` | security.md | OWASP 보안 스캔 |

### Agent Orchestrator — CI/CD 자동화

```bash
# 설치: https://github.com/ComposioHQ/agent-orchestrator
ao start                    # 오케스트레이터 시작
ao spawn my-app ISSUE-42    # 이슈에 에이전트 할당
```

| 이벤트 | 동작 |
|--------|------|
| CI 실패 | 에이전트가 로그 분석 → 자동 수정 (2회 재시도) |
| 변경 요청 | 리뷰 코멘트 기반 자동 수정 |
| 승인 + 통과 | 알림 (자동 머지 옵션) |

### 조합 워크플로우

```
로컬 개발 (Claude Squad)          CI/CD (Agent Orchestrator)
┌────────────────────┐           ┌──────────────────────┐
│ 세션1: 프론트엔드    │  PR push  │ CI 실패 → 자동 수정   │
│ 세션2: 백엔드 API   │ ───────→ │ 리뷰 → 자동 반영      │
│ 세션3: 테스트       │           │ 승인 → 머지 알림      │
└────────────────────┘           └──────────────────────┘
```

자세한 내용은 [`orchestrators/README.md`](orchestrators/README.md) 참조.

## 기술 스택 호환성

현재 Next.js + TypeScript + Tailwind CSS 기반으로 최적화되어 있으나,
hooks와 rules를 수정하면 다른 스택에도 적용 가능:

- **hooks**: Prettier/ESLint/TypeScript 경로만 수정
- **rules**: 프레임워크별 conventions 수정
- **agents**: 범용적으로 설계됨

## 라이선스

MIT
