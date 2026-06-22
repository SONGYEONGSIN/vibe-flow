# Brainstorm: vibe-flow에 AHE(Agentic Harness Engineering) 정식화

> 작성 2026-06-23. 입력 = 사용자 goal(1순위 AHE 정식화). 근거 레포: [china-qijizhifeng/agentic-harness-engineering](https://github.com/china-qijizhifeng/agentic-harness-engineering) (evaluate→analyze→improve, 7-component observability, evolution meta-agent 4 필드).

## 의도

- **산출물**: vibe-flow 내부 감사를 AHE 루프로 정식화하는 3 컴포넌트 —
  1. `core/rules/harness-evolution.md` — AHE 루프 doctrine (evaluate→analyze→improve / 7-component observability / 4-필드 finding contract / decision-observability)를 vibe-flow 기존 인프라에 매핑.
  2. `/audit` 스킬 (`core/skills/audit/`) — 감사 라운드를 실행: dimension agent 병렬 dispatch → 4-필드 finding 자동 번호 → ledger 기록.
  3. **decision-observability ledger** (`.claude/memory/audit-ledger.jsonl`) — finding별 `predicted_delta` 기록 + 다음 라운드가 `actual_delta` 자동 대조.
- **사용자**: vibe-flow 메인테이너(본인) + cloud auto-build cycle. 감사 라운드 시 ad-hoc 프롬프트 대신 `/audit` 호출. **대체 행동(현재)** = 매 라운드 4개 dimension agent 프롬프트를 손으로 작성.
- **왜 지금**: 방금 R7에서 3 비효율 동시 노출 — (a) finding 번호 충돌(D1·D3 둘 다 `F-G01`), (b) 4 dimension 프롬프트 수작성, (c) R6 fix가 실제로 지표를 움직였는지 자동 확인 부재. R8도 같은 낭비 반복 예약.
- **성공 기준(측정 가능)**: `/audit` 1회 호출로 (1) dimension 병렬 실행, (2) finding 전역 단일 번호(충돌 0), (3) ledger에 `predicted_delta` 기록. 다음 라운드가 직전 finding들의 `actual_delta`를 자동 채움. **검증** = R8을 `/audit`로 완주 + ledger에 R7 fix들의 actual delta가 채워짐 + smoke test 통과.

## 제약

- **기술**: vibe-flow skill/rule 패턴 준수 — SKILL.md frontmatter, `core/ ↔ .claude/` sync(이번 R7 #110 drift 게이트 대상), `validate.sh` rule/skill 등록 루프, events.jsonl 스키마 호환. TDD smoke 필수(tdd.md Iron Law). CI(validation-tests.yml) 통과.
- **코드베이스(도메인 경계 — 과거 F-B 라우팅 교훈)**: `/audit`는 **"harness 자기 진화 루프"** 전담. 기존과 책임 분리 명시 —
  - `telemetry` = 사용량 관찰(AHE evaluate의 데이터 소스) / `retro`·`retrospective` agent = 프로젝트 회고(AHE analyze의 일부) / `learn` = 패턴 메모리 저장. `/audit`는 이들을 **소비**하되 대체하지 않음.
- **비즈니스**: surgical. auto-build 자동 제안 연동(improve 단계 완전 자동화)은 **후속(Phase 2)**, 본 작업은 evaluate+analyze+finding-contract+ledger까지(반자동).

## 대안 비교

| 항목 | 대안 A (규칙+스킬+ledger) | 대안 B (규칙+ledger만) | 대안 Z (do nothing) |
|------|--------------------------|------------------------|---------------------|
| 핵심 | AHE 루프를 **실행 가능**하게 (`/audit`) | doctrine + 포맷만, 실행은 계속 ad-hoc | 현행 ad-hoc 유지 |
| 비용 | 6~10 파일 (skill+rule+ledger+sync+test+mapping) | 2~3 파일 | 0 |
| 위험 | 스킬-도메인 중복(retro/telemetry)로 라우팅 혼란 → 경계 명시로 완화 | "정식화"가 문서에 그침, 다음 라운드도 수작성 | R8도 번호충돌/수작성/델타 미확인 반복 |
| 가역성 | 높음 (스킬/규칙 삭제로 복귀) | 매우 높음 | — |
| 학습 효과 | AHE 루프의 실 dogfooding(감사가 감사 도구를 만듦) | 낮음 | 없음 |

## 추천 + 근거

**추천: 대안 A** (단, 2-phase 분할).

- **선택 근거**: AHE의 가치는 **루프가 runnable**하다는 것(evaluate→analyze→improve). 규칙만(B)으론 "정식화"가 문서에 그쳐 R8도 4 프롬프트를 손으로 쓰게 됨 — `/audit` 스킬이 핵심 산출물. Z의 비용은 이번 세션이 실증(번호충돌 F-G01×2 + 프롬프트 수작성 + R6 델타 미확인).
- **Phase 분할**: **PR-1** = 규칙 + `/audit` 스킬(dimension dispatch + 4-필드 finding 자동번호 + ledger write) + ledger seed(R7 finding backfill) + smoke. **PR-2(후속)** = auto-build 연동(improve 자동 제안) + decision-observability actual_delta 자동 대조 자동화.
- **기각된 대안 B**: 더 가볍지만 실행 불가 → "정식화"의 목적(반복 비효율 제거) 미달. 단, PR-1이 너무 커지면 규칙+ledger(B)를 PR-1, 스킬을 PR-2로 재분할 가능.

## 다음 단계

- 저장됨: `.claude/memory/brainstorms/20260623-ahe-harness-evolution-formalization.md`
- 예상 변경 6~10 파일 (신규 rule + skill 디렉토리 + ledger + sync 미러 + smoke test + dev-workflow/MEMORY 매핑) → **HARD-GATE 간략 등급** → **권장: `/plan`** 으로 단계 분해 후 구현.
- PR-1 우선, auto-build 연동은 PR-2.
