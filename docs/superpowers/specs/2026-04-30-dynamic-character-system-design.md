# 동적 캐릭터 시스템 설계 (vibe-flow Phase 4)

- **작성일**: 2026-04-30
- **출처 ROADMAP 항목**: `🎮 동적 캐릭터 시스템 (게임화)` (v1.x 후속 후보)
- **타겟 repo**: `vibe-flow-dashboard` (별도 Next.js repo, App Router)
- **이 spec이 다루는 범위**: vibe-flow의 12 에이전트를 시각화한 *캐릭터 무대*를 dashboard `/characters` 페이지에 추가. 단일 픽셀 룸 안에서 chibi 캐릭터들이 가볍게 어슬렁거리다가 `events.jsonl` 트리거에 반응해 점프/만남/말풍선으로 표현된다.

---

## 1. 의도와 비-목표

### 의도
- vibe-coding 작업 중 **백그라운드 모니터처럼 활약** — 코드/도구 활동이 events 스트림으로 흐르고 있다는 사실을 *살아있는 캐릭터*로 시각화.
- 12 에이전트를 캐릭터로 인격화 → 메이커가 vibe-flow 시스템을 *기능*이 아닌 *팀*으로 인식.
- 게임화의 *재미* 요소를 추가하되 dashboard의 메트릭/현황 톤은 분리 (별도 페이지).

### 비-목표 (이 spec 범위 밖, 후속으로 분리)
- LLM이 매번 대사를 생성하는 동적 대사 모드
- 사용자 캐릭터 이름/외형 커스터마이즈
- 신규 의미적 이벤트(`commit_created`, `pair_started`) emit 인프라 추가
- 자유 로밍 / 픽셀 오피스 시뮬레이션 (Phaser 도입 — Path B)
- 캐릭터 레벨/뱃지 시스템
- 정식 픽셀아티스트 의뢰 에셋

---

## 2. 결정된 설계 선택지 (브레인스토밍 결과)

| 결정 항목 | 선택 |
|---|---|
| 범위 | events 연결 + Stage unlock + pair 강조 + 사용 카운트 |
| 비주얼 톤 | 단일 픽셀 룸 + 캐릭터 무대 (Path C 변형, 게임 엔진 X) |
| 움직임 | L2 (light wander) + L3 (event-driven 이동) — 자유 로밍 X |
| 캐릭터 디자인 | 12 visually distinct chibi (실루엣/체형부터 다름) |
| 캐릭터 톤 | Anthropic / Claude Code 마스코트 *오마주*, vibe-flow 오리지널 |
| 에셋 조달 | AI 픽셀아트 생성 → Aseprite 후처리 |
| 사이즈 | 48×48 픽셀 |
| 방향 프레임 | F2 — 좌/우 2방향 |
| 배치 | `vibe-flow-dashboard` repo `/characters` 페이지 |
| 대사 데이터 | 정적 풀 (JSON) — 후속에서 LLM 옵션 |

---

## 3. 시스템 구조

```
vibe-flow-dashboard (Next.js, App Router)
└─ src/app/characters/                   ← 새 페이지
   ├─ page.tsx                           ← 서버 컴포넌트, 정적 데이터 로드
   ├─ Stage.tsx                          ← 룸 배경 + 12 캐릭터 컨테이너
   ├─ Character.tsx                      ← 단일 캐릭터 (스프라이트 + 위치 + 말풍선)
   ├─ SpeechBubble.tsx                   ← 등장/페이드 애니메이션
   ├─ useCharacterEngine.ts              ← 무브먼트 + 트리거 + 대사 hook (로직 허브)
   ├─ useEventsStream.ts                 ← events.jsonl 구독 (SSE 또는 polling)
   └─ data/
      ├─ characters.ts                   ← Character Bible (12종 명세)
      ├─ event-map.ts                    ← events → 캐릭터/액션 매핑
      └─ dialogue-pool.json              ← 캐릭터 × 컨텍스트 × 대사[]

vibe-flow-dashboard/public/sprites/      ← 정적 에셋
└─ <agent>-{idle-l,idle-r,walk-l,walk-r}.png   (캐릭터당 4 PNG, 48×48)
```

