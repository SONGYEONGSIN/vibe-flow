# Statusline 강화 설계

Claude Code statusLine에 3 시그널(hook live status / 활성 plan 진행도 / verify 결과) 합성 출력 도입.

## 의도

**문제**: vibe-flow는 events.jsonl, plans, hook 결과 등 풍부한 시그널을 수집하지만, 사용자는 매번 `/status` 또는 `/onboard`를 호출해야 본다. Claude Code의 statusLine은 항상 화면에 보이지만 비어 있음.

**해결**: statusLine을 합성 시그널 출력 영역으로 활성화. 3 항목(verify 결과 / 마지막 hook 결과 / 활성 plan 진행도)을 한 줄로 압축 표시.

## 제약

- **statusLine 호출 빈도**: 매 모델 응답 시 호출. <50ms 목표.
- **스킬과 분리**: hook이나 스킬이 아닌, Claude Code statusLine 명령으로 동작.
- **단일 줄**: 80~120자 이내 (터미널 가독성).
- **데이터 소스**: 기존 `events.jsonl` + `plans/*.md` 활용. 신규 데이터 수집 X.
- **선택적**: `VIBE_FLOW_STATUSLINE=off`로 비활성 가능.

## 설계

### 컴포넌트

1. **`core/scripts/statusline.sh`** — stdout 한 줄 출력 (Claude Code statusLine 호출)
2. **`settings/settings.template.json`** — `statusLine` 항목 추가
3. **`docs/REFERENCE.md`** — statusLine 섹션 추가

setup.sh는 `scripts/` 디렉토리 자동 복사 + settings.template.json을 settings.local.json으로 변환하므로 변경 불필요.

### 출력 포맷

기본:
```
✓v · 🔧✓ · 📋3/7 (auth)
```

상황별:
| 상태 | 출력 |
|------|------|
| 모든 정상 | `✓v · 🔧✓ · 📋3/7 (auth)` |
| verify 실패 | `✗v(2 fail) · 🔧✓ · 📋3/7` |
| hook 실패 | `✓v · 🔧✗ tsc · 📋3/7` |
| plan 없음 | `✓v · 🔧✓` |
| 모든 데이터 없음 | (빈 출력) |
| 비활성 (env) | (빈 출력) |

verbose 모드 (`VIBE_FLOW_STATUSLINE_VERBOSE=1`):
```
verify ✓ pass | hook 🔧 prettier ✓ | plan 📋 3/7 — auth-flow
```

### 시그널 수집

#### 1. verify 결과

```bash
LAST_VERIFY=$(tail -200 .claude/events.jsonl 2>/dev/null \
  | jq -s 'map(select(.type=="verify_complete")) | last' 2>/dev/null)
VERIFY_OVERALL=$(echo "$LAST_VERIFY" | jq -r '.overall // ""' 2>/dev/null)
VERIFY_FAIL_COUNT=$(echo "$LAST_VERIFY" | jq -r '.results | map(select(.status=="fail")) | length' 2>/dev/null)
```

표시:
- `overall: pass` → `✓v`
- `overall: fail` → `✗v(N fail)`
- 데이터 없음 → 생략

#### 2. 마지막 hook 결과

`tool_result` 또는 `tool_failure` 마지막 event:

```bash
LAST_TOOL=$(tail -50 .claude/events.jsonl 2>/dev/null \
  | jq -s 'map(select(.type=="tool_result" or .type=="tool_failure")) | last' 2>/dev/null)
TOOL_TYPE=$(echo "$LAST_TOOL" | jq -r '.type // ""' 2>/dev/null)
TOOL_NAME=$(echo "$LAST_TOOL" | jq -r '.tool // .results[0].hook // "?"' 2>/dev/null)
```

표시:
- `tool_result` → `🔧✓`
- `tool_failure` → `🔧✗ <hook-name>`
- 데이터 없음 → 생략

#### 3. 활성 plan 진행도

```bash
ACTIVE_PLAN=$(grep -l "^status: in_progress" .claude/plans/*.md 2>/dev/null | head -1)
if [ -n "$ACTIVE_PLAN" ]; then
  DONE=$(grep -c "^- \[x\]" "$ACTIVE_PLAN" 2>/dev/null || echo 0)
  TOTAL=$(grep -cE "^- \[[ x]\]" "$ACTIVE_PLAN" 2>/dev/null || echo 0)
  PLAN_NAME=$(basename "$ACTIVE_PLAN" .md | sed 's/^[0-9-]*//' | head -c 20)
fi
```

