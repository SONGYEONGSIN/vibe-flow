---
name: receive-review
description: 코드 리뷰 피드백을 항목별로 검증·분류·의사결정한다. performative agreement도 blind rejection도 금지 — 각 피드백을 카테고리(bug/security/performance/architecture/style/preference)로 분류 후 증거 기반으로 accept/reject/clarify 판정. 사용법 /receive-review [<source>]
effort: high
---

리뷰 피드백을 받았을 때 "네 맞습니다" 식의 performative agreement도, "그건 그냥 취향이죠" 식의 defensive rejection도 막는다. 각 항목을 **증거 기반으로 검증** 후 명시적 의사결정을 내린다. 받는 쪽도 주는 쪽만큼 기술적 엄밀성이 필요하다.

## 사용 시점

- GitHub PR 리뷰 코멘트 받은 직후
- `/feedback`, `/security`, `/design-audit`, `/review-pr` 출력 받은 직후
- 토론 verdict (`.claude/messages/debates/`) 도착 직후
- 동료가 구두/메시지로 피드백 줬을 때 (사용자가 정리해서 입력)

## 호출 형태

```bash
/receive-review                       # 사용자가 피드백 텍스트를 인라인 입력
/receive-review pr <N>                # GitHub PR #N의 리뷰 코멘트 자동 가져오기 (gh CLI)
/receive-review file <path>           # 파일에서 피드백 로드 (예: /feedback 출력)
/receive-review debate <debate-id>    # 토론 verdict 항목별 처리
```

## 절차

### 1. 피드백 수집

```bash
# PR 모드
gh pr view <N> --json reviews,comments --jq '...'

# debate 모드
cat .claude/messages/debates/debate-<id>.json | jq '.action_items'

# file 모드
cat <path>
```

### 2. 항목 분리

리뷰가 한 덩어리로 와도 **개별 의견 단위로 분리**한다. 보통 한 코멘트당 1~3개 항목.

```
원문: "이 함수 너무 길고, error handling도 빠졌어요. 그리고 변수명 `data`는 너무 모호한 것 같습니다."

→ 분리:
  Item 1: 함수 길이 (architecture)
  Item 2: error handling 누락 (bug/correctness)
  Item 3: 변수명 'data' (style/preference)
```

### 3. 카테고리 분류 (6 카테고리)

| 카테고리 | 정의 | 검증 방법 |
|---------|------|----------|
| **Bug/Correctness** | 코드가 틀렸거나 실패할 가능성 | 재현 시도 + 실패 테스트 작성 |
| **Security** | 취약점, 데이터 누출 위험 | `security` 에이전트 또는 OWASP 매핑 |
| **Performance** | 측정 가능한 성능 저하 | 벤치마크 또는 메트릭 |
| **Architecture** | 설계 패턴, 모듈 경계 | `planner`/`feedback` 에이전트 의견 |
| **Style/Convention** | 코드 스타일, 네이밍 | `rules/` 디렉토리 매핑 |
| **Preference** | 리뷰어 취향, 객관 근거 없음 | 검증 불필요 |

### 4. 항목별 검증

| 카테고리 | 검증 단계 |
|---------|----------|
| Bug | 1. 코드 읽기 → 2. 실패 시나리오 시뮬 → 3. 가능하면 실패 테스트 작성 |
| Security | 1. `rules/donts.md` 보안 항목 매핑 → 2. `security` 에이전트 위임 가능 |
| Performance | 1. 영향 범위 추정 → 2. 측정 가능하면 벤치마크 → 3. "측정 안 한 추측"이면 clarify |
| Architecture | 1. `rules/conventions.md` 매핑 → 2. 큰 변경 영향 시 `/discuss` 권장 |
| Style | 1. `rules/conventions.md` / `rules/design.md` 매핑 → 2. 명시 규칙이면 accept, 아니면 preference로 재분류 |
| Preference | 검증 불필요 — 비용/이득 분석만 |

### 5. 의사결정 매트릭스

