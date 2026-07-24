---
name: manage-skills
description: 세션 변경사항을 분석하여 검증 스킬 누락을 탐지합니다. 기존 스킬을 동적으로 탐색하고, 새 스킬을 생성하거나 기존 스킬을 업데이트한 뒤 프로젝트 CLAUDE.md를 관리합니다.
disable-model-invocation: true
argument-hint: "[선택사항: 특정 스킬 이름 또는 집중할 영역]"
---

# 세션 기반 스킬 유지보수

## 목적

현재 세션에서 변경된 내용을 분석하여 검증 스킬의 드리프트를 탐지하고 수정합니다:

1. **커버리지 누락** -- 어떤 verify 스킬에서도 참조하지 않는 변경된 파일
2. **유효하지 않은 참조** -- 삭제되거나 이동된 파일을 참조하는 스킬
3. **누락된 검사** -- 기존 검사에서 다루지 않는 새로운 패턴/규칙
4. **오래된 값** -- 더 이상 일치하지 않는 설정값 또는 탐지 명령어

## 글로벌 스킬 특성

이 스킬은 `~/.claude/skills/`에 설치된 **글로벌 스킬**입니다.
프로젝트별 verify-* 스킬은 각 프로젝트의 `.claude/skills/`에 생성됩니다.
등록 테이블은 **프로젝트별 CLAUDE.md**에서 관리합니다.

### 스킬 위치 규칙

| 스킬 유형 | 위치 | 이유 |
|-----------|------|------|
| manage-skills (이 스킬) | `~/.claude/skills/` | 모든 프로젝트에서 공통 사용 |
| verify-implementation | `~/.claude/skills/` | 모든 프로젝트에서 공통 사용 |
| verify-* (검증 스킬) | 프로젝트 `.claude/skills/` | 프로젝트별 규칙/패턴 |

## 실행 시점

- 새로운 패턴이나 규칙을 도입하는 기능을 구현한 후
- 기존 verify 스킬을 수정하고 일관성을 점검하고 싶을 때
- PR 전에 verify 스킬이 변경된 영역을 커버하는지 확인할 때
- 검증 실행 시 예상했던 이슈를 놓쳤을 때
- 주기적으로 스킬을 코드베이스 변화에 맞춰 정렬할 때

## 등록된 검증 스킬

현재 프로젝트에 등록된 검증 스킬 목록입니다. 새 스킬 생성/삭제 시 이 목록을 업데이트합니다.

> **참고**: 이 테이블은 글로벌 레벨의 기본값입니다. 실제 프로젝트별 등록은 프로젝트 CLAUDE.md의 `## Verify Skills` 섹션에서 관리됩니다.

| 스킬 | 설명 | 커버 파일 패턴 |
|------|------|---------------|
| (프로젝트에서 `/manage-skills`로 생성됨) | (프로젝트 지침에 맞는 스킬을 생성하려면 `/manage-skills`를 실행하세요) | (자동으로 결정됨) |

## 에이전트 중복 감지 (CRITICAL)

verify-* 스킬을 생성하기 전에 기존 **전문 에이전트**가 해당 도메인을 이미 커버하는지 확인합니다.
중복 생성은 토큰 낭비이며 결과 충돌을 유발합니다.

### 에이전트-도메인 매핑

| 기존 에이전트 | 커버 도메인 | verify-* 스킬 생성 금지 |
|--------------|-----------|----------------------|
| security-reviewer | 보안 취약점, OWASP, CWE | verify-security, verify-auth-security |
| database-reviewer | DB 스키마, 쿼리 최적화, 마이그레이션 | verify-db, verify-schema, verify-migration |
| code-reviewer | 코드 품질, 네이밍, 복잡도 | verify-code-quality, verify-naming |
| build-error-resolver | 빌드 오류, 타입 오류 | verify-build, verify-types |
| e2e-runner | E2E 테스트 | verify-e2e |

### 판단 기준

```
새 verify-* 스킬 생성 요청 시:
    IF 위 에이전트-도메인 매핑에 해당하는 경우:
        → SKIP: "이 도메인은 {에이전트명} 에이전트가 담당합니다" 안내
    ELSE IF 에이전트가 일부만 커버하는 경우:
        → 에이전트가 커버하지 않는 부분만 verify-* 스킬로 생성
    ELSE:
        → 정상 생성 진행
```

## 워크플로우

