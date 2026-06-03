# Brainstorm: vibe-flow Phase 3.1 — Cloud-native 재설계 (Path A)

작성: 2026-05-23T09:28:12Z (filename에서 추출, retroactive F-A4 fix)

draft_status: 초안 — maker review 필요. plan/구현은 fresh session 권장 (2-3일 scope)

출발점:
- PR #67 (PR-C1, merged) — schedule-register.sh 1차 시도
- R4 dogfooding 발견 (2026-05-23 cycle 8): schedule = Anthropic cloud remote agent, local cron 가정 무효
- memory `project_phase3_1_r4_remote_vs_local` — 4 architectural 제약 명시
- User 결정 (cycle 8): Path A(Cloud-native 재설계) 채택 over Path B(launchd) / C(/loop)

## 의도

**무엇을**: vibe-flow Phase 3.1을 **cloud-native auto-build cycle**로 재설계. 자율 cycle 전체(brainstorm→plan→TDD→verify→commit→PR)가 Anthropic cloud remote agent에서 git checkout 위에 실행. user local session 부재 시에도 진정 자율 동작.

**누가**: maker 본인 — memory `project_auto_build_runtime_limit` 명시 "Phase 3 cron 전까지 session alive 필수" 제약의 진정 해소. memory `feedback_auto_build_anytime` 명시 "anytime 도구" 가치 cloud 확장.

**왜 지금**:
- R4 dogfooding으로 architectural reality 확정 (assumption-vs-reality gap 회수)
- PR-C1 schedule-register.sh의 일부(cron validation)만 재사용 가능 → 일찍 재설계할수록 sunk cost ↓
- alternative paths(B launchd / C /loop)의 trade-off가 명확 — A가 가장 ambitious + 정합

**성공**:
- cron firing (1시간 이상 간격) → remote agent가 git clone + queue 첫 task pop + /auto-build cycle 완주 + 결과 PR open + user 통보
- queue.jsonl이 git-committed (cloud 접근 가능)
- vote/safety hook cloud Claude Code session에서 정상 동작
- firing당 비용 정량 가시성 (events.jsonl + budget skill)
- 5회 연속 cloud abort 시 retrospective 자동 알림 (Phase 2 hook 활용)

## 제약

- **외부 의존 0 원칙 부분 위반**: Anthropic cloud(/schedule remote agent) 의존 신규. brainstorm 상위 명시 외부 의존 0과 충돌하나 R4 reality 수용 (cloud는 Anthropic 자체 인프라이므로 "self-contained" 정의 확장)
- **queue 영속 형식 변경**: gitignored jsonl → git-committed jsonl. branch/PR 충돌 가능성 — append-only 정책 유지
- **vote/safety hook cloud 호환**: PreToolUse hook이 cloud Claude Code session에서 활성되는지 검증 필요 (R8 신규)
- **runtime 비용 폭증 위험**: 1 firing = full cloud Claude session run. session당 tokens 100k~ 가능. cap은 cron freq + budget skill로 강제
- **cycle 중간 실패 진단 어려움**: cloud 환경 디버깅 user local보다 어려움. 풍부한 events.jsonl 로깅 + dashboard view 필수
- **multi-machine 사용자 부재 단일 vibe-flow repo 가정** (현 dogfooding 환경 유지)

## 대안 비교

### A1. Queue 영속 형식

| 옵션 | 형식 | git-committed | cloud 접근 |
|------|------|--------------|-----------|
| **A1.1 jsonl git-committed** | append-only line | ✓ | clone으로 자동 |
| A1.2 GitHub Issues + labels | issue 1개 = task | ✓ | gh api |
| A1.3 별 서버 (Supabase 등) | DB | △ (외부) | API |

**추천 A1.1** — vibe-flow 기존 패턴 일관. PR-A/B queue.sh 80% 재사용. git diff로 큐 변경 추적 가능.

### A2. Cloud 실행 단위

