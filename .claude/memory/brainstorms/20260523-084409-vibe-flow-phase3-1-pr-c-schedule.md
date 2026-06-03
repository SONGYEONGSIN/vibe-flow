# Brainstorm: vibe-flow Phase 3.1 PR-C — schedule 통합 + auto-recovery + depends_on

작성: 2026-05-23T08:44:09Z (filename에서 추출, retroactive F-A4 fix)

출발점:
- `.claude/memory/brainstorms/20260512-202958-vibe-flow-phase3-cron-scheduler.md` — Phase 3 상위 brainstorm (4 결정 채택 memory)
- `.claude/memory/brainstorms/20260512-213341-auto-build-run-queue-pr-b.md` — PR-B scope + schema 확정
- PR #61(PR-A queue CRUD) / #62(PR-B run-queue wrapper) merged 상태
- memory `project_auto_build_runtime_limit` — Phase 3 cron 전까지 session alive 필수

## 의도

**무엇을**: Phase 3.0(PR-A/B) 위에 `schedule(cron) 통합층` 추가. 3 sub-feature:
1. Claude Code `schedule` 스킬로 `run-queue.sh` 자동 trigger (cron expression 사용자 직접 설정)
2. `running` 상태 잔존 entry 자동 회수 (SIGKILL/abort 후 stale running 해소 — 현 수동 `queue.sh remove`)
3. `depends_on` 활성 — 후행 entry는 선행 entry의 PR merge 후 진입 (multi-repo 짝 cycle 표현)

**누가**: maker 본인 — session-less 자율 사이클 진정 활성화. memory `project_auto_build_runtime_limit` 명시 "Phase 3 cron 전까지 session alive 필수" 해소.

**왜 지금**: 
- Phase 3.0 PR-A/B 완료 + 짝 cycle 6-7 dogfooding 안정성 입증
- 상위 brainstorm 4 결정 모두 채택(schedule 스킬/N=3 cap/3.0+3.1 분할/dashboard 별 cycle) → 진입 게이트 통과
- R4(schedule 스킬 미지원 시 abort) 사전 검증 미완 → PR-C1 단독 dogfooding으로 회수
- 미루면 anytime 도구(memory `feedback_auto_build_anytime`) 가치 절반(manual 한정)

**성공**:
- (PR-C1) cron expression 등록 → 정해진 시각 trigger → `run-queue.sh` 자동 호출 (사용자 Claude Code 세션 미 alive)
- (PR-C1) 1 firing이 max 3 cycle 처리 (PR-B의 `AUTO_BUILD_QUEUE_MAX_CYCLES` 준수)
- (PR-C2) SIGKILL/abort 후 `running` 잔존 entry는 다음 `run-queue` firing 시 자동 회수 (status_update aborted)
- (PR-C3) `depends_on` 필드 있는 entry는 선행 entry status=done + 해당 PR=merged 검증 후 진입

## 제약

- **외부 의존 0**: Claude Code `schedule` 스킬만 사용 (Anthropic 내장). macOS launchd / GitHub Actions cron 후순위
- **token 비용 폭증 회피**: 일일 firing cap(예: `AUTO_BUILD_QUEUE_MAX_FIRINGS_PER_DAY=2`) 추가
- **destructive op 차단 유지**: Phase 2 `auto-build-safety.sh` cron 환경에서도 활성 (AUTO_BUILD_MODE=1 자동 export)
- **PR-A/B backward compat**: schema 변경 X(`{id, task, created_ts, status, depends_on?}` 그대로). running status enum 추가는 PR-B에서 이미 완료
- **multi-repo PR 머지 검증**: depends_on PR=merged 폴링은 `gh api` 호출 — rate limit 고려, 캐시
- **schedule 스킬 검증 R4**: PR-C1 1st cycle dogfooding 결과로 R4 격리 — schedule 동작 안 하면 PR-C1 abort, C2/C3는 무관 진행

## 대안 비교

### 대안 A — 1 PR 단일 통합 (schedule + auto-recovery + depends_on 한꺼번에)

- 핵심: 1 PR(~10 파일)에 3 sub-feature 통합. Phase 3.1 한 번에 완성.
- 비용: 1 PR, 1 dogfooding cycle (~2시간)
- 위험: schedule 스킬(R4) 미검증 상태에서 통합 시 PR 통째로 abort 위험. auto-recovery/depends_on이 schedule 실패에 휘말림.
- 가역성: 중. 부분 revert 어려움.
- 학습 효과: 한 cycle에 3 finding 회수 가능하나 격리 어려움.

### 대안 B — 3 sub-PR 분할 (PR-C1: schedule, PR-C2: auto-recovery, PR-C3: depends_on)

- 핵심: 각 sub-feature 1 PR씩. Phase 3.0 PR-A/B 분할 패턴과 일관.
- 비용: 3 PR (각 3-5 파일), 3 dogfooding cycle (~2시간 분산)
- 위험: PR-C1 R4 격리 — schedule 미지원 시 C1만 abort, C2/C3 무관 진행. 통합 시점 늘어남.
- 가역성: 높음. 각 PR 독립 rollback.
- 학습 효과: 각 sub-feature별 finding 회수. Phase 3.0 dogfooding 7 cycle calibration 패턴 활용.

### 대안 Z — PR-C 보류 (Phase 3.0 manual run-queue로 만족)

- 핵심: schedule 안정화 더 기다림. memory의 4 결정 채택 무력화.
- 비용: 0
- 위험: 자율 사이클 가치 절반(session alive 필수). memory `project_auto_build_runtime_limit`의 "Phase 3 cron 전까지 session alive 필수" 해소 안 됨.
- 가역성: 즉시.
- 학습 효과: 0. R4 검증 못함.

