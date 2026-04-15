---
name: pair
description: Builder(developer) + Validator(validator) 페어 프로그래밍 워크플로우. Builder는 작업하고, Validator는 fresh-context로 검증해 binary 판정(approved/needs-revision)을 회신한다.
---

# Pair Mode — Builder + Validator

커뮤니티 패턴([disler/claude-code-hooks-mastery](https://github.com/disler/claude-code-hooks-mastery)) 적용. 단일 에이전트가 자기 작업을 자가검증하는 한계를 **구조적 역할 분리**로 해소한다.

## 언제 사용하는가

**적합한 경우**:
- 머지/배포 전 **독립 검증**이 필요한 작업
- 버그 수정 후 regression test 유효성 검증
- 스펙 해석이 애매해서 **제3자 관점**이 필요한 기능 추가
- AI가 "대충 맞을 것 같다"며 급하게 끝내려는 경향 차단

**부적합한 경우**:
- 단순 타이포 수정, 로그 문자열 변경 (오버헤드만 큼)
- 탐색/리서치 작업 (결과물이 코드가 아님)
- 프로토타입 단계 (아직 검증 기준이 없음)

## 역할 분리

| 역할 | 에이전트 | 권한 | 책임 |
| --- | --- | --- | --- |
| **Builder** | `developer` | 풀 (Read/Edit/Write/Bash) | 구현 + 테스트 작성 + 자기 기준 통과까지 |
| **Validator** | `validator` | Read/Grep/Glob/Bash (Edit/Write 차단) | 실제 테스트 실행 + binary 판정 |

Validator는 **수정 권한이 없다**. 제안만 하고 회신. Builder가 다시 수정.

## 실행 흐름

```
/pair "작업 설명"
  ↓
1. 태스크 파싱 — task, acceptance_criteria 추출
2. Builder 스폰 (developer 에이전트)
   - TDD: 실패 테스트 작성 → 구현 → 타입/린트/테스트 통과
3. Builder 완료 시: pair-review-request 메시지 → validator
4. Validator 기동:
   - 스펙 재확인
   - git diff 범위 확인
   - TDD 증거 (테스트 커밋이 구현보다 먼저)
   - 실제 테스트 실행 (npx vitest/jest)
   - tsc --noEmit / eslint 실행
   - 영향 범위 grep
5. 판정:
   ├─ approved   → Builder 종료, 작업 머지 가능
   └─ needs-revision → Builder 재실행 (최대 3회)
6. 3회 반려 시: moderator 소환 (교착 해소)
```

## 사용법

### 1. 수동 (Claude Squad 환경)

```bash
# 터미널 1 — Builder 세션
cs → n → "developer" 프로필 선택 → 작업 설명 입력 → 구현
# (developer 에이전트가 작업 완료 시 자동으로 pair-review-request 발송)

# 터미널 2 — Validator 세션
cs → n → "validator" 프로필 선택 → 수신함 처리
```

### 2. 스크립트 기동 (단일 터미널)

```bash
# Builder 작업 완료 후
bash .claude/hooks/message-bus.sh send developer validator pair-review-request high \
  "[pair] feat/foo 검증 요청" \
  '{"task":"...", "branch_or_worktree":"feat/foo", "test_file":"src/foo.test.ts", "acceptance_criteria":[...]}'

# Validator 기동 (다른 세션 or 같은 세션에서 컨텍스트 초기화 후)
bash .claude/hooks/message-bus.sh list validator
# → 메시지 내용 읽고 validator 에이전트 호출
```

### 3. Agent Orchestrator 연동 (CI/CD)

`agent-orchestrator.yaml`의 reactions에 추가:

```yaml
reactions:
  pair-mode:
    on: "task-marked-complete"
    action: "spawn validator with pair-review-request payload"
    follow_up:
      approved: "merge"
      needs-revision: "re-spawn developer with feedback"
    max_iterations: 3
```

## Builder 측 프로토콜 (developer 에이전트)

작업 완료 판단 기준:
- [ ] 실패 테스트(RED) → 구현(GREEN) 순서 지킴
- [ ] `npx vitest run`, `npx tsc --noEmit`, `npx eslint` 모두 통과
- [ ] git commit 남김 (커밋 메시지에 스펙 명시)

그 후:
```bash
bash .claude/hooks/message-bus.sh send developer validator pair-review-request high \
  "[pair] <작업명> 검증 요청" \
  "$(jq -n --arg task "$TASK" --arg branch "$BRANCH" --arg tests "$TEST_FILES" \
     '{task:$task, branch_or_worktree:$branch, test_file:$tests, acceptance_criteria:[
       "전체 테스트 통과", "TypeScript 에러 0", "TDD 증거 (테스트 커밋 선행)"
     ]}')"
```

## Validator 측 프로토콜

`agents/validator.md`의 "검증 절차" 7단계 참조:
1. 스펙 재확인
2. 변경 범위 파악 (`git diff --stat`)
3. TDD 증거 확인 (`git log --follow`)
4. 테스트 실행 (실제로)
5. 정적 검사 (tsc, eslint)
6. 영향 범위 grep
7. 판정 + 회신

## 재시도 루프 (needs-revision)

1. Validator가 `needs-revision` 반환 시, Builder는 BLOCKER 항목만 수정 (SUGGESTED는 추후)
2. 재수정 후 다시 `pair-review-request` 발송
3. **최대 3회까지**. 3회 반려 시 **자동으로 moderator 에이전트 소환**:

```bash
bash .claude/hooks/message-bus.sh send validator moderator debate-invite critical \
  "[pair] 3회 반려 — 교착 해소 요청" \
  "Builder(developer)와 Validator(validator) 사이 3회 반려 발생. 쟁점 검토 요청."
```

## 메트릭 기록 (선택)

Pair 세션 종료 후 `.claude/events.jsonl`에 요약 append 권장 (observability와 연동):

```bash
echo '{"ts":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","type":"pair_session","task":"...","iterations":2,"verdict":"approved","duration_sec":420}' \
  >> .claude/events.jsonl
```

쿼리:
```bash
bash .claude/scripts/watch-events.sh --raw | jq 'select(.type == "pair_session")'
```

## 한계 및 확장

**현재 한계**:
- 수동 트리거 (자동 reaction 없음) — Agent Orchestrator 연동 시 해소
- 단일 Validator — 복잡 작업은 validator × N 병렬 검증 (향후)
- 모더레이터 교착 해소가 사람 개입 필요 — 자동화 여지

**확장 여지 (ROADMAP 후속)**:
- `pair --parallel-validators` 플래그로 validator 다수 스폰
- validator memory의 learnings를 Builder에게 사전 전달 (반복 실수 예방)
- `pair --mode strict` (Validator 반려 시 worktree 롤백)
