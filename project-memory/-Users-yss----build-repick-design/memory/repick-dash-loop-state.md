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
- 검증 인프라: 스크래치패드에 playwright 기반 sweep 스크립트 패턴(라우트×폭별 pageOver/tblOver 실측) — 재작성 쉬움. dev 서버는 포트 3100 (`npm run dev -- -p 3100`), 중복 기동 시 .next 잠금 충돌로 행 걸림 주의.
