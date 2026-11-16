---
name: b2b-landing
description: This skill should be used when the user requests "B2B 랜딩" or "SaaS 랜딩".
---

# B2B SaaS Landing Page Builder

검증된 전환 최적화 구조 기반 B2B SaaS 랜딩 페이지 생성 스킬.

## Page Structure (10 Sections)

```
1. Header         — 로고 + Trust Badges (인증/수상 뱃지)
2. Hero           — 대형 헤드라인 + 서브헤딩 + CTA 버튼 + 제품 이미지
3. Problem        — Pain Point 3개
4. Solution       — Feature & Benefit 3개
5. Social Proof   — Trusted By 기업 로고 5개+
6. How It Works   — 3단계 프로세스 플로우
7. Product Detail — 제품 이미지 + 핵심 혜택 체크리스트
8. FAQ            — 아코디언 Q&A 3~5개
9. Final CTA      — 마무리 CTA + 안심 문구
10. Footer        — 로고 + 법적 링크
```

## Workflow

### Phase 1: 요구사항 확인

사용자에게 다음 정보를 확인한다 (제공되지 않은 항목만 질문):

| 항목 | 필수 | 예시 |
|------|:----:|------|
| 서비스명 | O | "TeamFlow" |
| 한 줄 설명 | O | "팀 협업 자동화 플랫폼" |
| 타겟 고객 | O | "50인 이상 IT 기업" |
| 핵심 Pain Point 3개 | O | "수동 보고, 정보 분산, 느린 의사결정" |
| 핵심 기능/혜택 3개 | O | "자동 리포트, 통합 대시보드, 실시간 알림" |
| CTA 목표 | O | "무료 체험 시작" / "데모 신청" |
| 브랜드 색상 | - | "#2563EB" |
| 기존 고객/로고 | - | "삼성, LG, 카카오" |

### Phase 2: 페이지 생성

`references/section-guide.md`를 참조하여 각 섹션을 순서대로 구현한다.

**필수 준수 규칙:**
- 시맨틱 HTML (`<header>`, `<main>`, `<section>`, `<footer>`)
- 모바일 퍼스트 반응형
- 라이트/다크 모드 지원
- Pretendard 폰트
- 화이트/블랙 제외 최대 3색
- CSS 변수로 테마 관리
- 모든 이미지에 `alt` 속성
- CTA 버튼 최소 44x44px 터치 타겟
- `prefers-reduced-motion` 존중

**섹션별 구현 순서:**
1. CSS 변수 및 기본 스타일 정의
2. Header → Hero → Problem → Solution 순서
3. Social Proof → How It Works → Product Detail
4. FAQ → Final CTA → Footer
5. 반응형 미디어 쿼리 적용
6. 다크 모드 스타일 적용

### Phase 3: 카피 작성

`references/copy-patterns.md`를 참조하여 한국어 카피를 작성한다.

**카피 규칙:**
- 헤드라인/CTA: 비격식체 (해요/하기)
- 본문 설명: 격식체 (합니다)
- 숫자는 아라비아 숫자 ("3단계", "40% 절약")
- 모호한 표현 금지 ("혁신적인", "강력한" → 구체적 수치로)

### Phase 4: 검증

| 검증 항목 | 기준 |
|-----------|------|
| 섹션 순서 | 10개 섹션 모두 존재, 올바른 순서 |
| 시맨틱 HTML | div 남용 없음, 적절한 태그 사용 |
| 반응형 | 모바일/태블릿/데스크탑 대응 |
| 접근성 | alt, label, outline, 대비율 4.5:1+ |
| CTA | 페이지 내 최소 2회 (Hero + Final) |
| 다크 모드 | 정상 작동 |
| 성능 | 불필요한 JS 없음, CSS로 해결 가능한 것은 CSS |

## Anti-patterns

| 안티패턴 | 문제 | 해결 |
|----------|------|------|
| Hero에 입력 폼 배치 | B2C 느낌, 진입 장벽 | CTA 버튼만 배치 |
| 가격표 섹션 노출 | B2B는 커스텀 가격 | "문의하기" 또는 "데모 신청" |
| 보라색 그라데이션 | AI slop | 브랜드 단색 기반 |
| 이모지 남발 | 비전문적 | 텍스트 또는 커스텀 아이콘 |
| 기능 나열만 | 고객 관심 없음 | 기능 → 혜택으로 변환 |
| 모호한 헤드라인 | 전환율 하락 | 구체적 수치 + 결과 제시 |
| CTA 1회만 | 이탈 증가 | Hero + Final 최소 2회 |

## Troubleshooting

### Hero 섹션이 밋밋함
- **원인:** 헤드라인이 기능 설명에 그침
- **해결:** 고객의 결과/변화를 강조 ("보고서 자동화" → "매주 8시간을 돌려받으세요")

### CTA 클릭률 낮음
- **원인:** CTA 문구가 모호하거나, 안심 요소 부족
- **해결:** 구체적 행동 + 안심 문구 조합 ("14일 무료 체험 시작하기" + "카드 등록 없이")

### Pain Point가 공감이 안 됨
- **원인:** 기업 관점이 아닌 개발자 관점으로 작성
- **해결:** 의사결정자(CTO, PM)의 언어로 작성. 비용, 시간, 리스크 중심

### 다크 모드에서 가독성 문제
- **원인:** 라이트 모드 색상을 그대로 사용
- **해결:** CSS 변수를 `prefers-color-scheme: dark`에서 재정의

### FAQ가 형식적
- **원인:** 실제 고객 질문이 아닌 마케팅 문구
- **해결:** "가격은?", "기존 도구와 연동?", "데이터 보안?" 등 실제 구매 장벽 질문

## References

- `references/section-guide.md` — 10개 섹션별 상세 구현 가이드 (HTML 구조, 스타일, 콘텐츠 전략)
- `references/copy-patterns.md` — B2B SaaS 한국어 카피 패턴 (헤드라인, CTA, Pain Point 공식)
- `references/examples.md` — Before/After 예시 3개 (나쁜 랜딩 vs 좋은 랜딩)
- `~/.claude/skills/design-master/references/persuasion-conversion.md` — 행동경제학, 설득 심리학, 프라이싱 전략. **카피 완성 후 섹션 7 전환 체크리스트 필수 점검**
