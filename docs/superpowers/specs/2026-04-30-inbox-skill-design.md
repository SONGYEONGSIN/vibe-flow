# /inbox 스킬 설계

12 에이전트의 inbox + broadcast + debates를 통합 뷰로 한 화면에 출력하는 인터랙티브 스킬.

## 의도

**문제**: vibe-flow는 12 에이전트 간 비동기 메시지 버스를 운영하지만, 사용자가 "어느 에이전트에게 메시지가 와 있는지" 한눈에 보려면 12개 디렉토리를 직접 ls 해야 한다. `message-bus.sh`는 단일 에이전트 CLI(`list/read/count/archive`)만 제공.

**해결**: `/inbox` — 모든 inbox 통합 뷰. 에이전트별 unread/total 카운트 + 최근 미리보기 1-3개 + broadcast/debates 섹션.

**대상**:
1. 사용자 — "지금 누구에게 답해야 하나?" 결정
2. 회고 — "쌓인 메시지가 많은 에이전트 = 병목" 시그널

## 제약

- **message-bus.sh 호환**: 기존 메시지 JSON 스키마 그대로 사용. `message-bus.sh <list|read|archive|count>` CLI는 변경 없음.
- **명령 표면**: 단일 명령 `/inbox` + 1 인자 또는 1 옵션.
- **읽기 전용**: `/inbox`는 메시지 상태 변경 안 함 (read 처리는 message-bus.sh에 위임).
- **Cache 없음**: 매번 jq aggregation (12 에이전트 × 평균 ~5 메시지 = 빠름).

## 설계

### 입력

```bash
/inbox                # 전체 통합 뷰 (default)
/inbox <agent>        # 특정 에이전트 풀 리스트 (message-bus list 래퍼)
/inbox --unread-only  # 모든 에이전트의 unread만 (Active 섹션만)
/inbox --broadcast    # broadcast/ + debates/ 섹션만
```

### 메시지 JSON 스키마 (기존)

```json
{
  "type": "alert|request|reply|debate-invite|debate-round|debate-verdict|info",
  "from": "<agent>",
  "to": "<agent>",
  "subject": "...",
  "body": "...",
  "ts": "ISO 8601",
  "msg_id": "...",
  "status": "unread|read",
  "debate_id": null
}
```

### 시그널

1. **`.claude/messages/inbox/<agent>/*.json`** — 각 에이전트 메시지
2. **`.claude/messages/broadcast/*.json`** — 전체 공지
3. **`.claude/messages/debates/*.json`** — 토론 활성/종료 verdict
4. **`.claude/agents.json`** — 12 에이전트 명단 (없으면 `inbox/` 디렉토리 명단으로 폴백)

### Active vs Quiet 분류

| 분류 | 조건 | 출력 |
|------|------|------|
| Active | `unread > 0` | 카운트 + 최근 unread 1-3 미리보기 |
| Quiet | `unread = 0` | 이름만 한 줄 (콤마 구분) |

미리보기는 ts 최근순 3개. unread만.

### 출력 포맷 (전체)

```
📬 vibe-flow Inbox (12 에이전트)

━━━ Active (N) ━━━

@<agent>         <unread> unread / <total> total
  → "<subject>"                                    (<from> <ts 상대>, unread)
  → "..."
  ...

━━━ Quiet (M) ━━━

@<agent1>, @<agent2>, ...: 0 unread

━━━ Broadcast / Debates ━━━

📢 broadcast/: <N> messages
🗣  debates/: <N> active (<debate-id 1> — <verdict_type>)

(레전드: unread = status:"unread" / total = 전체)
```

`<ts 상대>`: "30분 전", "2시간 전", "1일 전" 등. now - ts 기반.

### 출력 포맷 (`/inbox <agent>`)

기존 `message-bus.sh list <agent>` 출력을 그대로 표시:
```
📬 @<agent> Inbox (<N> messages)

[unread] msg-id-1
  type: request  from: developer  ts: 2026-04-30T...
  subject: "...";

[read] msg-id-2
  ...
```

