# Phase 1 — vibe-flow 리브랜드 + 경량화 설계

**날짜**: 2026-04-30
**상태**: 합의 완료, 구현 대기
**작성자**: brainstorming 세션 결과
**스코프**: Sub-projects S1 (리브랜딩) + S2 (경량화)

---

## 1. 요약

`claude-builds` 빌드를 `vibe-flow`로 리브랜드하면서 23 스킬 / 12 에이전트 / 22 훅 / 6 규칙을 **Core(기본 설치) + Extensions(opt-in)** 두 단계로 재구성한다. 동일 repo 내 `core/` + `extensions/<name>/` 디렉토리 분할 방식. 단일 PR로 rename + restructure + migrate 모두 처리.

## 2. 목표 + 성공 기준

### 2.1 북극성 (D 방향)

> "vibe coder 초보부터 상급자까지 편하게 사용할 수 있도록"

- **초보** (vibe coder 첫날): Core 14 스킬만 보임 → 30분 학습 → 코드 한 사이클 완주
- **중급** (1주차): Core 풀 사용 + 익숙해지면 첫 extension 활성화
- **상급** (1개월차): Extensions 전체 활성, self-improving 루프 풀 가동

### 2.2 정량 성공 기준

| 지표 | Before (claude-builds) | After (vibe-flow) | 목표 |
|------|----------------------|-------------------|------|
| Core 스킬 수 | 23 | **14** | 첫날 학습 부담 ↓ |
| Total 스킬 수 (extensions 포함) | 23 | **23** | 기능 손실 없음 |
| README 길이 | 686 줄 | **~180 줄** | 74% 축소 |
| 학습 곡선 (첫 사이클) | "23개 중 뭐부터?" | "Core 14 + 단계별 확장" | 명확한 단계 |
| 마이그레이션 다운타임 | N/A | **5분 이내** | 메이커 본인 + 1 사용자 |

### 2.3 정성 성공 기준

- ✓ 새 사용자가 `bash setup.sh` 한 번으로 즉시 작업 시작 가능
- ✓ 기존 사용자가 `bash setup.sh` 한 번으로 자동 마이그레이션 (수동 작업 0)
- ✓ 글로벌 심볼릭이 Core만 가리켜 vibe coder 기본 환경 = Core
- ✓ 모든 스킬 이름 동일 (`/commit`, `/verify`, ...) — 근육 기억 손실 0
- ✓ self-improving 루프 (events.jsonl + retrospective + evolve) 그대로 작동

## 3. Non-goals (의도적 제외)

- ❌ 스킬 자체 기능 변경 — 이번엔 분류만, 동작 손대지 않음
- ❌ 명령어 prefix 도입 (`/vibe:commit` 같은 namespace) — vibe coder 친화 위배
- ❌ Plugin 마켓플레이스 배포 — 22 hooks + scripts/ 무거운 인프라 plugin 포맷 부적합
- ❌ UI 레이어 (dashboard/TUI) — Phase 3로 분리
- ❌ Core 자체 축소 (스킬 통합/제거) — 14 스킬 모두 의미 있게 사용 중
- ❌ 새 repo 생성 — rename으로 history 보존이 더 안전
- ❌ 단계 분할 PR — 1 PR로 rename+restructure 묶음 (1 사용자 환경)

## 4. 아키텍처

### 4.1 명명

**`vibe-flow`** — vibe + flow

- **vibe** = vibe coder 정조준 (사용자가 명시 강조)
- **flow** = (a) flow state 몰입 (b) 작업/데이터의 흐름 가시화
- → UI 가시성 비전과 self-improving 루프의 **연속된 흐름** 정체성을 동시에 담음

### 4.2 두 단계 디렉토리 구조

```
vibe-flow/
├─ core/                    ← 기본 설치 (필수)
│  ├─ skills/   (14)
│  ├─ agents/   (10)
│  ├─ hooks/    (22)        ← 모든 hook은 core
│  ├─ rules/    (6)
│  └─ agents.json
├─ extensions/              ← opt-in (5 카테고리)
│  ├─ meta-quality/         (skills 2, agents 2)
│  ├─ design-system/        (skills 2)
│  ├─ deep-collaboration/   (skills 2)
│  ├─ learning-loop/        (skills 2)
│  └─ code-feedback/        (skills 1)
├─ scripts/                 ← 공유 인프라 (SQLite, observability)
├─ orchestrators/
├─ templates/
├─ docs/                    ← 새 분리: REFERENCE, ARCHITECTURE, MIGRATION, ONBOARDING
├─ settings/
├─ setup.sh
├─ validate.sh
├─ sync-memory.sh
├─ README.md / ROADMAP.md / CHANGELOG.md / .gitignore
```

**의존 방향**: extensions → core 단방향. extensions 간 의존 금지.

