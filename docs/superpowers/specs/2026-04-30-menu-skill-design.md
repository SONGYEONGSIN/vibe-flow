# /menu 스킬 설계

24 스킬 카테고리별 발견성 + 사용 분포 + Stage별 추천 강조 인터랙티브 스킬.

## 의도

**문제**: vibe-flow 24 스킬(Core 15 + Extensions 9)은 `docs/REFERENCE.md`에 표로 나열되지만, 사용자가 자주 보는 위치가 아니다. 어떤 스킬을 한 번도 안 써봤는지, 지금 단계에서 어떤 게 추천되는지 한눈에 보기 어렵다. `/onboard`는 다음 1-2 행동만 좁게 추천하므로 전체 카탈로그 조망에는 부족.

**해결**: `/menu` 스킬 — 카테고리별 분류 + 사용 분포(events.jsonl 기반) + Stage별 추천 표시 + extension 활성 상태를 한 화면에 출력.

**대상**:
1. 신규 사용자 — "vibe-flow에 뭐가 있는지" 발견
2. 중급 사용자 — "내가 안 써본 스킬" 식별
3. 모든 사용자 — `/help` 대체용 빠른 reference

## 제약

- **/onboard와 코드 중복 회피**: `.claude/memory/onboard-state.json`을 그대로 활용 (stage 정보 재사용).
- **폴백 가능**: onboard 안 돌렸어도 단순 카탈로그로 동작.
- **사용 분포 시그널**: `events.jsonl`만 사용. store.db 가용 시도 옵션이지만 jq one-liner 우선.
- **명령 표면**: 단일 명령 `/menu` + 1개 인자(카테고리/`core`/`extensions`).
- **Cache 없음**: 매번 빠르게 출력 (jq 1패스 + 단순 lookup).

## 설계

### 입력

```bash
/menu                      # 전체 24 스킬 카테고리별
/menu core                 # Core 15만
/menu extensions           # Extensions 9만
/menu <category>           # 사이클 / 작업 / 검증 / git / 메타 / meta-quality / design-system / deep-collaboration / learning-loop / code-feedback
```

### 카테고리 정의

**Core 5 카테고리** (README.md의 카테고리 분류 그대로):

| 카테고리 | 스킬 |
|---------|------|
| 사이클 (4) | brainstorm, plan, finish, release |
| 작업 (3) | scaffold, test, worktree |
| 검증 (2) | verify, security |
| git (3) | commit, review-pr, receive-review |
| 메타 (3) | status, learn, onboard |

**Extension 5 카테고리** (extensions/ 디렉토리 그대로):

| 카테고리 | 스킬 |
|---------|------|
| meta-quality (2) | eval, evolve |
| design-system (2) | design-sync, design-audit |
| deep-collaboration (2) | pair, discuss |
| learning-loop (2) | metrics, retrospective |
| code-feedback (1) | feedback |

### 시그널

1. **`.claude/.vibe-flow.json`** — 활성 extensions 목록
2. **`.claude/memory/onboard-state.json`** (선택) — 현재 stage. 없으면 stage 표시 안 함.
3. **`.claude/events.jsonl`** (선택) — 스킬별 사용 횟수.
   - 카운트 기준: events.jsonl의 `type` 필드. type 매핑은 onboard와 동일 (commit, verify, brainstorm 등).
   - 미사용 분류:
     - 0회 → `·` (미사용)
     - 1~5회 → `·` (가끔)
     - 6+회 → `✓` (자주)

### Stage별 추천 매핑 (onboard와 일치)

| Stage | ⚡ 추천 표시 대상 |
|-------|---------------------|
| 0 | /brainstorm |
| 1 | /commit, /verify |
| 2 | /test, /security, /scaffold |
| 3 | /retrospective, learning-loop 활성화 |
| 4 | /eval, /evolve |

### 출력 포맷

**전체 (`/menu`)**:

```
📚 vibe-flow 24 스킬 (Core 15 + Extensions 9)
   현재 Stage: 2 — 핵심 익숙

━━━ Core ━━━

🔄 사이클 (4)
  /brainstorm "<주제>"       의도/제약/대안 탐색         ✓ 자주 사용
  /plan                       멀티스텝 계획 추적          ✓ 사용 중
  /finish                     머지/PR/cleanup 결정        · 가끔
  /release [version]          semver + CHANGELOG          · 미사용

🛠 작업 (3)
  /scaffold [domain]          보일러플레이트 생성         · 미사용 ⚡추천
  /test [file]                Vitest 테스트 자동 생성     · 미사용 ⚡추천
  /worktree [...]             git worktree 격리           · 미사용

✅ 검증 (2)
  /verify                     lint+tsc+test+e2e           ✓ 자주 사용
  /security                   OWASP Top 10                · 미사용 ⚡추천

🔀 Git (3)
  /commit                     Conventional commit         ✓ 자주 사용
  /review-pr [N]              GitHub PR 리뷰              · 가끔
  /receive-review             리뷰 비판적 수용            · 미사용

🎯 메타 (3)
  /status                     프로젝트 상태               ✓ 사용 중
  /learn [save|show]          메모리 관리                 · 가끔
  /onboard [--refresh]        단계 진단 + 추천            ✓ (방금 사용)

━━━ Extensions (활성: 0) ━━━

💎 meta-quality (미설치)        bash setup.sh --extensions meta-quality
   /eval, /evolve              스킬 자체 진화

🎨 design-system (미설치)
   /design-sync, /design-audit  참고 디자인 → 코드 매칭

🤝 deep-collaboration (미설치)
   /pair, /discuss             Builder/Validator + 토론

📈 learning-loop (미설치)
   /metrics, /retrospective    장기 메트릭 + 회고

📝 code-feedback (미설치)
   /feedback                   git diff 품질 분석

(레전드: ✓ 자주 (6+회) / · 가끔(1-5회)/미사용(0회) / ⚡ Stage 2 추천)
```