| 옵션 | 단위 |
|------|------|
| **A2.1 1 firing = 1 task cycle 완주 (orchestrator P0~P5)** | full /auto-build cycle |
| A2.2 1 firing = queue.sh next + 다른 firing이 처리 | 분산 |
| A2.3 1 firing = 다중 task 연쇄 (PR-B의 MAX_CYCLES 패턴) | batch |

**추천 A2.1** — 1 task = 1 cycle = 1 PR 일관. cloud 비용 정량성. PR-B의 batch는 local 한정으로 유지.

### A3. Vote/Safety hook cloud 활성화

| 옵션 | 메커니즘 |
|------|---------|
| **A3.1 cloud Claude Code session에 hook 자동 inherit (검증 필요)** | 기본 |
| A3.2 cloud agent 전용 simplified hook set | 분기 |
| A3.3 hook off — cloud는 보수 모드만 (vote confidence 1.0 강제) | 회피 |

**추천 A3.1, fallback A3.3** — R8 dogfooding으로 A3.1 가능 여부 검증. 실패 시 A3.3(보수 모드)로 graceful degradation.

### A4. firings cap 강제 위치

| 옵션 | 위치 |
|------|------|
| **A4.1 schedule cron freq 자체로 강제** | API level (e.g., 1일 2 firing = `0 0,12 * * *`) |
| A4.2 firings.jsonl git-committed + cap 체크 | runtime + git |
| A4.3 budget skill로 token level cap | external |

**추천 A4.1 + A4.3 병행** — A4.1로 firing 수 hard cap, A4.3로 token 비용 가시성. A4.2의 firings.jsonl은 PR-C1 잔재로 무효화 (gitignore 유지 → local manual 한정).

### A5. 결과 통보 (사용자 부재 시)

| 옵션 | 채널 |
|------|------|
| **A5.1 GitHub PR 자동 open + user notification (gh / email)** | PR-driven |
| A5.2 Discord/Slack webhook | chat |
| A5.3 dashboard view (Phase 3.1 별 cycle PR-D) | UI |

**추천 A5.1 + A5.3 분리** — A5.1은 본 Phase 진입점, A5.3은 dashboard cycle.

## 추천 + 근거

**추천: A1.1 + A2.1 + A3.1(fallback A3.3) + A4.1+A4.3 + A5.1 통합**

### 핵심 설계

1. **queue.jsonl git-committed** — gitignore 해제 + repo에 적재 (append-only 유지)
2. **cron firing → remote agent prompt 표준 템플릿**:
   ```
   /auto-build run-cloud
   ```
   `/auto-build run-cloud`는 신규 슬래시 명령 — orchestrator P0~P5을 cloud 환경에서 실행, queue.sh next로 task 선택, PR open, queue status_update
3. **safety hook cloud 검증 (R8)** — A3.1 동작 dogfooding. 실패 시 A3.3 보수 모드
4. **schedule cron 1시간 이상 freq** — 1일 2~4 firing(`0 0,12 * * *` 등) hard cap
5. **firings.jsonl deprecate** — local manual 한정 의미로 축소, gitignore 유지
6. **결과 PR open + 사용자 통보** — gh CLI 또는 Discord/Slack webhook (선택)

### 근거

- **R4 reality 수용**: cloud 환경 본질 인정. PR-C1.1 단순 wrapper 재설계로는 부족
- **PR-A/B 80% 재사용**: queue.sh CRUD/next/status-update 그대로. git-committed로 운영 모델만 전환
- **safety 보수**: vote confidence 0.7 → 1.0 강제(A3.3 fallback) 시 cloud는 high-confidence 결정만 진행
- **비용 가시성**: events.jsonl + budget skill로 firing당 cost 추적 → cap 조정 근거
- **scope 점진 분할**: 3-4 PR로 분할 가능 (PR-C1.1 schedule-register 재설계 / PR-C2 run-cloud 명령 / PR-C3 safety A3.1 검증 / PR-C4 결과 통보)

### 기각 alternative

