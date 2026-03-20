# Conventions

## 코드 스타일

- **Immutability**: 객체 직접 수정 금지, spread로 새 객체 생성
- **파일 크기**: 400줄 권장, 800줄 상한
- **함수 크기**: 50줄 이하
- **Nesting**: 4단계 이하
- **입력 검증**: 외부 입력은 zod로 검증

## 파일/폴더

- 기능(feature/domain) 기준으로 구성
- 컴포넌트 1파일 1컴포넌트
- barrel export(index.ts) 사용

## Server Action 패턴

- `useActionState` + zod 검증 + `revalidatePath` 조합
- 스키마: `features/{domain}/schemas.ts`
- 액션: `features/{domain}/actions.ts` (`"use server"`)
- zod 에러 접근: `parsed.error.issues[0].message` (`.errors` 아님)

## 디자인 토큰

- 색상, 간격, 타이포그래피 토큰은 `src/lib/design-tokens.ts`에 중앙 관리
- 컴포넌트에서 하드코딩 hex/rgb/hsl 색상 금지 → Tailwind 클래스 또는 토큰 상수 사용
- 동일 UI 패턴 3회 이상 반복 시 `src/components/common/`으로 추출
- 상세: `.claude/rules/design.md`
