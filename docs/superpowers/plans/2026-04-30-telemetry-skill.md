# /telemetry 스킬 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans

**Goal:** Phase 4 첫 항목 — `/telemetry` 스킬 (본인 1 머신 30일 분석).

**Architecture:** SKILL.md + evals.json. jq 1패스 group_by로 27 스킬 카운트. 4 모드.

**Tech Stack:** bash, jq, date

**Spec:** `docs/superpowers/specs/2026-04-30-telemetry-skill-design.md` (commit b948aa2)

---

## Task 1: branch + 디렉토리

- [ ] `git checkout -b feat/telemetry && mkdir -p core/skills/telemetry/evals`

---

## Task 2: SKILL.md

**Files:** `core/skills/telemetry/SKILL.md`

핵심 절차:
1. 모드 파싱 (all | skills | trends | --json)
2. 시그널 수집:
   - DAY_30_AGO + DAY_7_AGO 계산
   - jq 1패스 group_by → COUNTS_30D / COUNTS_7D 캐시
   - last_used per type
   - 일별 totals (sparkline용)
   - extension 활성 (.vibe-flow.json)
3. 분류: Top 5 / Active / Stale / 개선 후보
4. 모드별 출력 함수
5. events.jsonl에 telemetry append

스킬명 alias 매핑 함수 (commit_created → /commit, learn_save → /learn 등).

- [ ] **Step 1: SKILL.md 작성**
- [ ] **Step 2: commit**

```bash
git add core/skills/telemetry/SKILL.md
git commit -m "feat(telemetry): SKILL.md — 30일 분석 + Top 5/Active/Stale/개선 후보"
```

---

## Task 3: evals.json 5 케이스

**Files:** `core/skills/telemetry/evals/evals.json`

5 cases:
1. **빈 events** → 모든 0 / Stale 27 / 개선 후보 27
2. **Top 5 정확** — commit 100, verify 80, brainstorm 50, test 30, menu 20 → 정확 순서
3. **Stale 검출** — security never used → "deprecate 검토"
4. **추세 증가** — 마지막 7일 카운트 > 첫 7일 평균 → "↗ 증가"
5. **--json 모드** — 유효 JSON + 필수 키 (analyzed_events / top_5 / active_7d / stale_30d)

- [ ] **Step 1: 작성 + 검증**

---

## Task 4: setup.sh 자동 인식 검증

- [ ] 임시 setup → skills 19 (Core 18 → 19) + telemetry/SKILL.md 복사

---

## Task 5: docs 갱신

**Files:** README.md, docs/REFERENCE.md, CHANGELOG.md, ROADMAP.md

### README.md
- `Core 18` → `Core 19` (2 곳)
- 메타 행: `... /budget /telemetry`

### docs/REFERENCE.md
- `Skills (27 — Core 18 + Extensions 9)` → `Skills (28 — Core 19 + Extensions 9)`
- `### Core 18` → `### Core 19`
- budget 행 다음:
```markdown
| telemetry | `/telemetry [skills\|trends\|--json]` | 30일 분석 + Top 5/Stale/개선 후보 |
```

### CHANGELOG.md [Unreleased]
```markdown
- **`/telemetry` 스킬 (Phase 4 1번째)** — 본인 1 머신 30일 events.jsonl 분석. Top 5 + Active + Stale + 개선 후보 + 추세 (sparkline). 메이커 빌드 개선 결정 + 사용자 자가 진단. 4 모드: all/skills/trends/--json.
```

### ROADMAP.md
- P5 [✅ 완료] 마킹 (이전 PR에서 빠진 부분)
- Phase 4 telemetry [x]:
```markdown
#### 메이커 도구화
- [x] telemetry 통합 (스킬별 사용 빈도 → 경량화 결정 데이터)
- [ ] eval 자동 회귀 알림 (CI 통합)
- [ ] 빌드 자체 메트릭 dashboard
```

- [ ] **Step 1: 4 파일 갱신 + commit**

---

## Task 6: PR + 머지

```bash
git push -u origin feat/telemetry
gh pr create --title "feat(telemetry): /telemetry — 본인 1 머신 30일 분석 (Phase 4)" --body "..."
PR_NUM=$(gh pr view --json number --jq '.number')
gh pr merge $PR_NUM --squash --delete-branch
git checkout main && git fetch origin && git reset --hard origin/main
git branch -D feat/telemetry 2>/dev/null
git fetch --prune
```

---

## Self-Review

- [ ] Spec coverage: 4 모드 / Top 5 / Active / Stale / 개선 후보 / 추세 / extension 식별 모두 매핑 ✓
- [ ] Path consistency: `core/skills/telemetry/` 일관
