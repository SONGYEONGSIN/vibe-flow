---
name: sync-claude-md
description: This skill should be used when the user requests "sync", "동기화", "CLAUDE.md 업데이트", "오늘 정리", "세션 정리", "하루 마무리", "/sync".
user-invocable: true
allowed-tools: Bash(git log:*), Bash(git diff:*), Bash(git status:*), Bash(ls:*), Bash(wc:*), Read, Write, Edit, Glob, Grep
---

# CLAUDE.md 동기화 워크플로우

3개 소스(프로젝트 스캔 → 대화 컨텍스트 → git delta)를 종합하여 프로젝트 CLAUDE.md를 생성/업데이트한다.

---

## 메모리 계층 이해

이 스킬은 **프로젝트 루트 `CLAUDE.md`** (단일 파일)만 관리한다.

| 타입 | 위치 | 로딩 | 이 스킬 관리 |
|------|------|------|:----------:|
| Project memory | `./CLAUDE.md` | 세션 시작 시 전체 로드 | **O** |
| Project local | `./CLAUDE.local.md` | 세션 시작 시 전체 로드 (gitignore) | X |
| Project rules | `./.claude/rules/*.md` | 세션 시작 시 전체 로드 | X |
| User memory | `~/.claude/CLAUDE.md` | 세션 시작 시 전체 로드 | X |
| Auto memory | `~/.claude/projects/.../memory/` | MEMORY.md 200줄만 로드 | X |

**CLAUDE.md에 넣을 것:** 빌드 명령어, 기술 스택, 프로젝트 구조, 코딩 컨벤션, 아키텍처 결정, 제약/주의사항, 워크플로우
**넣지 말 것:** 개인 선호 (`CLAUDE.local.md` 사용), API 키/시크릿, 임시 메모, 미검증 추측

> 참고: `@path/to/file` 문법으로 다른 파일을 import 가능 (최대 5단계). 300줄 초과 시 별도 .md로 분리 후 import하는 방법도 고려.

---

## Phase 1: 프로젝트 스캔 (뼈대)

코드베이스에서 **검증 가능한 사실**을 수집한다. 아래를 **병렬로** 실행.

### 1-1. 기술 스택 추출

```
Read: package.json → dependencies, devDependencies, scripts
Read: tsconfig.json → target, strict, paths
Read: next.config.ts (또는 .js/.mjs) → 주요 설정
Read: tailwind.config.* → 테마 커스터마이즈 여부
Read: eslint.config.* → 주요 플러그인, 커스텀 규칙
```

추출 항목:
- 프레임워크 + 버전 (package.json의 dependencies)
- 빌드/개발/테스트 스크립트 (package.json의 scripts)
- TypeScript 설정 핵심 (strict, paths, target)
- ESLint 커스텀 규칙 (기본 preset과 다른 것만)

### 1-2. 프로젝트 구조 파악

```bash
# 1단계 디렉토리
ls src/

# 주요 하위 디렉토리 (존재하는 것만)
ls src/app/ src/components/ src/lib/ 2>/dev/null
```

Glob으로 패턴 파악:
```
Glob: src/app/**/route.ts → API 라우트 수
Glob: src/app/**/page.tsx → 페이지 수
Glob: src/components/**/*.tsx → 컴포넌트 수
Glob: src/services/*.ts → 서비스 수
Glob: src/repositories/*.ts → 리포지토리 수
```

### 1-3. 설정 파일 스캔

```
Glob: .env.example 또는 .env.local.example → 환경변수 목록
Read: supabase/config.toml → Supabase 설정 (있으면)
Read: docker-compose.yml → 인프라 의존성 (있으면)
```

### 검증

최소한 `package.json`이 존재해야 한다. 없으면 "프로젝트 루트를 확인하세요" 출력 후 **즉시 종료**.

---

## Phase 2: 대화 컨텍스트 분석 (살)

