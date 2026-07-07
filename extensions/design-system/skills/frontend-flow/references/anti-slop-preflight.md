# Anti-Slop Pre-Flight (P4)

> 기계 단언 3-state: **fail**(게이팅, exit 1) / **warn**(비게이팅, exit 0) / **pass**. `scripts/anti-slop-check.js`가 실행한다.
> **브랜드 우선 원칙**: DESIGN.md에 명시된 폰트/색은 아래 금지 규칙을 무효화한다.

## 실행

```bash
# 스킬 실행 CWD는 프로젝트 루트 → 루트 기준 풀 경로로 호출
node extensions/design-system/skills/frontend-flow/scripts/anti-slop-check.js <src 디렉토리|파일> [정본 DESIGN.md 경로]
```

- stdout에 JSON `{target, checks:[{id,status,detail}], passed, warned, failed}`
- exit 1은 **fail이 하나라도** 있을 때만. **warn은 exit 0 유지**(비게이팅 — 리뷰 신호). 인자 없음·경로 없음·**스캔 대상 0개**(커버리지 0)는 exit 2.

## v1 체크 (구현됨)

### FAIL 게이팅 (이진, 브랜드 우선)

- **em-dash-ban** — 소스에 `—`(U+2014) 0개. 브랜드 무관 항상 적용.
- **forbidden-font** — `Inter`, `Fraunces`, `Instrument Serif` 금지. DESIGN.md에 명시되면 양보.
- **pure-black-ban** — `#000000`/`#000` + tailwind `*-black` 유틸 금지. DESIGN.md가 검정 hex를 명시하면 양보.

### WARN 비게이팅 (결정론적 카운팅 — exit 0 유지)

- **radius-system** — 스케일 반경 고유값 > 2(full/none 제외) **또는** SaaS 카드 조합(`rounded-xl` + 좌측 보더 **폭** 유틸 `border-l`/`border-l-0/2/4/8`)이면 warn. 색상 유틸(`border-l-zinc-200`)은 실 폭 0이라 제외(v2.3.1). 규칙 3.
- **eyebrow-density** — `uppercase` className 개수(파일에 `tracking-wid*` 존재 시) > `ceil(sectionCount/3)`이면 warn. `uppercase`/`tracking`이 별도 className으로 쪼개진 `cn()` 패턴도 포착(v2.3.1). `<section>` 0개면 N/A(pass). 규칙 8 스케일 감각.
- **single-accent** (v2.3.2) — 유색 액센트(hex·oklch·tailwind, 중성색 제외)를 hue 30° 버킷화. **버킷 > 3**(색상 난립) **또는** 한 버킷에 raw 값 > 3개(near-dup 토큰 미추출, "파랑 다섯")이면 warn. tailwind shade는 토큰이라 near-dup 대상 아님. 규칙 7. `scripts/color-utils.js` 헬퍼 사용.
- **low-saturation** (v2.3.2) — 과포화 네온 액센트: hex **HSL S ≥ 90%** 또는 oklch **chroma ≥ 0.25**이면 warn. 정상 브랜드 채도(예: blue-600 S=83%)는 통과(FP 방지). tailwind 유틸은 curated 팔레트라 채도 검사 면제. 규칙 7.

> **브랜드 우선(색상)**: DESIGN.md에 명시된 색은 `single-accent`(버킷 제외)·`low-saturation`(raw 제외)에서 양보.
> **주석 스트립(v2.3.1)**: 모든 검사는 블록/라인 주석 제거 후 스캔한다(주석 속 em-dash·`<section>`·주석처리된 `font-inter` 오탐 방지). `://`·문자열 내 `//`(URL)은 보존.

## deferred 체크 (스펙 확정 · `anti-slop-check.js` 미구현)

> 아래는 **후속 구현 대상**이며 현재 스크립트는 실행하지 않는다(스펙만 확정).
> 문맥(표면 분류) 판단이 필요해 이진 FAIL이 아닌 **WARN**으로 구현하거나 에이전트 리뷰에 위임할 것.
> `radius-system`·`eyebrow-density`(v2.3.1)·`single-accent`·`low-saturation`(v2.3.2)은 이미 구현됨(위 WARN 섹션).
> 원격 규칙 출처: Trystan-SA/claude-design-system-prompt `ai-slop-check.md` (MIT).

### layout-family (마케팅 표면 한정)

- 레이아웃 패밀리 ≥ 4/8 섹션(랜딩/포트폴리오만, 대시보드·데이터 UI 제외). 심각도 WARN.

### editorial-warm-combo (규칙 9 — 새 AI 클리셰 · 신설)

> 과거의 보라 그라데이션에 대응하는 **오늘날의 기본-템플릿 룩**. 개별 신호는 정당할 수 있으나
> **조합**이 브랜드 근거 없이 나타나면 클리셰다. 특히 대시보드·개발도구·핀테크·헬스케어·엔터프라이즈 표면.

- **신호 4종**:
  1. 크림/웜 오프화이트 배경(`#F4F1EA` 계열, oklch로 warm off-white)
  2. serif 디스플레이 페이스를 **조용한 기본값**으로 사용(Georgia, Playfair Display, Fraunces 등)
  3. 헤드라인의 italic 단어 강조
  4. 테라코타/앰버 액센트
- **탐지·판정**: 위 신호 중 **≥3개 동시** 출현 **AND** 표면이 마케팅(랜딩/포트폴리오/호스피탈리티/에디토리얼)이 **아님** → 지적. 마케팅 표면에서는 정당한 방향일 수 있어 제외.
- **브랜드 우선**: 정본 DESIGN.md가 이 방향을 명시적으로 커밋했으면 양보. 근거 없으면 커밋된 방향으로 교체하거나 사용자에게 플래그.
- **심각도**: WARN(단일 신호는 무시, 조합만 경고).

### runtime a11y (별도 문서로 분리)

- 정적 소스 a11y(4-차원)는 `references/a11y-audit.md`로 이관(브라우저 불필요, 항상 실행).
- Playwright 접근성 트리 기반 **실제 브라우저** a11y는 도구 있으면 실행, 없으면 graceful skip(`status:skipped` ≠ pass).

## 스코프

- 마케팅 표면(랜딩/포트폴리오)에만 **레이아웃** 규칙 적용. 대시보드/데이터 UI 제외.
- 색상/폰트/em-dash 규칙은 표면 무관 적용 (단, 브랜드 토큰 우선).
