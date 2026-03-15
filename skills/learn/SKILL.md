---
name: learn
description: 프로젝트 메모리에 패턴/규칙을 저장하거나 조회한다
argument-hint: "[save|show] [pattern|error|profile]"
---

프로젝트 메모리를 관리한다.

## 사용법

- `/learn save pattern` — 현재 세션에서 발견한 코드 패턴 저장
- `/learn save error` — 해결한 에러 패턴 저장
- `/learn save profile` — 프로젝트 특성 업데이트
- `/learn show` — 메모리 전체 조회
- `/learn show patterns` — 패턴만 조회
- `/learn show errors` — 에러 해결법만 조회
- `/learn show profile` — 프로젝트 프로파일만 조회

## 절차

### save 모드

1. `$ARGUMENTS`에서 모드와 카테고리 파싱
2. 현재 세션 컨텍스트 분석:
   - `git diff HEAD~3` — 최근 변경사항
   - `git log --oneline -10` — 최근 커밋
   - `.claude/session-logs/` — 최신 세션 로그
   - `.claude/metrics/` — 최신 메트릭 (실패 패턴 파악)
3. 분석 결과에서 학습할 내용 추출

#### save pattern
- 반복 사용된 코드 구조 (API 호출 패턴, 상태 관리 패턴 등)
- 자주 적용한 리팩토링 (컴포넌트 분리, 타입 추출 등)
- `.claude/memory/patterns.md`의 `## 코드 패턴` 섹션에 추가

#### save error
- TypeScript 에러 메시지 + 해결법 쌍
- ESLint 위반 유형 + 수정 방법
- 런타임 에러 + 디버깅 과정
- `.claude/memory/patterns.md`의 `## 에러 해결` 섹션에 추가

#### save profile
- 프로젝트에서 자주 사용하는 DB 테이블명, API 엔드포인트
- 외부 서비스 연동 패턴
- 프로젝트 고유 규칙/컨벤션
- `.claude/memory/project-profile.md`에 업데이트

4. 중복 검사: 기존 항목과 유사하면 업데이트 (새로 추가하지 않음)
5. 타임스탬프와 출처(커밋 해시) 기록

### show 모드

1. `.claude/memory/` 디렉토리의 파일 읽기
2. 카테고리별로 정리하여 출력
3. 파일이 없으면 "아직 학습된 내용이 없습니다. `/learn save pattern`으로 시작하세요." 안내

## 메모리 파일 포맷

### patterns.md

```markdown
# 학습된 패턴

## 코드 패턴

### [패턴명] — [YYYY-MM-DD]
- **상황**: [이 패턴이 필요한 상황]
- **해결**: [코드 패턴 또는 접근법]
- **출처**: [커밋 해시]

## 에러 해결

### [에러 유형] — [YYYY-MM-DD]
- **에러**: [에러 메시지 요약]
- **원인**: [근본 원인]
- **해결**: [수정 방법]
- **출처**: [커밋 해시]
```

### project-profile.md

```markdown
# 프로젝트 프로파일

## 데이터베이스
- 주요 테이블: [목록]
- RLS 정책: [요약]

## API 엔드포인트
- [엔드포인트]: [용도]

## 외부 서비스
- [서비스명]: [용도, 주의사항]

## 프로젝트 고유 규칙
- [규칙 설명]
```

## 규칙

- 항목당 5줄 이내로 간결하게
- 메모리 파일은 `.gitignore`에 추가하지 않음 (팀 공유 가능)
- 100개 이상 축적되면 오래되거나 중복된 항목 정리 제안
- 파일이 없으면 자동 생성
