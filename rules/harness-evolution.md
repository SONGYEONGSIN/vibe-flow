# Harness Evolution — 관찰성 기반 자기 진화 (AHE)

vibe-flow는 자신을 감사하고 고치는 harness다. 이 규칙은 그 루프를 **AHE(Agentic Harness Engineering)** 형식으로 정식화한다 — 모델은 고정하고 **harness(rules/skills/agents/hooks)만** 관찰성 증거에 근거해 진화시킨다.

> 출처: [agentic-harness-engineering](https://github.com/china-qijizhifeng/agentic-harness-engineering) — evaluate→analyze→improve 루프 + 7-component observability + evolution meta-agent 4 필드. vibe-flow의 내부 감사(R1~R7, 3.0→4.4)는 이 루프를 손으로 돌려온 것이며, 본 규칙이 그것을 실행 가능한 계약으로 고정한다.

핵심 원칙: **증거 없는 harness 수정 금지.** 모든 변경은 4-필드 finding으로 정당화되고, 그 효과는 다음 라운드가 반증한다.

---

## 1. 루프 — evaluate → analyze → improve

| 단계 | 무엇 | vibe-flow 매핑 |
|------|------|---------------|
| **evaluate** | pass/fail이 아닌 **trace** 수집 | `telemetry`(events.jsonl 사용량) + session-logs + `validate.sh`/CI 결과 |
| **analyze** | trace를 root-cause 리포트로 압축 | `/audit` dimension agent 병렬(D1~Dn) + `retrospective` agent |
| **improve** | 4-필드 evolution finding → PR | `/audit` finding → `/plan`/직접 구현 → `/finish` PR |

자동화 수준: evaluate+analyze+finding은 `/audit`가 수행, improve는 사람(surgical 직접 PR) 또는 자율(`ledger.sh enqueue` → `auto-build` 큐 → cloud cycle fix PR). fix 머지 후 `mark-fixed` → 다음 라운드 `pending-verify`가 `predicted_delta`를 `actual_delta`로 반증(decision-observability 폐루프). **개선되더라도 단계를 건너뛰지 않는다** — trace 없이 분석 없고, finding 없이 수정 없고, 반증 없이 라운드 안 닫는다.

## 2. 7-Component Observability

harness를 7개 직교 컴포넌트로 나눠 **git(`core/`)에서 추적**한다. 감사 dimension과 finding은 반드시 이 중 하나 이상에 귀속된다:

1. **system prompts** — `CLAUDE.md.template`, `core/rules/*`
2. **tool/skill descriptions** — SKILL.md frontmatter `description` (trigger 품질)
3. **implementations** — skill 본문 + `scripts/`
4. **middleware/hooks** — `core/hooks/*`
5. **skills** — `core/skills/*` 카탈로그
6. **sub-agents** — `core/agents/*`
7. **memory** — `.claude/memory/` (MEMORY.md 인덱스 + leaves)

> drift 검증(`validate.sh` + `sync-drift.sh`, R7 F-G01~G03)이 이 7-component의 `core/ ↔ .claude/` 정합을 보장한다 — 관찰 대상과 런타임이 갈라지면 진화가 거짓 신호 위에 선다.

## 3. 4-필드 Finding Contract

모든 finding은 4 필드를 **전부** 채운다 (누락 시 finding 무효):

| 필드 | 내용 | 자기검증 |
|------|------|---------|
| **evidence** | `file:line` + 1줄 인용 (재현 가능) | "추측인가 증거인가" — F-D6/F-F7류 false positive 차단 |
| **root cause** | 왜 결함인가 (증상 아닌 원인) | "증상을 가렸나, 원인을 짚었나" |
| **targeted fix** | surgical 수정 1줄 | "인접 코드 개선 아닌 최소 변경인가" (donts.md Surgical) |
| **predicted impact** | 어느 component·dimension 지표를 얼마 움직이나 | "측정 가능한 델타인가" |

finding ID는 **전역 단일 시퀀스**(`F-<라운드><번호>`, 예 `F-G01`)로 **dimension 간 충돌 금지** (R7에서 D1·D3가 같은 `F-G01` 부여한 사고 재발 방지).

## 4. Decision Observability — 예측의 반증

각 finding의 `predicted impact`는 **ledger**(`.claude/memory/audit-ledger.jsonl`)에 기록되고, **다음 라운드가 `actual_delta`를 채워 반증**한다:

- 예측한 지표가 실제로 움직였나? → fix 유효성 확인
- 안 움직였거나 악화 → fix 재검토 또는 finding 오진 (메타-학습)
- 라운드 평균 점수 델타(현재 측정)를 **finding 단위로 하향** — "어느 fix가 점수를 올렸나"를 추적

ledger 1 entry = `{round, id, component, dimension, evidence, root_cause, fix, predicted_delta, actual_delta, status}`. `status` ∈ `open|fixed|verified|refuted|deferred`.

> **lifecycle 불변식 (F-H07, R8)**: finding 은 `append`(status=open)로 시작해 fix PR 머지 시 `mark-fixed`(→fixed, actual_delta=null), 다음 라운드가 측정 후 `resolve`(→verified/refuted)로 닫는다. **`actual_delta`는 반드시 실측 델타** — "fix live on main" 같은 배포-상태 문자열 금지(측정 없이 verified 로 닫으면 반증 메커니즘이 단락된다). seed/backfill 시에도 `verified`가 아닌 `fixed`로 넣어 다음 라운드가 `pending-verify`로 실측하게 한다.

## 5. Cross-link

- 실행: **`/audit` 스킬** — 본 규칙의 루프를 1 호출로 수행 (dimension dispatch → 4-필드 finding → ledger write)
- 데이터: `skills/telemetry`(evaluate) / `agents/retrospective`(analyze) / `skills/learn`(memory 저장)
- 게이트: `rules/git.md` HARD-GATE(improve PR 등급) / `rules/tdd.md`(fix는 RED→GREEN) / `rules/donts.md`(surgical) / `rules/karpathy-principles.md` §5(context 큐레이션)
- 정합: `validate.sh` + `scripts/sync-drift.sh` (7-component `core ↔ .claude` drift)

> **anti-pattern**: 점수만 보고 finding 없이 "느낌으로" rules/skills를 고치는 것. AHE의 교훈 — "rank 30→top 5는 prompt 재작성이 아니라 구조(컨텍스트 전달·도구 토폴로지·관찰성) 변경에서 온다." 증거→근거→수정→반증의 사슬을 끊지 않는다.
