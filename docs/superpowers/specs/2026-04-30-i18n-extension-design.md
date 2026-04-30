# i18n Extension 설계

번역 키 누락/미사용 자동 검출. 라이브러리 무관 정규식 기반 (Phase 4 새 Extension).

## 의도

**문제**: i18n 프로젝트에서 새 기능 추가 시 번역 키 누락(코드에 있는데 locale 파일 없음) 또는 미사용 키(locale에 있는데 코드에 없음)가 쉽게 발생. 수동 검사는 지루하고 누락되기 쉽다.

**해결**: `/i18n-audit` 스킬 — 코드 디렉토리에서 i18n 키 패턴 정규식 추출 + locale JSON 파싱 + 비교 → 누락/미사용/총 카운트 보고.

**대상**: i18n 적용된 모든 프로젝트 (Next.js + next-intl, React + react-i18next, Vue + vue-i18n 등 라이브러리 무관).

## 제약

- **라이브러리 무관**: 정규식 기반 (특정 라이브러리 강제 X). 흔한 5 패턴 인식.
- **외부 의존 0**: jq + grep + find. node 불필요.
- **자동화 수준 낮음**: audit 1개 스킬. setup / 키 추가는 LLM에게 위임.
- **명령 표면 최소**: `/i18n-audit` 또는 `/i18n-audit <locale-dir>` 1개.
- **새 extensions 카테고리**: extensions/i18n/ 신설 (6번째 카테고리).

## 설계

### 입력

```bash
/i18n-audit                    # 자동 탐색 (locale + code 디렉토리)
/i18n-audit <locale-dir>       # locale 디렉토리 명시 (예: messages/, public/locales/)
/i18n-audit --json             # JSON 출력
```

### 키 추출 패턴 (정규식)

코드 파일 (`*.{ts,tsx,js,jsx,vue}`)에서:

| 패턴 | 정규식 |
|------|--------|
| `t('key')` / `t("key")` | `\bt\(['"]([^'"]+)['"]` |
| `useTranslation`의 t — 위와 동일 |
| `i18n.t('key')` | `\bi18n\.t\(['"]([^'"]+)['"]` |
| `<Trans i18nKey="key">` | `i18nKey=['"]([^'"]+)['"]` |
| `formatMessage({id: 'key'})` | `formatMessage\(\s*\{[^}]*id:\s*['"]([^'"]+)['"]` |

조합 정규식 (단일 grep `-oE`):
```bash
grep -roEh "(\bt\(['\"]|\bi18n\.t\(['\"]|i18nKey=['\"]|formatMessage\(\s*\{[^}]*id:\s*['\"])([^'\"]+)['\"]" \
  src/ app/ components/ pages/ 2>/dev/null \
  | sed -E "s/.*['\"]([^'\"]+)['\"].*/\\1/" \
  | sort -u > /tmp/code-keys.txt
```

### Locale 파일 자동 탐색

흔한 위치:
- `messages/<locale>.json` (next-intl)
- `public/locales/<locale>/<ns>.json` (i18next)
- `locales/<locale>.json` (custom)
- `src/i18n/<locale>.json`

자동 탐색:
```bash
LOCALE_DIRS=()
for d in messages public/locales locales src/i18n src/locales; do
  [ -d "$d" ] && LOCALE_DIRS+=("$d")
done
```

명시 인자 시 그것만 사용.

### Locale 키 추출 (JSON 파싱)

JSON 중첩 키를 dot.notation으로 평탄화:
```bash
flatten_json() {
  jq -r '
    paths(scalars) as $p
    | $p | join(".")
  ' "$1"
}
```

예: `{"auth": {"login": "Sign in"}}` → `auth.login`.

### 비교 로직

```bash
sort -u /tmp/code-keys.txt > /tmp/code-keys-sorted.txt
sort -u /tmp/locale-keys.txt > /tmp/locale-keys-sorted.txt

# 누락: 코드에 있는데 locale에 없음
comm -23 /tmp/code-keys-sorted.txt /tmp/locale-keys-sorted.txt > /tmp/missing.txt

# 미사용: locale에 있는데 코드에 없음
comm -13 /tmp/code-keys-sorted.txt /tmp/locale-keys-sorted.txt > /tmp/unused.txt
```