### 4.3 Core 14 스킬 (정확)

| 카테고리 | 스킬 |
|---------|------|
| 사이클 | `brainstorm`, `plan`, `finish`, `release` |
| 작업 | `scaffold`, `test`, `worktree` |
| 검증 | `verify`, `security` |
| Git | `commit`, `review-pr`, `receive-review` |
| 메타 | `status`, `learn` |

### 4.4 Extensions 9 스킬 분포

| Extension | 스킬 | 에이전트 | 의존성 |
|-----------|------|---------|--------|
| `meta-quality` | `eval-skill`, `evolve` | `skill-reviewer`, `grader` | core (events.jsonl) |
| `design-system` | `design-sync`, `design-audit` | (designer는 core) | playwright, sharp, pixelmatch |
| `deep-collaboration` | `pair`, `discuss` | (모두 core 호출) | core (message-bus) |
| `learning-loop` | `metrics`, `retrospective` | (retrospective는 core) | core (events.jsonl, store.db) |
| `code-feedback` | `feedback` | (feedback agent는 core) | git |

### 4.5 State 파일

**위치**: `.claude/.vibe-flow.json`

**Schema**:
```json
{
  "vibe_flow_version": "1.0.0",
  "installed_at": "ISO 8601",
  "last_updated_at": "ISO 8601",
  "core_files": ["..."],
  "extensions": {
    "<extension-name>": {
      "version": "1.0.0",
      "installed_at": "ISO 8601",
      "files": [".claude/skills/...", ".claude/agents/..."]
    }
  }
}
```

**용도**:
1. 갱신 시 마지막 설정 replay (사용자 재선택 불필요)
2. 제거 시 정확한 파일 식별
3. 마이그레이션 감지 (없으면 claude-builds → vibe-flow 자동 추론)
4. Validate 시 reconciliation 기준

## 5. 상세 설계

### 5.1 setup.sh CLI

```bash
# 기본
bash setup.sh                                   # Core only
bash setup.sh --all                             # Core + 모든 extensions

# 선택
bash setup.sh --extensions meta-quality
bash setup.sh --extensions meta-quality,design-system

# 발견
bash setup.sh --list-extensions
bash setup.sh --info <extension>

# 제거
bash setup.sh --remove-extension <name>

# 갱신 (재실행, state 기반 replay)
bash setup.sh

# 검증
bash setup.sh --check                           # validate.sh 호출

# 기타
bash setup.sh --with-orchestrators
bash setup.sh --force                           # 백업 없이 덮어쓰기
```

### 5.2 마이그레이션 자동 감지

setup.sh가 다음 조건에서 **claude-builds → vibe-flow 마이그레이션** 수행:

```
.claude/ 존재 + .claude/.vibe-flow.json 없음
```

추론 절차:
1. 각 extension의 시그니처 스킬 디렉토리 존재 여부 확인
   - `eval-skill/` → meta-quality
   - `design-sync/` → design-system
   - `pair/` → deep-collaboration
   - `metrics/` → learning-loop
   - `feedback/` → code-feedback
2. 추론된 extensions로 state 파일 생성
3. Core 갱신 + 추론된 extensions 갱신
4. 사용자에게 추론 결과 보고 (수동 정정 안내)

### 5.3 validate.sh — 10 stages

| # | Stage | 새 검증 |
|---|-------|--------|
| 1 | 디렉토리 구조 | `+.vibe-flow.json` 존재 |
| 2 | 필수 도구 | unchanged |
| 3 | **State file 무결성** | NEW — schema + 파일 존재 |
| 4 | Hooks (22) | unchanged |
| 5 | agents.json + 파일 | extension agents 포함 |
| 6 | Frontmatter | unchanged |
| 7 | Rules | unchanged |
| 8 | Settings | unchanged |
| 9 | **Reconciliation** | NEW — orphan/missing 검출 |
| 10 | design-tokens.ts | unchanged |

`--check` flag를 setup.sh에 추가 → `bash .claude/validate.sh` 단축.

### 5.4 마이그레이션 메커니즘 (4 위치)

| 위치 | 액션 | 자동/수동 |
|------|------|----------|
| GitHub repo | rename UI | 수동 (5초) |
| 로컬 클론 | `mv` + `git remote set-url` | 자동 스크립트 |
| 글로벌 심볼릭 | rm 3 + ln 3 + cp agents.json | 자동 스크립트 |
| 1 사용 프로젝트 | `bash setup.sh` 1회 | 자동 (감지) |

**전체 다운타임 예상**: 5분

### 5.5 문서 재구성

