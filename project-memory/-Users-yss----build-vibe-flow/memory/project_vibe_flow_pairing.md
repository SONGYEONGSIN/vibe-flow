---
name: vibe-flow ↔ vibe-flow-dashboard paired repo
description: vibe-flow는 hook/skill 메이커, vibe-flow-dashboard는 events.jsonl 시각화 UI — 두 repo가 짝으로 동작
type: project
originSessionId: 7779691f-257c-4310-930b-eb2ae234e397
---
`/Users/yss/개발/build/vibe-flow` (hook/skill 본체) 와 `/Users/yss/개발/build/vibe-flow-dashboard` (Next.js `/characters` 시각화) 는 짝으로 운영된다.

데이터 플로우:
- vibe-flow의 hook (예: `core/hooks/skill-tracker.sh`)이 사용자 Claude Code 프로젝트의 `.claude/events.jsonl`에 이벤트 push
- vibe-flow-dashboard가 events.jsonl을 tail/stream해서 12 에이전트 픽셀 캐릭터 반응 트리거
- 매핑은 `src/app/characters/data/event-map.ts` (`SKILL_TO_AGENT` + `mapEvent`)
- 대사 풀: `src/app/characters/data/dialogue-pool.json` (캐릭터 × 컨텍스트 키 × 대사 배열)

**Why:** 한 기능이 보통 두 repo 모두 변경 필요 (hook 추가 → dashboard 매핑 추가). PR도 짝으로 생성됨 (예: vibe-flow#17 ↔ dashboard#6).

**How to apply:**
- vibe-flow에서 새 hook 또는 이벤트 타입 추가 시, dashboard의 `event-map.ts` + `dialogue-pool.json`도 같이 업데이트해야 풀 사이클 동작
- PR 본문에 짝 PR 링크 (`SONGYEONGSIN/vibe-flow#N` 형식) 명시
- 검증은 vibe-flow side는 격리 임시 git repo + stdin, dashboard side는 `npm test` (vitest 37+ 케이스, event-map.test.ts에 시나리오 포함)
