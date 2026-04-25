---
name: pair
description: Builder(developer) + Validator(validator) 페어 프로그래밍 자동 오케스트레이션. /pair "task"로 호출하면 Claude가 단일 세션에서 developer → validator 루프를 자동 실행하고 최종 판정(approved/needs-revision)까지 보고한다.
effort: high
---

# Pair Mode — 자동 오케스트레이션 스킬

커뮤니티 패턴([disler/claude-code-hooks-mastery](https://github.com/disler/claude-code-hooks-mastery)) 적용. 단일 에이전트 자가검증의 한계를 **Builder + Validator 구조적 역할 분리**로 해소하며, **L2 자동화**로 전체 루프를 `/pair` 한 번에 돌린다.

## 사용법

```
/pair "사용자 로그인 기능 구현"
/pair "checkout.ts의 totalAmount 계산 버그 수정"
/pair "Button 컴포넌트 props 인터페이스 리팩터링"
```

`$ARGUMENTS`에 작업 설명 전달. 설명이 비어 있으면 Claude가 사용자에게 명확화 질문.

## 역할 분리 (불변)

| 역할 | 에이전트 | 권한 | 책임 |
| --- | --- | --- | --- |
| **Builder** | `developer` | Read/Grep/Glob/Bash/Edit/Write | 구현 + 테스트 작성 + 자기 기준 통과까지 |
| **Validator** | `validator` | Read/Grep/Glob/Bash (Edit/Write 차단) | 실제 테스트 실행 + binary 판정 |

Validator는 수정 권한 없음. 제안만 하고 회신. Builder가 다시 수정.

## 오케스트레이션 절차 (Claude가 실행)

### 1. 작업 파싱

`$ARGUMENTS`에서 작업 설명 추출:
- 비어 있으면 사용자에게 "어떤 작업을 pair mode로 처리할까요?" 질문 후 대기
- 길이 너무 짧으면(10자 미만) acceptance criteria 도출이 어려우니 추가 설명 요청

획득한 후 아래 컨텍스트 초기화:
```
TASK_DESC = $ARGUMENTS
ITERATION = 0
MAX_ITERATIONS = 3
PREV_FEEDBACK = null
```

### 2. Builder 스폰 (Agent 도구)

`Agent` 도구로 developer 에이전트 위임. **agents/developer.md의 내용을 시스템 프롬프트 컨텍스트로 제공**:

```
subagent_type: "general-purpose"
description: "Pair mode Builder"
prompt: """
너는 `developer` 에이전트다. `.claude/agents/developer.md`의 역할·규칙을 그대로 따른다.

## 작업
{TASK_DESC}

## 이전 반려 피드백 (있으면)
{PREV_FEEDBACK or "없음 (최초 시도)"}

## 완료 기준 체크리스트
- [ ] 실패 테스트(RED) → 구현(GREEN) → 리팩터(IMPROVE) 순서 지킴 (커밋 이력에 반영)
- [ ] `npx vitest run`, `npx tsc --noEmit`, `npx eslint` 모두 종료 코드 0
- [ ] git commit 완료 (커밋 메시지에 스펙 명시)

## 출력 형식
작업 완료 후 아래 JSON 1개 출력:
{
  "status": "completed",
  "branch_or_worktree": "<현재 브랜치 or worktree 경로>",
  "test_files": ["<테스트 파일 경로 리스트>"],
  "changed_files": ["<변경 파일 경로 리스트>"],
  "commit_hashes": ["<추가한 커밋 해시>"],
  "summary": "<1~3줄 변경 요약>"
}

테스트 실패 or 타입 에러가 남은 상태면 "status": "incomplete"와 함께 이유를 출력하고 종료.
"""
```

Builder 결과 파싱:
- `status: "completed"` → 3단계로 진행
- `status: "incomplete"` → 사용자에게 즉시 보고 후 중단 (Builder 자가판단 불충족)

### 3. Validator 스폰 (Agent 도구)

`Agent` 도구로 validator 에이전트 위임. **agents/validator.md의 내용을 시스템 프롬프트 컨텍스트로 제공**:

```
subagent_type: "general-purpose"
description: "Pair mode Validator"
prompt: """
너는 `validator` 에이전트다. `.claude/agents/validator.md`의 역할·7단계 검증 절차를 그대로 따른다.

**권한 제약 준수**: 절대 Edit/Write 도구 사용 금지. Read/Grep/Glob/Bash만 사용.

## 검증 요청 (pair-review-request)
{
  "task": "{TASK_DESC}",
  "branch_or_worktree": "{Builder 결과.branch_or_worktree}",
  "changes_summary": "{Builder 결과.summary}",
  "test_file": {Builder 결과.test_files},
  "changed_files": {Builder 결과.changed_files},
  "commit_hashes": {Builder 결과.commit_hashes},
  "acceptance_criteria": [
    "전체 테스트 통과 (npx vitest run)",
    "TypeScript 에러 0 (npx tsc --noEmit)",
    "ESLint 치명 에러 0",
    "TDD 증거 (테스트 커밋이 구현 커밋보다 선행 또는 동일)",
    "스펙 범위 밖 변경 없음 (surgical changes)"
  ]
}

## 출력 형식
검증 완료 후 아래 JSON 1개 출력:
{
  "verdict": "approved" | "needs-revision",
  "evidence": {
    "spec_match": "<스펙 일치 여부 한 줄>",
    "tests": {"ran": <N>, "passed": <N>, "duration_sec": <float>},
    "typecheck": {"errors": <N>, "command": "npx tsc --noEmit"},
    "lint": {"errors": <N>, "warnings": <N>},
    "tdd_evidence": "<TDD 순서 요약 or N/A if 버그 수정>",
    "surface_check": "<영향 범위 grep 결과 요약>"
  },
  "blockers": ["<approved 불가 이유 리스트 — needs-revision일 때만>"],
  "suggested": ["<선택적 개선 — approved여도 기록 가능>"],
  "re_verify_instructions": "<needs-revision일 때 Builder에게 전달할 수정 지침>"
}
"""
```

### 4. 판정 처리

Validator JSON 파싱:

**Case A: `verdict: "approved"`**
- 사용자에게 최종 보고 (아래 "최종 출력" 형식)
- 루프 종료

**Case B: `verdict: "needs-revision"`**
- `ITERATION += 1`
- `PREV_FEEDBACK = validator 출력의 blockers + re_verify_instructions`
- `ITERATION < MAX_ITERATIONS`면 **2단계(Builder)로 돌아가서 재시도**
- `ITERATION >= MAX_ITERATIONS`면 **5단계(교착 해소)로 진행**

### 5. 교착 해소 (3회 반려 시)

moderator 에이전트 소환:

```
subagent_type: "general-purpose"
description: "Pair mode deadlock mediation"
prompt: """
너는 `moderator` 에이전트다. `.claude/agents/moderator.md`의 중재 절차를 따른다.

Pair mode에서 Builder(developer)와 Validator(validator) 사이 3회 반려 발생. 쟁점을 검토하고 판정한다.

## 쟁점
- 작업: {TASK_DESC}
- Builder의 마지막 완료 주장: {last_builder_output}
- Validator의 마지막 반려 이유: {last_validator_blockers}

## 출력
다음 중 하나:
1. approve_with_caveats — Validator의 일부 반려 사유를 과도하다 판단. approved 처리 + 남은 지적은 follow-up 태스크로
2. reject_as_incomplete — Validator 판단 지지. Builder 재설계 필요
3. needs_human_input — 판단 불가. 사용자 개입 요청

근거와 함께 JSON 한 개 출력.
"""
```

moderator 판정에 따라 최종 결과 보고 후 루프 종료.

### 6. 최종 출력

사용자에게 아래 형식으로 보고:

```markdown
## Pair Session 결과

**작업**: {TASK_DESC}
**결과**: approved / needs-revision-max / moderator-resolved
**반복 횟수**: {ITERATION + 1}

### Builder 요약
- 변경 파일: {changed_files}
- 테스트 파일: {test_files}
- 커밋: {commit_hashes}

### Validator 판정
- 테스트: {tests.passed}/{tests.ran} 통과 ({duration_sec}s)
- 타입체크: {typecheck.errors} errors
- lint: {lint.errors} errors / {lint.warnings} warnings
- TDD 증거: {tdd_evidence}

### (needs-revision 시) BLOCKER
- {blockers 리스트}

### 추천 (SUGGESTED)
- {suggested 리스트}

### 다음 단계
- approved → git push 또는 머지 가능
- needs-revision-max → 수동 개입 필요 ({blockers} 해결)
- moderator-resolved → {moderator 판정에 따른 후속}
```

### 7. events.jsonl 기록 (observability 연동)

세션 종료 후 `.claude/events.jsonl`에 요약 append:

```bash
echo '{"ts":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","type":"pair_session","task":"{TASK_DESC}","iterations":'"$ITERATION"',"verdict":"{final_verdict}","status":"{final_status}"}' >> .claude/events.jsonl
```

## 언제 사용하는가

**적합한 경우**:
- 머지/배포 전 독립 검증 필요한 작업
- 버그 수정 후 regression test 유효성 검증
- 스펙 해석이 애매해서 제3자 관점 필요한 기능 추가
- AI가 "대충 맞을 것 같다"며 급하게 끝내려는 경향 차단

**부적합한 경우**:
- 단순 타이포 수정, 로그 문자열 변경 (오버헤드만 큼)
- 탐색/리서치 작업 (결과물이 코드 아님)
- 프로토타입 단계 (아직 검증 기준 없음)

## 한계

- **단일 Claude 세션 내에서만 동작** — Task tool 의존
- **Builder/Validator는 서브에이전트로 실행** — 긴 작업은 오케스트레이터(이 스킬) context 소비가 누적
- Iteration 3회 × 2 에이전트 = **최대 6번 서브에이전트 호출** 비용
- 병렬 Validator 지원 없음 (단일 Validator만)

## 수동 L1 워크플로우 (하위 호환)

L2 자동화 없이 Claude Squad + message-bus.sh로 수동 운영하고 싶다면:

```bash
# 터미널 1 — Builder 세션
cs → n → "developer" 프로필 → 작업 후 pair-review-request 메시지 발송

# 터미널 2 — Validator 세션
cs → n → "validator" 프로필 → message-bus.sh list validator → 검증 + 회신
```

message-bus.sh 프로토콜 상세는 `agents/validator.md`의 "검증 절차" 섹션 참조.

## Agent Orchestrator 연동 (CI/CD, 선택적)

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

CI에서는 `/pair` 슬래시 명령 대신 이 reaction이 트리거.

## 확장 여지

- `/pair --parallel-validators N` 플래그로 Validator 다수 스폰 (N=2~3)
- Validator memory의 learnings를 Builder에게 **사전** 전달 (반복 실수 예방)
- `/pair --strict` 모드 — 3회 반려 시 worktree 자동 롤백
- Iteration 횟수와 verdict 패턴을 `scripts/store.js`의 events 테이블에 저장 → `weekly-trend`로 pair 품질 추이 관찰
