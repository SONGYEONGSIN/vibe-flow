# Dead Code 탐지 가이드

## 탐지 대상 6가지

### 1. 미사용 Export
- `Grep`으로 `export` 키워드가 있는 모듈 추출
- 각 export 이름을 프로젝트 전체에서 `import` 검색
- 어디서도 import하지 않는 export → dead code 후보

### 2. 미사용 컴포넌트
- `Glob`으로 `**/*.tsx` 컴포넌트 파일 수집
- 컴포넌트명(PascalCase)을 다른 파일에서 JSX 태그로 사용하는지 검색
- 라우트 파일(page.tsx, layout.tsx)은 Next.js가 자동 로드하므로 제외

### 3. 도달 불가 코드
- early return 이후 코드
- `if (false)`, `if (0)` 등 항상 false인 조건문
- throw/return 이후 남은 코드
- TypeScript strict 모드에서 `--noUnusedLocals`, `--noUnusedParameters` 활용

### 4. 미사용 의존성
```bash
npx depcheck --ignores="@types/*,eslint-*,prettier,typescript"
```
- devDependencies 중 빌드/린트 도구는 false positive가 많으므로 `--ignores`로 제외
- peerDependencies는 직접 import하지 않아도 정상

### 5. 미사용 변수/함수
```bash
npx tsc --noEmit --noUnusedLocals --noUnusedParameters 2>&1 | grep "declared but"
```
- `_` 접두사 변수는 의도적 미사용이므로 제외

### 6. 빈 파일 / 주석만 있는 파일
- 0바이트 파일
- 주석과 import만 있고 실제 로직이 없는 파일

## 출력 형식

```markdown
### Dead Code 탐지 결과

| 파일 | 유형 | 대상 | 줄 수 | 안전 제거 |
|------|------|------|-------|----------|
| `src/utils/old.ts` | 미사용 export | `formatLegacy` | 45줄 | Yes |
| `src/components/Unused.tsx` | 미사용 컴포넌트 | `<Unused />` | 120줄 | Yes |
| `package.json` | 미사용 의존성 | `lodash` | - | 확인 필요 |

**예상 절감**: 총 165줄 제거 가능
```

## 주의사항
- **Dynamic import**: `import()` 문법으로 로드하는 모듈은 정적 분석으로 탐지 불가 → 제거 전 확인 필수
- **Re-export 패턴**: 배럴 파일(index.ts)에서 re-export만 하는 경우, 최종 소비자 추적 필요
- **라이브러리 public API**: npm 패키지로 배포하는 경우 외부에서 사용할 수 있으므로 export 제거 주의
- **CSS-in-JS / className**: 문자열로 참조하는 컴포넌트는 Grep에 잡히지 않을 수 있음
