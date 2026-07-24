---
allowed-tools: Bash(git:*), Bash(mkdir:*), Bash(rm:*), Bash(cp:*), Read, Write
description: 작업 상태 저장/복원 (v6)
argument-hint: save|restore|list|diff|delete ["이름"] [--tag 태그]
---

# /checkpoint - 작업 상태 저장/복원 (v6)

---

## 0단계: 파라미터 파싱

| 서브커맨드 | 설명 | 필수 인자 |
|-----------|------|----------|
| `save` | 현재 상태 저장 | "이름" |
| `restore` | 저장된 상태 복원 | "이름" |
| `list` | 저장된 체크포인트 목록 | 없음 |
| `diff` | 체크포인트 간 차이 비교 | "이름" |
| `delete` | 체크포인트 삭제 | "이름" |

옵션:
- `--tag 태그`: 체크포인트에 태그 부착 (예: `--tag stable`, `--tag pre-refactor`)

---

## 1단계: 저장소 경로

체크포인트 저장 위치:

```
.claude/checkpoints/
  {name}/
    metadata.json
    staged.patch      # staged 변경사항
    unstaged.patch    # unstaged 변경사항
    untracked/        # untracked 파일 복사본
```

저장소 디렉토리가 없으면 생성한다:

```bash
mkdir -p .claude/checkpoints
```

---

## 2단계: save 서브커맨드

### 2-1. 현재 상태 수집

```bash
# 현재 브랜치
git branch --show-current

# 현재 커밋
git rev-parse --short HEAD

# staged 변경사항
git diff --cached > .claude/checkpoints/{name}/staged.patch

# unstaged 변경사항
git diff > .claude/checkpoints/{name}/unstaged.patch

# 변경 통계
git diff --stat HEAD

# untracked 파일 목록
git ls-files --others --exclude-standard
```

### 2-2. untracked 파일 복사

untracked 파일이 있으면 복사본을 저장한다:

```bash
mkdir -p .claude/checkpoints/{name}/untracked
# 각 untracked 파일을 디렉토리 구조 유지하며 복사
```

### 2-3. 메타데이터 생성

```json
{
  "name": "기능완료",
  "timestamp": "2026-02-07T15:30:00Z",
  "branch": "feature/auth",
  "commit": "abc1234",
  "files": [
    "src/auth/login.ts",
    "src/auth/register.ts"
  ],
  "stats": {
    "additions": 45,
    "deletions": 12,
    "files_changed": 3,
    "untracked_count": 1
  },
  "tags": ["stable"],
  "auto": false,
  "v6_metadata": {
    "security_status": "pass"
  }
}
```

v6_metadata 필드 설명:
- `security_status`: 마지막 보안 검사 결과 (pass/fail/unknown)

### 2-4. 자동 체크포인트

다음 상황에서 자동으로 체크포인트를 생성한다:
- `/commit-push-pr` 실행 전
- `/handoff-verify` 검증 3회 실패 시

자동 체크포인트의 `auto` 필드는 `true`로 설정한다.
이름 형식: `auto-{YYYYMMDD-HHmmss}`

---

## 3단계: restore 서브커맨드

### 3-1. 체크포인트 존재 확인

```bash
ls .claude/checkpoints/{name}/metadata.json
```

### 3-2. 현재 상태 백업

복원 전 현재 상태를 `pre-restore-{timestamp}` 이름으로 자동 저장한다.

### 3-3. 복원 실행

```bash
# staged 변경사항 복원
git apply .claude/checkpoints/{name}/staged.patch
git add -A

# unstaged 변경사항 복원
git apply .claude/checkpoints/{name}/unstaged.patch

# untracked 파일 복원
cp -r .claude/checkpoints/{name}/untracked/* ./ 2>/dev/null
```

### 3-4. 복원 검증

복원 후 파일 상태를 확인하고 메타데이터와 대조한다.

---

## 4단계: list 서브커맨드

모든 체크포인트를 시간순으로 나열한다.

각 체크포인트의 metadata.json을 읽어 요약 정보를 표시한다.

---

## 5단계: diff 서브커맨드

지정된 체크포인트와 현재 상태의 차이를 보여준다.

```bash
# 체크포인트 커밋과 현재 커밋 비교
git diff {checkpoint_commit}..HEAD --stat
```

---

## 6단계: delete 서브커맨드

지정된 체크포인트 디렉토리를 삭제한다.

```bash
rm -rf .claude/checkpoints/{name}
```

삭제 전 체크포인트 내용을 표시하고 확인한다.

---

## 7단계: 출력

### save 성공 시

```
════════════════════════════════════════════════════════════════
  Checkpoint v6 - Save
════════════════════════════════════════════════════════════════

  이름: 기능완료
  브랜치: feature/auth
  커밋: abc1234
  변경: +45 -12 (3 files)
  태그: stable

  경로: .claude/checkpoints/기능완료/

════════════════════════════════════════════════════════════════
```

### restore 성공 시

```
════════════════════════════════════════════════════════════════
  Checkpoint v6 - Restore
════════════════════════════════════════════════════════════════

  복원: 기능완료 (2026-02-07 15:30)
  백업: pre-restore-20260207-160000

  복원된 파일: 3개
  상태: 정상

════════════════════════════════════════════════════════════════
```

### list 출력

```
════════════════════════════════════════════════════════════════
  Checkpoint v6 - List
════════════════════════════════════════════════════════════════

  총 3개 체크포인트

  [1] 기능완료         | feature/auth | +45 -12 | stable    | 02-07 15:30
  [2] pre-refactor    | main         | +120 -8 | -         | 02-07 14:00
  [3] auto-20260207   | feature/auth | +10 -3  | auto      | 02-07 13:00

  복원: /checkpoint restore "이름"
  비교: /checkpoint diff "이름"
  삭제: /checkpoint delete "이름"

════════════════════════════════════════════════════════════════
```
