---
name: sync-workflow
description: Use when agent files or skills have been added, removed, or modified and you need to check if dev-workflow.md and MEMORY.md skills mapping are still accurate
---

# sync-workflow

## Overview

dev-workflow.md와 MEMORY.md 스킬 매핑 테이블을 에이전트 파일 실제 상태와 비교해 불일치를 감지하고 수동 업데이트를 도와주는 스킬.

## When to Use

- 에이전트 파일을 추가/삭제/수정한 후
- 스킬 연결을 변경한 후
- "워크플로우 문서가 최신인지 확인해줘" 요청 시

## Workflow

### Step 1: 현재 상태 수집

다음을 병렬로 읽는다:

1. `~/.claude/agents/*.md` 전체 — name, model, skills 추출
2. `~/.claude/docs/dev-workflow.md` — 워크플로우 테이블의 에이전트 목록
3. `~/.claude/projects/<프로젝트-슬러그>/memory/MEMORY.md` — 에이전트별 최종 skills 매핑 테이블 (실제 경로는 환경별로 다름. `ls ~/.claude/projects/`로 확인)

### Step 2: 불일치 감지

**dev-workflow.md 점검:**
- 실제 에이전트 파일에 없는 에이전트가 워크플로우에 있는가?
- 새로 추가된 에이전트가 워크플로우에 없는가?
- 에이전트의 역할이 바뀌어 단계 배치가 어색해졌는가?

**MEMORY.md 스킬 매핑 점검:**
- 에이전트 파일의 실제 skills와 MEMORY.md 테이블이 다른가?
- 에이전트가 추가/삭제되었는데 테이블에 반영 안 된 행이 있는가?

### Step 3: 불일치 목록 제시

발견된 불일치를 명확하게 나열한다:

```
[MEMORY.md 스킬 매핑 불일치]
- ux-researcher: 실제(behavioral-science) ≠ 기록(없음)

[dev-workflow.md 불일치]
- brand-strategist: 에이전트 존재하지만 워크플로우에 없음
  → 브랜딩 트랙(1~3단계 병렬)에 추가 권장
```

불일치가 없으면: "모든 문서가 최신 상태입니다." 로 종료.

### Step 4: 변경 적용 (확인 후)

각 불일치에 대해 사용자 확인 후 적용:

- **MEMORY.md 스킬 매핑**: 직접 Edit으로 업데이트
- **dev-workflow.md**: 구체적 수정 내용을 제안하고 확인 받은 후 Edit 적용

## Notes

- dev-workflow.md의 단계 순서/구조는 AI가 임의 변경하지 않는다. 새 에이전트 추가 위치만 제안.
- MEMORY.md 스킬 매핑은 완전 자동 적용 가능 (에이전트 파일이 단일 소스).
- update-skills-mapping.py 스크립트가 있으면 Step 4에서 MEMORY.md 업데이트에 활용.