- **A1.2 (Issues)**: queue format 통째 변경 → PR-A/B 재사용률 ↓
- **A1.3 (Supabase)**: 외부 의존 신규 — 원칙 위반 깊음
- **A2.2 (분산)**: 1 firing 비용 부담 줄이지만 task latency 증가
- **A2.3 (batch)**: local PR-B와 의미 중복
- **A3.2 (분기 hook set)**: 코드 분기 복잡도 증가
- **A4.2 (firings.jsonl git)**: append-only conflict 위험 + cap 의미 cron freq와 중복

## 다음 단계

**hard_gate: full grade** — 영향 추정 25+ 파일 (Phase 3.1 전체 재설계). Planner 에이전트 필수.

### PR 시퀀스 권장 (4 PR 분할, 각 brief grade)

1. **PR-C1.1**: schedule-register.sh 재설계 → RemoteTrigger 호출 wrapper (cron 1h min validation + run_once_at 모드 + prompt 템플릿 생성). PR-C1 일부 retain
2. **PR-C2-cloud**: `/auto-build run-cloud` 슬래시 명령 신규 — orchestrator P0~P5 cloud 분기. queue.sh next 호출 + git clone 가정 명시 + PR open + status_update
3. **PR-C3-safety**: vote/safety hook cloud 동작 dogfooding + R8 결과 반영 (A3.1 또는 A3.3 fallback). queue.jsonl gitignore 해제 + git-committed schema 확정
4. **PR-C4-notify**: 결과 통보 — PR open만으로 충분 vs Discord/Slack webhook 옵션

### 검증 (Phase 3.1 완료 기준)

- `bash core/skills/auto-build/scripts/schedule-register.sh "0 */6 * * *"` → RemoteTrigger create 호출 + routine ID stdout
- 6시간 후 cron firing → cloud remote agent가 `/auto-build run-cloud` 실행 → queue 첫 task /auto-build cycle 완주 → PR open
- user local session inactive 상태에서 검증 (진정 session-less)
- vote/safety hook cloud 활성 확인 (R8 dogfooding)
- firings cost events.jsonl 기록 → budget skill로 가시화

## 리스크 (R1~R5 기존 + R6~R9 신규)

- **R4 (resolved by Path A)**: cloud reality 수용으로 해소
- **R6 (cron 부재 abort)**: Phase 2 retrospective hook 활용 (변경 X)
- **R7 (depends_on PR-merged polling)**: cloud agent가 gh api polling 가능. rate limit는 cap으로 회피 (PR-C3 또는 PR-C5 별 cycle)
- **R8 (vote/safety hook cloud 미동작)**: A3.1 dogfooding 결과로 A3.3 fallback 결정. PR-C3 scope
- **R9 (queue.jsonl git conflict)**: append-only이나 동시 cycle 2개 push 시 conflict 가능. lock 또는 single-writer 정책 (cloud agent 단일 lane 권장)
- **R10 (cloud token cost 폭증)**: budget skill + cron freq cap 이중 방어. 단 1 firing이 50k+ tokens 발생 시 알림 필요

## 결정 점 (maker review — fresh session 진입 시)

- [x] **Path A 채택** (cycle 8 R4 dogfooding 결과 본 brainstorm 추천)
- [ ] 4 PR 분할 vs 통합 1 PR (Planner 분석 필요)
- [ ] A3.1 dogfooding 시점 — PR-C3 진입 전 single firing 격리 검증 vs PR-C3 자체 dogfooding
- [ ] queue.jsonl gitignore 해제 시점 — PR-C3 함께 vs 별 PR
- [ ] cloud cron freq 기본 — `0 */6 * * *`(4 firing/day) vs `0 0,12 * * *`(2 firing/day)
- [ ] R10 cost 알림 threshold — firing당 50k tokens(예) 초과 시 사용자 webhook

## 다음 세션 진입점 (인계)

1. 본 brainstorm spec을 `/plan from-brainstorm` 입력으로 사용
2. Planner 에이전트로 4 PR 분할 plan 분석 (HARD-GATE full grade)
3. PR-C1.1부터 진입 (RemoteTrigger 호출 wrapper). PR-C1의 schedule-register.sh `1시간 이상 cron validation` 부분만 재사용
4. memory `project_phase3_1_r4_remote_vs_local` 검토 — 4 architectural 제약 fresh-context로 재확인
