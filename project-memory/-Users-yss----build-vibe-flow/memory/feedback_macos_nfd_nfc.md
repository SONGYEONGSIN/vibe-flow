---
name: macOS 한글 경로 NFD/NFC 정규화 차이
description: macOS에서 한글 경로 비교 시 git/pwd는 NFD, 파일/로그는 NFC로 저장될 수 있음 — strict equality 매칭 시 0건 반환 함정
type: feedback
originSessionId: 7779691f-257c-4310-930b-eb2ae234e397
---
macOS에서 한글이 포함된 경로 (`/Users/yss/개발/...`)는 도구별로 정규화 방식이 다르다:

- `git rev-parse --show-toplevel`, `pwd` → **NFD** (decomposed: 자모 분리, 예: `개` = `ᄀ + ᅢ`)
- 파일에 저장된 경로, Claude Code session-log의 `cwd` 필드 → **NFC** (precomposed: 결합, 예: `개`)

**Why:** macOS HFS+ 파일시스템 quirk. 같은 한글이 시각적으로 동일해도 바이트 레벨에서 다름. `==` strict equality 매칭 시 0건 반환되는 무성 오류 발생.

**How to apply:**

vibe-flow `/budget --tokens` 구현 중 발견 (PR #24). 한글 프로젝트 경로 + Claude Code 세션 로그 cwd 매칭에서 0건 반환되어 디버깅. 증상:

```bash
# git: NFD
$ git rev-parse --show-toplevel | od -c | head -1
0000000  / U s e r s / y s s / ᄀ ** ** ᅢ ** ** ᄇ ...

# 로그 파일 cwd: NFC
$ jq '.cwd' file.jsonl | od -c | head -1
0000000  " / U s e r s / y s s / 개 ** ** 발 ** ...
```

해결 — bash에서 python3로 NFC 정규화:

```bash
RAW=$(git rev-parse --show-toplevel)
NORMALIZED=$(python3 -c "import unicodedata,sys;print(unicodedata.normalize('NFC', sys.argv[1]))" "$RAW" 2>/dev/null || echo "$RAW")
# NORMALIZED를 jq --arg로 전달
```

이 패턴은 한글뿐 아니라 다른 자모 결합형 문자(일본어 가나, 베트남어 등)에도 적용. 후속 스킬에서도 외부 데이터(파일/API)와 macOS 파일시스템 경로 비교 시 항상 NFC 정규화 필요.
