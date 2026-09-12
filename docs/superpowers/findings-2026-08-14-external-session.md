# 외부 세션 발굴 finding — R24/Y 후보 3건

**출처**: pantograph 저장소에서 진행한 구현 세션 (2026-08-12~14). `/audit` 라운드가 아니라 **실작업 중 자기 실증**으로 나온 것이다.
**형식**: `harness-evolution.md` §3 4-필드 계약
**상태**: 전건 `open`. ledger 미등재 — 아래 §4 의 명령으로 넣는다.

> **근거의 성격**: 세 건 모두 이 세션에서 **실제로 발생한 실패**에 근거한다. 추측이 아니다. 다만 표본이 세션 하나이므로, 다른 프로젝트에서 같은 빈도로 나타나는지는 재지 않았다.

---

## F-Y01 — TDD 규칙이 "무의미한 테스트"를 RED 이력으로 판정한다

**component**: system prompts **dimension**: D1 (컨텍스트)

### evidence

```
core/rules/discipline.md:29  "항상 통과하는 테스트 작성 금지 (RED 단계를 거치지 않은 테스트는 무의미)"
core/rules/tdd.md:26         "항상 통과하는 테스트는 아무것도 검증하지 않으므로 무의미하다"
```

두 문장 모두 **무의미 ⇔ RED 미이행** 을 전제한다. 반례 2건을 실측했다.

**반례 A — RED 를 거쳤으나 보호력 0.** `tmpl` 정렬 슬라이스의 불변식 시험(T5). 픽스처가 삽입 지점 앞뒤에 앵커를 둬서 타깃 경로를 한 번도 지나지 않았다. RED 는 났지만 **다른 이유로** 났고, 그 테스트가 잡으려던 변이를 넣어도 초록이었다.

**반례 B — 작성 시점엔 유효했으나 이후 무효화.** CLI 회귀 시험 3건이 종료 코드와 출력 파일 유무만 검사했다. 작성 시점엔 거절 자체가 없어 RED 가 정당하게 났다. 이후 다른 검사(`missing_text`)가 같은 입력을 거절하게 되자 판별력을 잃었다 — `unused_field` 분기 3곳을 전부 `if false` 로 무력화해도 **초록**이었다(실측). 같은 시점 `internal/patch` 단위 시험 2건은 정상 실패했다.

### root cause

판별력을 **상태**로 다룬다. RED 는 일회성 사건이라 (a) 의도한 결함이 아닌 다른 이유로 실패했을 가능성과 (b) 시간이 지나며 다른 검사가 생겨 판별력을 잃는 경우를 구별하지 못한다. 판별력은 **시점마다 다시 재야 하는 성질**이다.

변이시험은 하네스에 **이미 있다** — `core/skills/` 아래 4개 파일이 언급한다(`codebase-analyzer/references/bug-finder.md`, `security-audit/SKILL.md`, `seo-master/SKILL.md`, `seo-master/references/ai-geo.md`). **전부 스킬이고 규칙은 하나도 없다.** 즉 **결함을 찾을 때만** 쓰고 **테스트를 만들 때는** 안 쓴다.

### targeted fix

`core/rules/tdd.md` 의 RED 절에 한 줄 추가:

> RED 확인 후, 담당 로직만 깨뜨리는 변이를 넣어 그 테스트가 실제로 실패하는지 확인하고 정확히 복원한다(`git checkout -- <file>`). **변이가 컴파일됐는지 먼저 확인한다** — 빌드 실패를 "실패 없음"으로 읽는 사고가 있었다.

### predicted impact

**D1 +0.2** — 감사에서 hollow 테스트로 분류되는 비율 증가. **측정**: 다음 라운드 D4 가 변이주입으로 잡는 "미검증 분기" finding 수가 줄어야 한다(작성 시점에 이미 걸러지므로). `tdd-enforce.sh` 는 변이 단계를 검사하지 않으므로 규칙 층 개선에 한정된다 — 훅 강제는 별도 finding 감이다.

---

## F-Y02 — 적대적 탐색이 어느 규칙·스킬·에이전트에도 없다

**component**: system prompts **dimension**: D4 (메타-검증)

### evidence

```
$ grep -rln "적대적|adversarial|반증 시도|뚫어" core/rules/ core/skills/ core/agents/
(0건)
```

대조: `core/rules/harness-evolution.md:37-46` 의 4-필드 finding 은 **이미 관측된 결함**을 정리하는 형식이다. "없다고 믿는 곳을 능동적으로 뚫어보라"는 요구는 어디에도 없다.

**실증**: pantograph 의 명시적 삭제 슬라이스에서 수정 웨이브를 3회 돌렸다.

| 웨이브 | 적대적 탐색 요구 | 결과 |
|---|---|---|
| 1 | 없음 | "닫았다"로 종료. **구멍 2개 잔존** |
| 2 | 명시 요구 | 새 결함 1건 발견 → `unbalanced_xml` 신설 |
| 3 | 명시 요구 | 새 결함 1건 발견 → `incomplete_xml` 신설 |

웨이브 1이 닫았다고 선언한 규칙("치환 XML 은 요소를 하나 이상 포함해야 한다")을 우회하는 입력이 두 종류 남아 있었고, 둘 다 **요구했을 때만** 나왔다.

