---
name: start-docs
description: This skill should be used when starting a new project to generate all planning documents at once. Use when the user requests "프로젝트 시작", "기획 문서", "start-docs", "문서 생성", or wants to create PRD, TRD, ERD, and other planning documents.
---

# Start Docs

프로젝트 기획에 필요한 7가지 핵심 문서를 순차적으로 생성하는 워크플로우 스킬.

## 생성 문서 목록

| 순서 | 문서 | 설명 |
|------|------|------|
| 1 | PRD | 제품 요구사항 문서 |
| 2 | 사용자 여정 | 페르소나와 사용자 시나리오 |
| 3 | IA | 정보 구조 (사이트맵, 네비게이션) |
| 4 | ERD | 엔티티 관계도 및 DB 스키마 |
| 5 | TRD | 기술 요구사항 문서 |
| 6 | 디자인 가이드 | 컬러, 타이포, 컴포넌트 |
| 7 | 코드 가이드라인 | 네이밍, 폴더 구조, 코딩 스타일 |

## 워크플로우

### Phase 1: 프로젝트 이해
1. 프로젝트 개요와 목표 확인
2. 타겟 사용자 정의
3. 핵심 기능 파악

### Phase 2: 문서 생성
각 문서는 `references/` 폴더의 템플릿을 참조하여 작성.

#### Step 1: PRD 작성
`references/prd-template.md` 참조
- 제품 개요 및 목표
- 기능 요구사항
- 성공 지표

#### Step 2: 사용자 여정 작성
`references/user-journey-template.md` 참조
- 페르소나 정의
- 주요 시나리오
- 터치포인트 및 감정곡선

#### Step 3: IA 작성
`references/ia-template.md` 참조
- 사이트맵
- 네비게이션 구조
- 콘텐츠 계층

#### Step 4: ERD 작성
`references/erd-template.md` 참조
- 엔티티 정의
- 관계 다이어그램
- 테이블 스키마

#### Step 5: TRD 작성
`references/trd-template.md` 참조
`references/design-principles.md` 참조

**⚠️ 필수: 기술 스택 버전 최신화 (context7 사용)**
템플릿의 버전은 플레이스홀더이다. TRD 작성 전 반드시 **context7 MCP 도구**를 사용하여 각 기술의 **최신 안정(stable) 버전**과 공식 문서를 조회한 후 기입한다.

검색 대상 (최소):
- 프레임워크: Next.js, React, TypeScript
- 스타일링: Tailwind CSS
- 상태관리: Zustand, TanStack Query
- 검증: Zod
- UI: shadcn/ui
- 차트: Recharts
- 폼: React Hook Form
- 테스트: Vitest, Playwright
- 패키지매니저: pnpm
- 린팅: ESLint

메이저 버전 변경이 있으면(예: Next.js 15→16, Zod 3→4) **breaking changes**도 함께 조사하여 TRD에 별도 섹션으로 기술한다.

- 기술 스택 (최신 안정 버전)
- 시스템 아키텍처
- 설계 원칙 검토 (SOLID + Repository/Factory/Strategy)
- API 설계
- 주요 프레임워크 변경사항 (breaking changes)

#### Step 6: 디자인 가이드 작성
`references/design-guide.md` 참조

**⚠️ 필수: design-master 스킬 참조**
기본 템플릿 외에 아래 5개 design-master 참조 파일을 반드시 읽고 해당 내용을 디자인 가이드에 반영한다:

| 참조 파일 | 반영 내용 |
|-----------|----------|
| `~/.claude/skills/design-master/references/ux-psychology.md` | UX 심리학 8법칙 (힉스, 피츠, 게슈탈트, 제이콥, 밀러, 도허티, 폰 레스토프, Norman 감정 디자인) — 프로젝트별 적용 방안 |
| `~/.claude/skills/design-master/references/ux-guidelines.md` | CRO 전략, 다크패턴 방지 체크리스트, 컴포넌트별 DO/DON'T |
| `~/.claude/skills/design-master/references/design-system.md` | 디자인 토큰 체계 (Primitive→Semantic), 컴포넌트 계층 (Primitive→Composite→Pattern), cva 패턴, Tailwind v4 @theme |
| `~/.claude/skills/design-master/references/modern-patterns.md` | Framer Motion 레시피, 모바일 UX (Thumb Zone, Bottom Sheet, 폼 최적화), 모던 시각 패턴 (Bento Grid, 대형 타이포, CSS View Transitions) |
| `~/.claude/skills/design-master/references/persuasion-conversion.md` | 랜딩/상세페이지 프로젝트 시 — 행동경제학 프라이싱, Cialdini 6원칙, 12-섹션 설득 구조, CTA 전략, 한국 시장 특화 |

