---
name: repick-dash-loop-state
description: repick-design 대시보드 생성 루프의 현재 상태·사용자 기준·핵심 크래프트 학습 (2026-07-12 기준)
metadata: 
  node_type: memory
  type: project
  originSessionId: 17c8ff41-43f3-4e21-9e27-d35e202e92db
---

repick-design의 "자유 창작 SaaS 대시보드 루프" 상태 (2026-07-12):

- **현재 /dash 구성 (14종)**: 1세대 킵 5(d7 CASSANDRA·d9 STELE·d12 QUARTERDECK·d16 LINEAGE·d20 DAILIES), 2세대 잔존(d22~d28, 단 FORME d21은 삭제됨), 3세대 서비스급(d29 Waypoint·d30 Slotted·d31 Conduit·d32 Meridian). 레퍼런스급 금융 대시보드는 별도 `/dash-rg`(Ridge).
- **사용자 품질 기준**: 상용 SaaS(Mercury/Asana/n8n/Coinbase)급. 라이트=순백(크림/페이퍼는 라이트 아님), 폰트는 Pretendard 단일(+숫자 tabular, mono는 코드성 데이터만), 같은 세대 안 레이아웃 아키타입 중복 금지, 그리드 정합에 매우 민감(카드 밖 잘림·스크롤바 노출·여백 불균형을 스크린샷으로 잡아냄).
- **생성 브리프**: `vault/00-principles/dash-brief-v3.md`에 보존(서비스급 기준 + 생존작 DNA 5 + 그리드 크래프트/검증 룰). 선별 학습은 `vault/30-ledger/landing-forms.jsonl`.
- **핵심 크래프트 함정** (반복 발생): ① `table-layout:auto`는 truncate 셀도 미절단 콘텐츠 폭을 최소폭으로 요구 → 데스크톱 테이블은 `table-fixed`+colgroup으로 유동화 ② 단일 폭(1440) 검증은 무의미 — 사용자 환경은 클래식 스크롤바(-15px)+임의 창 폭, 1280~1920 전 구간+여유≥16px 검증 ③ sr-only를 `<table>`에 직접 걸면 보이지 않는 레이아웃 박스가 페이지를 밀어냄 ④ Geist Mono에 ₩ 글리프 없음(통화는 Pretendard tabular-nums).
- **미해결 질문**: d31/d32의 레일형 레이아웃이 좁게 느껴진다는 피드백에 "①유지 ②레일 접기 토글 ③2-페인 단순화" 선택지를 제시한 채 세션 종료 — 다음 세션에서 사용자 답 확인.
- **층2 자율 진화 가동 중 (2026-07-15~, 2026-07-18 이중타깃 확장)**: dash 루프 완전 자율화. GitHub private `SONGYEONGSIN/repick-design`, 클라우드 routine 2개 — 야간 라운드(매일 03:00 KST, trig_01LpWcnPq9kGhdqVtjTqWwEX)·주간 반증 PR(일 06:00 KST, trig_01SXhBdFEDgyuUSiTT1XARA7). **이중 타깃**: 야간 라운드가 dash/landing 무작위 50/50(랜딩 정본=design-principles.md, 격리=landing-deltas-provisional.jsonl, 라우트=/landing-evolve/). ledger 통합 `vault/30-ledger/auto-ledger.jsonl`(target 필드). **LLM Wiki(Karpathy) 정렬**: `vault/index.md` 전수 카탈로그(승격 시 갱신 의무), `scripts/wiki-lint.mjs` 기계 lint(고아·깨진 링크·미등재, 주간 PR "위키 건전성" 게이트), apply의 ingest 파급 규칙. 스킬명은 dash-evolve/dash-falsify 유지(이중 타깃 겸용). 검증 스크립트 3종(dash-static-check·dash-sweep·wiki-lint).
- **에셋·인터랙션 상향 (2026-07-19)**: 이원 에셋 엔진 — 생성형 SVG/CSS(무제한·결정론) + 외부 이미지(next/image, remotePatterns=unsplash·picsum·pexels). 타깃 차등: landing 표현 상한 없음(framer-motion·스크롤 연출·히어로 이미지), dash 서비스급 절제 유지+도메인 시각화·인터랙션 밀도↑(최소 4종). 신규 static-check 이미지 규칙 3종: no-raw-img·img-needs-alt(source-level span 스캔 — 다중라인 alt 대응)·no-next-image-unopt. judge 렌즈2에 에셋·인터랙션 풍부도 축(장식 과잉 감점 유지). 전체 테스트 31개. 스모크 실증: dash r7 Tessera·landing r2 REVEAL(드래그 before/after 슬라이더). 스펙(이탈 각주 포함)은 `docs/superpowers/specs/2026-07-15-dash-auto-evolution-design.md`, 운영 기록은 `vault/30-ledger/AUTO-RUN-LOG.md`. r1(로컬)·r2(클라우드) 완주 — r2에서 질문 큐 첫 질문(judge 기준 충돌) 생성됨. **사용자 주간 루틴**: 일요일 PR 리뷰(킵/드롭·delta 승인/기각·질문 답변) 후 로컬에서 `/dash-falsify apply`. 주의: evolve/dash 조작 시 반드시 `git checkout -B evolve/dash origin/evolve/dash` 후 rebase. **단 이 리셋은 로컬에만 있는 미push 커밋을 버린다 — 스모크/라운드로 evolve/dash에 새 커밋을 만들었으면 리셋 전에 반드시 먼저 push하거나, 리셋 후 그 커밋을 cherry-pick으로 되살릴 것**(07-15 야간커밋 유실·07-19 에셋 스모크 r7/landing-r2 유실 — 둘 다 이 패턴, 둘 다 reflog에서 복구). 낡은 로컬 rebase→force-push도 같은 유실 클래스.
- 검증 인프라: `scripts/dash-sweep.mjs`(그리드 다중 폭 실측)·`scripts/dash-static-check.mjs`(폰트/비결정론/이모지) — repo에 정식 편입됨(테스트 17개). dev 서버 포트 3100 고정(package.json), 중복 기동 시 .next 잠금 충돌 주의.
- **통합 갤러리 `/gallery` (2026-07-17 출시)**: 전작 51종(랜딩 6·대시 18·자유 27)을 전시 도록 스타일 카테고리 탭으로 열람 — https://repick-design.vercel.app/gallery (프로덕션). 메타 단일 출처는 `app/src/lib/works.ts` — **신규 작품 승격 시 works.ts entry + LAST_UPDATED 갱신 필요**(주간 apply 때 함께). evolve 후보 탭은 evolve/dash 체크아웃에서만 자동 노출.
