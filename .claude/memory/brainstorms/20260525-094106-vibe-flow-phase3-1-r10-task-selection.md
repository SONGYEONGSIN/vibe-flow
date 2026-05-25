# Brainstorm: vibe-flow Phase 3.1 R10 dogfooding task 선정

작성: 2026-05-25T00:41:06Z
주제: safety hook (PreToolUse) + vote confidence floor (0.7) + orchestrator P0~P5를 모두 실 발동시킬 R10 cloud cycle task 후보 정리.

## 의도

- **산출물**: R10 dogfooding cycle용 task 1개 (`.claude/memory/auto-build-queue.jsonl` enqueue) + RemoteTrigger routine 등록용 spec.
- **사용자**: vibe-flow 본인 (cloud Claude Code agent가 task 수행), 검증 관찰자는 사람 사용자 (cloud session log 사후 확인).
- **트리거**: PR #74 (F10 fix) 머지 후 Phase 3.1 마무리 단계. master plan에 R10 = `safety/vote 실 검증`으로 명시됨. 다음 사용자 첫 실 task 들어가기 전 마지막 안전 게이트.
- **성공 기준**:
  1. cloud session log에 `auto-build-safety.sh` PreToolUse hook wired 확인 (또는 destructive op 차단 로그)
  2. orchestrator P0~P5에서 vote confidence 출력 (0.7 floor 통과/abort 여부 확인)
  3. PR 자동 생성 + `queue.jsonl` git-committed `done` status update
  4. routine `run_once_fired` + auto-disable

## 제약

- **기술**: cloud session log는 외부 (claude.ai/code/sessions/<id>) 직접 접근 불가 — 사용자가 별도 확인. 1 firing = 1 PR 정책. RemoteTrigger 등록 시각은 1h+ 후. cost 발생 (small, single task).
- **비즈니스**: 사용자 manual 개입 1회 (paste 단계) — 자동화 불가. firing 시각 사용자 상의 필요.
- **코드베이스**: task는 vibe-flow 기존 패턴 준수 (conventional commit / surgical change / 1~5 파일). PR 머지 후 main에 의미 없는 변경 X (의도적 결과물이 있어야).

## 대안 비교

### 대안 A: 명확한 unit test 1건 추가
- **핵심**: `core/skills/auto-build/scripts/queue.sh` 또는 `vote.sh`의 edge case test 1건 추가.
- **safety/vote 발동 예상**: safety wire 자연 확인. vote는 task가 specific하므로 **미발동 가능성 높음**.
- **비용**: PR 1건, cloud session ~10분.
- **위험**: vote 검증 못 함.

### 대안 B: ambiguous한 small refactor task
- **핵심**: 예 — "auto-build orchestrator의 vote 단계에서 confidence 계산 로직을 작은 helper 함수로 분리. 함수명/위치는 자율 결정." → cloud agent가 두 가지 이상 합리적 선택지 사이에서 vote 발동 가능성.
- **safety/vote 발동 예상**: vote 발동 가능성 **높음** (이름/위치 자율). safety wire 자연 확인.
- **비용**: PR 1건, cloud session ~15분.
- **위험**: refactor 방향 어긋날 시 PR 머지 안 함 (rollback OK, branch만 정리).
- **학습 효과**: vote confidence 실 출력 + ambiguous task 처리 패턴 검증.

### 대안 C: destructive op 유도 task (safety hook 차단 검증)
- **핵심**: 예 — "scripts/ 하위에서 더 이상 쓰이지 않는 .bak 파일을 `rm`으로 정리". safety hook이 destructive op (`rm`) PreToolUse에서 차단해야 함.
- **safety/vote 발동 예상**: safety hook 실 차단 로그 명확. vote/orchestrator 진행 중단 (abort).
- **비용**: 빠름 ~5분.
- **위험**: PR 생성 X (정상 동작이 abort), end-to-end pipeline 검증 X.
- **학습 효과**: safety hook 차단 실 동작 — 별 firing(R11)로 후속 적합.

### 대안 Z: do nothing — R10 skip
- safety/vote 미검증 잔존. 다음 사용자 첫 실 task에서 미검증 코드 path 실 진입 = production-like incident 위험.
- 임시 우회: 코드 review로만 검증 (실 동작 미확인).
- 비용 절감은 작음 (cloud cost는 single task small).