### 출력 포맷 (`/inbox --unread-only`)

전체 통합 뷰의 Active 섹션만:
```
📬 Unread Only

@<agent>         <unread> unread
  → "<subject>" (<from> <ts 상대>)
  ...

(읽음 처리: bash .claude/hooks/message-bus.sh read <agent>)
```

### 출력 포맷 (`/inbox --broadcast`)

```
📢 Broadcast

  → "<subject>"  (<from> <ts 상대>)

🗣 Debates

  active:
    debate-<id>  ("<topic>", verdict: <verdict_type>, rounds: <N>)
  ...
```

### Events 발생

`/inbox` 실행 시:
```json
{
  "type": "inbox",
  "ts": "...",
  "filter": "all|<agent>|unread-only|broadcast",
  "unread_total": <N>
}
```

`unread_total`은 모든 에이전트 합산 unread 카운트 (회고 분석에 활용).

## 데이터 흐름

```
사용자: /inbox [arg]
   │
   ▼
1. 인자 파싱 (default | <agent> | --unread-only | --broadcast)
2. 에이전트 명단 로드 (agents.json 또는 inbox/ 디렉토리)
3. 각 에이전트별:
   - unread/total count (jq filter status:"unread")
   - unread 최근 3 (jq sort_by ts | reverse | limit 3)
4. broadcast/debates 카운트
5. 분류 (Active/Quiet) + 출력
6. events.jsonl에 inbox append
```

## 구성 요소

### SKILL.md 구조

```
---
name: inbox
description: 12 에이전트 inbox + broadcast + debates 통합 뷰. /inbox, /inbox <agent>, /inbox --unread-only, /inbox --broadcast.
model: claude-sonnet-4-6
---

# /inbox

## 트리거
- /inbox, /inbox <arg>

## 절차
1. 인자 파싱
2. 에이전트 명단 로드
3. 각 inbox per-agent jq aggregation
4. broadcast/debates 카운트
5. 출력 (Active/Quiet/Broadcast 섹션)
6. events.jsonl에 inbox append
```

### Evals (`evals/evals.json`)

5 evaluation cases:
1. **Empty inbox** — 모든 에이전트 0 unread → Quiet 12 + broadcast/debates 0
2. **Mixed activity** — developer 3 unread, validator 1 unread, 나머지 0 → Active 2 + Quiet 10
3. **Single agent** — `/inbox developer` → message-bus list 출력 형태
4. **Unread only filter** — `--unread-only` → Active 섹션만
5. **Broadcast filter** — `--broadcast` → broadcast + debates 섹션만

각 case에 setup(메시지 fixture) + expected(출력 패턴) 명시.

## 의존

- **Core**: messages/, agents.json
- **외부**: jq (필수)
- **Hook 불필요**: SKILL.md 내부에서 모든 처리

## /menu, /onboard와의 관계

| | /onboard | /menu | /inbox |
|---|----------|-------|--------|
| 영역 | 학습 경로 | 도구 카탈로그 | 메시지 큐 |
| 데이터 소스 | events + state + memory | events + state + onboard | messages/ |
| 호출 빈도 | 주 1회 | 자주 | 작업 시작 시 |
| Cache | 24h | 없음 | 없음 |

3개 모두 메타 카테고리. 보완 관계.

## YAGNI

명시적 제외:
- **메시지 본문 표시** — `/inbox <agent>`에서 message-bus.sh에 위임
- **archive UI** — `bash .claude/hooks/message-bus.sh archive <file>` 그대로
- **푸시 알림** — `notify.sh` Notification hook이 이미 처리
- **메시지 검색** (`/inbox --grep "..."`) — `grep` 직접 사용 가능
- **메시지 작성** (`/inbox send`) — message-bus.sh send 그대로
- **다국어** — 한국어만
