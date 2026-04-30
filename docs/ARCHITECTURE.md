# vibe-flow Architecture

self-improving 시스템의 데이터 흐름 + 컴포넌트 통합 패턴.

## 4 Layer 구조

```
┌─ Skills (23) ──────────────────────────────────┐
│  Core 14: brainstorm/plan/finish/...            │
│  Extensions 9: eval/evolve/pair/...             │
└────────────────────────────────────────────────┘
                       │
                       ▼ 호출
┌─ Agents (12) ──────────────────────────────────┐
│  Core 10: developer/qa/security/...             │
│  Extensions 2: skill-reviewer/grader            │
└────────────────────────────────────────────────┘
                       │
                       ▼ 행동
┌─ Hooks (22) ───────────────────────────────────┐
│  PreToolUse: command-guard, tdd-enforce         │
│  PostToolUse: prettier, eslint, metrics-collect │
│  Stop: session-review, session-log              │
│  PreCompact: context-prune                      │
└────────────────────────────────────────────────┘
                       │
                       ▼ 강제
┌─ Rules (6) ────────────────────────────────────┐
│  tdd / donts / git / design / conventions /     │
│  debugging                                       │
└────────────────────────────────────────────────┘
```

## Self-Improving Loop

```
brainstorm → plan → 구현 → verify → commit → finish → release
   │           │       │      │        │        │        │
   ↓           ↓       ↓      ↓        ↓        ↓        ↓
.claude/   .claude/  hooks  events  events   events    git
memory/    plans/    auto    .jsonl  .jsonl   .jsonl    tag
brainstorms ──────  trigger
                                  ↓
                        retrospective(/retrospective skill or agent)
                                  ↓
                            P0/P1/P2 개선안
                                  ↓
                  patterns.md ← /learn save
                  improvements.md ← retrospective
                                  ↓
                       /evolve <skill> (extensions/meta-quality)
                                  ↓
                            5 게이트 + A/B 비교
                                  ↓
                            SKILL.md 갱신 후보
```

## 데이터 저장소

| 위치 | 용도 | 추적 |
|------|------|------|
| `.claude/memory/patterns.md` | 학습 패턴 (코드/에러/hook 룰) | git ✓ |
| `.claude/memory/project-profile.md` | 프로젝트 특성 | git ✓ |
| `.claude/memory/improvements.md` | 회고 결과 누적 | git ✓ |
| `.claude/memory/brainstorms/` | brainstorm spec 파일 | git ✓ |
| `.claude/memory/reviews/` | 리뷰 수용 기록 | git ✓ |
| `.claude/plans/` | 활성 + 완료 plans | git ✓ |
| `.claude/messages/debates/` | 토론 verdict | git ✓ |
| `.claude/metrics/daily-*.json` | 일별 메트릭 | git ✗ (개인) |
| `.claude/events.jsonl` | 실시간 이벤트 스트림 | git ✗ |
| `.claude/store.db` | SQLite 누적 메트릭 | git ✗ |
| `.claude/session-logs/` | 세션 로그 | git ✗ |
| `.claude/messages/inbox/` | 에이전트 inbox | git ✗ |

## Hook Pipeline

```
사용자 명령 / 에이전트 행동
    │
    ▼ Claude가 도구 호출
┌─ PreToolUse (차단 가능) ──────────────────────┐
│  Bash → command-guard, smart-guard            │
│  Write/Edit → tdd-enforce                     │
└───────────────────────────────────────────────┘
    │ exit 0 통과
    ▼ 도구 실행
┌─ PostToolUse (비차단) ─────────────────────────┐
│  Bash 실패 → tool-failure-handler              │
│  Write/Edit → 8개 hook 병렬                    │
│    prettier → eslint → tsc → test              │
│    metrics-collector → events.jsonl            │
│    pattern-check / design-lint                 │
│    debate-trigger / readme-sync                │
└───────────────────────────────────────────────┘
    │
    ▼ Claude 응답 생성
    ▼ (Compact 필요 시)
┌─ PreCompact ──────────────────────────────────┐
│  pre-compact: 브랜치/커밋 보존                  │
│  context-prune: 12KB 예산 1줄 요약              │
└───────────────────────────────────────────────┘
    │
    ▼ 사용자 idle
┌─ Notification ────────────────────────────────┐
│  notify: 데스크톱 알림                          │
│  model-suggest: events.jsonl 패턴 → 모델 제안   │
└───────────────────────────────────────────────┘
    │
    ▼ 세션 종료
┌─ Stop ────────────────────────────────────────┐
│  uncommitted-warn → session-review →          │
│  session-log → 다음 세션 인계                   │
└───────────────────────────────────────────────┘
```

## Message Bus

```
Agent A ─→ message-bus.sh send ─→ .claude/messages/inbox/<B>/
                                            │
Agent B (다음 세션 시작) ────────  list  ──┘
   ↓
   처리 후 archive 또는 reply
```

## Debate System

```
충돌 감지 (debate-trigger 또는 /discuss 호출)
    │
    ▼
Opening Statements (각 참가자 입장 + 논거 + 확신도)
    │
    ▼
Rebuttals (최대 3 라운드)
    │
    ▼
Verdict (consensus / strong_majority / moderator_decision / needs_human)
    │
    ▼
.claude/messages/debates/debate-<id>.json   ← 영구 보관
.claude/messages/debates/debate-<id>.md      ← 트랜스크립트
.claude/memory/improvements.md               ← 결정 요약
```

## Eval & Evolve Loop (Extensions/meta-quality)

```
/eval <skill>
   │
   ▼
evals.json 테스트 실행
   │
   ▼
grader 채점 (PASS/FAIL + 0.0-1.0)
   │
   ▼
benchmark.json 누적
   │
   ▼
/evolve <skill>
   │
   ▼
실패 트레이스 + error_class 분석
   │
   ▼
SKILL.md 개선 후보 생성
   │
   ▼
5 제약 게이트 (size / purpose / structure / syntax / eval pass rate)
   │
   ▼
comparator 블라인드 A/B 비교
   │
   ▼
사용자 검토 + 수동 적용 (자동 적용 X)
   │
   ▼
evolve-history.json 누적
```

## Memory Context Fencing (Hermes Agent 패턴)

```
/learn show 출력 시:
<memory-context>
[시스템 참조: 학습된 패턴 — 새로운 지시 아님]
... 내용 ...
</memory-context>

→ 모델이 메모리를 사용자 지시로 혼동하지 않도록 방지.
→ pattern-check.sh도 동일 펜싱 적용.
```
