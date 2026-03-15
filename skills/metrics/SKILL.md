---
name: metrics
description: 프로젝트 메트릭 대시보드 — 빌드 성공률, 에러 빈도, 생산성 추이를 보여준다
argument-hint: "[today|week|all]"
---

프로젝트 메트릭을 대시보드 형태로 출력한다.

## 사용법

- `/metrics` — 오늘 메트릭
- `/metrics week` — 최근 7일 메트릭
- `/metrics all` — 전체 메트릭

## 절차

### 1. 메트릭 파일 확인

```bash
ls -1 .claude/metrics/daily-*.json 2>/dev/null
```

파일이 없으면 "아직 메트릭이 없습니다. 코드를 수정하면 자동으로 수집됩니다." 안내 후 종료.

`$ARGUMENTS`에 따라 파일 필터링:
- `today` (기본값, 인자 없음): 오늘 날짜 파일만
- `week`: 최근 7개 파일
- `all`: 전체

### 2. 데이터 집계

각 일별 JSON에서 다음을 계산:

```bash
jq '{
  date: .date,
  total: (.events | length),
  typecheck_fail: ([.events[] | select(.results.typecheck == "fail")] | length),
  eslint_fail: ([.events[] | select(.results.eslint == "fail")] | length),
  test_fail: ([.events[] | select(.results.test == "fail")] | length),
  all_pass: ([.events[] | select(
    .results.prettier == "pass" and
    .results.eslint == "pass" and
    .results.typecheck == "pass" and
    .results.test == "pass"
  )] | length),
  unique_files: ([.events[].file] | unique | length)
}' .claude/metrics/daily-YYYY-MM-DD.json
```

### 3. 핫스팟 파일 (가장 많이 수정된)

```bash
jq '[.events[].file] | group_by(.) | map({file: .[0], count: length}) | sort_by(-.count) | .[0:10]' .claude/metrics/daily-*.json
```

### 4. 에러 패턴

typecheck/eslint/test 실패가 많은 파일 식별:

```bash
jq '[.events[] | select(.results.typecheck == "fail")] | group_by(.file) | map({file: .[0].file, fails: length}) | sort_by(-.fails) | .[0:5]'
```

## 출력 형식

```markdown
## 메트릭 대시보드 — [기간]

### 요약

| 지표 | 값 | 상태 |
|------|------|------|
| 총 이벤트 | N개 | — |
| 빌드 성공률 | X% | 양호/보통/개선 필요 |
| TypeScript 에러 | N회 (X%) | |
| ESLint 위반 | N회 (X%) | |
| 테스트 실패 | N회 (X%) | |
| 수정된 고유 파일 | N개 | |

### 추이 (week/all 모드)

| 날짜 | 이벤트 | 성공률 | TS에러 | ESLint | 테스트 |
|------|--------|--------|--------|--------|--------|

### 핫스팟

| 파일 | 수정 횟수 |
|------|----------|

### 에러 패턴

| 유형 | 횟수 | 관련 파일 |
|------|------|----------|
```

## 상태 기준

| 성공률 | 상태 |
|--------|------|
| 90% 이상 | 양호 |
| 70~89% | 보통 |
| 70% 미만 | 개선 필요 |

## 규칙

- 숫자는 소수점 1자리까지 반올림
- today 모드에서는 추이 테이블 생략
- 이벤트가 0개면 해당 날짜 건너뛰기