## 추천 + 근거

**추천: 대안 B (3 sub-PR 분할)**

**선택 근거**:
1. Phase 3.0 PR-A/B의 분할 dogfooding 패턴이 cycle 8(memory 진입점)에서 검증됨 — calibration 일관
2. R4 리스크 격리 — PR-C1 단독 abort 시 PR-C2/C3 무관. memory `project_auto_build_runtime_limit`의 "다음 세션 진입점 = cycle 8" 자연 매칭
3. 각 sub-PR brief grade(3-5 파일) → 자율 사이클 dogfooding 가능 → vote calibration sample 추가 회수(상위 brainstorm R5 완화)
4. 통합 시점 늘어남(단점)은 cycle 9-11에 분산되어 cap 압박 0

**기각된 대안 A**: 통합 단일 PR은 schedule 스킬 미검증 상태에서 R4 영향 범위 큼. auto-recovery/depends_on은 schedule과 무관 — 분할 정당. A 전환 가치는 schedule 스킬 충분 검증 후 다시 통합 PR로 압축 시 (현 상태에서는 부적합).

**기각된 대안 Z**: memory 명시 4 결정 채택 → 진행이 합리적. anytime 원칙(memory `feedback_auto_build_anytime`) 충족 위해 cron 필수.

## 다음 단계

**hard_gate: brief grade per sub-PR** — 각 PR 영향 파일 추정:

### PR-C1 (schedule 통합) — 진입점
- `core/skills/auto-build/scripts/run-queue.sh` (DRYRUN 기본 0 분기 + schedule 호출 모드 추가)
- `core/skills/auto-build/SKILL.md` (schedule 등록 가이드 섹션)
- `core/skills/auto-build/orchestrator.md` (cron-triggered cycle 분기 — destructive op cap 강화)
- 신규 `core/skills/auto-build/scripts/schedule-register.sh` (schedule 스킬 호출 helper)
- 신규 `scripts/tests/schedule-smoke.sh` (etc/cron expression validation)
- 예상 5 파일

### PR-C2 (auto-recovery)
- `core/skills/auto-build/scripts/queue.sh` (next 시 stale running 검출 + 자동 status_update aborted)
- `core/skills/auto-build/scripts/run-queue.sh` (run-queue 진입 시 stale 회수 1회)
- `scripts/tests/queue-tests.sh` (Test 10-11: stale running 회수 케이스 추가)
- 예상 3 파일

### PR-C3 (depends_on 활성)
- `core/skills/auto-build/scripts/queue.sh` (next 시 depends_on entry의 선행 PR=merged 검증)
- 신규 `core/skills/auto-build/scripts/check-pr-merged.sh` (gh api wrapper + 캐시)
- `core/skills/auto-build/SKILL.md` (depends_on 사용법 예시 추가)
- `scripts/tests/queue-tests.sh` (Test 12: depends_on gating)
- 예상 4 파일

**총 ~12 파일** (3 PR로 분산 시 각 brief grade)

### 권장 진행 순서

1. **PR-C1 진입 (cycle 8 dogfooding)** — schedule 스킬 R4 검증 우선. 성공 시 cycle 9 진입, 실패 시 다른 cron 메커니즘(A1.1) 재평가.
2. **PR-C2 (cycle 9)** — schedule 무관, 단독 실행 가능. PR-C1과 병렬 가능하나 sequential 권장 (memory note: stacked PR 회피).
3. **PR-C3 (cycle 10)** — gh api 의존 + multi-repo 짝 cycle 패턴 검증.
4. **PR-D (cycle 11, 별 cycle)** — dashboard `/morning` 페이지 (상위 brainstorm 결정 4번)

### 검증 (Phase 3.1 완료 기준)

- (C1) `schedule` 등록된 cron expression이 정해진 시각 firing → `run-queue.sh` 실행 → 큐 첫 task /auto-build 사이클 PR 생성
- (C2) `queue.sh next` 실행 시 stale running(>1h old) 자동 aborted 마킹
- (C3) depends_on entry는 선행 PR merged 전까지 queued 유지, merged 후 다음 next에 진입

## 리스크 (상위 brainstorm R1~R5 + 본 PR-C-specific)

- **R4 (상위 brainstorm)**: schedule 스킬 미지원 → PR-C1 abort 시 macOS launchd(A1.1) 재평가. 본 brainstorm은 R4 dogfooding 회수를 진입 가치로 명시.
- **R6 (신규)**: cron firing 시 사용자 부재 → 사이클 abort 통계 누적 위험. **Phase 2 retrospective hook (5건 연속 abort 알림) 활용** 명시 — Phase 3.1 신규 hook X.
- **R7 (신규)**: depends_on PR-merged 폴링이 gh api rate limit 초과 위험. 캐시(5분 TTL) + 단일 firing당 최대 5회 API 호출 cap.

## 결정 점 (maker review)

- [x] **대안 B 채택** (3 sub-PR 분할) — 본 brainstorm 추천
- [ ] PR-C1 cycle 진입 시점 — 즉시 cycle 8 vs schedule 스킬 사전 dry-run 검증 후
- [ ] AUTO_BUILD_QUEUE_MAX_FIRINGS_PER_DAY 기본값 — 2 (보수) vs 4 (적극)
- [ ] PR-C2/C3 순서 — sequential(권장) vs PR-C1 결과 보고 결정
