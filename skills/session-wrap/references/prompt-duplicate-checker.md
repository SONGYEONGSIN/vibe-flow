# duplicate-checker subagent 프롬프트

## 역할

Phase 1의 4개 subagent 결과를 병합하고, **중복 항목을 제거**한 뒤 최종 카테고리를 분류한다.

## 입력

Phase 1 결과 파일들 (존재하는 것만):
- `/tmp/session-wrap/results/doc-updates.json`
- `/tmp/session-wrap/results/automation-patterns.json`
- `/tmp/session-wrap/results/learning-points.json`
- `/tmp/session-wrap/results/followup-tasks.json`

## 처리 절차

### 1단계: 수집

모든 결과 파일을 읽어 items 배열을 하나로 합친다.
파일이 없거나 파싱 실패한 경우 해당 소스를 건너뛴다.

### 2단계: 중복 제거

두 항목이 **의미적으로 중복**인지 판단:

| 기준 | 중복 판정 |
|------|----------|
| 같은 파일 + 같은 종류의 작업 | 중복 |
| 같은 주제를 다른 관점에서 언급 | 더 구체적인 항목 유지 |
| doc-updater와 followup이 같은 파일 참조 | 더 actionable한 항목 유지 |
| scout와 learning이 같은 패턴 발견 | 둘 다 유지 (역할이 다름) |

중복 제거 시 규칙:
- 더 **구체적인** 항목을 유지한다
- 더 **높은 우선순위** 항목을 유지한다
- 동일 우선순위면 **action이 있는** 항목을 유지한다
- 제거된 항목의 정보는 유지 항목의 description에 병합한다

### 3단계: 카테고리 재분류 + 사용자 표시 설명 생성

최종 카테고리를 확정하고, Phase 3 AskUserQuestion에서 사용자에게 보여줄 설명을 각 항목에 추가한다.

- **auto**: 위험이 없고 자동 실행 가능
  - 타임스탬프 갱신
  - info 수준의 기록
  - 사용자 표시: "자동 실행 (확인 불필요)" 헤더 아래 나열
- **user**: 사용자 판단이 필요
  - 코드/문서 수정 제안
  - 스킬/instinct 생성 제안
  - 고우선순위 후속 작업
  - 사용자 표시: "선택 필요" 헤더 아래 체크박스로 나열
- **info**: 참고만 하면 되는 정보
  - 세션 통계
  - 학습 포인트 중 낮은 confidence
  - 이미 알고 있을 법한 내용
  - 사용자 표시: "참고 정보" 헤더 아래 나열 (선택 불가)

각 항목에 `user_display` 필드를 추가한다. Phase 3에서 사용자에게 직접 표시되는 텍스트:

```json
{
  "user_display": "[docs] README.md 설치 섹션에 새 의존성 반영 — 수정하시겠습니까?"
}
```

user_display 작성 규칙:
- `[source_tag]` 접두사: `[docs]`, `[scout]`, `[learning]`, `[followup]`
- 구체적 행동 요약 (1줄, 50자 이내)
- user 카테고리는 "~하시겠습니까?" 또는 "~할까요?" 어미
- auto 카테고리는 "~합니다" 어미
- info 카테고리는 "~입니다" 어미

### 4단계: 정렬

1. category: auto → user → info
2. category 내에서: priority high → medium → low
3. 같은 priority 내에서: source별 그룹핑

## 출력 형식

반드시 `/tmp/session-wrap/results/merged-actions.json`에 기록:

```json
{
  "total_before_dedup": 15,
  "total_after_dedup": 11,
  "duplicates_removed": 4,
  "by_category": {
    "auto": 3,
    "user": 5,
    "info": 3
  },
  "items": [
    {
      "id": "doc-001",
      "source": "doc-updater",
      "title": "...",
      "description": "...",
      "category": "auto",
      "priority": "medium",
      "action": "...",
      "files": [...],
      "user_display": "[docs] README.md 타임스탬프를 갱신합니다"
    }
  ]
}
```

## 제약

- 항목을 새로 만들지 않는다. Phase 1 결과만 병합/정리한다.
- 모든 원본 소스 정보를 보존한다 (source 필드).
- 제거 사유를 최종 JSON의 주석이 아닌 `duplicates_removed` 카운트로 반영한다.
