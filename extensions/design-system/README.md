# design-system Extension

참고 디자인을 코드와 정량 매칭. URL/이미지/HTML에서 CSS 추출 + 비주얼 회귀 테스트.

## 포함

| 종류 | 항목 | 설명 |
|------|------|------|
| Skill | `/design-sync <URL\|이미지\|--from-file>` | 7/5/6 단계 자동 워크플로우, 싱크율 95%/85~90%/92% 목표 |
| Skill | `/design-audit` | 토큰 커버리지, 하드코딩 색상, 중복 UI 패턴 감사 |

## 의존

- Core (designer 에이전트는 core에 있음 — Phase 0 자율 모드 가능)
- **외부**: `playwright`, `sharp`, `pixelmatch`, `pngjs` (별도 npm i)

```bash
npm install -D playwright sharp pixelmatch pngjs
npx playwright install chromium
```

## 사용 시나리오

- 디자이너가 제공한 참고 디자인 (URL/Figma export 이미지) → 코드베이스 자동 매칭
- 디자인 부패 정기 감사 (`/design-audit`)
- 다크 모드 / 멀티 뷰포트 / hover 상태 시각적 회귀 테스트

## 설치

```bash
bash setup.sh --extensions design-system
# 의존성 별도 설치 후
npm install -D playwright sharp pixelmatch pngjs
```