```
README.md (180줄)            ← Quick Start 중심
docs/
├─ REFERENCE.md              ← 전체 명령 레퍼런스 (NEW)
├─ ARCHITECTURE.md           ← self-improving 루프 + 데이터 흐름 (NEW)
├─ MIGRATION.md              ← claude-builds → vibe-flow (NEW)
├─ ONBOARDING.md             ← 단계별 vibe coder 가이드 (NEW)
├─ architecture.png/html     ← 기존
└─ claude-code-spec.md       ← 기존
extensions/<name>/README.md  ← 각 extension 자체 문서 (NEW)
```

ROADMAP.md / CHANGELOG.md / CLAUDE.md.template 갱신은 별도 항목.

### 5.6 Self-reference 갱신 정책

**자동 (sed 일괄)**:
- `setup.sh` echo 메시지
- 모든 `*.sh` hook 메시지 prefix
- `validate.sh` 헤더
- 단순 명사 참조 (`claude-builds` → `vibe-flow`)

**수동 검토 필수**:
- `README.md` (전면 재구성)
- `ROADMAP.md` (Phase 0/1 분리)
- `CHANGELOG.md` (1.0.0 항목 추가, 역사 보존)
- `CLAUDE.md.template`
- 새 docs/* 파일 작성

**의도적 보존** (변경 금지):
- `CHANGELOG.md` 1.0.0 이전 항목 — 역사적 사실
- 출처 링크 — claude-builds 시기에 발생한 사건 정확히 표기

## 6. 마이그레이션 실행 순서

```
[메이커 본인 작업 — 단일 세션]
1. GitHub UI에서 repo rename (claude-builds → vibe-flow)
2. 로컬 디렉토리 mv + git remote set-url
3. 새 구조 commit (이번 spec의 결과물 — 1 PR)
   - core/, extensions/ 디렉토리 분리
   - setup.sh 새 명령 체계
   - validate.sh 10 stages
   - state 파일 로직
   - self-reference 갱신
   - README 재구성 + docs/* 작성
4. 글로벌 심볼릭 rm 3 + ln 3 + cp agents.json
5. 사용 프로젝트에서 bash setup.sh 1회
6. validate.sh로 전체 검증
```

**롤백**: PR revert + GitHub redirect 자동 작동 — 충분한 안전망.

## 7. 위험 + 완화

| 위험 | 가능성 | 영향 | 완화 |
|------|-------|------|------|
| 자동 마이그레이션 추론 오류 | 중 | 중 | 사용자에게 추론 결과 보고 + 수동 정정 가능 |
| 글로벌 심볼릭 dead 중간 상태 | 낮 | 중 | rm + ln 원자적으로 (스크립트로 묶음) |
| safe_copy 충돌 (사용자 수정본) | 낮 | 낮 | `.bak.<ts>` 백업 자동 — 손실 없음 |
| Extension 의존성 미설치 (playwright 등) | 중 | 낮 | validate.sh stage 10에서 warn |
| GitHub redirect 실패 (드뭄) | 매우 낮 | 중 | `git remote set-url`로 명시 갱신 |
| README 재구성 정보 손실 | 낮 | 낮 | 기존 README 내용은 docs/REFERENCE.md로 이동 |

## 8. Future work (이번 phase에서 명시 제외)

다음 Phase에서 다룸:

- **Phase 2 (UX)**:
  - `/onboard` 스킬 (인터랙티브 가이드)
  - `/menu` 스킬 (스킬 발견성)
  - `/inbox` 통합 뷰 (메시지 버스)
  - statusline에 hook live status

- **Phase 3 (UI/Maturity)**:
  - vibe-flow-dashboard (별도 web UI 패키지)
  - 메이커 거버넌스 도구 (telemetry, eval 통합)

- **기존 P2 (이전 ROADMAP에서)**:
  - 토큰/비용 예산 프레임워크

## 9. 참고

이 설계는 다음 합의 사이클을 거침:
- 북극성: **D** (Vibe coder 친화, Core+Extensions)
- Core 경계: **β+** (Balanced + Team default)
- 이름: **`vibe-flow`** (vibe + flow)
- 실행 모드: **A** (Big Bang in single repo, rename)
- 디렉토리 방식: **접근 1** (두 단계 디렉토리 분할)

기각된 대안:
- **이름**: vibe-studio (안전하지만 차별화 부족), vibe-deck (조종실 강조 과함), atelier/loom (vibe coder 정체성 약함)
- **Core 경계**: α 미니멀 (self-improving 핵심 손실), γ 풍부 (압도 위험), 메이커 전용 (의도와 모순)
- **방식**: Frontmatter 태깅 (시각적 발견성 부족), Manifest indirection (메타 부담 큼)
- **모드**: Phased B/C (1 사용자라 과한 신중함), 새 repo D (history 손실)

## 10. 다음 단계

이 spec 사용자 합의 후 → `writing-plans` 스킬로 전환하여 단계별 구현 계획 수립.