- 컬러 시스템 + 60-30-10 규칙
- 타이포그래피
- 디자인 토큰 체계
- 컴포넌트 계층 구조
- 컴포넌트 상태 스펙
- UX 심리학 법칙 적용
- 마이크로인터랙션 (Framer Motion)
- 모바일 UX 패턴
- 모던 시각 패턴
- 접근성

#### Step 7: 코드 가이드라인 작성
`references/code-guidelines.md` 참조
- 네이밍 규칙
- 폴더 구조
- 코딩 스타일

### Phase 3: 리뷰
- 문서 간 일관성 확인
- 누락된 요소 점검
- 최종 검토

## 출력 형식

모든 문서는 `docs/` 폴더에 마크다운 형식으로 저장:

```
docs/
├── PRD.md
├── USER-JOURNEY.md
├── IA.md
├── ERD.md
├── TRD.md
├── DESIGN-GUIDE.md
└── CODE-GUIDELINES.md
```

## 사용 예시

```
사용자: /start-docs
Claude: 프로젝트에 대해 알려주세요. 어떤 서비스를 만드시나요?
사용자: 반려동물 건강관리 앱을 만들려고 해요
Claude: [7가지 문서를 순차적으로 생성...]
```

---

## Troubleshooting

| 문제 | 원인 | 해결 |
|------|------|------|
| 문서가 너무 추상적 | 프로젝트 정보 부족 | 사용자에게 추가 질문 |
| ERD가 프로젝트와 안 맞음 | DB 요구사항 불명확 | 핵심 엔티티 3-5개 먼저 확인 |
| TRD 기술 스택 부적절 | 팀 역량/상황 미고려 | 팀 규모, 경험 먼저 파악 |
| 문서 간 불일치 | 순차 생성 중 변경 | PRD 확정 후 나머지 생성 |
| 문서가 너무 길음 | 모든 섹션 상세 작성 | MVP 범위로 축소 |
| 디자인 가이드 적용 어려움 | 추상적 원칙만 기술 | 구체적 Tailwind 클래스 포함 |

## Anti-patterns

| 패턴 | 문제 | 대안 |
|------|------|------|
| 문서 없이 코딩 시작 | 방향 없는 구현, 재작업 | 최소 PRD + ERD 먼저 |
| 문서 과잉 (100페이지+) | 읽지 않는 문서 | MVP 범위, 핵심만 |
| 문서 1회 작성 후 방치 | 구현과 괴리 | 스프린트마다 갱신 |
| 모든 문서 동시 생성 | 기반 문서 없이 상세 문서 | PRD → TRD → ERD 순서 |
| 템플릿 그대로 사용 | 프로젝트 특성 미반영 | references 기반 커스터마이징 |

## References

| 문서 | 경로 | 내용 |
|------|------|------|
| PRD 템플릿 | `references/prd-template.md` | 제품 요구사항 문서 구조 |
| TRD 템플릿 | `references/trd-template.md` | 기술 설계 문서 구조 |
| ERD 템플릿 | `references/erd-template.md` | DB 설계 문서 구조 |
| 디자인 가이드 | `references/design-guide.md` | UI/UX 디자인 시스템 |
| IA 템플릿 | `references/ia-template.md` | 정보 아키텍처 구조 |
| 코드 가이드 | `references/code-guidelines.md` | 코딩 컨벤션, 스타일 가이드 |
| 디자인 원칙 | `references/design-principles.md` | 핵심 디자인 원칙 |
| 유저 여정 | `references/user-journey-template.md` | 사용자 여정 맵 |
