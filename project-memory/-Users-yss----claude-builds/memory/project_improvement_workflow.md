---
name: claude-builds 개선 워크플로우
description: 3단계 개선 프로세스 — 내부감사 → 공식문서 → 커뮤니티 순서로 빌드 강화
type: project
---

claude-builds 개선은 3단계 프로세스로 진행한다:

1. **내부감사** — 코드 품질/보안/일관성 점검 후 P0~P2 수정
2. **엔쓰로픽 공식문서** — 공식 스펙 대비 미적용 기능 식별 후 적용
3. **커뮤니티(깃허브)** — 오픈소스 프로젝트에서 베스트 프랙티스 수집 후 적용

**Why:** 내부 → 외부 순서로 하면 기존 문제를 먼저 정리한 뒤 새 기능을 안정적으로 추가할 수 있다.

**How to apply:** 새 개선 사이클 시작 시 이 순서를 따른다. 각 단계에서 P0/P1/P2/P3로 우선순위를 매기고 순서대로 처리.

### 2026-04-14 기준 완료 상태
- 내부감사: ✅ 완료 (P0~P2 19건 + component-map 분할 + set -u 호환성)
- 공식문서: ✅ 완료 (path rules, agent frontmatter, conditional hooks, auto mode, prompt hooks, 신규 이벤트 3종)
- 커뮤니티: ✅ 완료 (instinct store P1~P3 — pragma, migration, retention, summary, trend, export)
