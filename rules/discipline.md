# Work Discipline

작업 종류(코드 / 스크립트 / 문서 / 설정)와 무관하게 **항상 적용되는 일반 작업 원칙**. frontmatter가 없어 글로벌로 상시 로드된다 — 하네스가 자기 자신(`.sh`/`.md`/rules)을 수정할 때도 이 discipline이 컨텍스트에 존재한다. TS/React 특화 don'ts·conventions는 `rules/donts.md`·`rules/conventions.md`(path-scoped `src/**`)에 분리.

## 설계 선행 원칙

모든 코드 변경 전에 설계/계획이 선행되어야 한다. "간단한 변경"도 예외 없음.
순서: **설계 → TDD(테스트 작성 → 구현) → 검증**. `rules/tdd.md`의 RED-GREEN-REFACTOR는 설계 완료 후 적용.

- **최소 설계 체크리스트** (1줄이라도 답해야 구현 시작 가능):
  1. **무엇을**: 어떤 파일의 어떤 부분을 변경하는가
  2. **왜**: 이 변경이 필요한 이유 (버그? 기능? 리팩토링?)
  3. **영향**: 이 변경이 다른 코드에 미치는 영향
  4. **검증**: 변경 후 어떻게 확인할 것인가
- 규모별 설계 수준은 `rules/git.md`의 HARD-GATE 참조
- 설계 없이 코드부터 작성하면 **삭제하고 다시 시작**

## Surgical Change (작업 범위)

- **무관한 dead code 발견 시 언급만 하고 삭제하지 마라** — 별도 PR/이슈로 분리. drive-by 정리는 리뷰 부담만 키운다.
- **본인 변경이 만든 orphan만 정리** — import/변수/함수가 이번 변경으로 미사용이 됐다면 제거. 기존부터 dead였던 것은 건드리지 않는다.
- **인접 코드 "개선" 금지** — 안 깨진 거 리팩토링하지 않는다. 변경된 모든 줄이 사용자 요청에 직접 연결돼야 한다.
- **이해하지 못한 주석 임의 수정/삭제 금지** — 작성 의도가 명확하지 않은 주석은 보존한다. Karpathy 관찰 (X): *"agents change/remove comments and code they don't sufficiently understand as side effects, even if orthogonal to the task."* 의심스러우면 사용자에게 묻거나 별도 작업으로 분리.

## 완료 기준

- 테스트 없이 완료 선언 금지
- 테스트를 구현 코드보다 나중에 작성 금지 (test-last 금지, `rules/tdd.md` 참조)
- 항상 통과하는 테스트 작성 금지 (RED 단계를 거치지 않은 테스트는 무의미)
- TypeScript 에러가 있는 상태로 커밋 금지
- ESLint 경고가 있는 상태로 커밋 금지
- "should work" / "아마 될 거다" 금지 — 실행 결과 증거 필수
- `/verify` 실행 없이 완료 선언 금지
- 에러 발생 시 찍어맞추기(guess-and-check) 금지 (`rules/debugging.md` 참조)

## 합리화 방지

규칙을 회피하기 위한 합리화는 금지한다. 아래 패턴을 인식하고 차단할 것.

| 합리화 | 진실 |
|--------|------|
| "이건 간단한 변경이라 설계 안 해도 됨" | 간단해 보이는 변경이 가장 위험하다. 예외 없음 |
| "테스트 나중에 추가하면 됨" | 나중은 오지 않는다. 지금 작성한다 |
| "시간이 없어서 검증 생략" | 검증 없는 코드는 코드가 아니다 |
| "이전에 비슷한 걸 해봤으니 됨" | 경험은 증거가 아니다. 실행해서 확인한다 |
| "타입 에러인데 기능은 됨" | TypeScript 에러가 있는 코드는 커밋 불가 |
| "리팩토링이라 테스트 안 해도 됨" | 리팩토링이야말로 테스트가 필수다 |
| "설정 파일만 바꿨으니 괜찮음" | 설정 변경이 빌드를 깨뜨린 사례는 수없이 많다 |
| "한 줄만 바꿨는데 뭘" | 한 줄이 프로덕션을 멈출 수 있다 |
| "force push로 지난 커밋 정리할게" | Force push는 협업자 작업을 silently 덮어씌운다. rebase 후에도 `--force-with-lease`만 허용 |
| "이 테스트만 잠깐 skip할게" | `test.skip`/`it.skip`은 GREEN을 가짜로 만든다. 삭제하거나 고친다 |
| "복잡한 타입이라 `as any`/`!` 한 번만" | 타입 단언은 컴파일러 보호를 끈다. `unknown` + 가드 또는 제네릭으로 해결한다 |
| "이 부분은 `@ts-ignore` 빼고 못 짠다" | 못 짜는 게 아니라 설계가 잘못된 것. 타입을 다시 모델링한다 |
| "긴급 핫픽스니 TDD는 다음에" | 일반 버그/이슈는 RED→GREEN 강제. **단 production incident with active customer impact는 예외**: 수정→배포 가능, 다만 **24시간 내 회귀 테스트 + 인시던트 회고 필수** (`rules/tdd.md` 예외 섹션 참조) |

## 컨텍스트 윈도우 보호

Karpathy `context engineering` 원칙 (`rules/karpathy-principles.md` §5) 의 실 적용 룰.

- **긴 명령 출력은 파일로 리다이렉트, `tee` 금지** — `command > /tmp/out.log 2>&1` 패턴. `tee`는 stdout을 컨텍스트 윈도우에 흘려보내 노이즈를 만든다. Karpathy verbatim (autoresearch program.md): *"redirect everything... do NOT use `tee` or let output flood your context."*
- **대형 검색/조회 결과는 subagent에 위임** — 50+ 파일 grep, 전체 디렉토리 트리 dump, 큰 로그 분석 등은 Explore/general-purpose agent로 격리해 main context 보호.