**핵심 결정:**
- 게임 엔진 없음. **CSS `transform` + React state**만으로 구현. `transition: transform 0.4s linear`로 자연스러운 이동.
- 스프라이트 애니메이션은 **CSS `steps()` + background-position-x** (전통 sprite sheet 방식).
- events 구독은 dashboard 기존 패턴 재사용. 없으면 단순 polling (3~5초)로 시작.
- `useCharacterEngine`이 로직 허브 — 무브먼트 스케줄, 트리거 큐, 대사 선택. 컴포넌트는 dumb display.

---

## 4. 데이터 흐름

```
[vibe-flow 본체 (사용자 프로젝트의 .claude/)]                [vibe-flow-dashboard /characters]
.vibe-flow.json (Stage)            ──→ getStaticData()  → Character Bible + Stage 로드
events.jsonl (append-only)         ──→ /api/events/stream  (SSE 또는 polling)
                                            │
                                            ▼
                                       useEventsStream()
                                            │ (event 도착)
                                            ▼
                                       useCharacterEngine()
                                            │
                                            ├─→ event-map 조회 → 어느 캐릭터 / 어느 액션?
                                            ├─→ dialogue-pool 조회 → 랜덤 대사 선택
                                            ├─→ 캐릭터 state 업데이트
                                            │     - position (L3 만남 좌표 또는 home 복귀)
                                            │     - currentAction (idle/walk/jump/clap)
                                            │     - bubble: { text, expiresAt }
                                            │     - usageCount += 1
                                            │
                                            └─→ wander tick (L2): 5~15s 랜덤 간격
                                                home 영역 안 새 좌표 선택 → walk 액션
                                            ▼
                                       <Stage> + <Character × 12>
                                       (CSS transition으로 부드럽게 이동)
```

### 4.1 캐릭터 상태 모델

```ts
type CharacterState = {
  id: AgentId                                  // 'planner' | 'designer' | ...
  home: { x: number; y: number }               // 룸 안 home 좌표 (px)
  position: { x: number; y: number }           // 현재 좌표
  facing: 'left' | 'right'                     // F2 방향
  action: 'idle' | 'walk' | 'jump' | 'clap'
  bubble: { text: string; expiresAt: number } | null
  usageCount: number
  unlocked: boolean                            // Stage 기반
}
```

### 4.2 events 처리 순서 (예: `verify_complete` overall=fail — MVP 시나리오)

1. SSE/polling 수신 → `{ type: 'verify_complete', overall: 'fail', results: [{hook: 'tsc', status: 'fail'}, ...] }`
2. event-map: `verify_complete` (fail) → validator는 `walk` 액션으로 실패한 hook 매칭 캐릭터(`tsc` → developer) 옆 좌표로 이동
3. dialogue: validator는 `validator.rejected` 풀에서 1개, developer는 `developer.tool_fail` 풀에서 1개 → 0.5초 간격 표시
4. 도착 후 둘 다 `idle`. 4초 후 말풍선 페이드아웃
5. 30초 후 또는 다음 verify pass 시 → validator home 복귀

같은 패턴이 후속 spec의 `pair_started`/`pair_completed` 이벤트에도 그대로 적용된다 (두 캐릭터가 만나는 모든 시나리오).

### 4.3 events 첫 로드 정책

- 페이지 진입 시 `events.jsonl` 마지막 50건만 처리 (그 이전은 무시 — 캐릭터 폭주 방지)
- 마지막 처리 offset/timestamp 메모리 보관, 재구독 시 그 이후만

---

## 5. Character Bible — 12 캐릭터 명세

### 5.1 캐릭터 표

