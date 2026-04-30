# vibe-flow Onboarding

vibe coder를 위한 단계별 가이드.

## 단계 0 — 설치 (5분)

```bash
git clone https://github.com/SONGYEONGSIN/vibe-flow.git ~/dev/vibe-flow
cd /your/project
bash ~/dev/vibe-flow/setup.sh
```

→ Core 14 스킬 + 22 훅 + 10 에이전트 + 6 규칙 활성. extensions는 나중에 필요할 때.

검증:
```bash
bash .claude/validate.sh
```

## 단계 1 — 첫 코드 한 사이클 (30분)

목표: 작은 기능 하나를 brainstorm부터 finish까지.

```bash
# Claude Code 시작
claude

# 1. 의도 탐색 (3분)
> /brainstorm "유저 프로필 페이지에 아바타 업로드"

# 결과: .claude/memory/brainstorms/<file>.md 생성됨
# 내용: 의도 4문항 + 대안 2-3개 + 추천

# 2. 코드 작성 (10분)
> 위 brainstorm 결과대로 구현해줘

# Claude가 code 작성. 자동으로:
#   - prettier 포맷
#   - eslint 자동 수정
#   - tsc 타입 체크
#   - 관련 test 실행
#   - design-lint 하드코딩 색상 검사

# 3. 검증 (5분)
> /verify

# lint + tsc + test + e2e 순차 실행. PASS여야 다음.

# 4. 커밋 (1분)
> /commit

# Conventional commit 메시지 자동 생성. 사용자 확인 후 커밋.

# 5. 마무리 결정 (2분)
> /finish

# 변경 규모 / verify 상태 / branch 자동 점검
# → PR / Direct push / Cleanup 경로 자동 추천
```

**5분짜리 하루 사이클**: brainstorm → code → verify → commit → finish.

## 단계 2 — 첫 프로젝트 (3일)

추가로 활용:

```bash
> /plan "큰 기능 — 결제 통합"
# 멀티스텝 계획을 .claude/plans/<file>.md로 추적
# 단계별 진행 상태 (pending → in_progress → done)

> /test src/payment.ts
# Vitest 단위 테스트 자동 생성

> /security
# OWASP 스캔
```

자동 강제:
- TDD strict 기본 — 테스트 없이 .ts 코드 수정 시 차단
- 위험 명령 27 패턴 차단 (rm -rf /, force push 등)
- 디자인 토큰 강제 (하드코딩 색상 감지)

## 단계 3 — 협업 (1주)

```bash
> /worktree create feat/dashboard
# 격리된 git worktree 생성, 병렬 작업 가능

> /review-pr 42
# GitHub PR #42 코드 리뷰

> /receive-review pr 42
# 받은 리뷰 항목별 분류 + 증거 기반 accept/reject/clarify
```

`design-lint` hook이 자동으로:
- 하드코딩 색상 (oklch 포함) 경고
- 인접 주석 false positive 처리

## 단계 4 — Extensions 활성화 (1개월~)

데이터가 누적되고 익숙해지면:

```bash
bash ~/dev/vibe-flow/setup.sh --list-extensions
# 5 카테고리 보고

# 가장 흔한 추가:
bash ~/dev/vibe-flow/setup.sh --extensions learning-loop
# /metrics, /retrospective 활성

# 회고 정기화
> /retrospective
# 메트릭+세션로그+events 분석 → P0/P1/P2 개선안

# 메이커 도구 (스킬 자체 진화)
bash ~/dev/vibe-flow/setup.sh --extensions meta-quality
> /eval brainstorm    # 정량 측정
> /evolve brainstorm  # 자동 개선 후보 (5 게이트 + A/B)
```

## 흔한 함정

### "스킬 23개 다 외워야 하나?"

**No.** Core 14만 익히고 시작. extensions는 필요할 때.

```
첫주: brainstorm/commit/verify/finish/status/learn 만으로 충분
```

### "TDD strict가 너무 빡빡"

```bash
# 일시적 완화 (특정 세션)
export CLAUDE_TDD_ENFORCE=warn

# 영구 완화 (해당 프로젝트만)
# .claude/settings.local.json의 env에 추가
```

### "에이전트 12개 헷갈림"

평소엔 명시 호출 안 함. /pair, /discuss, /retrospective 등이 내부적으로 호출.
직접 부르고 싶으면: `@developer 인증 로직 구현해줘`

### "설계 안 하고 그냥 만들고 싶어"

작은 변경(3 파일 미만)은 brainstorm 스킵 가능. 큰 변경은 강제 권고. 그래도 무시하면 결국 retrospective에서 "brainstorm 스킵 후 회귀" 패턴 잡힘.

### "메모리가 너무 많아져"

```bash
> /learn show
# 어떤 패턴이 누적됐는지 확인

# 불필요한 항목 직접 .claude/memory/patterns.md에서 삭제
```

## FAQ

### Q. 글로벌에 설치하면 모든 프로젝트에 적용?

`~/.claude/skills`/`agents`/`rules`로 심볼릭 링크하면 글로벌 활성.
hook 자동화는 프로젝트별 setup.sh로만 활성 (settings.local.json 필요).

### Q. 다른 사람과 메모리 공유?

`.claude/memory/` 는 git 추적 (default). 팀원이 clone하면 자동 공유.
민감하면 `.gitignore`에 추가.

### Q. 다른 IDE에서 사용?

Claude Code 전용. 다른 IDE 통합 계획 미정.

### Q. AI cost는?

Hooks는 LLM 호출 안 함 (단순 shell script). 비용은 사용자가 호출하는 스킬 LLM 비용만.
무거운 스킬: /pair, /discuss, /evolve, /design-sync.