```
Bug         → 재현됨 → accept (즉시 수정)
            → 재현 안 됨 → clarify (재현 시나리오 요청)

Security    → 위험 확인됨 → accept (즉시 수정 + security 에이전트 검토)
            → 영향 없음 입증 → reject (입증 근거 응답)
            → 모호함 → clarify

Performance → 측정된 영향 → accept
            → 추측 → clarify ("벤치마크가 있나요?")

Architecture → rules/ 명시 위반 → accept
             → 새 패턴 제안 → /discuss 권장 (단독 수용 금지)
             → scope 외 → clarify (이번 PR과 분리)

Style       → rules/ 매핑됨 → accept
            → rules에 없음 → preference로 재분류

Preference  → 비용 ≤ 5분 + 가독성 향상 → accept (low-cost goodwill)
            → 비용 큼 또는 의미 변경 → reject (정중한 근거 응답)
```

### 6. 응답 초안 작성

각 항목에 대해 **명시적 응답**을 만든다. 무응답이나 silent ignore 금지:

```markdown
### Item N: <리뷰어 코멘트 요약>

- **Category**: <카테고리>
- **검증**: <무엇을 했는가 — 코드 읽음 / 테스트 작성 / 에이전트 호출 / rules 매핑>
- **결정**: accept / reject / clarify
- **근거**: <1~2 문장>
- **응답 초안**:
  > <리뷰어에게 보낼 메시지>
```

### 7. 후속 액션 분기

| 결정 | 다음 단계 |
|------|----------|
| accept (small) | 즉시 `/commit` 또는 직접 수정 |
| accept (multi-step) | `/plan revise <id>` 또는 새 `/plan` 생성 |
| reject | 응답 메시지를 PR 코멘트로 게시 (gh pr comment) |
| clarify | 명확화 질문을 PR 코멘트로 게시 |

GitHub PR 응답 자동화 옵션:
```bash
gh pr comment <N> --body "$(cat reply.md)"
```

### 8. 메모리 저장 — 표준 파일 형식

```bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SOURCE_SLUG="<pr-N|debate-id|feedback>"   # 예: pr-42, debate-20260425-100000, feedback
mkdir -p .claude/memory/reviews
REVIEW_FILE=".claude/memory/reviews/${TIMESTAMP}-${SOURCE_SLUG}.md"
```

저장 파일 구조 (frontmatter + 표준 섹션):

```markdown
---
review_id: <YYYYMMDD-HHMMSS>-<source-slug>
source: pr | feedback | security | design-audit | debate
source_ref: <pr-N | debate-id | file-path>
status: pending | responded | partial    # 응답 게시 여부
created: <ISO 8601>
items_total: N
items_accepted: A
items_rejected: R
items_clarify: C
categories: [bug, security, style, ...]
---

# Review 받음: <source>

## 요약
- 항목 수 / 카테고리 분포 / accept-reject-clarify 비율

## 항목별 결정

### Item 1: <리뷰어 코멘트 요약>
- **Category**: <bug|security|performance|architecture|style|preference>
- **검증**: <무엇을 했는가>
- **결정**: ACCEPT | REJECT | CLARIFY
- **근거**: <1~2 문장>
- **응답 초안**:
  > <리뷰어에게 보낼 메시지>
- **후속 액션**: <commit | plan revise | gh pr comment | none>
- **응답 게시 여부**: yes | no | <ts>

### Item 2: ...

## 후속 액션 추적
| 시각 | Item | 액션 | 결과 |
|------|------|------|------|
| 2026-04-25T10:00:00Z | 1 | /commit fix(auth): null 체크 | sha=abc1234 |
| 2026-04-25T10:05:00Z | 3 | gh pr comment 게시 | reply posted |
```

**status 필드 의미**:
- `pending`: 결정만 완료, 응답 미게시
- `responded`: 모든 reject/clarify 항목에 응답 게시 완료
- `partial`: 일부 항목만 게시 (다음 세션 인계 필요)

events.jsonl 기록:
```bash
echo "{\"ts\":\"...\",\"type\":\"review_received\",\"source\":\"$SOURCE\",\"items\":N,\"accepted\":A,\"rejected\":R,\"clarify\":C,\"status\":\"$STATUS\"}" >> .claude/events.jsonl
```

## 출력 형식

