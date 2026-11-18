---
name: oauth-only-no-api-key
description: 이 프로젝트는 Claude 호출을 로컬 claude CLI 서브프로세스로만 한다 — ANTHROPIC_API_KEY 도입 제안 금지
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 9506aee2-6ed0-4c18-8d97-c98fc82fa321
  modified: 2026-07-31T23:09:52.108Z
---

repick-cardnews 는 Anthropic 을 SDK 로 직접 호출하지 않는다. `/api/generate` 가 로컬 `claude -p` 를 서브프로세스로 띄우고, 인증은 그 CLI 의 자체 로그인에 맡긴다. 종량제 `ANTHROPIC_API_KEY` 로 전환하거나 병행하자는 제안은 하지 않는다.

**Why:** 2026-07-31 에 `.env.local` 의 OAuth 토큰(`ANTHROPIC_AUTH_TOKEN`)이 사용량 한도에 걸려 Opus·Sonnet 이 모두 429 인데 로컬 CLI 경로는 멀쩡한 것을 실측으로 확인했고, 그 자리에서 API 키 추가를 제안했다가 "OAuth 로컬 방식으로 진행한다고 했잖아" 라고 정정받았다. 이후 SDK 경로를 완전히 제거했다.

**How to apply:** 429 나 인증 이슈가 나오면 해결책을 CLI 범위 안에서만 제시한다 — 같은 계정의 다른 Claude 작업 중단, 또는 사용량 창 리셋 대기. `src/lib/claude-cli.ts` 의 `childEnv` 는 `ANTHROPIC_AUTH_TOKEN`·`ANTHROPIC_API_KEY`·`CLAUDE_CODE_OAUTH_TOKEN` 셋 다 자식 env 에서 지우므로, 셸에 그 변수들이 있어도 자식 CLI 는 자기 로그인을 쓴다. 이 삭제 목록을 줄이면 한도 걸린 토큰이 다시 새고 증상은 조용한 429 로만 나타난다.
