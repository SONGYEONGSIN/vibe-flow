---
name: eval-skill
description: 지정 스킬의 evals를 실행하여 품질을 정량 측정한다. 사용법: /eval <skill-name>
---

스킬의 `evals/evals.json`을 로드하고 테스트 프롬프트를 실행하여 품질을 정량 측정한다.

## 사용법

- `/eval commit` — commit 스킬 eval 실행
- `/eval security` — security 스킬 eval 실행
- `/eval verify` — verify 스킬 eval 실행
- `/eval --all` — 모든 스킬 eval 실행 (evals.json이 있는 스킬만)

## 절차

### 1. Eval 데이터 로드

```
.claude/skills/<skill-name>/evals/evals.json
```

evals.json이 없으면 에러를 출력하고 종료한다.

### 2. 테스트 프롬프트 실행

각 eval 항목의 `prompt`를 subagent로 실행한다.
- 모델: eval에 지정된 모델 또는 기본 `sonnet`
- 병렬 실행: 독립적인 eval은 `Agent` 도구로 병렬 처리
- 타임아웃: eval당 최대 2분

### 3. 결과 평가

**grader** 에이전트를 호출하여 각 결과를 평가:
- 실제 출력 vs 기대 결과(`expectations`) 비교
- PASS/FAIL 판정 + 근거 작성
- claims 자동 추출 (출력에서 검증 가능한 사실)

### 4. 벤치마크 생성

결과를 `benchmark.json`으로 저장:

```json
{
  "skill": "commit",
  "runAt": "2026-03-17T10:00:00Z",
  "results": [
    {
      "id": 1,
      "prompt": "...",
      "status": "PASS",
      "score": 1.0,
      "reasoning": "모든 기대 결과를 충족함",
      "claims": ["커밋 메시지가 conventional commits 형식", "Co-Authored-By 포함"]
    }
  ],
  "summary": {
    "total": 5,
    "passed": 4,
    "failed": 1,
    "passRate": 80.0
  }
}
```

### 5. 결과 출력

```
=== Eval Report: commit ===

  [1] PASS — 단일 파일 수정 커밋 메시지 생성
  [2] PASS — 다중 파일 수정 커밋 메시지 생성
  [3] FAIL — 브레이킹 체인지 감지
      Expected: BREAKING CHANGE 포함
      Actual: 일반 feat 메시지 생성
  [4] PASS — 한국어 커밋 메시지

  Pass Rate: 3/4 (75.0%)
  Saved: .claude/skills/commit/evals/benchmark.json
```

## --all 모드

모든 스킬을 순회하며 evals.json이 있는 스킬만 eval 실행:

```
=== Eval Summary (all skills) ===

  commit:   3/4 (75.0%)
  verify:   5/5 (100%)
  security: 2/3 (66.7%)

  Overall: 10/12 (83.3%)
```

## evals.json 포맷

```json
{
  "skill_name": "commit",
  "evals": [
    {
      "id": 1,
      "prompt": "src/auth.ts 파일에 로그인 함수를 추가한 상황에서 커밋 메시지를 생성해라",
      "expectations": [
        { "description": "conventional commits 형식 (feat/fix/...)", "type": "must_pass" },
        { "description": "Co-Authored-By 포함", "type": "must_pass" },
        { "description": "변경 내용을 정확히 반영", "type": "should_pass" }
      ],
      "model": "sonnet"
    }
  ]
}
```

## A/B 비교 모드

스킬 변경 전후 품질을 비교할 때:

1. 변경 전 benchmark.json이 있으면 자동 로드
2. **comparator** 에이전트로 블라인드 A/B 비교
3. 개선/퇴보 판정 + 세부 비교표 출력

## 규칙

- evals.json이 없는 스킬은 "eval 미설정" 안내만 출력
- eval 실행 중 에러 발생 시 해당 항목만 FAIL 처리 (전체 중단 금지)
- benchmark.json은 `.claude/skills/<skill-name>/evals/` 에 저장
- 이전 benchmark와 비교하여 퇴보 항목은 경고 출력
