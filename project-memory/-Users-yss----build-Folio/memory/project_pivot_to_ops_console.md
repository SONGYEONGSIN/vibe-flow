---
name: chrome 명칭 PIVOT → OPS Console rebrand
description: 2026-05-08 chrome 좌측 brand가 PIVOT(모더니즘 사각)에서 OPS Console(>_ 터미널 프롬프트)로 교체됨.
type: project
originSessionId: f1dae096-5cba-4988-9e0e-8dc18bebf09f
---
chrome 좌측 brand가 `OPS Console` + `>_` 마크로 확정. 이전 `PIVOT` + `▣` + `OPS DESK` 부제는 모두 폐기.

**Why**: PIVOT은 추상 모더니즘이라 운영 시스템 본질이 약했음. 사용자가 직설적 명칭 + 명령행 메타포로 변경 결정.

**How to apply**:
- 새 chrome 컴포넌트 생성 시 OPS Console 워드마크 + 검은 사각 안 흰 `>_` 모노스페이스 패턴 사용
- 테스트/e2e 어설션 작성 시 `OPS Console` + `>_` 검사
- 부제(OPS DESK 류) 추가 금지 — 이름 단독으로 충분
- chrome-graphite/snow/muted 토큰 이름은 변경 없이 그대로 사용 (브랜드명과 무관한 색 식별자)
