# SkillTest Project Memory

## Project Rules

- **작업 범위**: `/Users/yss/개발/SkillTest` 폴더 안에서만 파일 읽기/수정
- 다른 폴더(`~/.claude/`, `~/개발/claude-forge/` 등) 접근 금지
- 예외: 사용자가 명시적으로 외부 파일 작업을 요청한 경우만 허용

## TODO (SkillTest 추후 적용)

- **성능 최적화**: Optimistic UI, 캐싱, 로딩 스켈레톤
- **접근성(a11y)**: ARIA, 키보드 네비게이션, 스크린리더 대응
- **인프라**: 에러 모니터링, 로깅, CI/CD 파이프라인 강화

## Playwright MCP

- 프로젝트에 등록 완료 (`~/.claude.json` → projects → SkillTest)
- 명령: `npx @playwright/mcp@latest`
- 사용법: `browser_navigate` → `browser_console_messages(level: "error")` 로 콘솔 에러 확인
- `/verify` 스킬 5단계에 자동화 통합 완료

## 테스트 계정

- Email: `test@skilltest.com` / PW: `Test1234!`
- Supabase Email Confirm: OFF (즉시 로그인 가능)
