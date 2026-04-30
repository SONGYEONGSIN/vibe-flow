---
name: i18n-audit
description: i18n 번역 키 누락/미사용/locale 간 불일치 자동 검출. 라이브러리 무관 정규식 (t/i18n.t/Trans/formatMessage) + JSON 파싱 + comm 비교. node 불필요.
model: claude-sonnet-4-6
---

# /i18n-audit

i18n 프로젝트의 번역 키를 코드 ↔ locale 비교하여 누락 / 미사용 / locale 간 불일치를 검출한다.

## 트리거

- `/i18n-audit` — 자동 탐색
- `/i18n-audit <locale-dir>` — locale 디렉토리 명시
- `/i18n-audit --json` — JSON 출력

## 절차

### 1. 인자 파싱

```bash
ARG="${1:-auto}"
case "$ARG" in
  --json) MODE="json"; LOCALE_DIR="" ;;
  ""|auto) MODE="auto"; LOCALE_DIR="" ;;
  *) MODE="auto"; LOCALE_DIR="$ARG" ;;
esac
```

### 2. Locale 디렉토리 탐색

```bash
LOCALE_DIRS=()
if [ -n "$LOCALE_DIR" ]; then
  [ -d "$LOCALE_DIR" ] && LOCALE_DIRS+=("$LOCALE_DIR")
else
  for d in messages public/locales locales src/i18n src/locales; do
    [ -d "$d" ] && LOCALE_DIRS+=("$d")
  done
fi

if [ ${#LOCALE_DIRS[@]} -eq 0 ]; then
  echo "🌐 i18n 미적용 감지 — locale 디렉토리 (messages/, public/locales/, locales/, src/i18n/) 없음"
  exit 0
fi
```

### 3. Locale 파일 + 키 추출

```bash
TMPDIR=$(mktemp -d)

# 모든 locale 파일 수집
LOCALE_FILES=()
for dir in "${LOCALE_DIRS[@]}"; do
  while IFS= read -r f; do
    LOCALE_FILES+=("$f")
  done < <(find "$dir" -name "*.json" -type f 2>/dev/null)
done

if [ ${#LOCALE_FILES[@]} -eq 0 ]; then
  echo "🌐 locale 디렉토리는 있으나 .json 파일 없음: ${LOCALE_DIRS[*]}"
  exit 0
fi

# Locale별 키 추출 (dot-notation 평탄화)
> "$TMPDIR/locale-keys-all.txt"
declare -A LOCALE_KEY_FILES
for f in "${LOCALE_FILES[@]}"; do
  # 파일명에서 locale 추출 (예: en.json → en, ko.json → ko)
  local_name=$(basename "$f" .json)
  keys_file="$TMPDIR/locale-${local_name}.txt"

  jq -r 'paths(scalars) | map(tostring) | join(".")' "$f" 2>/dev/null \
    | sort -u > "$keys_file"

  cat "$keys_file" >> "$TMPDIR/locale-keys-all.txt"
  LOCALE_KEY_FILES[$local_name]="$keys_file"
done

sort -u "$TMPDIR/locale-keys-all.txt" > "$TMPDIR/locale-keys-sorted.txt"
```

### 4. 코드에서 i18n 키 추출

```bash
> "$TMPDIR/code-keys-raw.txt"

# 스캔 대상 디렉토리
CODE_DIRS=()
for d in src app components pages lib; do
  [ -d "$d" ] && CODE_DIRS+=("$d")
done

if [ ${#CODE_DIRS[@]} -eq 0 ]; then
  CODE_DIRS+=(".")
fi

# 5 패턴 통합 grep
# 1) t('key') / t("key")  — useTranslation의 t
# 2) i18n.t('key')
# 3) i18nKey="key"        — <Trans>
# 4) formatMessage({id:'key'})
for d in "${CODE_DIRS[@]}"; do
  grep -roEh \
    -e "\bt\(['\"][^'\"]+['\"]" \
    -e "\bi18n\.t\(['\"][^'\"]+['\"]" \
    -e "i18nKey=['\"][^'\"]+['\"]" \
    -e "formatMessage\(\s*\{[^}]*id:\s*['\"][^'\"]+['\"]" \
    --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.vue" \
    "$d" 2>/dev/null \
    | sed -E "s/.*['\"]([^'\"]+)['\"].*/\\1/" \
    >> "$TMPDIR/code-keys-raw.txt"
done

sort -u "$TMPDIR/code-keys-raw.txt" > "$TMPDIR/code-keys-sorted.txt"
```

### 5. 비교 (누락 / 미사용)

```bash
# 누락: 코드에 있는데 locale에 없음
comm -23 "$TMPDIR/code-keys-sorted.txt" "$TMPDIR/locale-keys-sorted.txt" > "$TMPDIR/missing.txt"

# 미사용: locale에 있는데 코드에 없음
comm -13 "$TMPDIR/code-keys-sorted.txt" "$TMPDIR/locale-keys-sorted.txt" > "$TMPDIR/unused.txt"

MISSING_COUNT=$(wc -l < "$TMPDIR/missing.txt" | tr -d ' ')
UNUSED_COUNT=$(wc -l < "$TMPDIR/unused.txt" | tr -d ' ')
CODE_COUNT=$(wc -l < "$TMPDIR/code-keys-sorted.txt" | tr -d ' ')
LOCALE_TOTAL_COUNT=$(wc -l < "$TMPDIR/locale-keys-sorted.txt" | tr -d ' ')
```