### Step 1: 세션 변경사항 분석

현재 세션에서 변경된 모든 파일을 수집합니다:

```bash
# 커밋되지 않은 변경사항
git diff HEAD --name-only

# 현재 브랜치의 커밋 (main에서 분기된 경우)
git log --oneline main..HEAD 2>/dev/null

# main에서 분기된 이후의 모든 변경사항
git diff main...HEAD --name-only 2>/dev/null
```

중복을 제거한 목록으로 합칩니다. 선택적 인수로 스킬 이름이나 영역이 지정된 경우 관련 파일만 필터링합니다.

**표시:** 최상위 디렉토리(첫 1-2 경로 세그먼트) 기준으로 파일을 그룹화합니다:

```markdown
## 세션 변경사항 감지

**이 세션에서 N개 파일 변경됨:**

| 디렉토리 | 파일 |
|----------|------|
| src/components | `Button.tsx`, `Modal.tsx` |
| src/server | `router.ts`, `handler.ts` |
| tests | `api.test.ts` |
| (루트) | `package.json`, `.eslintrc.js` |
```

### Step 2: 등록된 스킬과 변경 파일 매핑

#### Sub-step 2a: 등록된 스킬 확인

**프로젝트 CLAUDE.md**의 `## Verify Skills` 섹션에서 등록된 스킬 목록을 읽습니다.
글로벌 레벨의 등록 테이블도 참조합니다.

등록된 스킬이 0개인 경우, Step 4 (CREATE vs UPDATE 결정)로 바로 이동합니다. 모든 변경 파일이 "UNCOVERED"로 처리됩니다.

등록된 스킬이 1개 이상인 경우, 각 스킬의 `.claude/skills/verify-<name>/SKILL.md`를 읽고 다음에서 추가 파일 경로 패턴을 추출합니다:

1. **Related Files** 섹션 -- 테이블을 파싱하여 파일 경로 및 glob 패턴 추출
2. **Workflow** 섹션 -- grep/glob/read 명령어에서 파일 경로 추출

#### Sub-step 2b: 변경된 파일을 스킬에 매칭

Step 1에서 수집한 각 변경 파일에 대해, 등록된 스킬의 패턴과 대조합니다. 파일이 스킬과 매칭되는 조건:

- 해당 스킬의 커버 파일 패턴과 일치
- 해당 스킬이 참조하는 디렉토리 내에 위치
- 해당 스킬의 탐지 명령어에 사용된 regex/문자열 패턴과 일치

#### Sub-step 2c: 매핑 표시

```markdown
### 파일 -> 스킬 매핑

| 스킬 | 트리거 파일 (변경된 파일) | 액션 |
|------|--------------------------|------|
| verify-api | `router.ts`, `handler.ts` | CHECK |
| verify-ui | `Button.tsx` | CHECK |
| (스킬 없음) | `package.json`, `.eslintrc.js` | UNCOVERED |
```

### Step 3: 영향받은 스킬의 커버리지 갭 분석

영향받은(AFFECTED) 각 스킬(매칭된 변경 파일이 있는 스킬)에 대해, 전체 SKILL.md를 읽고 다음을 점검합니다:

1. **누락된 파일 참조** -- 이 스킬의 도메인과 관련된 변경 파일이 Related Files 섹션에 목록되어 있지 않은 경우?
2. **오래된 탐지 명령어** -- 스킬의 grep/glob 패턴이 현재 파일 구조와 여전히 일치하는지? 샘플 명령어를 실행하여 테스트합니다.
3. **커버되지 않은 새 패턴** -- 변경된 파일을 읽고 스킬이 검사하지 않는 새로운 규칙, 설정, 패턴을 식별합니다. 확인 사항:
   - 새로운 타입 정의, enum 변형, 또는 exported 심볼
   - 새로운 등록(registration) 또는 설정
   - 새로운 파일 명명 또는 디렉토리 규칙
4. **삭제된 파일의 잔여 참조** -- 스킬의 Related Files에 있는 파일이 코드베이스에 더 이상 존재하지 않는 경우?
5. **변경된 값** -- 스킬이 검사하는 특정 값(식별자, 설정 키, 타입 이름)이 수정된 파일에서 변경되었는지?

발견된 각 갭을 기록합니다:

