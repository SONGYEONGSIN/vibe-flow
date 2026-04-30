---
name: release
effort: medium
description: 릴리즈 — conventional commits에서 semver 자동 판단, CHANGELOG.md 갱신, git tag + push. /release [version]
---

Chops release 스킬 패턴 적용. Conventional Commits 기반 semver 자동 결정 + CHANGELOG 관리 + 사용자 확인 후 태그.

## 사용법

- `/release` — 커밋 분석으로 버전 자동 결정
- `/release 1.2.0` — 지정 버전으로 릴리즈
- `/release --dry-run` — 실제 태그 없이 미리보기만

## 절차

### 1. 사전 검증

다음을 모두 확인하고 하나라도 실패하면 안내 후 종료:

1. **작업 트리 클린**: `git status --porcelain` — 미커밋 변경 있으면 "먼저 커밋하세요" 안내
2. **main 브랜치**: `git branch --show-current` — main이 아니면 "main에서 실행하세요" 안내
3. **CHANGELOG.md 존재**: 없으면 "CHANGELOG.md가 없습니다" 안내

### 2. 버전 결정

`$ARGUMENTS`에 버전이 명시되어 있으면 그대로 사용. 없으면 자동 결정:

1. 최신 태그 확인:
   ```bash
   git tag -l 'v*' | sort -V | tail -1
   ```
   태그가 없으면 `v0.0.0`을 기준으로 사용.

2. 마지막 태그 이후 커밋 목록:
   ```bash
   git log <latest_tag>..HEAD --oneline --format='%s'
   ```

3. Semver 자동 판단:
   - `feat:` 또는 `feat(` → **minor** (0.1.0 → 0.2.0)
   - `fix:`, `refactor:`, `chore:`, `docs:`, `perf:`, `test:`, `ci:` → **patch** (0.1.0 → 0.1.1)
   - `BREAKING CHANGE` 또는 `!:` 접미사 → 사용자에게 확인 요청
   - 판단 불가 → 사용자에게 질문: "Patch / Minor / Major 중 선택"

4. 태그 이후 커밋이 0개면 "릴리즈할 변경사항이 없습니다" 안내 후 종료.

### 3. 사용자 확인

**반드시** 진행 전 확인:

```
릴리즈 v{VERSION} 진행할까요?

포함 커밋 ({N}개):
  - feat: 새 기능 A
  - fix: 버그 B 수정
  ...

[계속 / 버전 변경 / 취소]
```

취소 시 종료. 버전 변경 시 새 버전 입력 받기.

### 4. CHANGELOG.md 갱신

1. `## [Unreleased]` 섹션 내용 확인
2. 내용이 비어있으면 커밋에서 자동 생성:
   - 커밋 메시지를 **사용자 관점으로 재작성** (기술 용어 → 사용자 혜택)
   - 나쁜 예: "feat: add error classifier to tool-failure-handler"
   - 좋은 예: "도구 실패 시 13가지 에러 유형을 자동 분류하고 복구 힌트 제공"
   - 작성 후 사용자에게 확인 요청
3. `## [Unreleased]`를 `## [{VERSION}] - {YYYY-MM-DD}`로 변경
4. 최상단에 빈 `## [Unreleased]` 섹션 추가

### 5. 태그 및 푸시

`--dry-run`이면 여기서 결과만 보여주고 종료.

```bash
git add CHANGELOG.md
git commit -m "chore: release v{VERSION}"
git tag -a "v{VERSION}" -m "Release v{VERSION}"
git push origin main --tags
```

### 6. 완료 보고

```markdown
## Release v{VERSION} 완료

- 태그: v{VERSION}
- 커밋: {N}개 포함
- CHANGELOG: 갱신됨
- 푸시: origin/main + tags
```

### 7. events.jsonl 기록

```bash
echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"type\":\"release\",\"version\":\"$VERSION\",\"semver_type\":\"$SEMVER_TYPE\",\"commits\":$N}" >> .claude/events.jsonl
```

`semver_type`: `major` | `minor` | `patch`. retrospective의 릴리즈 빈도 분석 입력.

## 규칙

- 사용자 확인 없이 태그/푸시 절대 금지
- CHANGELOG 항목은 사용자 관점으로 재작성 (커밋 메시지 복사 붙여넣기 금지)
- `--dry-run`은 파일 수정 없이 미리보기만
- 릴리즈 커밋은 `chore: release v{VERSION}` 형식
- CHANGELOG에 `## [Unreleased]` 섹션이 항상 최상단에 존재해야 함