### 6. Locale 간 불일치 검출

```bash
declare -A LOCALE_MISSING
LOCALE_NAMES=("${!LOCALE_KEY_FILES[@]}")

if [ ${#LOCALE_NAMES[@]} -ge 2 ]; then
  # 첫 번째 locale 기준
  REF_LOCALE="${LOCALE_NAMES[0]}"
  REF_FILE="${LOCALE_KEY_FILES[$REF_LOCALE]}"

  for locale in "${LOCALE_NAMES[@]}"; do
    [ "$locale" = "$REF_LOCALE" ] && continue
    other_file="${LOCALE_KEY_FILES[$locale]}"

    # ref에는 있는데 other에 없는 키
    missing_in_other=$(comm -23 "$REF_FILE" "$other_file" | wc -l | tr -d ' ')
    LOCALE_MISSING[$locale]=$missing_in_other
  done
fi
```

### 7. 출력 (auto 모드)

```bash
if [ "$MODE" = "json" ]; then
  print_json
else
  print_report
fi

print_report() {
  echo "🌐 vibe-flow i18n Audit"
  echo ""
  echo "📂 Locale 디렉토리: ${LOCALE_DIRS[*]}"
  for locale in "${LOCALE_NAMES[@]}"; do
    n=$(wc -l < "${LOCALE_KEY_FILES[$locale]}" | tr -d ' ')
    echo "   - ${locale}.json (${n} keys)"
  done
  echo ""
  echo "📝 코드 키: ${CODE_COUNT} (${CODE_DIRS[*]} 스캔)"
  echo ""

  echo "━━━ 누락 (코드 → locale 없음) ━━━"
  if [ "$MISSING_COUNT" -eq 0 ]; then
    echo "  ✓ 없음"
  else
    head -10 "$TMPDIR/missing.txt" | while read -r k; do
      echo "  ✗ $k"
    done
    [ "$MISSING_COUNT" -gt 10 ] && echo "  ... (총 ${MISSING_COUNT})"
    echo "  (총 ${MISSING_COUNT} 누락)"
  fi
  echo ""

  echo "━━━ 미사용 (locale → 코드 없음) ━━━"
  if [ "$UNUSED_COUNT" -eq 0 ]; then
    echo "  ✓ 없음"
  else
    head -10 "$TMPDIR/unused.txt" | while read -r k; do
      echo "  ⚠ $k"
    done
    [ "$UNUSED_COUNT" -gt 10 ] && echo "  ... (총 ${UNUSED_COUNT})"
    echo "  (총 ${UNUSED_COUNT} 미사용)"
  fi
  echo ""

  if [ ${#LOCALE_MISSING[@]} -gt 0 ]; then
    echo "━━━ Locale 간 불일치 ━━━"
    for locale in "${!LOCALE_MISSING[@]}"; do
      echo "  ${locale}.json missing: ${LOCALE_MISSING[$locale]} keys (${REF_LOCALE} 기준)"
    done
    echo ""
  fi

  echo "━━━ 결과 ━━━"
  echo "  코드 키: ${CODE_COUNT}"
  echo "  Locale 통합 키: ${LOCALE_TOTAL_COUNT} (${#LOCALE_NAMES[@]} locales)"
  echo "  누락: ${MISSING_COUNT} / 미사용: ${UNUSED_COUNT}"
}

print_json() {
  local locales_json
  locales_json=$(printf '"%s"\n' "${LOCALE_NAMES[@]}" | jq -s .)

  jq -n \
    --argjson code "$CODE_COUNT" \
    --argjson loc "$LOCALE_TOTAL_COUNT" \
    --argjson m "$MISSING_COUNT" \
    --argjson u "$UNUSED_COUNT" \
    --argjson locales "$locales_json" \
    --rawfile missing "$TMPDIR/missing.txt" \
    --rawfile unused "$TMPDIR/unused.txt" \
    '{
      code_keys: $code,
      locale_keys: $loc,
      locales: $locales,
      missing_count: $m,
      unused_count: $u,
      missing: ($missing | split("\n") | map(select(length > 0))),
      unused: ($unused | split("\n") | map(select(length > 0)))
    }'
}
```

### 8. Events 발생

```bash
NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
mkdir -p .claude
LOCALES_JSON=$(printf '"%s"\n' "${LOCALE_NAMES[@]}" | jq -s .)
jq -nc \
  --arg ts "$NOW_ISO" \
  --argjson m "$MISSING_COUNT" \
  --argjson u "$UNUSED_COUNT" \
  --argjson c "$CODE_COUNT" \
  --argjson l "$LOCALE_TOTAL_COUNT" \
  --argjson locs "$LOCALES_JSON" \
  '{type:"i18n_audit", ts:$ts, missing:$m, unused:$u, code_keys:$c, locale_keys:$l, locales:$locs}' \
  >> .claude/events.jsonl

# Cleanup
rm -rf "$TMPDIR"
```

## 출처

Phase 4 새 Extension. spec: `docs/superpowers/specs/2026-04-30-i18n-extension-design.md`.
