# Anti-Slop Pre-Flight (P4)

> 전부 이진 pass/fail 기계 단언. `scripts/anti-slop-check.js`가 실행한다.
> **브랜드 우선 원칙**: DESIGN.md에 명시된 폰트/색은 아래 금지 규칙을 무효화한다.

## 실행

```bash
# 스킬 실행 CWD는 프로젝트 루트 → 루트 기준 풀 경로로 호출
node extensions/design-system/skills/frontend-flow/scripts/anti-slop-check.js <src 디렉토리|파일> [정본 DESIGN.md 경로]
```

- stdout에 JSON `{target, checks:[{id,status,detail}], passed, failed}`
- 전부 통과 exit 0, 하나라도 실패 exit 1, 인자 없음·경로 없음·**스캔 대상 0개**(커버리지 0) exit 2

## v1 체크 (구현됨)

- **em-dash-ban** — 소스에 `—`(U+2014) 0개. 브랜드 무관 항상 적용.
- **forbidden-font** — `Inter`, `Fraunces`, `Instrument Serif` 금지. DESIGN.md에 명시되면 양보.
- **pure-black-ban** — `#000000`/`#000` 금지. DESIGN.md가 검정을 명시하면 양보.

## deferred 체크 (후속 태스크)

- `accent-color == 1` — 페이지 전체 단일 액센트
- `radius-system == 1` — 단일 코너 반경 체계
- 레이아웃 패밀리 ≥ 4/8 섹션
- 채도 < 80%
- eyebrow 밀도 ≤ `ceil(sectionCount / 3)`
- Playwright 접근성 트리 기반 실제 브라우저 a11y (도구 없으면 graceful skip)

## 스코프

- 마케팅 표면(랜딩/포트폴리오)에만 **레이아웃** 규칙 적용. 대시보드/데이터 UI 제외.
- 색상/폰트/em-dash 규칙은 표면 무관 적용 (단, 브랜드 토큰 우선).