```markdown
| 스킬 | 갭 유형 | 상세 |
|------|---------|------|
| verify-api | 파일 누락 | `src/server/newHandler.ts`가 Related Files에 없음 |
| verify-ui | 새 패턴 | 새 컴포넌트가 검사되지 않는 규칙을 사용 |
| verify-test | 오래된 값 | 설정 파일의 테스트 러너 패턴이 변경됨 |
```

### Step 4: CREATE vs UPDATE 결정

다음 결정 트리를 적용합니다:

```
커버되지 않은 각 파일 그룹에 대해:
    IF 기존 전문 에이전트가 해당 도메인을 커버하는 경우:
        -> "에이전트 위임"으로 표시 (verify-* 스킬 불필요)
    ELSE IF 기존 스킬의 도메인과 관련된 파일인 경우:
        -> 결정: 기존 스킬 UPDATE (커버리지 확장)
    ELSE IF 3개 이상의 관련 파일이 공통 규칙/패턴을 공유하는 경우:
        -> 결정: 새 verify 스킬 CREATE
    ELSE:
        -> "면제"로 표시 (스킬 불필요)
```

결과를 사용자에게 제시합니다:

```markdown
### 제안 액션

**에이전트 위임** (N개)
- `src/auth/*.ts` -- security-reviewer 에이전트가 보안 검증 담당
- `src/db/*.ts` -- database-reviewer 에이전트가 DB 검증 담당

**결정: 기존 스킬 UPDATE** (N개)
- `verify-api` -- 누락된 파일 참조 2개 추가, 탐지 패턴 업데이트
- `verify-test` -- 새 설정 패턴에 대한 탐지 명령어 업데이트

**결정: 새 스킬 CREATE** (M개)
- 새 스킬 필요 -- <패턴 설명> 커버 (X개 미커버 파일)

**액션 불필요:**
- `package.json` -- 설정 파일, 면제
- `README.md` -- 문서, 면제
```

`AskUserQuestion`을 사용하여 확인합니다:
- 어떤 기존 스킬을 업데이트할지
- 제안된 새 스킬을 생성할지
- 전체 건너뛰기 옵션

### Step 5: 기존 스킬 업데이트

사용자가 업데이트를 승인한 각 스킬에 대해, 현재 SKILL.md를 읽고 대상 편집을 적용합니다:

**규칙:**
- **추가/수정만** -- 아직 작동하는 기존 검사는 절대 제거하지 않음
- **Related Files** 테이블에 새 파일 경로 추가
- 변경된 파일에서 발견된 패턴에 대한 새 탐지 명령어 추가
- 커버되지 않은 규칙에 대한 새 워크플로우 단계 또는 하위 단계 추가
- 코드베이스에서 삭제가 확인된 파일의 참조 제거
- 변경된 특정 값(식별자, 설정 키, 타입 이름) 업데이트

**예시 -- Related Files에 파일 추가:**

```markdown
## Related Files

| File | Purpose |
|------|---------|
| ... 기존 항목 ... |
| `src/server/newHandler.ts` | 유효성 검사가 포함된 새 요청 핸들러 |
```

**예시 -- 탐지 명령어 추가:**

````markdown
### Step N: 새 패턴 검증

**파일:** `path/to/file.ts`

**검사:** 검증할 내용에 대한 설명.

```bash
grep -n "pattern" path/to/file.ts
```

**위반:** 잘못된 경우의 모습.
````

### Step 6: 새 스킬 생성

**중요:** 새 스킬을 생성할 때, 반드시 사용자에게 스킬 이름을 확인받아야 합니다.

새로 생성할 각 스킬에 대해:

1. **에이전트 중복 확인** -- 위 "에이전트 중복 감지" 섹션의 매핑 테이블을 참조하여 해당 도메인의 전문 에이전트가 없는지 확인

2. **탐색** -- 관련 변경 파일을 읽어 패턴을 깊이 이해합니다

3. **사용자에게 스킬 이름 확인** -- `AskUserQuestion`을 사용합니다:

   스킬이 커버할 패턴/도메인을 제시하고, 사용자에게 이름을 제공하거나 확인하도록 요청합니다.

   **이름 규칙:**
   - 이름은 반드시 `verify-`로 시작해야 합니다 (예: `verify-auth`, `verify-api`, `verify-caching`)
   - 사용자가 `verify-` 접두사 없이 이름을 제공하면 자동으로 앞에 추가하고 사용자에게 알립니다
   - kebab-case를 사용합니다 (예: `verify-error-handling`, `verify_error_handling` 아님)

4. **생성** -- 프로젝트의 `.claude/skills/verify-<name>/SKILL.md`를 다음 템플릿에 따라 생성합니다:

```yaml
---
name: verify-<name>
description: <한 줄 설명>. <트리거 조건> 후 사용.
disable-model-invocation: true
---
```

필수 섹션:
- **Purpose** -- 2-5개의 번호가 매겨진 검증 카테고리
- **When to Run** -- 3-5개의 트리거 조건
- **Related Files** -- 코드베이스의 실제 파일 경로 테이블 (`ls`로 검증, 플레이스홀더 불가)
- **Workflow** -- 검사 단계, 각각 다음을 명시:
  - 사용할 도구 (Grep, Glob, Read, Bash)
  - 정확한 파일 경로 또는 패턴
  - PASS/FAIL 기준
  - 실패 시 수정 방법
- **Output Format** -- 결과를 위한 마크다운 테이블
- **Exceptions** -- 최소 2-3개의 현실적인 "위반이 아닌" 케이스

5. **3-way 동기화** -- 새 스킬 생성 후 반드시 아래 3개 파일을 업데이트합니다:

   **5a. 이 파일 자체 (`manage-skills/SKILL.md`) 업데이트:**
   - **등록된 검증 스킬** 섹션의 테이블에 새 스킬 행을 추가합니다
   - 첫 번째 스킬 추가 시 "(아직 등록된 검증 스킬이 없습니다)" 텍스트와 HTML 주석을 제거하고 테이블로 교체합니다
   - 형식: `| verify-<name> | <설명> | <커버 파일 패턴> |`

   **5b. `verify-implementation/SKILL.md` 업데이트:**
   - **실행 대상 스킬** 섹션의 테이블에 새 스킬 행을 추가합니다
   - 첫 번째 스킬 추가 시 "(아직 등록된 검증 스킬이 없습니다)" 텍스트와 HTML 주석을 제거하고 테이블로 교체합니다
   - 형식: `| <번호> | verify-<name> | <설명> |`
   - **글로벌**: `~/.claude/skills/verify-implementation/SKILL.md`
   - **프로젝트**: 프로젝트 CLAUDE.md에도 반영

   **5c. 프로젝트 `CLAUDE.md` 업데이트:**
   - `## Verify Skills` 테이블에 새 스킬 행을 추가합니다
   - 해당 섹션이 없으면 `## Skills` 아래에 `## Verify Skills` 섹션을 생성합니다
   - 형식: `| verify-<name> | <한 줄 설명> | <커버 파일 패턴> |`

### Step 7: 검증

모든 편집 후:

1. 수정된 모든 SKILL.md 파일을 다시 읽기
2. 마크다운 형식이 올바른지 확인 (닫히지 않은 코드 블록, 일관된 테이블 열)
3. 깨진 파일 참조가 없는지 확인 -- Related Files의 각 경로에 대해 파일 존재 확인:

```bash
ls <file-path> 2>/dev/null || echo "MISSING: <file-path>"
```

4. 업데이트된 각 스킬에서 탐지 명령어 하나를 드라이런하여 문법 유효성 검증
5. **3-way 동기화 확인** -- 다음 3개 테이블이 동기화되어 있는지 확인:
   - `manage-skills/SKILL.md`의 **등록된 검증 스킬** 테이블
   - `verify-implementation/SKILL.md`의 **실행 대상 스킬** 테이블
   - 프로젝트 `CLAUDE.md`의 **Verify Skills** 테이블

### Step 8: 요약 보고서

최종 보고서를 표시합니다:

```markdown
## 세션 스킬 유지보수 보고서

### 분석된 변경 파일: N개

### 에이전트 위임: A개
- `src/auth/*` -> security-reviewer (보안 검증)
- `src/db/*` -> database-reviewer (DB 검증)

### 업데이트된 스킬: X개
- `verify-<name>`: N개의 새 검사 추가, Related Files 업데이트
- `verify-<name>`: 새 패턴에 대한 탐지 명령어 업데이트

### 생성된 스킬: Y개
- `verify-<name>`: <패턴> 커버

### 3-way 동기화 상태:
- `manage-skills/SKILL.md`: 등록된 검증 스킬 테이블 업데이트
- `verify-implementation/SKILL.md`: 실행 대상 스킬 테이블 업데이트
- 프로젝트 `CLAUDE.md`: Verify Skills 테이블 업데이트

### 영향없는 스킬: Z개
- (관련 변경사항 없음)

### 미커버 변경사항 (적용 스킬 없음):
- `path/to/file` -- 면제 (사유)
```

---

## 생성/업데이트된 스킬의 품질 기준

생성되거나 업데이트된 모든 스킬은 다음을 갖추어야 합니다:

- **코드베이스의 실제 파일 경로** (`ls`로 검증), 플레이스홀더가 아닌 것
- **작동하는 탐지 명령어** -- 현재 파일과 매칭되는 실제 grep/glob 패턴 사용
- **PASS/FAIL 기준** -- 각 검사에 대해 통과와 실패의 명확한 조건
- **최소 2-3개의 현실적인 예외** -- 위반이 아닌 것에 대한 설명
- **일관된 형식** -- 기존 스킬과 동일 (frontmatter, 섹션 헤더, 테이블 구조)

---

## Related Files

| File | Purpose |
|------|---------|
| `~/.claude/skills/verify-implementation/SKILL.md` | 통합 검증 오케스트레이터 (이 스킬이 실행 대상 목록을 관리) |
| `~/.claude/skills/manage-skills/SKILL.md` | 이 파일 자체 (등록된 검증 스킬 목록을 관리) |
| 프로젝트 `CLAUDE.md` | 프로젝트 지침 (이 스킬이 Verify Skills 섹션을 관리) |
| `~/.claude/skills/verification-engine/SKILL.md` | 기술 검증 엔진 (빌드/타입/린트/테스트 - 이 스킬과 상호보완) |
| `~/.claude/agents/` | 전문 에이전트 디렉토리 (중복 감지 참조) |

## 예외사항

다음은 **문제가 아닙니다**:

1. **Lock 파일 및 생성된 파일** -- `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `Cargo.lock`, 자동 생성된 마이그레이션 파일, 빌드 출력물은 스킬 커버리지가 불필요
2. **일회성 설정 변경** -- `package.json`/`Cargo.toml`의 버전 범프, 린터/포매터 설정의 사소한 변경은 새 스킬이 불필요
3. **문서 파일** -- `README.md`, `CHANGELOG.md`, `LICENSE` 등은 검증이 필요한 코드 패턴이 아님
4. **테스트 픽스처 파일** -- 테스트 픽스처로 사용되는 디렉토리의 파일(예: `fixtures/`, `__fixtures__/`, `test-data/`)은 프로덕션 코드가 아님
5. **영향받지 않은 스킬** -- UNAFFECTED로 표시된 스킬은 검토 불필요; 대부분의 세션에서 대부분의 스킬이 이에 해당
6. **CLAUDE.md 자체** -- CLAUDE.md의 변경은 문서 업데이트이며, 검증이 필요한 코드 패턴이 아님
7. **벤더/서드파티 코드** -- `vendor/`, `node_modules/` 또는 복사된 라이브러리 디렉토리의 파일은 외부 규칙을 따름
8. **CI/CD 설정** -- `.github/`, `.gitlab-ci.yml`, `Dockerfile` 등은 인프라이며, 검증 스킬이 필요한 애플리케이션 패턴이 아님
9. **`.claude/` 디렉토리 파일** -- 스킬, 에이전트, 커맨드, 설정 파일은 메타 설정이며 verify-* 스킬 대상이 아님

## verification-engine과의 역할 구분

| 항목 | verification-engine | manage-skills + verify-* |
|------|-------------------|------------------------|
| 검증 대상 | 기술적 정합성 (빌드, 타입, 린트, 테스트) | 패턴/규칙 준수 (코딩 규칙, 아키텍처 패턴, 프로젝트 규약) |
| 실행 방식 | 서브에이전트 (fresh context) | 직접 실행 또는 서브에이전트 (스킬 수에 따라) |
| 자동 수정 | Fixable 9종 자동 수정 | 사용자 승인 후 수정 |
| 통합 지점 | `/handoff-verify` 커맨드 | `/verify-implementation` 커맨드 |

두 시스템은 **상호보완**이며 대체가 아닙니다:
- verification-engine = "코드가 동작하는가?" (빌드 통과, 테스트 통과)
- verify-* 스킬 = "코드가 규칙을 따르는가?" (패턴 준수, 규약 준수)
