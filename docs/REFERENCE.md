# vibe-flow Reference

전체 명령 / 에이전트 / 훅 / 규칙 레퍼런스.

## Skills (25 — Core 16 + Extensions 9)

### Core 16

| 스킬 | 호출 | 설명 |
|------|------|------|
| brainstorm | `/brainstorm "<주제>"` | 의도/제약/대안 구조화 탐색 |
| plan | `/plan` | 멀티스텝 계획 파일화·추적 |
| finish | `/finish` | 머지/PR/cleanup 의사결정 트리 |
| release | `/release [version]` | semver + CHANGELOG + tag |
| scaffold | `/scaffold [domain]` | 보일러플레이트 자동 생성 |
| test | `/test [file]` | Vitest 단위 테스트 자동 생성 |
| worktree | `/worktree [create\|list\|remove]` | git worktree 격리 |
| verify | `/verify` | lint + tsc + test + e2e |
| security | `/security` | OWASP Top 10 스캔 |
| commit | `/commit` | Conventional commit 자동 생성 |
| review-pr | `/review-pr [N]` | GitHub PR 리뷰 |
| receive-review | `/receive-review [<source>]` | 리뷰 피드백 비판적 수용 |
| status | `/status` | 프로젝트 상태 대시보드 |
| learn | `/learn [save\|show]` | 메모리 관리 |
| onboard | `/onboard [--refresh]` | 5단계 자가진단 + 다음 행동 추천 |
| menu | `/menu [core\|extensions\|<category>]` | 24 스킬 카테고리별 + 사용 분포 + Stage 추천 |

### Extensions 9

#### meta-quality
| 스킬 | 호출 |
|------|------|
| eval-skill | `/eval <skill>` |
| evolve | `/evolve <skill>` |

#### design-system
| 스킬 | 호출 |
|------|------|
| design-sync | `/design-sync <URL\|이미지\|--from-file>` |
| design-audit | `/design-audit` |

#### deep-collaboration
| 스킬 | 호출 |
|------|------|
| pair | `/pair "<task>"` |
| discuss | `/discuss "<주제>"` |

#### learning-loop
| 스킬 | 호출 |
|------|------|
| metrics | `/metrics [today\|week\|all]` |
| retrospective | `/retrospective` |

#### code-feedback
| 스킬 | 호출 |
|------|------|
| feedback | `/feedback` |

## Agents (12 — Core 10 + Extensions 2)

### Core 10
- `@developer` — 구현
- `@qa` — 테스트
- `@security` — OWASP
- `@validator` — Pair mode 검증
- `@planner` — 작업 분해
- `@feedback` — 코드 품질
- `@moderator` — 토론 중재
- `@comparator` — A/B 비교
- `@designer` — UI/UX (Phase 0 자율 모드)
- `@retrospective` — 회고 분석

### Extensions 2 (meta-quality)
- `@skill-reviewer` — 8단계 100점 스코어카드
- `@grader` — eval 채점

## Hooks (22 — 모두 Core)

### PreToolUse
- `command-guard.sh` — 27 패턴 위험 명령 차단 (jq fail-closed)
- `smart-guard.sh` — patterns.md 학습 패턴 2차 검증
- `tdd-enforce.sh` — 테스트 없이 코드 수정 차단 (strict 기본)

### PostToolUse (Write/Edit)
- `prettier-format.sh` — 포맷
- `eslint-fix.sh` — 린트 자동 수정
- `typecheck.sh` — TypeScript 체크
- `test-runner.sh` — 관련 테스트 실행
- `metrics-collector.sh` — 3중 기록 (JSON + SQLite + JSONL)
- `pattern-check.sh` — 학습 패턴 준수
- `design-lint.sh` — 하드코딩 색상 (oklch 포함) 감지
- `debate-trigger.sh` — 충돌 시 토론 자동 개시
- `readme-sync.sh` — README 수치 자동 동기화

### PostToolUseFailure
- `tool-failure-handler.sh` — 13-class 에러 분류 + 복구 힌트

### PreCompact
- `pre-compact.sh` — 컨텍스트 압축 전 브랜치/커밋 보존
- `context-prune.sh` — events.jsonl 1줄 요약 (12KB 예산)

### Stop
- `uncommitted-warn.sh` — 미커밋 변경 경고
- `session-review.sh` — 품질 종합 리뷰
- `session-log.sh` — 세션 로그 저장

### Notification
- `notify.sh` — 데스크톱 알림 (macOS)
- `model-suggest.sh` — events 패턴 분석 → 모델 전환 제안

### 유틸리티
- `_common.sh` — 공용 함수 (truncate, mtime, hex)
- `message-bus.sh` — 에이전트 간 메시지 송수신

## Rules (6)

- `tdd.md` — Iron Law: RED-GREEN-REFACTOR
- `donts.md` — 합리화 방지 표 13건
- `git.md` — Conventional Commits + HARD-GATE
- `design.md` — 디자인 토큰 / 하드코딩 금지 / arbitrary value 정책
- `conventions.md` — 코드 스타일 + Server Action 패턴
- `debugging.md` — 4단계 체계적 디버깅

## setup.sh CLI

```bash
bash setup.sh                                   # Core only
bash setup.sh --all                             # Core + 5 extensions
bash setup.sh --extensions <name>[,<name>...]   # 선택
bash setup.sh --remove-extension <name>         # 제거
bash setup.sh --list-extensions                 # 목록
bash setup.sh --info <name>                     # 상세
bash setup.sh --check                           # validate.sh 단축
bash setup.sh --with-orchestrators              # Squad/AO 포함
bash setup.sh --force                           # 백업 없이 덮어쓰기
```

## State File — `.claude/.vibe-flow.json`

```json
{
  "vibe_flow_version": "1.0.0",
  "installed_at": "ISO 8601",
  "last_updated_at": "ISO 8601",
  "core_files": ["..."],
  "extensions": {
    "<name>": {
      "version": "1.0.0",
      "installed_at": "ISO 8601",
      "files": ["..."]
    }
  }
}
```

## Events.jsonl Type 분포

| Type | 발생 위치 | 핵심 필드 |
|------|----------|----------|
| `tool_result` | metrics-collector | tool, file, results |
| `tool_failure` | tool-failure-handler | tool, error_class, error |
| `verify_complete` | verify | overall, results |
| `commit_created` | commit | commit_type, files_changed, sha |
| `security_scan` | security | high, medium, low, overall |
| `release` | release | version, semver_type, commits |
| `feedback` | feedback | score, items, files |
| `review_pr` | review-pr | pr, score, verdict |
| `discuss` | discuss | debate_id, participants, rounds, verdict_type |
| `design_audit` | design-audit | coverage, violations, duplicate_patterns |
| `design_sync` | design-sync | mode, sync_rate_initial/final |
| `learn_save` | learn | category, summary |
| `brainstorm` | brainstorm | topic, alternatives, chosen |
| `plan_created` / `plan_step_complete` | plan | plan_id, steps, hard_gate |
| `finish` | finish | path, branch, changed_files |
| `review_received` | receive-review | source, items, accepted/rejected/clarify |
| `pair_session` | pair | iterations, verdict |
| `skill_evolve` | evolve | skill, baseline, candidate, improved |
