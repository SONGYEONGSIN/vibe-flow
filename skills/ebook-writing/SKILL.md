---
name: ebook-writing
description: Use when writing, drafting, or reviewing ebook chapters, sections, or full manuscripts. Triggers on "전자책 써줘", "챕터 작성", "집필", "ebook writing", "전자책 집필", "원고 작성", "전자책 리뷰", "집필 리뷰".
---

# Ebook Writing

범용 전자책 집필 스킬. 변화 설계 → 구조 설계 → 챕터 집필 → 진단의 Phase 기반 워크플로우.

## 경계 규칙

이 스킬은 **전자책 콘텐츠 자체의 설계와 집필**을 담당한다.

| 필요한 것 | 참조 스킬 |
|----------|----------|
| 판매 페이지 카피 | `digital-product-copy` |
| 리드마그넷 퍼널/채널 설계 | `growth-marketing` |
| 웹 카피 (랜딩, 홈페이지) | `copywriting` |
| 브랜드 전략/포지셔닝 | `branding` |

---

## Phase 0: 컨텍스트 수집 (BLOCKING)

**이 단계를 완료하기 전까지 구조 설계나 집필을 시작하지 않는다.**

| # | 항목 | 질문 | 필수 |
|---|------|------|:----:|
| 1 | 유형 | 무료(리드마그넷) / 유료? | O |
| 2 | 타겟 | 누가 읽나? (직업, 경험 수준, 상황) | O |
| 3 | 현재 상태 | 독자가 지금 겪는 고통/막막함 (3층: 외부/내부/철학) | O |
| 4 | 도착 상태 | 읽은 후 구체적으로 뭐가 달라지나 | O |
| 5 | 정체성 변형 | [현재 정체성] → [변화된 정체성] 한 문장 | O |
| 6 | 주제 | 무엇에 대한 전자책인가 | O |
| 7 | 포맷 | 노션/PDF/웹 | 권장 |
| 8 | 분량 목표 | 대략적 챕터 수 또는 단어 수 | 권장 |

### 컨텍스트 파일 우선 확인
`docs/ebook/{slug}/outline.md`가 이미 존재하면 읽고, Phase 1로 건너뛴다.

### "주제 ≠ 변화" 체크 (CRITICAL)
- "바이브코딩에 대한 전자책" → 주제만 있음 (X)
- "비개발자가 2주 만에 웹앱을 만들 수 있게 되는 전자책" → 변화 있음 (O)

Phase 0 완료 후 `references/transformation-arc.md`의 BAB 워크시트를 작성한다.

---

## Phase 1: 변화 아크 + 구조 설계

### 1-1. 변화 아크 설계

`references/transformation-arc.md` 참조.

1. 독자의 Before State (3층 분석: 외부/내부/철학)
2. 독자의 After State (열망적 정체성)
3. Bridge (저자의 해결 체계)
4. 5대 전환점 배치 (촉매제 → 목표 → 미드포인트 → 어두운 밤 → 클라이맥스)
5. 감정 장부 초안 작성

### 1-2. 구조 패턴 선택

`references/structure-patterns.md`의 패턴 선택 의사결정 트리 참조.

| 패턴 | 적합 상황 |
|------|----------|
| 문제-해결 6단계 | 독자의 구체적 고통 해결 (가장 범용적) |
| 프로세스 (How-To) | 특정 기술/과정 교육 |
| 원칙/주제별 | 여러 원칙을 병렬 전달 |
| 스토리/경험 | 저자 여정이 핵심 가치 |
| 큐레이션 | 리소스/도구 모음 (무료 리드마그넷에 적합) |

### 1-3. 무료/유료 캘리브레이션

`references/free-vs-paid.md` 참조.

- 무료: What 중심, Micro-Win, 15분 내 가치 체감, 의도적 간극
- 유료: How 전체 공개, Paradigm Shift, 완전한 변화 아크

### 1-4. 목차 확정 + 저장

목차를 `docs/ebook/{slug}/outline.md`에 저장. 포맷:

```
# {전자책 제목}

## 변화 스토리보드
- Before: {현재 상태}
- After: {변화 후 상태}
- 정체성: {From} → {To}
- Bridge: {해결 체계}

## 목차
Ch.1: {제목}
  훅: {장치}
  핵심: {주장 2~3개}
  감정 장부: {시작} → {종료}

Ch.2: ...
```

### 1-5. 목차 검증

- [ ] 각 챕터가 미니 Before-After-Bridge인가?
- [ ] 감정 장부에서 시작=종료인 챕터가 없는가?
- [ ] 최소 1개 Switch 챕터가 있는가? (Dial만 있으면 정보 모음집)
- [ ] 챕터 수와 분량이 무료/유료 가이드라인에 맞는가?
- [ ] 목차 안티패턴(MECE 위반, 과도한 세분화, 위계 역전)이 없는가?

사용자에게 목차를 제시하고 확인받은 후 Phase 2로 진행.

