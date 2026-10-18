# 의존성 관리 명령어 레퍼런스

## npm outdated

```bash
npm outdated              # 기본: Current / Wanted / Latest 비교
npm outdated --long       # + Package Type, Homepage 포함
npm outdated --json       # JSON 출력 (파싱용)
```

- **Current**: 설치된 버전
- **Wanted**: semver 범위 내 최신 (package.json 준수)
- **Latest**: npm 레지스트리 최신

## npm-check-updates (ncu)

```bash
npx npm-check-updates                    # 업데이트 가능 목록 확인 (변경 안 함)
npx npm-check-updates -u                 # package.json 업데이트 (모든 패키지)
npx npm-check-updates -u --target minor  # 마이너/패치만 업데이트
npx npm-check-updates -u --target patch  # 패치만 업데이트
npx npm-check-updates -u --filter <pkg>  # 특정 패키지만 업데이트
npx npm-check-updates --interactive      # 대화형 선택
npx npm-check-updates --peer             # peer dependency도 포함
```

## depcheck

```bash
npx depcheck                                    # 기본 분석
npx depcheck --ignores="@types/*,eslint-*"      # 특정 패키지 무시
npx depcheck --skip-missing                     # missing만 무시
npx depcheck --json                             # JSON 출력
```

**출력 항목**:
- `Unused dependencies`: 코드에서 import하지 않는 dependencies
- `Unused devDependencies`: 코드에서 import하지 않는 devDependencies
- `Missing dependencies`: import하지만 package.json에 없는 패키지

**False positive 주의**:
- PostCSS/Tailwind 플러그인: config 파일에서만 참조 → depcheck이 미감지
- Babel/ESLint 플러그인: 설정 파일에서 문자열로 참조
- CLI 도구 (husky, lint-staged): 스크립트에서만 사용
- `@types/*`: 타입 정의는 직접 import 안 해도 필요

## npm audit

```bash
npm audit                          # 전체 취약점 보고
npm audit --audit-level=moderate   # moderate 이상만
npm audit fix                      # 자동 수정 (semver 범위 내)
npm audit fix --force              # breaking change 허용 (주의!)
npm audit --json                   # JSON 출력
```

## npm ls (의존성 트리)

```bash
npm ls                     # 직접 의존성만
npm ls --all               # 전체 트리 (깊은 의존성 포함)
npm ls <package>           # 특정 패키지 위치 확인
npm ls --all 2>&1 | grep "peer dep"   # peer dependency 충돌 확인
npm ls --all 2>&1 | grep "ERESOLVE"   # 해결 불가 충돌
```

## npm info (패키지 정보)

```bash
npm info <package> version         # 최신 버전
npm info <package> versions        # 전체 버전 목록
npm info <package> repository.url  # GitHub URL (CHANGELOG 확인용)
npm info <package> peerDependencies # peer 요구사항
```