| 항목 | 대안 A | 대안 B | 대안 C | 대안 Z |
|------|--------|--------|--------|--------|
| safety wire 검증 | ✓ (자연) | ✓ (자연) | ✓ (차단까지) | ✗ |
| safety 차단 검증 | ✗ | ✗ | ✓ | ✗ |
| vote 발동 검증 | △ (낮음) | ✓ (높음) | ✗ (abort) | ✗ |
| orchestrator P0~P5 | ✓ | ✓ | △ (중단) | ✗ |
| PR e2e 검증 | ✓ | ✓ | ✗ | ✗ |
| 비용 | low | mid | very low | none |
| 가역성 | 머지 후 revert | 머지 안 함이면 zero | abort = zero impact | n/a |

## 추천 + 근거

**대안 B (ambiguous small refactor)**.

**근거**:
1. safety hook + vote + orchestrator P0~P5 + PR e2e 4개 중 3개를 한 firing으로 검증 (safety 차단만 빠짐).
2. vote 발동 가능성이 대안 중 가장 높음 (ambiguous 자율 선택 강제).
3. 머지 부담 적음 (refactor 방향 안 맞으면 그냥 PR 닫음 — 추가 정리 zero).

**기각 — 대안 A**: vote 발동 가능성이 낮아 R10 핵심 검증 항목 1개 누락 위험.
**기각 — 대안 C**: PR 생성 X = end-to-end pipeline 검증 X. R11로 후속하면 safety 차단 단독 검증 가능.
**기각 — 대안 Z**: 미검증 코드 path가 사용자 첫 실 task와 같이 들어가면 incident 위험. 비용은 small이라 회피 명분 약함.

**후속 계획 명시**: R10 (대안 B) PASS 후 → R11 (대안 C) firing으로 safety 차단 단독 검증. R11은 별 enqueue + 별 routine.

## 다음 단계

- 저장됨: `.claude/memory/brainstorms/20260525-094106-vibe-flow-phase3-1-r10-task-selection.md`
- 권장: **직접 구현** (1~5 파일 등급, 인라인 설계 OK) — task description 작성 → `queue.sh add` → RemoteTrigger create payload 생성 → 사용자 paste

### 사후 검토 (2026-05-25 추가)

원래 초안에서 가정한 `core/skills/auto-build/scripts/vote.sh` 파일은 실재하지 않음. vote 로직은 `orchestrator.md` 명세 + `persona-vote.sh` (92줄) 조합으로 존재하며, 분리 가능한 helper 함수가 명확히 없음 → 원안 그대로는 cloud agent가 task를 잡지 못함.

vote 발동을 강제하려면 코드 변경 자체에 "복수 합리적 선택지"가 있어야 하는데, vibe-flow의 vote 코드 path에 자연스럽게 그런 task가 부족하다. 더불어 R10 검증의 본질은 "vote가 발동하는 정확한 조건"보다는 "vote 코드 path가 cloud session에서 실행되어 confidence 값을 출력하는지"임. 따라서 task가 vote를 100% 발동시킬 필요는 없고, orchestrator P0~P5 진입 시 vote 코드 path를 통과하는 것만 확인하면 됨.

### 구체 R10 task description (보정안)

```
core/skills/auto-build/SKILL.md 파일에 새 H2 섹션 '## R10 dogfooding marker (cloud cycle 두 번째 실 task — 2026-05-25)'와 본문 1줄 '본 marker는 R10 dogfooding 사이클이 safety hook + vote 코드 path + orchestrator P0~P5 모두 정상 통과했음을 표시한다.'를 추가한다. 섹션의 정확한 삽입 위치(말미 / 기존 ## R9 dogfooding marker 바로 아래 / 다른 위치 중 가장 자연스러운 곳)는 자율 결정한다. 빈 줄 1줄로 앞뒤 분리. 다른 파일 절대 수정 X. PR 제목은 'docs(auto-build): R10 dogfooding marker'.
```

**삽입 위치 자율 결정** 부분이 vote-friendly 조건 추가 — cloud agent가 R9 marker 바로 아래 vs SKILL.md 말미 두 후보 사이에서 결정하는 ambiguity 주입. 검증 후 결과 위치는 사용자 review로 확인.

### 후속 (R11)

R11 firing은 destructive op (`rm` 등) 유도 task로 safety hook 차단 단독 검증. R10 PASS 후 별 enqueue + 별 routine 등록.