### root cause

감사·리뷰 절차가 **관측된 결함에서 출발**한다. 규칙이 새로 생긴 직후 — 검증이 가장 얇은 시점 — 에 그 규칙의 우회 경로를 찾는 단계가 없다. 새 게이트는 자기가 막으려던 것만 막고, 막지 못하는 이웃 입력은 아무도 시도하지 않는다.

### targeted fix

`core/rules/discipline.md` "완료 기준"에 한 줄 추가:

> 새 제약·검증·게이트를 도입한 작업은 완료 선언 전에 **그 제약을 우회하는 입력을 최소 3종 시도**하고 결과를 보고한다. 통과한 것이 있으면 그것이 다음 finding 이다.

### predicted impact

**D4 +0.3** — 게이트 도입 슬라이스의 잔존 우회 경로 발견율 증가. **측정**: 게이트를 신설한 PR 이후 라운드에서, 같은 게이트를 대상으로 하는 신규 finding 수. 현재는 도입 후 라운드에서 발견되지만(사후), fix 후에는 도입 슬라이스 안에서 발견되어야 한다(사전). 사후 발견 건수가 줄면 유효.

---

## F-Y03 — CLAUDE.md 는 배포되지만 관측되지 않는다

**component**: middleware/hooks **dimension**: D4 (메타-검증)

### evidence

설치 경로는 **있다**:

```
setup.sh:560   "$SCRIPT_DIR/templates/CLAUDE.md.template" \
```

관측 경로는 **없다**:

```
$ grep -rln "CLAUDE.md" core/hooks/          (0건, 훅 29개)
$ grep -n "CLAUDE.md" core/scripts/*.sh      (0건, validate.sh·sync-drift.sh 포함)
```

**실측** — `~/개발/build/` 하위 git 저장소 15개 중 **5개에 `CLAUDE.md` 없음**:

```
repick-Design Publishing / repick-design / repick-prompt-biz / repick-prompt / vibe-flow
```

마지막 항목에 주의. **템플릿을 배포하는 vibe-flow 자신이 그것을 갖고 있지 않다.**

(pantograph 는 이 세션에서 만들었다. 그 전까지는 6/15 였다.)

### root cause

7-component 중 1번(system prompts)의 **원본**(`templates/CLAUDE.md.template`)은 감사 대상이고 실제로 finding 이 나온 이력도 있다(F-Q10 등). 그러나 **배포본**(각 프로젝트의 `CLAUDE.md`)은 어느 컴포넌트에도 속하지 않는다.

`setup.sh` 는 1회성이라 미설치·삭제·노후를 검출하지 못한다. 그 결과 프로젝트 고유 계약이 에이전트 컨텍스트에 상주하지 않고, **서브에이전트를 띄울 때마다 사람이 손으로 주입**해야 한다. pantograph 의 지난 슬라이스에서 같은 제약 문단을 실행자 3회·리뷰어 5회·수정 웨이브 3회, 합쳐 열 번 넘게 반복해 붙였다. 한 번이라도 빠뜨렸으면 그 에이전트는 프로젝트 규칙 없이 작업했다.

### targeted fix

`core/scripts/validate.sh` 에 체크 하나 추가:

> 현재 저장소 루트에 `CLAUDE.md` 가 있는지 확인하고, 없으면 `setup.sh` 의 템플릿 설치를 안내한다.

### predicted impact

**D4 +0.2** — 현재 5/15 미보유가 검출 가능해진다. **측정**: 체크 도입 후 `~/개발/build/` 하위 저장소의 `CLAUDE.md` 미보유 수. 0 에 수렴하면 유효. 수렴하지 않으면 검출은 되나 조치되지 않는다는 뜻이고, 그건 별개 문제다.

---

## §4 ledger 등재

아래 세 줄을 `.claude/memory/audit-ledger.jsonl` 에 append 한다. **아직 넣지 않았다** — 자율 루프가 즉시 집어가므로 사람이 판단할 지점이다.

`round` 은 최근 라운드가 `X`(R23) 이므로 `Y` 로 잡았다. `/audit` 라운드가 아닌 외부 세션 발굴이므로, 라운드 번호를 쓰는 것이 맞는지는 확인이 필요하다.

```
core/skills/audit/scripts/ledger.sh append \
  --round Y --id F-Y01 --component "system prompts" --dimension D1 ...
```

세 건 모두 **수정 대상이 규칙 파일**이다. `evolution-guard.sh` 의 보호 대상에 걸리는지 확인이 필요하다 — F-X11 이 지적한 "protected 파일을 요구하는 task 가 자율 큐에 섞이는" 경우에 해당할 수 있다.

## §5 이 문서의 한계

- 표본이 **세션 하나**다. 세 결함 모두 실제로 발생했지만, 다른 프로젝트·다른 작업 종류에서 같은 빈도로 나타나는지는 재지 않았다
- `predicted_delta` 의 수치는 **추정**이다. 각 finding 의 측정 방법을 함께 적었으므로 다음 라운드가 반증할 수 있다 — 그것이 이 수치의 유일한 용도다
- F-Y01 의 fix 는 규칙 층에만 닿는다. 훅으로 강제하는 것은 별도 판단이 필요하다 (변이시험은 자동 판정이 어렵다)
