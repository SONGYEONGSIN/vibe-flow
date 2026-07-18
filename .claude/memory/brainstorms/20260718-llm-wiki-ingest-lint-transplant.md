# Brainstorm: Karpathy LLM wiki ingest/lint 를 vibe-flow 메모리에 이식

> 출처 개념: [karpathy llm-wiki gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) — 3계층(sources/wiki/schema) + 3작업(Ingest/Query/Lint). vibe-flow 는 wiki(.claude/memory/ + MEMORY.md 인덱스)와 schema(memory 규칙)는 이미 보유, **Ingest 와 Lint 가 명시적 작업으로 부재**.

## 의도

- **산출물**: ① `/learn ingest <source>` — 외부 소스(아티클/gist/문서)를 읽어 **기존 메모리 파일을 갱신**(신규 생성보다 우선)하고 기존 주장과 모순 시 양쪽 병기+표시하는 절차 ② `memory-lint.sh` — 기계 검사 가능한 위생 축(dead 링크/고아 leaf/200줄 cap/hook 규칙 형식)을 fixture 기반으로 검증하는 스크립트 + 스모크
- **사용자**: 메이커 본인(소스를 읽고 "메모리에 정리해줘" 시점) + 자율 세션(audit D1 evaluate, retrospective). 대체 행동: 지금은 ad-hoc 편집 → desync 재발 (R12→R13 에서 F-M01 하루 만에 재발 실증)
- **트리거(왜 지금)**: R13 F-M01/F-M02 가 정확히 "lint 부재" 증상 — M02 로 첫 lint 축(ledger 양끝 ID)을 넣었고, 이를 일반화할 시점. LLM wiki 패턴 학습 직후라 컨텍스트 최신
- **성공 기준**: ① memory-lint 가 dead 링크·고아 leaf·cap 초과를 fixture RED 로 검출(exit 1) ② /learn ingest 절차에 "갱신 우선 + 모순 병기" 규칙 명문화 ③ audit Phase 1 evaluate 소스에 lint 등재 ④ 스킬 카운트 불변(45 유지)

## 제약

- **기술**: 2계층 메모리 — project(.claude/memory, git-tracked, CI 게이트 가능) / user-level(untracked, `[[name]]` 링크 관습). CI 는 project 만 게이트. lint 는 디렉토리 인자로 양쪽 실행 가능하게. `[[name]]` 미해결은 설계상 허용("나중에 쓸 것 표시")이므로 **WARN**, markdown 링크 dead 는 **FAIL**
- **코드베이스**: patterns.md 는 3 호출자 혼합 포맷(사람 + smart-guard + pattern-check) — lint 가 이 포맷을 강제하되 깨지 않아야 함. check-doc-counts 의 M02 축(ledger↔MEMORY)과 중복 금지. F-J01 교훈: 스크립트 경로는 SCRIPT_DIR 해석. 신규 스모크 추가 시 EXPECTED_SMOKE 27→28 갱신 필수(M09 등가 게이트)
- **비즈니스**: 모순 감지는 기계화 불가 — LLM 판단 축(ingest 절차 + audit D1)과 기계 축(lint 스크립트)을 명확히 분리, lint 에 LLM 호출 넣지 않음

## 대안 비교

| 항목 | A: /learn 확장 + lint 스크립트 | B: 신규 /wiki 스킬 (full 3-layer) | Z: do nothing |
|------|------|------|------|
| 비용 | ~5 파일, 인라인 HARD-GATE 상한 | 스킬 신설 + sources/ 디렉토리 정책 + 카운트 게이트 연쇄(45→46) | 0 |
| 위험 | ingest 가 learn 의 기존 save 경로와 혼동될 수 있음 (사용법 절에서 경계 명시로 완화) | 기존 메모리와 이중 지식 저장소 — Karpathy 형식을 위해 실 사용 구조를 복제 (Simplicity First 위반) | desync 재발 — R12→R13 하루 만에 F-M01 재발 실증. audit 라운드 사이 무방비 |
| 가역성 | 높음 — 서브커맨드 제거로 원복 | 낮음 — 디렉토리 구조·카운트·문서 연쇄 | — |
| 학습 효과 | ingest/lint 개념이 실 사용 표면(learn/audit)에 붙어 dogfooding 즉시 가능 | Karpathy 원형 충실 재현 학습 | 없음 |

## 추천 + 근거

**추천: 대안 A**

1. **기존 자산 재사용** — learn(쓰기 진입점), audit D1(의미적 lint 는 이미 라운드마다 수행), F-M02(게이트 선례)가 있어 Karpathy 의 본질(ingest/lint 작업)만 이식하고 형식(3-layer 디렉토리)은 도입하지 않는다. Simplicity First.
2. **스킬 카운트 불변** — 45 유지, doc-counts/manifest 연쇄 없음.
3. **AHE 정합** — lint 스크립트는 fixture 스모크로 게이트 가능(D4 자산화), 모순 감지는 audit D1 의 기존 책임으로 명시 분리.

**기각 B**: 외부 소스 원본 아카이브(sources/)가 실제로 쌓여 보존 필요성이 생기면 그때 전환 가치 있음 — 현재는 소스가 URL/일회성이라 원본 계층이 speculative.
**기각 Z**: 재발 실증(F-M01)이 이미 있어 방치 비용이 명확.

**스코프 결정**: lint 는 `memory-lint.sh [MEMORY_DIR]` 로 project(.claude/memory, 기본값)와 user-level 양쪽 실행 가능. CI 게이트는 project 만. FAIL 축 = dead markdown 링크 / 200줄 cap / hook 규칙 형식 위반. WARN 축 = `[[name]]` 미해결 / 고아 leaf(브레인스톰·데이터 파일 제외).

## 다음 단계

- 저장됨: `.claude/memory/brainstorms/20260718-llm-wiki-ingest-lint-transplant.md`
- 권장: **직접 구현** (5 파일 — 인라인 HARD-GATE 상한, TDD: memory-lint-smoke RED→GREEN)
  1. `core/skills/learn/scripts/memory-lint.sh` 신설
  2. `scripts/tests/memory-lint-smoke.sh` 신설 (+ validation-tests.yml EXPECTED_SMOKE 27→28)
  3. `core/skills/learn/SKILL.md` — ingest 절차 + lint 사용법 + description trigger 갱신
  4. `core/skills/audit/SKILL.md` — Phase 1 evaluate 에 memory-lint 1줄
