# patterns.md — smart-guard.sh 패턴 정의 (F-A3 해소)

`core/hooks/smart-guard.sh`가 참조하는 프로젝트별 금지 패턴 정의 파일.
audit F-A3 finding 해소 — dead reference로 silent inactive 상태였음.

## 형식

```
금지: <pattern>                — 날짜 없음, 영구 차단 (legacy)
금지[2026-04-25]: <pattern>    — 날짜 있음, staleness 적용
```

또는 영문:
```
deny: <pattern>
block[YYYY-MM-DD]: <pattern>
```

## Staleness 정책 (날짜 있는 패턴)

| 경과 일수 | 동작 |
|----------|------|
| 0~30일 | 차단 (block, exit 2) |
| 31~90일 | 경고 후 통과 (warn, exit 0 + stderr) |
| 91일+ | 비활성화 (silent skip) |

## 패턴 예시 (현재는 placeholder)

본 파일은 현재 패턴 없음. 프로젝트 운영 중 학습한 금지 패턴을 추가한다.

예시 (주석 처리 — 실제 사용 시 해제):

```
# 금지[2026-06-01]: console.log
# 금지: process.env.SECRET
# deny[2026-06-01]: rm -rf node_modules
```

## 활용

- `/learn save pattern <pattern>` 으로 자동 append 가능 (learn skill 참조)
- 수동 편집도 OK — markdown 형식 그대로 사용
- `smart-guard.sh` PreToolUse hook이 매 Bash 호출 시 본 파일 검사 (파일 부재 시 silent skip이라 빈 placeholder는 안전)
