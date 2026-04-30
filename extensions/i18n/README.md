# i18n Extension

번역 키 누락/미사용 자동 검출. 라이브러리 무관.

## 포함

| 종류 | 항목 | 설명 |
|------|------|------|
| Skill | `/i18n-audit [<locale-dir>\|--json]` | 코드 ↔ locale 비교 → 누락/미사용/불일치 |

## 의존

- jq, grep, find, comm, sort (POSIX)
- node 불필요 (라이브러리 무관)

## 인식 패턴

코드에서 다음 패턴 정규식으로 키 추출:
- `t('key')` / `t("key")`
- `i18n.t('key')`
- `<Trans i18nKey="key">`
- `formatMessage({id: 'key'})`

Locale 자동 탐색:
- `messages/<locale>.json` (next-intl)
- `public/locales/<locale>/<ns>.json` (i18next)
- `locales/<locale>.json`
- `src/i18n/<locale>.json`

## 사용 시나리오

- PR 직전 번역 키 누락 검사
- 정기 미사용 키 cleanup
- 신규 locale 추가 후 일관성 검증

## 설치

```bash
bash setup.sh --extensions i18n
```
