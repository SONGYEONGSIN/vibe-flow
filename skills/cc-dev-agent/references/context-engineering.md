# Context Engineering 심화

## 개념 정의

**Context**: LLM에서 샘플링할 때 포함되는 토큰 세트

**Context Engineering**: "어떤 컨텍스트 구성이 모델의 원하는 행동을 생성할 가능성이 가장 높은가?"에 답하는 것

---

## Context Window

### 모델별 크기 (2026년 기준)

| 모델 | 컨텍스트 윈도우 |
|------|-----------------|
| Claude 4.5 Opus | 200K 토큰 |
| Claude 4.5 Sonnet | 200K 토큰 |

### 효과적 윈도우

**중요**: 길이만 중요한 게 아님. **효과적 윈도우는 약 50-60%**.

대화 중간에 복잡한 작업을 시작하지 말 것. `/compact` 또는 새 대화 시작.

---

## Context Rot / Degradation

### 원인

- Attention mechanism의 pairwise relationships 모델링 한계
- 새 토큰 도입 시 검색 성능 저하
- 제한된 "attention budget"

### 증상

- 이전 지시 망각
- 중간 내용 누락 (Lost in the Middle)
- 일관성 없는 응답

### 대응 전략

1. **가장 관련 있는 컨텍스트만** plug
2. **무관한 컨텍스트** 줄이기
3. **적고 충돌하지 않는 지시** 유지
4. **reminders**로 목표 반복 주입

---

## 도구 호출과 토큰

### 토큰 누적 예시

```
Context window:
├─ User: "Make a landing page for my coffee shop"
│
├─ Assistant: [tool_call: web_search(...)]
├─ Tool result: [10 results]                    ← ~1.5K tokens
│
├─ Assistant: [tool_call: read_file("brand.pdf")]
├─ Tool result: [extracted text]                ← ~4K tokens
│
├─ Assistant: [tool_call: create_file("page.html")]
├─ Tool result: [success]                       ← ~50 tokens
│
└─ Total: ~6K+ tokens for one task
```

**핵심**: 도구 호출 + 결과 모두 컨텍스트에 추가됨 (LLM은 stateless)

---

## System Reminders

### todo.md 패턴 (Manus 방식)

**목적**: Attention 조작을 통한 goal misalignment 방지

**방법**:
1. 복잡한 작업 시 todo.md 생성
2. 단계별로 업데이트 및 체크
3. 목표를 컨텍스트 끝에 반복

**효과**: Lost-in-the-middle 문제 회피

### Claude Code의 System Reminders

```xml
<system-reminder>
As you answer the user's questions, you can use the following context:
# claudeMd
Codebase and user instructions are shown below...
</system-reminder>
```

도구 결과와 사용자 메시지에 자동 주입됨.

---

## MCP와 Context Bloat

### 문제

- 도구 정의가 컨텍스트 윈도우 과부하
- 중간 도구 결과가 추가 토큰 소비
- 더 많은 MCP 서버 = 더 많은 bloating

### 해결책: Code Execution MCP

직접 도구 호출 대신:
1. 코드 API 노출
2. 샌드박스 실행 환경 제공
3. 도구 호출을 코드로 작성

---

## 컨텍스트 관리 실전

### /context로 모니터링

복잡한 작업 중 수시로 체크. **60% 도달 시 조치**.

### /compact 사용

```
/compact 이전에 결정한 변수 규칙과 API 설계는 기억해줘
```

핵심 기억 유지하며 압축.

### /clear 사용

- 새 Task 시작
- 에러 루프 탈출
- 컨텍스트 오염 해결

### Handoff 패턴

세션 종료 전 현재 상태 정리:
1. 완료된 작업
2. 진행 중인 작업
3. 다음 해야 할 것
4. 주의사항

---

## 베스트 프랙티스

### DO

- 관련 파일을 모델이 직접 읽게 하기
- 정기적으로 /context 체크
- 60% 도달 시 /compact 또는 /clear
- todo.md로 목표 반복

### DON'T

- 대화 중간에 복잡한 작업 시작
- 불필요한 파일 컨텍스트에 포함
- 충돌하는 지시 여러 개 제공
- MCP 서버 과다 연결