| # | 에이전트 | 컨셉 한 줄 | 핵심 모티프 | 메인 컬러 | 보조 컬러 |
|---|---|---|---|---|---|
| 1 | planner | 길쭉한 안테나 책상님 | 클립보드 든 손, 머리 위 안테나 흰 점 | `#5e9bd6` (블루) | 흰색 |
| 2 | designer | 베레모 쓴 마젠타 | 검정 베레모, 팔레트 | `#e36ba7` (마젠타) | 노랑 팔레트 |
| 3 | developer | 정사각 헤드폰러 | 검정 헤드폰, 정사각 실루엣 | `#5fb380` (그린) | 검정 |
| 4 | qa | 큰 눈 탐정 동그라미 | 흰자 도드라진 큰 눈, 돋보기 | `#7dd6c2` (민트) | 검정 |
| 5 | security | 헬멧+바이저 경비 | 골드 헬멧, 검정 바이저, 가슴 배지 | `#3a3a4a` (다크) | `#dba83b` 골드 |
| 6 | validator | 기둥형 + 가슴 별 | 세로 기둥 실루엣, 노랑 별 | `#3da068` (라임) | 노랑 별 |
| 7 | feedback | 털 한 가닥 + 큰 입 | 머리 털 한 올, 활짝 입 | `#f5b8d2` (소프트 핑크) | 검정 |
| 8 | moderator | 통통 콧수염 망치 | 콧수염, 작은 망치 든 손 | `#a89366` (베이지) | `#5a3f1a` 갈색 |
| 9 | comparator | 듀얼톤 좌우반반 | 몸 좌/우 다른 색, 가슴 VS 표식 | `#5e9bd6` 좌 / `#d97757` 우 | 흰자 눈 |
| 10 | retrospective | 안경 + 책 더미 | 둥근 안경, 책 두 권 위 | `#8b6cb0` (퍼플) | 책 색 |
| 11 | grader (Stage 4 잠금) | 차트 든 회색 | 안고있는 차트, 흐릿 | `#6c8db5` (다크 블루) | — |
| 12 | skill-reviewer (Stage 4 잠금) | 캡 + 렌치 작업복 | 오렌지 캡, 골드 렌치 | `#7a8290` (그레이) | `#d97757` 캡 |

### 5.2 공통 디자인 언어

- 톤: chibi / 단순 / 흑색 점 눈 / 둥근 가장자리
- 사이즈: **48×48 픽셀 캔버스**, 캐릭터는 그 안 ~36×36 영역
- 그림자: 발 밑 어두운 타원 (모든 캐릭터 동일)
- 외곽선: 1px 진한 동족 컬러 (있으면 좋음, 없어도 OK)
- 라이선스 안전선: OpenClaw / Claude Code 마스코트와 *식별 가능할 정도로 다른 실루엣*. 위 12종은 모두 새 컨셉.

### 5.3 프레임 명세 (캐릭터당)

| 프레임 | 목적 | 필수/선택 |
|---|---|---|
| `idle-l`, `idle-r` | 정지 (호흡) | **필수** (각 1프레임 OK, 2프레임이면 호흡 애니) |
| `walk-l`, `walk-r` | 좌/우 이동 | **필수** (각 2프레임이면 다리 교차 애니) |
| `jump` | 트리거 반응 (점프) | 선택 — 없으면 idle에 `transform: translateY(-6px)` |
| `clap` | 박수 | 선택 — 없으면 jump로 대체 |

**최소 출시 세트**: 캐릭터당 idle-l/r + walk-l/r = 4 프레임 × 12명 = **48 sprites**.

### 5.4 에셋 파이프라인

```
[Step 1] AI 생성 (Midjourney / Pixelicious / SD pixel-LoRA)
  공통 prompt: "chibi pixel art mascot, 48x48, transparent bg, 2-tone shading,
              [캐릭터 컨셉], side view, idle pose"
  같은 seed/style 재사용으로 일관성 유지

[Step 2] Aseprite 후처리
  픽셀 정렬, 배경 투명, 외곽선 정리, 색 팔레트 통일
  좌/우 미러링 (한쪽 그리고 flip)
  walk 2프레임 = idle 다리만 살짝 변형

[Step 3] Sprite sheet 또는 단일 PNG
  public/sprites/<agent>.png

[Step 4] CSS 통합
  background-image + background-position step()
```

**시간 예상**: 1~2일 (혼자, 비주얼 디렉션 명확). 만족 못 하면 후속에서 픽셀아티스트 의뢰.

**코드/에셋 분리 원칙**: 코드는 sprite 파일명만 알면 동작. placeholder PNG로 코드 먼저 작성 가능. 에셋 교체 시 코드 변경 없음.

---

## 6. 이벤트/Stage 매핑 + 대사 풀

### 6.1 이벤트 매핑 — 기존 events.jsonl 타입

`events.jsonl`은 `<user-project>/.claude/events.jsonl`에 push되는 append-only JSONL. 현재 emit되는 타입:

| events.jsonl 타입 | 추출 필드 | 트리거 캐릭터 | 캐릭터 액션 | 대사 풀 키 |
|---|---|---|---|---|
| `tool_result` (status=pass) | `tool` | tool과 매칭되는 캐릭터 | `jump` (또는 clap) | `<agent>.tool_pass` |
| `tool_result` (status=fail) | `tool` | 매칭 캐릭터 + qa | qa는 `walk` 와서 옆에 섬, 매칭은 `idle` 정지 | `<agent>.tool_fail`, `qa.investigation` |
| `verify_complete` (overall=pass) | — | validator | `jump` + 별 빛남 | `validator.approved` |
| `verify_complete` (overall=fail) | `results[].hook` | validator + 실패 hook 매칭 | validator는 실패 캐릭터에게 `walk` | `validator.rejected` |
| `error` (tool failure) | `tool` | qa | `walk` + 화면 중앙 | `qa.bug_found` |

### 6.2 Tool ↔ Agent 매핑

확정 매핑 테이블 (spec에 박힘):

```ts
const TOOL_TO_AGENT = {
  prettier: 'designer',
  eslint:   'designer',
  tsc:      'developer',
  test:     'qa',           // vitest 등 단위 테스트
  playwright: 'qa',
  // 매칭 안 되면 fallback:
  '*':      'moderator',
}
```

### 6.3 신규 이벤트 emit (Phase 2 후속 — MVP 범위 외)

이상적이지만 *이 spec에 포함하지 않음* (events 인프라 변경은 별도 spec):

| 신규 타입 | emit 위치 | 매핑 캐릭터 |
|---|---|---|
| `commit_created` | `/commit` 스킬 또는 Stop hook | designer (박수) + planner |
| `pair_started` / `pair_completed` | `/pair` 스킬 진입/종료 | builder + validator |
| `discuss_started` | `/discuss` 스킬 | moderator + 양측 |
| `skill_invoked` | UserPromptSubmit hook | 해당 스킬 owner 캐릭터 |
| `retro_complete` | `/retrospective` 스킬 | retrospective |

**MVP에서는** `tool_result` 와 `verify_complete` 두 개만 매핑해도 캐릭터들이 충분히 살아있다 — 모든 hook 결과가 events 스트림으로 흐르고 있으니까.

### 6.4 Stage Unlock

`<user-project>/.vibe-flow.json`의 `stage` 필드 (0~4) 읽어서:

| Stage | 활성 캐릭터 | 사유 |
|---|---|---|
| 0 (신규) | planner, designer | 초기 설계/UI |
| 1 (도구 사용) | + developer, qa | 코드 + 테스트 |
| 2 (협업) | + validator, moderator, feedback | /pair, /discuss |
| 3 (자가 평가) | + security, comparator, retrospective | 점검·비교·회고 |
| 4 (자가 진화) | + grader, skill-reviewer | extension 영역 |

- 잠금 캐릭터는 흐릿하게 (opacity 0.35) + "Stage 2에서 등장" 같은 작은 라벨
- `.vibe-flow.json` 없거나 `stage` 누락 시 **Stage 1 default** (개발/테스트 편의)

### 6.5 대사 풀 (`dialogue-pool.json`)

```json
{
  "designer": {
    "tool_pass":   ["디자인 살아남! 🎨", "또 한 픽셀 추가!", "예쁘다…", "린트 깨끗", "포맷 ✨"],
    "tool_fail":   ["어… 다시 볼게", "스타일 어긋남", "줄 맞춰야지"],
    "wander":      ["흠…", "스케치 중", "🎨"]
  },
  "validator": {
    "approved":    ["통과!", "GOOD ✨", "넘겨라", "✅"],
    "rejected":    ["다시", "안 됨", "수정 필요"],
    "wander":      ["검토 중", "확인…"]
  },
  "qa": {
    "tool_pass":   ["좋아", "테스트 OK"],
    "tool_fail":   ["버그다!", "재현 시도", "🔍"],
    "bug_found":   ["여기다!", "이거 봐!"],
    "investigation": ["확인 중…", "🔍"],
    "wander":      ["흠…"]
  }
  // ... 12 캐릭터 전체
}
```

- 캐릭터당 **5개 컨텍스트 키** × **3~5 대사** ≈ 15~25 라인 = 12명 × 평균 20 = **약 240 라인**
- 작성: 메이커 직접 또는 AI 1차 생성 후 톤 보정 (1~2시간)
- `wander` 키: L2 wander 시작 시 **30% 확률**로 가벼운 말풍선 (사일런트 UI 방지)
- 모든 키 fallback: 빈 풀이면 말풍선 없이 액션만

### 6.6 대사 선택 로직