```markdown
## Review 받음: <source>

### 요약
- 항목 수: 5
- accept: 3 / reject: 1 / clarify: 1
- 카테고리 분포: bug 1, security 1, style 2, preference 1

### 항목별 결정

#### Item 1: <리뷰어 코멘트>
- Category: bug
- 검증: <code path>:<lines> 읽음 — null 체크 누락 확인. 실패 테스트 작성 가능
- 결정: ACCEPT
- 근거: 재현됨. user.email이 null일 때 throw.
- 다음 단계: /commit fix(auth): null 체크 추가

#### Item 2: <리뷰어 코멘트>
- Category: preference
- 검증: rules/conventions.md에 명시 없음. 변수명 변경 시 8 파일 영향
- 결정: REJECT
- 근거: 비용 > 이득. 'data'가 모호하지만 컨텍스트(query result)에서 명확.
- 응답:
  > 'data'는 query result로 컨텍스트가 명확합니다. 다른 8 파일의 동일 변수도 변경 필요해 비용이 커서 이번엔 reject 합니다. 향후 컨벤션으로 정착되면 일괄 변경 가능합니다.

[...]

### 후속 액션
- ✓ accept 항목 → /commit + /plan revise feat-auth-improvements
- ✓ reject/clarify → gh pr comment <N>로 게시 명령 안내
- ✓ 메모리 저장: .claude/memory/reviews/...
```

## 다른 스킬과의 연계

| 트리거 | 호출 |
|--------|------|
| accept (코드 변경 필요) | `/commit` (단순) 또는 `/plan revise` (멀티스텝) |
| 보안 항목 검증 필요 | `security` 에이전트 |
| 아키텍처 항목 큰 변경 | `/discuss` (planner + feedback + 리뷰어 가상 참여) |
| reject 항목 정당화 강화 | `comparator` (대안 제시한 경우 A/B 비교) |
| 누적 패턴 학습 | `/learn save pattern` (자주 받는 피드백 → 규칙화) |

## 카테고리별 안티패턴 (받는 쪽이 빠지기 쉬운)

| 안티패턴 | 어떻게 보이는가 | 교정 |
|---------|--------------|------|
| Performative agreement | "네 맞습니다" 후 검증 없이 implement | 항상 검증 단계 거치기 |
| Defensive rejection | "그건 그냥 취향이죠" | 카테고리 분류 → preference만 reject 가능 |
| Scope creep agreement | 무관한 제안도 accept | "이번 PR scope 밖" 명시 후 별도 이슈로 |
| Preference vs principle 혼동 | 리뷰어 취향을 rules로 오해 | rules/ 디렉토리 매핑으로 검증 |
| Silent ignore | 답변 없이 다른 항목만 처리 | 모든 항목에 명시 응답 |

## 메시지 버스 알림 (선택적)

기본 정책: **알림 안 함**. 다음 좁은 케이스에만 발송:

| 조건 | 수신자 | type / priority |
|------|--------|----------------|
| Security 카테고리 accept (즉시 수정) | `security` | request / high ("리뷰어가 발견한 보안 이슈 검증") |
| Architecture 카테고리 accept + 큰 변경 | `planner` | request / medium ("리뷰 기반 아키텍처 변경 계획 필요") |
| 동일 패턴 3회+ 반복 감지 | `retrospective` | proposal / medium ("규칙화 권장") |

```bash
bash .claude/hooks/message-bus.sh send receive-review <to> request <priority> "..." "..."
```

## 규칙

- 모든 항목에 명시 응답 — silent ignore 금지
- 검증 단계 없이 accept 하지 않는다 (preference 카테고리 제외)
- reject 시 반드시 정중한 근거 응답 — 무응답 또는 "그건 안 됨"만은 안 됨
- accept 했으면 후속 액션을 즉시 수행 또는 plan에 단계로 추가 (정체 금지)
- preference 카테고리도 비용 ≤ 5분이면 goodwill로 accept 권장
- 동일 패턴의 리뷰가 3회 이상 반복되면 `/learn save pattern`으로 규칙화 후보
- 리뷰어와 의견 충돌이 풀리지 않으면 `/discuss`로 토론 전환 (개인 vs 의견 분리)
- review 응답을 PR에 게시하기 전 한 번 더 톤 점검 — 기술적으로 옳아도 무례하면 협업 망침