---

## Phase 2: 챕터 루프

`outline.md`에서 해당 챕터 목표를 확인하고, 한 챕터씩 집필한다.

### 2-1. 챕터 템플릿 선택

`references/chapter-writing.md` 참조. 챕터 성격에 맞는 템플릿 선택:

| 유형 | 템플릿 | 적합 |
|------|--------|------|
| 교육형 | Gagné 9 Events | 튜토리얼, 단계별 학습 |
| 프레임워크형 | 4MAT (Why→What→How→What If) | 원칙/방법론 전달 |
| 스토리형 | Scene→Tension→Insight→Application | 경험/사례 기반 |
| 범용 | Fat Outline (Hook→주장→사례→실천→전환) | 대부분의 논픽션 |

한 전자책 안에서 챕터마다 다른 템플릿을 쓸 수 있다.

### 2-2. 집필

`references/chapter-writing.md`의 독자 유지 장치(Slippery Slide, Open Loop, Curiosity Gap) 참조.
`references/korean-writing.md`의 한국어 가독성 기준 적용.

### 2-3. 챕터 단위 진단

`references/chapter-writing.md`의 자가 점검 5종 적용:

1. **깨달음 점검**: Lie→Truth, 결정적 사례/비유, What vs How
2. **감정 장부 점검**: 시작 감정 ≠ 종료 감정
3. **가독성 점검**: 문장/문단/챕터 분량
4. **내용 점검**: One Idea, Show Don't Tell, So What, Curse of Knowledge
5. **Slop 방지**: 뻔한 서론, 과도한 격려, 반복 요약

### 2-4. 저장 + 다음 챕터

챕터를 `docs/ebook/{slug}/chapter-{N}.md`에 저장하고 다음 챕터로.

---

## Phase 3: 전체 진단 + 라우팅

### 3-1. 전체 흐름 진단

- [ ] **변화 아크 완성도**: Before → After 여정이 실제로 완성되는가?
- [ ] **감정 장부 전체**: 챕터 간 감정 흐름이 자연스러운가?
- [ ] **난이도 곡선**: 점진적으로 어려워지는가, 갑자기 뛰는 곳은 없는가?
- [ ] **중복/누락**: 같은 내용을 반복하는 챕터, 빠진 단계가 없는가?
- [ ] **5대 전환점**: 촉매제/목표/미드포인트/어두운 밤/클라이맥스가 배치되었는가?
- [ ] **Action/Reaction 리듬**: 새 개념 → 적용/성찰이 교대하는가?

### 3-2. 완독률 체크

`references/completion-strategies.md` 참조.

- [ ] 처음 2개 챕터에서 빠른 성공 체험이 있는가?
- [ ] 챕터당 2,000단어를 넘지 않는가?
- [ ] 진행률을 시각적으로 확인할 수 있는가?
- [ ] 챕터 끝마다 다음 챕터로 이어지는 장치가 있는가?

### 3-3. 포맷 적용

`references/notion-format.md` 참조 (노션인 경우).

### 3-4. 라우팅

| 다음 단계 | 참조 스킬 |
|----------|----------|
| 판매 페이지 작성 | `digital-product-copy` |
| 리드마그넷 퍼널 설계 | `growth-marketing` |
| 런칭 카피 | `copywriting` |

---

## 금지 사항

1. **Phase 0 스킵 금지**: 컨텍스트 수집 없이 집필하지 않는다
2. **"주제"로 시작 금지**: 반드시 "변화"를 정의한 후 시작
3. **막연한 형용사 금지**: "쉬운", "효과적인" 단독 사용 금지. 장면/숫자로 구체화
4. **정보 나열 금지**: 모든 챕터는 독자의 상태를 변화시켜야 함 (감정 장부 체크)
5. **How 누락 금지**: 주장만 있고 실행 단계가 없으면 안 됨
6. **진단 스킵 금지**: Phase 2 챕터 진단, Phase 3 전체 진단 모두 필수

---

## References

| 파일 | 역할 | Phase |
|------|------|-------|
| `references/transformation-arc.md` | 변화 설계, 백워드 디자인, 시퀀스 변환, 워크시트 | 0~1 |
| `references/structure-patterns.md` | 목차 아키텍처 패턴, 분량 가이드, 패턴 선택 트리 | 1 |
| `references/free-vs-paid.md` | 무료/유료 캘리브레이션, 의도적 간극 설계 | 0~1 |
| `references/chapter-writing.md` | 챕터 템플릿 4종, 깨달음 설계, 독자 유지, 자가 점검 | 2 |
| `references/completion-strategies.md` | 완독률 방어 전략, 이탈 데이터 | 2~3 |
| `references/korean-writing.md` | 한국어 가독성 기준, Slop 금지 목록 | 2 |
| `references/notion-format.md` | 노션 포맷 가이드 (콜아웃/토글/임베드/체크리스트) | 3 |
