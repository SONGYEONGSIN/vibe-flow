---
name: audit
description: vibe-flow harness 자기 진화 감사 (AHE evaluate→analyze→improve). dimension agent 병렬로 4-필드 finding(evidence/root-cause/fix/predicted-impact) 발굴 + 전역 단일 번호 + decision-observability ledger 기록. "내부 감사", "audit", "/audit", "harness 진화", "dimension 점검", "감사 라운드", "self-improvement" 요청 시 사용. retro(프로젝트 회고)·telemetry(사용량)와 구분 — 이건 harness(rules/skills/agents/hooks) 자체를 감사.
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent
---

# /audit — AHE harness 자기 진화 루프

`rules/harness-evolution.md`의 evaluate→analyze→improve 루프를 1 호출로 실행한다. 모델은 고정하고 harness만 증거 기반으로 진화시킨다. **증거 없는 수정 금지** — 모든 finding은 4 필드를 채우고, 그 효과는 ledger가 다음 라운드에 반증한다.

> **도메인 경계**: `/audit` = harness 자기 진화(7-component: prompts/descriptions/impl/hooks/skills/agents/memory). `retro` = 프로젝트 회고. `telemetry` = 사용량 관찰(이 스킬의 evaluate 데이터 소스). `/security-audit` = 공격 벡터. 중복 호출 금지.

---

## Phase 0. 라운드 라벨 + 직전 finding 반증 (decision-observability)

```bash
LEDGER_SH="core/skills/audit/scripts/ledger.sh"   # (.claude/ 런타임은 .claude/skills/audit/scripts/ledger.sh)
# 직전 라운드 open finding 목록 — fix 가 머지됐으면 actual_delta 채워 verified/refuted 전이
bash "$LEDGER_SH" open
```

**먼저** 직전 라운드 finding 중 fix가 머지된 것을 점검한다. 각 finding의 `predicted_delta`가 실제로 움직였는지 telemetry/점수로 확인 → `ledger.sh resolve <id> "<actual>" verified|refuted`. 움직이지 않았으면 `refuted`(오진 또는 무효 fix → 메타-학습). 이 단계가 AHE의 "decision observability" — 예측이 자동 반증된다.

라운드 라벨은 직전 라운드의 다음 글자(R1=A … R7=G → 다음 H).

## Phase 1. evaluate — trace 수집 (병렬)

pass/fail이 아닌 **trace**를 모은다. 병렬로:
- `telemetry --source events` + `--source session` (사용량/계측 — 7-component 중 skills/agents 활동)
- `git log --oneline` 직전 라운드 머지 PR (직전 fix 범위)
- `validate.sh` + 최근 CI(validation-tests.yml) 결과 (정합/회귀)
- 직전 ledger의 refuted finding (반복 결함 후보)

## Phase 2. analyze — dimension agent 병렬 위임

dimension마다 fresh-context agent를 **병렬**로 띄운다. 기본 4 + 필요 시 7-component 확장:

| Dim | 초점 (7-component) | agent |
|-----|-------------------|-------|
| D1 컨텍스트 | memory + system prompts | general-purpose |
| D2 아키텍처 | skills + sub-agents + hooks 경계/wire | architecture-reviewer |
| D3 dogfooding | 실 사용(telemetry) + tool descriptions trigger | general-purpose |
| D4 메타-검증 | validate.sh/sync/CI 거짓 PASS 경로 | general-purpose |

각 agent 프롬프트에 **반드시** 포함(템플릿):
1. baseline 점수(직전 라운드 dimension 점수) + Δ 산출 요구
2. **4-필드 finding contract 강제**: evidence(file:line+인용) / root_cause / targeted_fix(surgical 1줄) / predicted_impact(어느 component·지표 얼마)
3. **자가 반증 필수**: "추측 아닌 증거인가, 의도된 설계 아닌가" — 과거 false positive(F-D6, F-F7) 차단
4. component 귀속(7 중 하나 이상)
5. raw 파일 덤프 금지, 구조화 보고만 (Karpathy §5)

## Phase 3. number + de-conflict — 전역 단일 시퀀스

dimension 결과를 통합하고 **전역 단일 번호**를 부여한다 (dimension 간 충돌 금지 — R7에서 D1·D3가 같은 F-G01 부여한 사고 차단). 중복 finding은 병합(가장 강한 증거 채택), severity P0~P3 분류.

```bash
# finding 1건 = ledger append (id 자동 부여, stdout 으로 id 회신)
echo '{"round":"H","component":"skills","dimension":"D2",
  "evidence":"core/skills/x/SKILL.md:12 \"...\"","root_cause":"...",
  "fix":"...","predicted_delta":"+0.2 D2"}' | bash "$LEDGER_SH" append
```

## Phase 4. improve — fix PR (HARD-GATE 등급)

finding을 fix PR로 전환한다. `rules/git.md` HARD-GATE 등급(1~5 인라인 / 6~19 /plan / 20+ planner) + `rules/tdd.md`(RED→GREEN) + `rules/donts.md`(surgical) 준수. 테마별 PR 묶음(R6 #108 trio / R7 #110~#113 패턴). P3는 묶거나 defer(ledger status=`deferred`).

## Phase 5. 보고

```markdown
## 내부 감사 Round <N>
| Dim | 직전 | 현재 | Δ | 핵심 |
...
## Finding 매트릭스 (P0~P3, ledger 기록됨)
## 직전 라운드 반증 결과 (verified/refuted)
## 권장 fix 시퀀스 (PR 분할)
```

라운드 종료 시 `.claude/memory/MEMORY.md`(상태) + user-level audit memory(상세) 갱신.

## 규칙

- finding 4 필드 누락 시 무효 — ledger append 거부됨
- 점수만 보고 finding 없이 수정 금지 (anti-pattern, harness-evolution.md §5)
- dimension은 7-component 중 하나 이상에 귀속
- 직전 라운드 반증(Phase 0)을 건너뛰지 않는다 — decision observability가 루프를 닫는다
- fix는 본 스킬이 아니라 사람/`auto-build`가 수행 (evaluate+analyze+ledger까지가 `/audit` 책임; improve는 hand-off)