**Stage 표시 폴백** (onboard-state.json 없음):

```
📚 vibe-flow 24 스킬 (Core 15 + Extensions 9)

(stage 정보 없음 — /onboard로 진단 가능)

━━━ Core ━━━
[stage 추천 ⚡ 없이 카탈로그 출력]
```

**카테고리 필터** (`/menu 사이클`):

```
📚 사이클 카테고리 (4 스킬)

  /brainstorm "<주제>"       의도/제약/대안 탐색
  /plan                       멀티스텝 계획 추적
  /finish                     머지/PR/cleanup 결정
  /release [version]          semver + CHANGELOG
```

stage / 사용 분포 표시는 동일 규칙 적용.

**Extensions 필터** (`/menu extensions`):

```
📚 Extensions 9 스킬 (5 카테고리)

[Core 부분 생략, Extensions 섹션만 출력]
```

### Events 발생

`/menu` 실행 시 `events.jsonl`에 1줄 append:
```json
{"type":"menu","ts":"...","filter":"core|extensions|<category>|all"}
```

retrospective가 "menu 자주 호출 = 발견성 부족 시그널" 분석에 활용 가능.

## 데이터 흐름

```
사용자: /menu [filter]
   │
   ▼
1. 활성 extensions 조회 (.claude/.vibe-flow.json)
2. 현재 stage 조회 (.claude/memory/onboard-state.json — 없으면 null)
3. events.jsonl 스킬 사용 분포 (jq aggregation, 1패스)
4. 카테고리별 + 필터별 출력 합성
5. events.jsonl에 menu 이벤트 append
```

## 구성 요소

### SKILL.md 구조

```
---
name: menu
description: 24 스킬 카테고리별 발견성 + 사용 분포 + Stage별 추천 강조. /menu, /menu core, /menu extensions, /menu <category>.
model: claude-sonnet-4-6
---

# /menu

## 트리거
- /menu, /menu <filter>

## 절차
1. 시그널 수집 (state, onboard-state, events 분포)
2. 카테고리 매핑 + Stage 추천 적용
3. 필터 적용 → 출력
4. events.jsonl에 menu append
```

### 스킬 메타데이터 단일 소스

스킬 명단/설명/카테고리는 SKILL.md 내부 case 또는 (선택) 별도 JSON. 단순화 위해 SKILL.md 안의 bash case 또는 heredoc.

### Evals (`evals/evals.json`)

5 evaluation cases:
1. `/menu` 전체 출력 — 24 스킬 모두 포함
2. `/menu core` — Core 15만, Extensions 섹션 없음
3. `/menu extensions` — Extensions 9만
4. `/menu 사이클` — 사이클 4 스킬만
5. `/menu` (stage 정보 없음) — 폴백 — stage 라벨 없이 출력

## 의존

- **Core**: events.jsonl, .vibe-flow.json (선택), memory/onboard-state.json (선택)
- **외부**: jq (필수). 다른 의존 없음.
- **Hook 불필요**: SKILL.md 안에서 모든 처리.

## /onboard와의 비교

| 항목 | /onboard | /menu |
|------|----------|-------|
| 출력 폭 | 좁음 (다음 1-2 행동) | 넓음 (전체 카탈로그) |
| 단계 활용 | 단계 결정이 본질 | 단계로 강조만 |
| 카테고리 | 단계만 | 5+5 카테고리 분류 |
| Cache | 24h | 없음 (매번 빠름) |
| 자가보고 | 데이터 부족 시 폴백 | 폴백 없음 (단순 카탈로그) |
| 사용 빈도 | 주 1회 정도 | 자주 (참고용) |

`/onboard`는 학습 경로 안내. `/menu`는 도구 카탈로그.

## YAGNI

명시적 제외:
- **검색** (`/menu --search verify`) — `grep -r "verify" docs/REFERENCE.md`로 충분
- **정렬 옵션** — 카테고리 순서가 자연스러움
- **JSON 출력** — 사람이 읽는 도구
- **Cache** — 매번 빠름 (24 스킬 lookup + jq 1패스)
- **알림 통합** — 다른 스킬 영역
- **다국어** — 한국어만 (vibe-flow 정책)