```ts
function pickLine(agent: AgentId, contextKey: string, lastUsed: Map<string, string[]>) {
  const pool = dialogue[agent]?.[contextKey] ?? [];
  if (!pool.length) return null;
  // 최근 N개 사용한 대사 회피해서 다양성 ↑
  return weightedRandom(pool, lastUsed.get(`${agent}:${contextKey}`) ?? []);
}
```

---

## 7. 무브먼트 시스템 (L2 + L3)

### 7.1 룸 좌표계

- 룸 캔버스: `1024 × 576` (16:9, 디자인 단위 px). 컨테이너 폭에 맞춰 비례 스케일.
- 캐릭터 home: 12명을 가로 6 × 세로 2 격자에 배치. 격자 셀 ≈ 170×288, home은 셀 중심 (양쪽 padding ~50px 확보).
- wander radius: home 기준 ±60px (다른 캐릭터 home과 충돌 안 하도록 여유)

### 7.2 L2 — Light Wander

- 각 캐릭터 독립 스케줄: `setTimeout`으로 5~15초 랜덤 간격
- 새 좌표 = `clamp(home + random(-radius, +radius), room_padding, room_size - padding)`
- 이동 거리에 따라 transition 시간 조정 (대략 40px/sec)
- walk 액션 + facing 방향 결정 (newX > currentX → 'right')
- 도착 후 idle로 복귀
- wander 시 30% 확률로 `dialogue.wander` 풀에서 한 줄 말풍선

### 7.3 L3 — Event-Driven Movement

**MVP에서 L3 트리거 주요 시나리오** = `verify_complete` (fail) 시 validator → 실패 hook 매칭 캐릭터 옆으로 이동, `tool_result` (fail) 시 qa → 실패 캐릭터 옆으로 이동. 후속 spec의 `pair_started`도 동일 패턴.

- 두 캐릭터가 만나야 하는 이벤트 시:
  - 이동 캐릭터(validator/qa)의 목표 좌표 = 대상 캐릭터 home에서 +40px 옆 (겹치지 않게)
  - `walk` 액션으로 그 좌표로 이동
  - 도착하면 대상을 바라보는 facing으로 `idle`
  - 30~60초 타임아웃 또는 후속 pass 이벤트 시 home 복귀
- `tool_result` (pass) 등 단일 캐릭터 점프 이벤트:
  - 위치 이동 없음 — `jump` 액션만 (CSS `translateY(-12px)` 후 복귀)

### 7.4 동시성 / 우선순위

- 한 캐릭터가 여러 이벤트 받을 때 — *마지막 이벤트의 액션이 이김* (interrupt OK)
- L3 이동 중 L2 wander tick → L3 우선, wander 일시정지
- `document.visibilitychange`로 탭 inactive 시 모든 tick 일시정지 (배터리)

---

## 8. UI 스펙

### 8.1 페이지 레이아웃 (`/characters`)

```
┌─────────────────────────────────────────────────┐
│ ← Dashboard | 🎮 Characters                     │  ← 헤더
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌───────────────────────────────────────────┐  │
│  │                                           │  │
│  │           [픽셀 룸 배경]                   │  │
│  │                                           │  │
│  │   🟢   🟦   ⬛   🟩   ⬜   ⬛               │  │  ← 12 캐릭터
│  │                                           │  │
│  │   🟪   🟧   🟨   ⬜   ⬜🔒  ⬜🔒            │  │
│  │                                           │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
│  [Recent events feed — 최근 5건 (작게)]          │
│                                                 │
└─────────────────────────────────────────────────┘
```

### 8.2 컴포넌트 동작

- `<Stage>`: 룸 배경 + 12 `<Character>` 자식. 글로벌 좌표 기준.
- `<Character>`: 절대 위치 (`transform: translate(x, y)`). sprite background. action class에 따라 frame 변경. `<SpeechBubble>` 자식 (말풍선 있을 때).
- `<SpeechBubble>`: 등장 시 0.2s fade-in, 만료 직전 0.4s fade-out. expiresAt 기본 4초.

### 8.3 접근성 / 모션 감소

- `prefers-reduced-motion: reduce` 시 wander 비활성, 이벤트 액션은 *정지 상태로 색만 강조* + 말풍선만 표시
- 캐릭터에 `aria-label="<agent name> — <current action>"` (스크린리더 친화)

---

## 9. 에러 처리 / 폴백

