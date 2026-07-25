---
name: specimen-gallery-redesign
description: "repick-design /gallery 전면 개편 프로그램 — 'Specimen'(AI 에이전트용 디자인 시스템 갤러리) 재정체화. G1(그리드+정체성) 병합, G2(상세)·G3(랜딩) 대기"
metadata:
  node_type: memory
  type: project
  originSessionId: e86865b7-f9ef-4364-ba1b-a507fee91ac7
---

repick-design의 `/gallery`를 **전면 개편하는 프로그램** (2026-07-25 착수). 발단: 사용자가 갤러리를 refero/tasteskill 느낌으로 재포장 + repick 브랜드 제거 요청.

**정체성 결정**: **Specimen** — "AI 에이전트용 디자인 시스템 갤러리". 레포의 실제 성격(게이트 통과·judge 선정·DNA 일관 디자인 자동 생성 + delta/토큰/카탈로그 축적)과 정확히 일치. 참고 사이트: styles.refero.design(갤러리·상세 느낌)·tasteskill.dev(메인 느낌). repick 원본 이름 사용 금지. (이름 후보 중 Codex=OpenAI 겹침·Foundry=Palantir 겹침으로 배제, Specimen 채택.)

**하위 분해** (spec: `docs/superpowers/specs/2026-07-25-specimen-gallery-g1-design.md` §0):
- **G1 ✅ 병합 완료 (squash aeda706 on main, PR#20)** — 갤러리 그리드 refero식 개편 + Specimen 정체성 + i18n. 카테고리 탭→**단일 통합 카드 그리드 + 검색 + 필터 칩**(All/Dashboard/Landing/Free/Native/Winners). **i18n**: `Work.desc`→`{en,ko}` 이중언어(~61작품 영문 태그라인 신규), `app/src/app/gallery/gallery-i18n.ts`(STRINGS 사전), **기본 영문 + EN/KO 토글**(localStorage `specimen-lang`, hydration-safe). repick/RE:픽 제거(v0 브랜드 "V0 — Champion", app "App — Dashboard"). refero 카드(미리보기 iframe/img 유지 + 이름 + desc[lang] + 카테고리 태그). collection-mark.tsx 삭제. `desc:{en,ko}` 교차 타입 변경 파급으로 `/dash`·`/free` 인덱스도 `.ko` 접근자 갱신. 변경=works.ts·gallery 4파일·dash/free page·collection-mark 삭제. build·45/45·a11y 95. **다음 재개점 = G2.**
- **G2 ✅ 병합 완료 (squash c48141d on main, PR#21, Vercel 자동배포)** 작품 **상세 페이지** `/gallery/[id]`. spec `docs/superpowers/specs/2026-07-25-specimen-gallery-g2-detail-design.md`, plan `.../plans/2026-07-25-specimen-gallery-g2.md`, SDD ledger `.superpowers/sdd/progress.md`(8태스크). **하이브리드 데이터**: 기계 추출기 `scripts/extract-palette.mjs`(Tailwind v4 **OKLCH→hex** — 주의: v4 팔레트는 OKLCH라 v3 hex와 다름, 예 indigo-600 v3 #4f46e5≠v4) + 저작 스펙 `app/src/lib/specimen-specs.data.json`(작품별 팔레트 역할·철학·Do/Don't·**Agent Prompt/DESIGN.md**, 완주게이트 `scripts/specimen-spec-schema.mjs`, SUBSET 15). 상세=refero MVP(히어로 미리보기·팔레트+Copy·타이포/스페이싱·Do/Don't·Agent Prompt·More like this), 미서브셋=coming-soon. 카드→`/gallery/[id]` 라우팅(진화후보 id에 "/" → 라이브 유지). 공용 `catalogWorks()`(works.ts). **심층 스펙 영문 전용**, 크롬만 EN/KO. **서브셋 15**: dash d29~d38·landing v0/v6/v7/v8·native n1(전부 hex 추출기/tokens 대조). **의도된 편차**: 미서브셋 baseline 팔레트 없음(추출기=저작보조, 전작 baseline은 §8 후속). 65/65 tests·build 61 SSG·opus 최종리뷰 Ready. **비차단 후속**: ①set-state-in-effect/`<img>` lint repo-wide cleanup(gallery-client·work-card·detail-client 공유 훅) ②id===key assertion ③baseline 배치 시 미서브셋 보강. **다음 재개점 = PR#21 머지 후 G3**(또는 후속 batch로 나머지 ~46작품 rich 스펙).
- **G3 (미착수)** **메인 랜딩** — tasteskill.dev식 히어로 캐러셀(최고 작품들)·포지셔닝. G2 머지 뒤.

**주의**: 개별 작품 라우트(`/`=repick 프로덕션 랜딩, `/dashboard`, /dash/*, /v* 등)는 여전히 repick 브랜드 — G1은 갤러리 크롬만 de-brand. 개별 페이지 de-brand는 후속(범위 밖). 생성 카피는 이미 영문 전용 규칙(PR#19) — 새 라운드부터 적용.

관련: [[repick-native-loop]](멀티플랫폼 진화 루프)·[[repick-dash-loop-state]](대시보드 루프·주간 반증).
