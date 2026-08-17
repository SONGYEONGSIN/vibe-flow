---
name: claude-agent-sdk-hardening
description: "Claude Agent SDK를 호스팅할 때 실측으로 확인한 함정 4가지 — MCP 상속·도구 화이트리스트·interrupt·fetch 매달림"
metadata:
  node_type: memory
  type: reference
  originSessionId: ec85b534-6819-4191-82d9-815a5d99874c
  modified: 2026-08-17T15:19:34.778Z
---

`@anthropic-ai/claude-agent-sdk`로 에이전트를 직접 호스팅할 때 2026-08-16~17에 **실측으로 확인한** 함정. 전부 추측이 아니라 재현해서 잡았고, 각 항목은 OPS-Console PR로 고쳐져 있다.

**1. `allowedTools` 화이트리스트는 MCP를 가리지 않는다** (가장 위험)
`allowedTools: ["Read","Glob","Grep"]` + `permissionMode: "bypassPermissions"` 상태에서 "내 구글 캘린더 조회해줘" 한 줄에 `mcp__claude_ai_Google_Calendar__list_events`를 호출해 **실제 개인 일정을 읽어냈다.** `ToolSearch`로 알아서 찾아간다.
→ 끊는 법: `strictMcpConfig: true` + `mcpServers: {}`(또는 내 도구만) + `settingSources: []`. 셋 다 필요.

**2. `allowedTools`만으로는 Bash도 안 막힌다**
`bypassPermissions`가 화이트리스트를 무력화한다. `disallowedTools`를 **함께** 줘야 "Bash로 ls 실행하라"는 프롬프트 지시까지 무시한다.

**3. `run.interrupt()`는 도구가 응답 안 준 상태에서 부르면 진단 문자열을 뱉는다**
`Claude Code returned an error result: [ede_diagnostic] result_type=user last_content_type=n/a stop_reason=tool_use`
→ 끝나지 않는 도구로 재현 완료. 같은 상황에 `options.abortController` + `ac.abort()`를 쓰면 `Claude Code process aborted by user`로 깔끔히 끝난다. **상한은 abortController로 걸 것.**

**4. 내 도구 핸들러의 `fetch`에 타임아웃이 없으면 SDK 상한이 무의미**
핸들러가 매달리면 SDK 루프가 도구 결과를 기다리며 멈춰, interrupt/abort 전에 시간이 다 간다. 실제로 962초(16분)를 물고 있었다. `AbortSignal.timeout()`을 모든 fetch에 걸 것.

**부수 실측**:
- **구독(OAuth) 인증이 SDK에서 그대로 된다** — `ANTHROPIC_API_KEY` 없이 동작. SDK가 Claude Code CLI를 구동하므로 그 PC의 로그인 세션을 쓴다
- **스킬은 `cwd/.claude/skills/`에서 로드된다** — 지시를 그대로 따르는 것 확인. 단 스킬은 지시문일 뿐 실행되지 않는다(DB 조회 같은 건 도구여야 함)
- **파일 목록을 프롬프트에 미리 넣어도 안 빨라진다** — 오히려 느려졌다(43.8초, Glob 6회). 모델은 어차피 탐색한다
- 도구 없이 30초, 볼트 읽기 포함 30~45초

**Why:** 이 넷은 문서를 읽어서가 아니라 사고로 알게 됐고, 모르면 같은 코드를 또 짠다. **How to apply:** Agent SDK를 새로 붙일 때 이 4가지를 설정 단계에서 먼저 넣고, "막았다"고 말하기 전에 실제 프롬프트로 뚫어볼 것.

관련: [[assistant-chat-launcher]] · [[knowledge-vault-project]]