| 상황 | 처리 |
|---|---|
| `events.jsonl` 파일 없음 | 캐릭터 idle wander만, 배너 "no events yet" 작게 표시 |
| `events.jsonl` 파싱 실패 라인 | 해당 라인 skip (try/catch 한 라인 단위), 다음 라인 계속 |
| `dialogue-pool.json` 누락 키 | 말풍선 없이 액션만 (silent ok) |
| 스프라이트 PNG 로드 실패 | fallback CSS 사각형(메인 컬러), `console.warn` 1회 |
| `.vibe-flow.json` 없음 또는 stage 누락 | Stage 1 default |
| SSE/polling 끊김 | 자동 재시도 백오프 3s/9s/27s 최대 30s, UI 상단 작은 dot indicator |
| 동시 다발 events 폭주 (>10건/s) | 200ms 디바운스 큐, 같은 캐릭터 액션 중첩은 마지막 것만 |
| 탭 inactive | wander/animation tick 일시정지 (`document.visibilitychange`) |
| wander 좌표 룸 밖으로 산출 | clamp 적용 |

---

## 10. 테스트 전략

| 레이어 | 종류 | 도구 | 범위 |
|---|---|---|---|
| 매핑 로직 | unit | Vitest | event-map.ts 입력/출력, weightedRandom 분포 |
| 캐릭터 엔진 | unit + fake timers | Vitest | wander 스케줄, action transition, bubble 만료 |
| events 스트림 | integration | Vitest + mock fs | 더미 events.jsonl push → state 변화 |
| 컴포넌트 | render | React Testing Library | Stage / Character 렌더, sprite class 변화 |
| 시각 회귀 | screenshot (선택) | Playwright | `/characters` 페이지 12 캐릭터 렌더 |

**커버리지 목표 (MVP)**: `event-map.ts`와 `useCharacterEngine.ts` 논리 테스트 우선. 픽셀 비주얼 자체는 시각 검수.

---

## 11. 작업 분해 (구현 plan 미리보기)

writing-plans 단계에서 step별로 더 세분화. 큰 덩어리 6개:

| # | 덩어리 | 산출물 | 추정 |
|---|---|---|---|
| 1 | Character Bible + 데이터 파일 | `data/characters.ts`, `event-map.ts`, `dialogue-pool.json` (240 라인) | ~0.5d |
| 2 | 에셋 파이프라인 | 48 sprite PNG (12 캐릭터 × 4 프레임) | ~1~2d (코드와 병렬) |
| 3 | events 스트림 hook | `useEventsStream.ts` (polling 또는 SSE) | ~0.5d |
| 4 | 캐릭터 엔진 | `useCharacterEngine.ts` + Vitest 단위 테스트 | ~1d |
| 5 | UI 컴포넌트 | `Stage.tsx`, `Character.tsx`, `SpeechBubble.tsx`, sprite CSS | ~1d |
| 6 | `/characters` 페이지 통합 | `app/characters/page.tsx`, navigation 링크, README | ~0.5d |

**합계**: 코드 ~3.5d + 에셋 1~2d (병렬). 한 사람 풀타임 **4~5일**.

---

## 12. ROADMAP 갱신

이 spec 채택 시 `ROADMAP.md` 다음 항목을:

```diff
- [ ] **🎮 동적 캐릭터 시스템 (게임화)** — vibe-coding에 재미 요소
+ [ ] 🚧 **🎮 동적 캐릭터 시스템 (게임화)** — vibe-coding에 재미 요소 (spec: 2026-04-30, 진행중)
```

완료 시 `[x]` + 실제 구현 PR/커밋 해시 추가.

---

## 13. 후속 spec 후보 (이 spec 끝난 뒤)

- **dynamic-dialogue-llm** — 매 이벤트 LLM 호출로 동적 대사 (캐싱 + budget 가드)
- **character-customization** — 사용자가 캐릭터 이름/대사/색 커스터마이즈 (`.vibe-flow-character.json` 스키마)
- **vibe-flow-events-v2** — 의미적 이벤트 emit 추가 (`commit_created`, `pair_started`, `skill_invoked`, `retro_complete`)
- **character-roaming-phaser** — Phaser 도입, 자유 로밍, 픽셀 오피스 시뮬 (Path B 업그레이드)
- **character-leveling** — 사용 카운트 → 레벨/뱃지/Stage별 외형 진화 (C3b/c)
- **pixel-artist-handover** — 정식 픽셀아티스트 의뢰로 에셋 교체 (코드 변경 X)
