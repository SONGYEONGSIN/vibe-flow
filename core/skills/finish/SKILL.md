---
name: finish
description: 작업 완료 시 머지/PR/cleanup 경로를 자동 판정하고 후속 단계를 안내한다. 테스트/커밋/plan/branch 상태를 종합 점검 후 의사결정 트리로 명확한 다음 행동 제시. 사용법 /finish [--path pr|direct|release|cleanup]
effort: medium
---

작업이 끝났다고 느낄 때 호출하는 **"이제 뭐 하지?"의 명시적 답**. /commit이 단일 커밋이라면, /finish는 작업 묶음 전체의 클로징. PR 만들어 두고 잊어버리거나, branch가 영원히 살아남거나, plan 상태가 in_progress로 영원히 남는 결손을 막는다.

## 사용 시점

- 모든 코드 변경이 끝나고 `/verify`가 통과한 후
- 활성 `/plan`의 모든 단계 완료
- 기능 브랜치 머지 직전
- 큰 작업 끝났는데 다음 단계가 막연할 때

## 호출 형태

```bash
/finish                       # 자동 경로 판정
/finish --path pr             # PR 경로 강제
/finish --path direct         # 직접 push 강제 (HARD-GATE 인라인 한정)
/finish --path release        # /release로 위임
/finish --path cleanup        # 머지된 branch/worktree 정리만
```

## 절차

### 1. 상태 점검 (자동)

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
UNCOMMITTED=$(git status --porcelain | wc -l | tr -d ' ')
AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
BEHIND=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
CHANGED_FILES=$(git diff --name-only "$(git merge-base HEAD origin/main 2>/dev/null || echo HEAD~10)" HEAD 2>/dev/null | wc -l)

# /verify 결과 확인 — 마지막 verify_complete 이벤트의 overall=pass 인지 검증
# events.jsonl이 없거나 verify_complete가 없으면 → /verify 재실행 필요
LAST_VERIFY=$(jq -s 'map(select(.type=="verify_complete")) | last // empty' .claude/events.jsonl 2>/dev/null)
LAST_VERIFY_TS=$(echo "$LAST_VERIFY" | jq -r '.ts // empty' 2>/dev/null)
LAST_VERIFY_RESULT=$(echo "$LAST_VERIFY" | jq -r '.overall // "unknown"' 2>/dev/null)

# verify가 없거나, 실패했거나, 너무 오래된 경우(예: 코드 변경 후) → 재실행 권고
# 24시간 이상 경과한 verify 결과는 stale로 간주

