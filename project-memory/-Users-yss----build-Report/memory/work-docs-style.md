---
name: work-docs-style
description: 회사 업무 자료(엑셀·워드·기안)를 만들 때 적용할 스킬과 문체 규칙
metadata:
  node_type: memory
  type: feedback
  originSessionId: f835126a-fad4-44d4-98e9-9581cde3f8f5
  modified: 2026-11-06T22:37:27.133Z
---

회사 업무 자료는 Anthropic 문서 스킬을 항상 적용하고, AI가 쓴 티가 나지 않게 작성한다.

**Why:** 사용자가 "엔쓰로픽 스킬 적용", "AI 티 안나게 작성해야되는거 알지? 스킬 항상 적용해주고"라고 요청했다 (2026-11-07).
**How to apply:**
- 엑셀은 document-skills:xlsx, 워드는 docx 스킬을 쓴다. 보고·기안 문안은 internal-comms 스킬(general-comms 원칙)을 따른다. internal-comms 파일 위치: ~/.claude/plugins/cache/anthropic-agent-skills/document-skills/*/skills/internal-comms
- 기안은 개조식으로 쓴다(~함/~임). 전자결재 본문에 붙여 넣는 용도라 제목과 결재란은 넣지 않는다. 붙임은 워드 파일로 따로 만든다.
- 엑셀 서식 기준은 SMS 발신번호 「대학 제출 서류 목록」이다: 나눔고딕, 제목 14pt, 머리글 굵게에 아래 검은 선, 내용 줄은 연회색 선, 눈금선 숨김. 조직명은 서비스사업부가 아니라 운영부로 쓴다.
- AI 티 제거는 humanizer-zh 스킬(~/.claude/skills/synced/*/humanizer-zh/SKILL.md, 중국어판 AI 글쓰기 패턴 목록)의 패턴을 한국어 문장에 적용해 점검한다. 줄표(—), 판에 박힌 3개짜리 나열, "~를 통해", 과장된 수식어, 모호한 출처("언론 보도대로" 같은), 굵은 글씨 남용을 피한다.
- 기안 본문은 1쪽 안에 핵심만 쓰고, 자세한 내용은 붙임으로 돌린다.
- 관련: [[reply-in-korean]]
