---
name: dependency-manager
description: |
  Use when checking for outdated packages, breaking changes, unused dependencies, or lock file integrity.
  "의존성 점검", "패키지 업데이트", "outdated 확인", "depcheck", "npm outdated",
  "breaking change", "lock 파일", "의존성 정리", "패키지 정리" 요청 시 사용.
---

# Dependency Manager

프로젝트 의존성 라이프사이클을 관리하는 스킬. security-audit(공격 벡터 관점)과 구분: 이 스킬은 **패키지 건강성과 업그레이드 안전성**에 집중한다.

## 워크플로우

### Phase 1: 현황 파악

```bash
# 1. outdated 패키지 확인
npm outdated --long

# 2. 미사용 의존성 탐지
npx depcheck --ignores="@types/*,eslint-*,prettier,typescript,postcss,autoprefixer,tailwindcss"

# 3. 보안 취약점 (security-audit과 공유 영역)
npm audit --audit-level=moderate

# 4. lock 파일 정합성
npm ls --all 2>&1 | grep "ERESOLVE\|peer dep\|invalid"
```

### Phase 2: 분류 및 우선순위

결과를 4단계로 분류:

| 등급 | 기준 | 조치 |
|------|------|------|
| **Critical** | 보안 취약점 (High/Critical) | 즉시 업데이트 |
| **Major** | 메이저 버전 뒤처짐 (2+ major) | breaking change 분석 후 업데이트 |
| **Minor** | 마이너/패치 버전 뒤처짐 | 일괄 업데이트 가능 |
| **Cleanup** | 미사용 의존성 | 제거 |

### Phase 3: Breaking Change 분석

Major 업데이트가 필요한 패키지에 대해 `references/breaking-change-analysis.md`의 체크리스트를 따른다.

핵심 단계:
1. 해당 패키지의 CHANGELOG/릴리스 노트 확인 (GitHub releases 또는 npm info)
2. Breaking changes 목록 추출
3. 프로젝트 내 영향받는 코드 검색 (`Grep`으로 deprecated API 사용처 탐색)
4. 업그레이드 순서 결정 (의존성 트리 하위부터)

### Phase 4: 안전한 업데이트 실행

```bash
# 1. 패치/마이너 일괄 업데이트 (안전)
npx npm-check-updates -u --target minor
npm install

# 2. 빌드 검증
npm run build

# 3. 테스트 검증
npm test

# 4. Major 업데이트는 하나씩
npx npm-check-updates -u --filter <package-name>
npm install
npm run build && npm test
```

### Phase 5: Lock 파일 정합성 확인

```bash
# package.json과 lock 파일 동기화 확인
npm ls 2>&1 | head -50

# peer dependency 충돌 확인
npm ls --all 2>&1 | grep "peer dep"
```

문제 발견 시: `rm -rf node_modules package-lock.json && npm install`로 clean install 후 재검증.

## 출력 형식

```markdown
## 의존성 점검 결과

**점검 일시**: [DATE]
**총 의존성**: [N]개 (dependencies: X, devDependencies: Y)

### Critical (즉시 조치)
| 패키지 | 현재 | 최신 | 사유 |
|--------|------|------|------|

### Major (분석 후 업데이트)
| 패키지 | 현재 | 최신 | Breaking Changes |
|--------|------|------|-----------------|

### Minor (일괄 업데이트 가능)
[패키지 목록]

### Cleanup (제거 대상)
| 패키지 | 사유 |
|--------|------|

### Lock 파일 상태
- 정합성: [OK / 문제 있음]
- peer dependency 충돌: [없음 / 목록]

### 권장 업데이트 순서
1. [첫 번째 패키지] — 이유
2. [두 번째 패키지] — 이유
```

## 명령어 상세

`references/commands.md` 참조 — npm outdated, depcheck, npm-check-updates 옵션 상세.

## Breaking Change 분석 상세

`references/breaking-change-analysis.md` 참조 — 프레임워크별 마이그레이션 체크리스트.
