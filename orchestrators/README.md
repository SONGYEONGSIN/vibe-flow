# Orchestrators

claude-builds의 에이전트를 멀티 세션으로 오케스트레이션하는 도구 설정.

## 개요

| 도구 | 용도 | 설치 | 설정 위치 |
|------|------|------|-----------|
| Claude Squad | 로컬 tmux 멀티 에이전트 | `brew install claude-squad` | `~/.claude-squad/config.json` |
| Agent Orchestrator | CI/CD 연동 자동화 | `git clone` + `pnpm build` | 프로젝트 루트 `agent-orchestrator.yaml` |

## Claude Squad

### 설치

```bash
brew install claude-squad
```

### 설정 적용

```bash
# setup.sh --with-orchestrators 가 자동 수행
# 또는 수동:
cp orchestrators/claude-squad/config.template.json ~/.claude-squad/config.json
```

### 에이전트-프로필 매핑

| 프로필 | 에이전트 | 역할 | 도구 권한 |
|--------|----------|------|-----------|
| planner | agents/planner.md | 작업 분해, 영향 분석 | Read, Grep, Glob, Agent |
| designer | agents/designer.md | UI/UX 설계, Tailwind CSS | Read, Grep, Glob |
| developer | agents/developer.md | 코드 구현 | Read, Grep, Glob, Bash, Edit, Write |
| feedback | agents/feedback.md | 코드 품질 리뷰 | Read, Grep, Glob, Bash |
| qa | agents/qa.md | 테스트 작성/실행 | Read, Grep, Glob, Bash, Edit, Write |
| security | agents/security.md | OWASP 보안 스캔 | Read, Grep, Glob |
| retrospective | agents/retrospective.md | 메트릭 분석, 개선안 도출 | Read, Grep, Glob, Bash |
| grader | agents/grader.md | eval 결과 채점 | Read, Grep, Glob, Bash |
| comparator | agents/comparator.md | 블라인드 A/B 비교 | Read, Grep, Glob |
| skill-reviewer | agents/skill-reviewer.md | 스킬 품질 8단계 검토 | Read, Grep, Glob |

### 사용법

```bash
cs                    # TUI 실행

# TUI 내에서:
# n → 새 세션 생성 (프로필 선택)
# tab → 출력/diff 전환
# s → 커밋 + GitHub push
# c → 커밋 + 일시중지
```

### 병렬 작업 패턴

```
세션 1 (developer): feat/user-profile 브랜치 — 사용자 프로필 구현
세션 2 (developer): feat/dashboard 브랜치 — 대시보드 구현
세션 3 (qa):        test/coverage 브랜치 — 기존 기능 테스트 보강
```

각 세션은 독립 git worktree에서 동작 → 충돌 없이 병렬 작업 가능.

### 추천 워크플로우

```
1. planner 세션 → 작업 계획 수립
2. designer 세션 → UI/UX 설계
3. developer 세션 × N → 병렬 구현 (기능별 분리)
4. qa 세션 → 테스트 작성
5. feedback 세션 → 코드 리뷰
6. security 세션 → 보안 점검
7. retrospective 세션 → 메트릭 분석 + 개선안 도출
8. grader 세션 → eval 채점 (스킬 품질 측정 시)
```

---

## Agent Orchestrator

### 설치

```bash
git clone https://github.com/ComposioHQ/agent-orchestrator.git
cd agent-orchestrator && pnpm install && pnpm build
# ao 명령이 PATH에 포함되도록 설정
```

### 설정 적용

```bash
# setup.sh --with-orchestrators 가 자동 수행
# 또는 수동:
cp orchestrators/agent-orchestrator/agent-orchestrator.template.yaml \
   /your/project/agent-orchestrator.yaml
# {{PLACEHOLDER}} 값 수정
```

### 리액션 시스템

| 이벤트 | 자동 | 동작 |
|--------|------|------|
| CI 실패 | O | 에이전트가 로그 분석 → 자동 수정 (2회 재시도) |
| 변경 요청 | O | 리뷰 코멘트 기반 자동 수정 (30분 타임아웃) |
| 승인 + 통과 | X | 알림만 (`auto: true`로 자동 머지 가능) |

### 사용법

```bash
ao start                          # 오케스트레이터 시작
ao spawn my-app ISSUE-42          # 이슈에 에이전트 할당
ao send session-1 "구현하라"       # 세션에 지시
ao status                         # 전체 상태 확인
ao dashboard                      # 웹 대시보드 (localhost:3001)
```

---

## 두 도구 조합

```
개발자 (로컬)
    │
    ▼
┌─ Claude Squad (tmux) ──────────────────┐
│  세션1: 프론트엔드 (워크트리 A)          │
│  세션2: 백엔드 API (워크트리 B)          │
│  세션3: 테스트 (워크트리 C)              │
│  → 완료되면 PR 생성                      │
└────────────────────────────────────────┘
    │ PR push
    ▼
┌─ Agent Orchestrator (CI/CD) ───────────┐
│  CI 실패 → 자동 수정                     │
│  리뷰 코멘트 → 자동 반영                 │
│  승인 + 통과 → 머지 알림                 │
└────────────────────────────────────────┘
```

## 선택 가이드

| 상황 | 추천 |
|------|------|
| 로컬에서 여러 작업 병렬 처리 | Claude Squad |
| CI/CD 파이프라인 자동화 | Agent Orchestrator |
| GitHub 이슈 자동 할당 | Agent Orchestrator |
| 빠른 프로토타이핑 | Claude Squad |
| 팀 협업 + 자동 리뷰 대응 | Agent Orchestrator |
| 개발~배포 전 구간 자동화 | 둘 다 사용 |

## 비용 관리

- 병렬 에이전트 수 = API 비용 배수
- 복잡 작업 (planner, developer): Opus 모델
- 단순 작업 (feedback, qa, security): Sonnet/Haiku 모델
- 경계가 명확한 작업만 병렬화