### 출력 포맷

```
🌐 vibe-flow i18n Audit

📂 Locale 디렉토리: messages/ (자동 탐색)
   - en.json (147 keys)
   - ko.json (145 keys)

📝 코드 키: 152 (src/ + app/ 스캔)

━━━ 누락 (코드 → locale 없음) ━━━
  ✗ auth.signup.email_invalid
  ✗ checkout.payment.expired
  ✗ profile.bio.placeholder
  (총 3 누락)

━━━ 미사용 (locale → 코드 없음) ━━━
  ⚠ legacy.old_button
  ⚠ deprecated.removed_feature
  (총 2 미사용)

━━━ Locale 간 불일치 ━━━
  ko.json missing: auth.signup.email_invalid (en.json에는 있음)
  ko.json missing: 1 keys

━━━ 결과 ━━━
  코드 키: 152
  Locale 평균: 146 (en 147 / ko 145)
  누락: 3 / 미사용: 2 / 불일치: 1

권장:
  1. 누락 3 키를 locale 파일에 추가
  2. 미사용 2 키 deprecation 검토
  3. ko.json에 1 키 보완
```

### Locale 간 불일치 검출

여러 locale 파일이 있으면 (en + ko) 키 셋 비교:
```bash
# en.json 키 셋 vs ko.json 키 셋
comm -23 en-keys.txt ko-keys.txt > en-only.txt
comm -13 en-keys.txt ko-keys.txt > ko-only.txt
```

ko.json missing = en.json은 있는데 ko.json에 없는 키.

### Events 발생

```json
{
  "type": "i18n_audit",
  "ts": "...",
  "missing": <count>,
  "unused": <count>,
  "code_keys": <count>,
  "locale_keys": <count>,
  "locales": ["en", "ko"]
}
```

## 데이터 흐름

```
사용자: /i18n-audit
   │
   ▼
1. Locale 디렉토리 탐색 (messages/, public/locales/, locales/, src/i18n/)
2. 각 locale.json 키 추출 (jq paths)
3. 코드 디렉토리 (src/, app/, components/, pages/)에서 i18n 키 정규식 추출
4. 비교 (comm 23 / 13)
5. 출력 (누락 / 미사용 / locale 간 불일치)
6. events.jsonl에 i18n_audit append
```

## 구성 요소

### extensions/i18n/ 디렉토리

```
extensions/i18n/
├── README.md
├── skills/
│   └── i18n-audit/
│       ├── SKILL.md
│       └── evals/
│           └── evals.json
└── agents/
    └── .gitkeep
```

### setup.sh 갱신

`get_extensions_list` 함수에 i18n 추가:
```bash
get_extensions_list() {
  echo "meta-quality"
  echo "design-system"
  echo "deep-collaboration"
  echo "learning-loop"
  echo "code-feedback"
  echo "i18n"
}
```

`get_extension_summary` 함수에 i18n case 추가.

### Evals (5 케이스)

1. **빈 프로젝트** — locale/code 디렉토리 없음 → "i18n 미적용 감지" 메시지
2. **모든 키 일치** — 0 누락 / 0 미사용
3. **누락 키 검출** — 코드 t('foo') 있는데 locale에 없음
4. **미사용 키 검출** — locale에 있는데 코드 사용 없음
5. **multi-locale 불일치** — en.json에 있는데 ko.json 누락

## 의존

- **외부**: jq, grep, find, comm, sort (POSIX)
- **node 불필요** (라이브러리 무관)

## YAGNI 제외

- **자동 setup** (next-intl 설치 + 설정) — LLM 위임
- **키 자동 추가** — 사용자가 직접 (audit 결과 보고 결정)
- **번역 LLM 호출** — 비용 + 품질 변동
- **다국어 지원 (UI 자체)** — 한국어/이모지

## 다른 Extensions와의 관계

| Extension | 영역 |
|-----------|------|
| meta-quality | 스킬 자체 진화 |
| design-system | 디자인 매칭 |
| deep-collaboration | 페어/토론 |
| learning-loop | 메트릭/회고 |
| code-feedback | git diff 분석 |
| **i18n** (신규) | **번역 키 누락/미사용** |

같은 패턴: 단일 도구로 정량적 검사 자동화.