# 활성 plan 체크
ACTIVE_PLANS=$(grep -l "^status: in_progress" .claude/plans/*.md 2>/dev/null)
PENDING_STEPS=$(awk '/^### T[0-9]+:/{step=$0} /^- \*\*상태\*\*: pending|^- \*\*상태\*\*: in_progress/{print step}' .claude/plans/*.md 2>/dev/null | wc -l)
```

### 2. 의사결정 트리

```
시작
 │
 ▼ 미커밋 변경 있는가?
 ├─ Yes → [경로 E: 차단] /commit 먼저
 │
 ▼ /verify 통과했는가? (LAST_VERIFY_RESULT == "pass" + 24h 이내)
 ├─ No / 결과 없음 / stale → [경로 E: 차단] /verify 실행 + 실패 수정
 │
 ▼ 현재 main/master 브랜치인가?
 ├─ Yes → [경로 E: 차단] feat/* 브랜치로 전환 후 재시도
 │
 ▼ 활성 plan에 pending/in_progress 단계 있는가?
 ├─ Yes → [경로 E: 차단] 단계 완료 후 또는 /plan revise로 명시적 정리
 │
 ▼ HARD-GATE 등급 판정 (변경 파일 수)
 ├─ 1~5개 (인라인) → PR 또는 direct push 모두 가능 → 사용자 선택
 ├─ 6~19개 (간략)  → [경로 A: PR] 강제
 └─ 20+개 (전체)   → [경로 A: PR] 강제 + 리뷰어 명시 필요
 │
 ▼ Conventional commit이 release-worthy인가?
 ├─ Yes (feat!/major fix) + 사용자가 release 의도 표명 → [경로 C: Release]
 │
 ▼ 머지된 브랜치/worktree 정리 필요한가?
 └─ Yes → [경로 D: Cleanup]
```

### 3. 경로별 절차

#### 경로 A — PR 생성

```bash
# 1. 마지막 커밋 정리 (squash 후에도 의도 살리려면 rebase -i 권장)
git log --oneline origin/main..HEAD

# 2. push
git push -u origin "$BRANCH"

# 3. PR 생성 — git.md "PR 규칙" 준수
#    - 제목: Conventional Commits 형식 (squash 후 main에 남는 단일 커밋)
#    - 본문: ## Summary + ## Test plan
#    - HARD-GATE 20+ 시 리뷰어 명시
gh pr create --title "<conv-prefix>: <title>" --body "..."

# 4. /review-pr 자체 점검 권장 (PR 만든 직후)
echo "  → /review-pr <N>으로 셀프 리뷰 권장"
```

#### 경로 B — Direct push (HARD-GATE 인라인 한정)

```bash
# 1. 인라인 설계 등급 재확인
[ "$CHANGED_FILES" -le 5 ] || { echo "ERROR: 6+ 파일 변경은 PR 필수"; exit 1; }

# 2. main으로 rebase 후 push
git pull --rebase origin main
git push origin main
```

> **경고**: 이 경로는 1~5 파일 + 일반적으로 단독 작업 환경에서만. 팀 작업이면 항상 PR.

#### 경로 C — Release

```bash
/release           # release 스킬에 위임 (semver 자동 판단 + CHANGELOG + tag)
```

#### 경로 D — Cleanup

```bash
# 머지 완료된 로컬 브랜치 식별
git branch --merged main | grep -v "^\*\|main\|master"

# worktree 정리 (있다면)
git worktree list
git worktree remove ../<obsolete-worktree>

# 로컬 브랜치 삭제 (사용자 확인 후)
git branch -d <merged-branch>
```

#### 경로 E — Block (조건 미충족)

상태 점검에서 막힌 항목을 사용자에게 명시 + 해결 명령 제시:

```
🚫 /finish 차단됨 — 다음을 먼저 처리하세요:

  1. 미커밋 변경 12개 → /commit
  2. /verify 미통과 → /verify 실행 후 실패 수정
  3. 활성 plan 'priority-feature'에 단계 T4 in_progress

해결 후 /finish 재호출하세요.
```

### 4. Plan / Memory 갱신

```bash
# 활성 plan을 completed로 마킹 (해당 plan이 이번 작업과 매칭되면)
# /plan complete <plan_id>:<step_id>를 모든 pending 단계에 호출하거나
# 사용자 합의 후 frontmatter status를 completed로 일괄 업데이트

# events.jsonl 기록
echo "{\"ts\":\"...\",\"type\":\"finish\",\"path\":\"pr|direct|release|cleanup\",\"branch\":\"$BRANCH\",\"changed_files\":$CHANGED_FILES}" >> .claude/events.jsonl
```

### 5. 다음 세션 인계

머지/배포 직후 retrospective 권장 시점인지 판단:

- 큰 작업(20+ 파일) 완료 → `/retrospective` 즉시 권장
- 소규모 + 마지막 retrospective 후 7일 이상 → 다음 세션에 권장
- 정기 회고 일정 직전 → 그때까지 대기

`.claude/memory/improvements.md`에 다음 항목 추가 후보:
- plan과 실제 이탈 (revise 발생 시)
- 새로 발견한 패턴 (`/learn save pattern` 권장)
- 회고 트리거 (다음 retrospective에서 다룰 주제 메모)

## 출력 형식

```markdown
## /finish 분석

### 현재 상태
- 브랜치: feat/priority-feature
- 변경 파일: 14개 (HARD-GATE: 간략)
- 미커밋: 0
- /verify: 통과 (2026-04-25T15:30:00Z)
- 활성 plan: priority-feature (모든 단계 done)

### 추천 경로: A (PR)

근거: HARD-GATE 간략 등급 + 팀 작업 환경

### 다음 명령

\`\`\`bash
git push -u origin feat/priority-feature
gh pr create --title "feat: 우선순위 기능 추가" --body "..."
/review-pr <N>   # 셀프 리뷰
\`\`\`

### Plan/Memory 갱신
- ✓ priority-feature plan을 completed로 마킹
- ✓ events.jsonl에 finish 기록
- 권장: /retrospective (다음 세션, 14일 누적 데이터 임계 도달)
```

## 다른 스킬과의 연계

| 트리거 | 호출 |
|--------|------|
| 미커밋 변경 발견 | `/commit` |
| /verify 미통과 | `/verify` (자동 재실행 또는 사용자에게 안내) |
| PR 생성 후 셀프 리뷰 | `/review-pr <N>` |
| Release 의도 | `/release` |
| 큰 작업 완료 | `/retrospective` (권장) |
| 활성 plan 정리 | `/plan complete` 또는 `/plan revise` |
| worktree 사용 중이었음 | `/worktree remove` |

## 메시지 버스 알림 (선택적)

기본 정책: **알림 안 함** — finish는 사용자 직접 명령 실행에 의존. 다음 케이스에만 발송:

| 조건 | 수신자 | type / priority |
|------|--------|----------------|
| 큰 작업 PR 생성 (HARD-GATE 전체 20+) | `feedback` | request / medium ("셀프 리뷰 권장") |
| 보안 관련 변경 포함 (auth/RLS 파일 수정) | `security` | request / high ("PR 보안 점검 권장") |
| Cleanup 경로 — worktree 정리 시 | `retrospective` | info / low ("작업 묶음 종료") |

```bash
bash .claude/hooks/message-bus.sh send finish <to> request <priority> "..." "..."
```

## 규칙

- 미커밋/미통과 상태에서 finish 강행 금지 — 차단 후 해결 명령 명시
- main/master 직접 finish는 강제 차단 (협업 환경 가정)
- HARD-GATE 등급에 맞지 않는 경로 강제 시도(`--path direct`로 20개 파일) 거부
- 활성 plan을 silent하게 archived 처리하지 않음 — 명시적 사용자 합의
- finish 결과는 항상 events.jsonl에 기록 (retrospective의 "완료율" 분석 입력)
- 작업이 진짜 끝났는지 확신 없으면 /finish 호출하지 말고 추가 작업 진행 — 잘못된 finish 호출이 plan을 망가뜨림
- /finish는 **결정**을 자동화하지만 **실행**은 사용자 명령으로 — push/pr 자동 실행은 안 함 (gh/git 명령은 사용자가 보고 실행)
