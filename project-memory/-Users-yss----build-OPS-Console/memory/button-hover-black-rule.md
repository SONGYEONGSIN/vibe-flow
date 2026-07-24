---
name: button-hover-black-rule
description: OPS-Console 기본 디자인 규칙 — 버튼 호버 시 배경 검정(ink) + cream 글씨
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 67837481-9935-4c11-8e14-c848da1e6782
---

OPS-Console에서 **버튼 호버 시 배경을 검정색으로** 하는 것은 기본 디자인 규칙이다. Tailwind 토큰으로 `hover:bg-ink hover:text-cream` (보더 있는 버튼은 `hover:border-ink`도 함께). 하드코딩 hex 금지(디자인 린트).

**Why:** 에디토리얼 톤 UI에서 호버 어포던스를 강한 대비(검정 배경/밝은 글씨)로 통일하기 위함. 사용자가 명시적으로 "기본 디자인 규칙"이라고 지정함 (2026-06-14, 실시간 현황 우선순위 피드 페이저 이전/다음 버튼 작업 중).

**How to apply:** 새 버튼/페이저/칩 등 인터랙티브 요소를 만들 때 호버 스타일은 `hover:bg-washi-raised` 같은 약한 톤 대신 `hover:bg-ink hover:text-cream`를 기본으로 적용. 기존에 약한 호버로 된 버튼도 이 규칙으로 통일 가능.
