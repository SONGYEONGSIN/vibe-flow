---
name: design-audit
description: 코드베이스의 디자인 시스템 준수 상태를 점검 — 하드코딩 색상, 중복 UI 패턴, 토큰 커버리지를 분석한다
---

코드베이스 전체의 디자인 시스템 준수 상태를 분석하고 개선 제안을 출력한다.

## 절차

### 1. 하드코딩 색상 스캔

`src/` 하위의 `.tsx`/`.jsx`/`.css` 파일에서 하드코딩된 색상값을 검색한다.

```bash
# hex 색상 (토큰 정의 파일 제외)
grep -rnE '#[0-9a-fA-F]{3,8}\b' src/ --include='*.tsx' --include='*.jsx' --include='*.css' | grep -v 'design-tokens' | grep -v 'tailwind.config' | grep -v 'globals.css'

# rgb/hsl 함수
grep -rnEi '(rgb|hsl)a?\(' src/ --include='*.tsx' --include='*.jsx' --include='*.css' | grep -v 'design-tokens' | grep -v 'tailwind.config' | grep -v 'globals.css'
```

파일별 하드코딩 색상 수를 집계하고, 가장 빈번한 색상값 TOP 10을 추출한다.

### 2. 디자인 토큰 커버리지

- `src/lib/design-tokens.ts` 존재 여부 확인
- 존재 시: 토큰에 정의된 색상 수 vs 코드베이스에서 사용된 고유 하드코딩 색상 수 비교
- 미존재 시: 토큰 파일 생성 가이드 포함 (`.claude/rules/design.md` 참조)

커버리지 = 100 - (하드코딩 색상이 있는 파일 수 / 전체 컴포넌트 파일 수) × 100

### 3. 중복 UI 패턴 감지

다음 패턴의 출현 횟수를 검색한다:

```bash
# 검색/필터 바: Input + Search 아이콘 조합
grep -rlE '(Search|Filter).*className|search.*input|filter.*select' src/ --include='*.tsx' | wc -l

# 테이블 헤더: 동일 스타일링 반복
grep -rlE 'TableHeader|<thead|<th.*className' src/ --include='*.tsx' | wc -l

# 상태 뱃지: rounded + 색상 + text-xs/sm 조합
grep -rlE 'rounded.*(text-xs|text-sm).*bg-|bg-.*rounded.*(text-xs|text-sm)' src/ --include='*.tsx' | wc -l
```

3회 이상 반복되는 패턴은 `src/components/common/`으로 추출을 제안한다.

### 4. 공통 컴포넌트 현황

- `src/components/common/` 디렉토리 존재 여부 확인
- 존재 시: 기존 공통 컴포넌트 목록 출력
- `src/components/ui/` 목록과 비교하여 원자/조합 수준 분포 확인
- 추출 후보 목록 제시

## 출력 형식

```markdown
## 디자인 시스템 감사 결과

### 토큰 커버리지: X%

- 디자인 토큰 파일: [있음/없음]
- 토큰 정의 색상: N개
- 하드코딩 색상이 있는 파일: M개

### 하드코딩 색상 (N건)

| 순위 | 색상값 | 출현 횟수 | 주요 파일 | 제안 |
|------|--------|----------|----------|------|
| 1 | #334155 | 12회 | page.tsx 외 5개 | bg-slate-700 또는 토큰 |

### 파일별 위반 (상위 10개)

| 파일 | 하드코딩 색상 수 |
|------|-----------------|
| src/app/.../page.tsx | 15건 |

### 중복 UI 패턴

| 패턴 | 발견 횟수 | 파일 목록 | 추출 제안 |
|------|----------|----------|----------|
| 검색/필터 바 | 12회 | contacts, tasks... | SearchFilterBar 컴포넌트 |

### 공통 컴포넌트 현황

- 디렉토리: [있음/없음]
- ui/ 컴포넌트: N개 (atom)
- common/ 컴포넌트: M개 (molecule)

### 개선 우선순위

| 우선순위 | 항목 | 예상 효과 |
|---------|------|----------|
| P0 | 토큰 파일 생성 | 색상 일괄 변경 가능 |
| P1 | 검색/필터 바 추출 | 12개 파일 중복 제거 |
| P2 | 테이블 헤더 통일 | 스타일 일관성 확보 |
```

## 규칙

- 각 하드코딩 색상에 대해 가장 가까운 Tailwind 클래스 또는 토큰명 제안
- 중복 패턴은 3회 이상만 보고
- 토큰 파일이 없으면 `.claude/rules/design.md`의 구조 가이드 포함
- 결과는 건설적으로 제시 — 비판이 아닌 개선 방향 중심