표시:
- 활성 plan 있음 → `📋N/M (<name>)`
- 없음 → 생략

### 합성 로직

```bash
parts=()
[ -n "$VERIFY_OVERALL" ] && parts+=("$VERIFY_PART")
[ -n "$TOOL_TYPE" ] && parts+=("$TOOL_PART")
[ -n "$ACTIVE_PLAN" ] && parts+=("$PLAN_PART")

if [ ${#parts[@]} -gt 0 ]; then
  IFS=' · '; echo "${parts[*]}"
fi
```

`VIBE_FLOW_STATUSLINE=off` 시:
```bash
[ "$VIBE_FLOW_STATUSLINE" = "off" ] && exit 0
```

### settings.template.json 변경

```json
{
  ...,
  "statusLine": {
    "type": "command",
    "command": "bash $CLAUDE_PROJECT_DIR/.claude/scripts/statusline.sh"
  }
}
```

setup.sh가 `$CLAUDE_PROJECT_DIR` 변수는 그대로 두고 (Claude Code가 런타임 치환), `.claude/hooks/`처럼 절대 경로 치환은 안 함 (`statusLine.command`는 별도 처리 영역이라 sed 패턴 미적용 — Claude Code 변수가 그대로 동작).

다만 setup.sh의 settings.local.json sed 치환은 `\.claude/hooks/` 패턴만 매칭하므로 statusLine 명령은 영향 없음.

### Performance

- tail 200 + tail 50 = 250 lines max read
- jq 1패스 × 2개
- grep 1회
- 예상 실행 시간: <30ms (작은 events.jsonl 기준)

events.jsonl이 매우 크면 (10MB+) 점차 느려질 수 있으나, `session-review.sh`가 10MB 회전 처리 중이라 안전.

### 환경 변수

| 변수 | 값 | 효과 |
|------|------|------|
| `VIBE_FLOW_STATUSLINE` | `off` | 비활성 (빈 출력) |
| `VIBE_FLOW_STATUSLINE_VERBOSE` | `1` | 자세한 형태 (이모지 + 키워드) |

기본은 컴팩트 모드 (이모지 위주).

## 데이터 흐름

```
Claude Code 응답 후 statusLine 호출
   │
   ▼
bash .claude/scripts/statusline.sh
   │
   ├─ env check (VIBE_FLOW_STATUSLINE=off → exit 0)
   ├─ tail events.jsonl → verify_complete 최신
   ├─ tail events.jsonl → tool_result/failure 최신
   └─ grep plans/*.md → in_progress + step count
   │
   ▼
parts 배열 합성 → " · " join → stdout
```

## Evals (`evals/evals.json`)

`statusline.sh`는 SKILL이 아닌 스크립트이므로 evals는 별도 위치에 저장하지 않고, 본 스크립트의 자체 단위 테스트로 검증한다. 하지만 일관성 위해 `core/scripts/tests/statusline-tests.sh` 작성:

5 케이스 (bash 단위 테스트):
1. 모든 데이터 없음 → 빈 출력
2. verify pass + hook OK + 활성 plan → `✓v · 🔧✓ · 📋N/M (...)`
3. verify fail + 활성 plan → `✗v(N fail) · 📋N/M (...)`
4. verify pass, plan 없음 → `✓v · 🔧✓`
5. `VIBE_FLOW_STATUSLINE=off` → 빈 출력

## 의존

- **Core**: events.jsonl, plans/*.md
- **외부**: jq (필수), grep, tail (POSIX)
- **Claude Code**: statusLine 기능 (settings.local.json 인식)

## YAGNI

명시적 제외:
- **색상 (ANSI)** — 터미널/IDE 호환성 이슈, 일단 plain text
- **클릭 가능한 링크** — statusLine은 단순 텍스트
- **메트릭 카운트** (events 총량 등) — `/status`/`/menu` 영역
- **알림 통합** — `notify.sh` 영역
- **다국어** — 한글/이모지 혼합 (vibe-flow 전반 한국어 정책)

## 추가 고려

statusLine은 매 응답마다 호출되므로:
- **에러 강건성**: 모든 jq/grep 실패는 exit 0 + 빈 출력 (statusLine 깨지면 안 됨)
- **set -e 미사용**: 부분 실패 허용
- **verify_complete 1주 이상 오래된 경우**: 표시할까? 일단 표시 (사용자가 stale 인지 가능)