프로젝트 스캔으로 알 수 없는 **경험적 지식**을 대화에서 추출한다.

### 추출 대상

| 카테고리 | 예시 | 스캔으로 알 수 없는 이유 |
|----------|------|------------------------|
| 기술적 제약 | "Zod 4 `.format()` deprecated" | 코드에 이미 우회 적용됨 |
| 아키텍처 근거 | "Repository 패턴 선택 이유" | 코드 구조만으론 why 불명 |
| ESLint 함정 | "`!` 대신 `getClientEnv()` 사용" | 규칙 이름만으론 맥락 부족 |
| 디버깅 교훈 | "sweph는 require 필수" | import로 바꾸면 깨지는 이유 |
| 워크어라운드 | "`as never` 캐스팅 필요" | 왜 필요한지 코드만으론 불명 |
| 컨벤션 합의 | "커밋 메시지 한국어" | 설정 파일에 없는 팀 합의 |

### 대화가 없거나 압축된 경우

- 대화 컨텍스트가 비어있어도 **Phase 1만으로 진행** 가능
- 이 경우 "대화 컨텍스트 없이 프로젝트 스캔만으로 생성" 명시

---

## Phase 3: Git Delta 반영 (변경분)

기존 CLAUDE.md가 있을 때, 최근 변경사항만 **incremental 반영**한다.

### 3-1. 변경 수집

```bash
# 오늘 커밋
git log --since="midnight" --oneline --stat

# 변경 파일 목록
git log --since="midnight" --name-only --pretty=format:"" | sort -u

# 커밋 없으면 staged/unstaged
git diff --stat
git diff --cached --stat
```

### 3-2. Delta 분류

변경된 파일을 CLAUDE.md 섹션에 매핑:

| 변경 파일 패턴 | 영향 섹션 | 액션 |
|---------------|----------|------|
| `package.json` (deps 변경) | 기술 스택 | 추가/수정 |
| `src/app/**/` 새 라우트 | 프로젝트 구조 | 추가 |
| `eslint.config.*` | 코딩 컨벤션 | 수정 |
| `tsconfig.json` | 기술 스택 | 수정 |
| 새 `src/` 1단계 디렉토리 | 프로젝트 구조 | 추가 |
| `supabase/migrations/` | 알려진 제약 또는 구조 | 확인 필요 |

### 3-3. CLAUDE.md가 없을 때

Phase 1 + Phase 2 결과로 **신규 생성**. Git delta는 무시 (전체가 새 내용이므로).

---

## Phase 4: CLAUDE.md 작성/업데이트

### 표준 구조

```markdown
# 프로젝트명

## 빠른 시작
설치/개발/빌드/테스트 명령어

## 기술 스택
주요 기술과 버전 제약

## 프로젝트 구조
핵심 디렉토리 설명 (2단계까지)

## 코딩 컨벤션
네이밍, Import 순서, 타입 패턴, ESLint 주의사항

## 아키텍처 결정
주요 기술 선택과 근거

## 알려진 제약 & 주의사항
호환성 이슈, 환경 차이, 워크어라운드

## 개발 워크플로우
브랜치 전략, 커밋 컨벤션, 배포 프로세스
```

### 신규 생성 시

Phase 1(스캔)으로 빠른 시작 / 기술 스택 / 프로젝트 구조를 채우고, Phase 2(대화)로 코딩 컨벤션 / 아키텍처 결정 / 제약을 채운다.

> 참고: Claude Code `/init` 명령으로도 초기 CLAUDE.md 생성 가능. 이 스킬은 `/init`보다 더 깊은 스캔과 대화 컨텍스트 반영을 제공한다.

### 기존 파일 수정 시

1. 기존 구조를 **최대한 유지**
2. 새 항목은 해당 섹션 **끝에 추가**
3. 변경 항목은 기존 내용을 **수정** (중복 금지)
4. 무효화된 항목은 **삭제**
5. Phase 1 스캔 결과와 기존 내용이 **불일치**하면 스캔 결과로 교정

