# 정본 DESIGN.md 포맷 (P1 병합 산출물)

> 상단 YAML 프론트매터(머신리더블 토큰) + 9개 산문 섹션.
> `why(입력 DESIGN.md)` + `what(사이트 HTML 추출)` 병합 결과를 이 형태로 emit.
> 출처: VoltAgent/awesome-design-md (Google Stitch 9섹션 표준).

## YAML 프론트매터 (머신리더블 토큰)

```yaml
---
colors:
  primary: "#hex"        # 시맨틱명 + hex
  background: "#hex"
  foreground: "#hex"
typography:
  heading: { fontFamily: "...", size: "...", weight: "...", lineHeight: "...", letterSpacing: "..." }
  body:    { fontFamily: "...", size: "...", weight: "...", lineHeight: "...", letterSpacing: "..." }
rounded:
  card: "..."
  button: "..."
  badge: "..."
---
```

- `colors`는 `design-tokens.ts`의 우선 소스가 된다 (`rules/design.md` §DESIGN.md 연동).
- 라이트/다크 분리 시 `colors.light` / `colors.dark` 두 세트로 확장한다.

## 1. Visual Theme & Atmosphere

전체 무드/분위기를 1~2문단 산문으로. (예: "차분한 에디토리얼, 여백 중심")

## 2. Color Palette & Roles

각 색을 `시맨틱명 + hex + 기능적 역할`로 표기. 예: "Deep Teal-Navy (#294056) — primary actions".

## 3. Typography Rules

폰트 페어링 + 위계 표 (display/heading/body/caption의 size·weight·lineHeight·letterSpacing).

## 4. Component Stylings

버튼/카드/입력 등 핵심 컴포넌트의 스타일 + 상태(hover/focus/active/disabled).

## 5. Layout Principles

스페이싱 스케일, 그리드, 컨테이너 max-width, 섹션 리듬.

## 6. Depth & Elevation

그림자/서피스 위계. 배경 색조에 맞춘 shadow 틴트 규칙.

## 7. Do's and Don'ts

프로젝트 고유 체크리스트. anti-slop 기본값 위에 브랜드 특수 규칙을 추가한다.

## 8. Responsive Behavior

브레이크포인트(sm/md/lg/xl/2xl), 터치 타겟 최소 44px, 모바일 collapse 규칙.

## 9. Agent Prompt Guide

빠른 색상 레퍼런스 + P3 구현에 바로 넣을 수 있는 준비된 프롬프트 문구.
