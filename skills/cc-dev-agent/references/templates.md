# MD 파일 템플릿

Claude Code 프로젝트 핵심 마크다운 파일 템플릿.

## 파일 역할

| 파일 | 역할 | 비유 |
|------|------|------|
| CLAUDE.md | 프로젝트 규칙 | 사규 |
| spec.md | 요구사항 정의 | 설계도 |
| prompt_plan.md | 구현 계획표 | 작업 지시서 |
| .gitignore | Git 제외 파일 | 차단 목록 |

---

## .gitignore (CRITICAL - 먼저 설정)

**위치**: 프로젝트 루트

**중요**: 병렬 워크트리 사용 시 `.claude/context/` 미포함 → 병합 충돌 발생

```gitignore
# Dependencies
node_modules/
.pnp
.pnp.js

# Build outputs
.next/
out/
build/
dist/

# Environment
.env
.env.local
.env.*.local

# IDE
.idea/
.vscode/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Claude Code 자동 생성 (병렬 워크트리 충돌 방지) - CRITICAL
.claude/context/
.claude/settings.json
.claude/settings.local.json
.claude/handoff.md
CLAUDE.local.md

# Debug
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Testing
coverage/
```

---

## CLAUDE.md

**위치**: 프로젝트 루트 또는 `~/.claude/CLAUDE.md`

**원칙**: 짧고 간결 (150~200개 지시사항 이하), 추론 불가능한 정보만

```markdown
# [프로젝트명]

## 개요
- [한 줄 설명]

## 기술 스택
- Frontend: Next.js 14, Tailwind CSS
- Backend: FastAPI, PostgreSQL

## 핵심 명령어
- `npm run dev`: 개발 서버
- `npm test`: 테스트
- `npm run lint`: 린트

## 규칙
- **테스트 우선**: TDD 필수
- **언어**: 주석/커밋 한국어
- **타입 안전**: strict 모드, any 금지

## 금지 사항
- any 타입 사용
- 하드코딩된 API 키/비밀번호
- /legacy 폴더 수정

## 병렬 개발 주의사항
- `.gitignore`에 `.claude/context/` 포함 확인 필수
- 워크트리 생성 전 `git status`로 `.claude/` 변경사항 확인
```

---

## spec.md

**위치**: 프로젝트 루트 또는 `docs/spec.md`

**원칙**: 600줄 이하, 구체적으로 (모호함 = 환각 유발)

```markdown
# 프로젝트: [프로젝트명]

## 1. 목표
[무엇을, 누구를 위해, 왜]

## 2. 핵심 기능

### P0 (MVP 필수)
- [ ] 이메일/비밀번호 로그인 (JWT)
- [ ] 목록 조회
- [ ] 상세 페이지

### P1 (추후)
- [ ] 소셜 로그인

## 3. 기술 스택
- Frontend: Next.js 14, TypeScript
- Backend: FastAPI, Python 3.11
- Database: PostgreSQL 15

## 4. 데이터 모델

### User
| 필드 | 타입 | 설명 |
|------|------|------|
| id | UUID | PK |
| email | string | unique |
| password_hash | string | bcrypt |

## 5. API 엔드포인트

| 메서드 | 경로 | 설명 |
|--------|------|------|
| POST | /auth/register | 회원가입 |
| POST | /auth/login | 로그인 |

## 6. 예외 처리
- 이메일 형식 오류 → 400
- 중복 이메일 → 409

## 7. 성공 기준
- 인증 API 테스트 통과
- 테스트 커버리지 80%+
```

---

## prompt_plan.md

**위치**: 프로젝트 루트

**원칙**: TDD 방식, 1-2시간 단위 Task, Milestone 그룹화

```markdown
# 구현 계획

## Milestone 1: 셋업
- [ ] Task 1.1: 프로젝트 초기화
- [ ] Task 1.2: ESLint, Prettier 설정
- [ ] Task 1.3: DB 연결

## Milestone 2: 인증
- [ ] Task 2.1: 회원가입 테스트 (Red)
- [ ] Task 2.2: 회원가입 구현 (Green)
- [ ] Task 2.3: 로그인 테스트 (Red)
- [ ] Task 2.4: 로그인 구현 (Green)

## Milestone 3: 핵심 기능
- [ ] Task 3.1: 목록 API 테스트 (Red)
- [ ] Task 3.2: 목록 API 구현 (Green)

## Milestone 4: 최종
- [ ] Task 4.1: 전체 테스트
- [ ] Task 4.2: 보안 검토
```

---

## Custom Sub-agent

**위치**: `.claude/agents/[name].md`

```markdown
---
name: code-reviewer
description: 코드 품질 및 보안 리뷰
tools: Read, Grep
model: sonnet
---

시니어 코드 리뷰어로서 검토:
1. 보안 취약점 (SQL Injection, XSS)
2. 성능 이슈 (N+1, 불필요한 루프)
3. 가독성 및 유지보수성

이슈를 Critical/Major/Minor로 분류.
```

---

## Hooks 설정

**위치**: `.claude/settings.json`

```json
{
  "hooks": {
    "Stop": [
      { "command": "afplay /path/to/notification.mp3" }
    ]
  }
}
```

---

## 새 프로젝트 초기화 체크리스트

```bash
# 1. Git 초기화
git init

# 2. .gitignore 먼저 생성 (CRITICAL)
# 위 .gitignore 템플릿 복사

# 3. 초기 커밋
git add .gitignore
git commit -m "init: .gitignore 설정"

# 4. CLAUDE.md 생성
# 위 템플릿 기반으로 작성

# 5. spec.md, prompt_plan.md 생성

# 6. 코드 추가 후 커밋
git add .
git commit -m "init: 프로젝트 초기 설정"
```