### 작성 규칙

- 한 줄에 하나의 규칙/정보
- 명령형 문체 ("사용한다", "금지한다")
- `why`를 괄호로 부연: "`getClientEnv()` 사용 (ESLint no-non-null-assertion)"
- 코드는 인라인 코드 또는 최소 코드 블록
- 불필요한 설명 제거 — 규칙과 사실만

### 검증

- 전체 **300줄 이하** (초과 시 압축)
- 마크다운 문법 확인
- 기존 내용 의도치 않은 삭제 여부 diff 확인

---

## Phase 5: 변경 보고

업데이트 완료 후 변경 요약을 출력한다.

```
## CLAUDE.md 동기화 완료

### 소스
- 프로젝트 스캔: O/X
- 대화 컨텍스트: O/X
- Git delta: O/X (N커밋)

### 추가 (N건)
- [섹션명] 항목 설명

### 수정 (N건)
- [섹션명] 변경 전 → 변경 후

### 삭제 (N건)
- [섹션명] 삭제 사유
```

---

## 금지 사항

- CLAUDE.md에 **개인 선호** 기록 금지 (`CLAUDE.local.md` 또는 Auto Memory 사용)
- **API 키, 시크릿, 인증 정보** 기록 금지
- **추측성 정보** 기록 금지 (스캔 또는 대화에서 확인된 사실만)
- 기존 CLAUDE.md **구조 임의 변경** 금지
- **300줄 초과** 금지 (초과 시 압축하거나 `@import`로 분리)
- CLAUDE.md를 **자동 커밋** 금지 (사용자 검토 후 직접 커밋)
- Auto Memory(MEMORY.md) **수정 금지** (별도 메커니즘)
- `package-lock.json`/`pnpm-lock.yaml` 내용 기록 금지

---

## Troubleshooting

### 프로젝트 스캔 결과가 빈약함
- **원인:** 비표준 프로젝트 구조, package.json 없음
- **해결:** 사용자에게 프로젝트 루트 확인. 수동으로 주요 파일 경로 질문

### CLAUDE.md가 비대해짐
- **원인:** 세션마다 항목 누적
- **해결:** 유사 항목 병합, 무효 항목 삭제, 300줄 제한 엄격 적용

### 스캔 결과와 기존 CLAUDE.md 불일치
- **원인:** 패키지 업그레이드, 구조 변경 후 CLAUDE.md 미반영
- **해결:** 스캔 결과를 우선 신뢰 (코드가 진실). 변경 보고에 교정 사항 명시

### 대화 없이 실행 (새 세션)
- **원인:** 세션 시작 직후 `/sync` 실행
- **해결:** Phase 1(스캔) + Phase 3(git delta)만으로 진행. 정상 동작

### Auto Memory와 중복
- **원인:** 같은 정보가 양쪽에 존재
- **해결:** 팀용 → CLAUDE.md, 개인용 → MEMORY.md. 중복 시 MEMORY.md에서 제거 제안

---

## Anti-patterns

| 안티패턴 | 문제 | 해결 |
|----------|------|------|
| 모든 것을 기록 | CLAUDE.md 비대화 | 팀에 유용한 것만 선별 |
| 코드 복붙 | 유지보수 불가 | 규칙/패턴만 간결히 기술 |
| 섹션 중복 | 혼란 | 하나의 정보는 하나의 섹션에만 |
| 자동 커밋 | 검토 없는 변경 | 사용자 diff 확인 후 커밋 |
| 날짜별 기록 | 로그화 | 시간순 아닌 주제별 정리 |
| 스캔 결과만 의존 | why 누락 | 대화 컨텍스트로 근거 보충 |
| 대화만 의존 | 사실 오류 | 스캔으로 교차 검증 |

---

## References

- `references/claude-md-examples.md` - 프로젝트 규모별 CLAUDE.md 예시 3종
