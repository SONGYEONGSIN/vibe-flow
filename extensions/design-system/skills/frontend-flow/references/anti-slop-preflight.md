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

- **radius-system** — 스케일 반경 고유값 > 2(full/none 제외) **또는** SaaS 카드 조합(`rounded-xl` + 좌측 보더)이면 warn. 규칙 3.
- **eyebrow-density** — eyebrow(`uppercase` + `tracking-wid*`) 개수 > `ceil(sectionCount/3)`이면 warn. `<section>` 0개면 N/A(pass). 규칙 8 스케일 감각.

## deferred 체크 (스펙 확정 · `anti-slop-check.js` 미구현)

> 아래는 **후속 구현 대상**이며 현재 스크립트는 실행하지 않는다(스펙만 확정).
> 색상 모델(hue/채도 변환)·문맥(표면 분류) 판단이 필요해 이진 FAIL이 아닌 **WARN**(exit 0 유지)로 구현하거나 에이전트 리뷰에 위임할 것.
> `radius-system`·`eyebrow-density`는 v1에서 이미 구현됨(위 WARN 섹션).
> 원격 규칙 출처: Trystan-SA/claude-design-system-prompt `ai-slop-check.md` (MIT).

### single-accent (규칙 7 — 색상값은 토큰으로 추적)

- **탐지**: 소스 전체 유색(회색·흰·검 제외) hex/oklch/tailwind 컬러 유틸을 색상군(hue 30° 버킷)으로 그룹핑. 한 페이지에서 서로 다른 액센트 hue가 **2개 초과**면 지적 — "한 파일에 미묘하게 다른 파랑 다섯 = 인라인 즉흥 색".
- **임계값**: 액센트 hue 그룹 ≤ 1. 초과분은 토큰으로 통합 제안.
- **브랜드 우선**: DESIGN.md가 다액센트 팔레트를 명시하면 양보.
- **심각도**: WARN. (색상 변환 헬퍼 필요 → 후속)

### low-saturation (규칙 7 — oklch 조화 팔레트)

- **탐지**: 액센트 색의 채도(HSL S 또는 oklch chroma 환산)가 과포화면 지적. oklch 기반이면 명도·채도 일관성 확인.
- **임계값**: 액센트 채도 < 80%(HSL 기준). 초과 시 톤 조정 제안.
- **브랜드 우선**: 브랜드가 고채도를 명시하면 양보.
- **심각도**: WARN.

### eyebrow-density (규칙 8 스케일 감각 응용 — 밀도 억제)

- **탐지**: eyebrow/kicker(섹션 상단 소형 라벨·`uppercase tracking-wide text-xs` 패턴) 개수가 섹션 수 대비 과다면 지적.
- **임계값**: eyebrow 밀도 ≤ `ceil(sectionCount / 3)`.
- **심각도**: WARN.

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
