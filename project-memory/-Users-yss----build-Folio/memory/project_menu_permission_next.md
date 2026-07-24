---
name: 메뉴별 권한 — 다음 epic 시드
description: 조직·권한(team)에 사용자별 메뉴 접근 권한 관리 추가. PR #14 머지 후 brainstorm 시작.
type: project
originSessionId: 73f1efdf-1934-4409-9720-f047206862e0
---
## 트리거

2026-05-10 사용자 발언: "조직권한에 메뉴별 권한도 추가해야 될거 같아". post variant epic(PR #14) 마무리 후 진행 예정.

## 알려진 컨텍스트

- 현재 권한 모델 = 시스템 권한 enum (`admin` / `member` / `viewer`) — operators 테이블 컬럼 (PR #8)
- 메뉴 = sidebar 항목 (`src/app/dashboard/_data.ts`의 sidebarSections — `kind: 'item'` slug + `pattern`)
- 현재 모든 인증 사용자가 모든 dashboard 메뉴 접근 가능 (middleware는 인증만 체크)
- admin 가드가 일부 페이지에서 적용됨 (`team/page.tsx`, `notices/page.tsx`)

## 미해결 / brainstorm 입력

1. **권한 단위**: 메뉴별 (slug 단위) vs 도메인별 vs 패턴별?
2. **저장 모델**: operators row에 `allowed_menus text[]`? 또는 별도 `menu_permissions` 테이블 (operator_id, slug, can_read, can_write)?
3. **디폴트 정책**: admin = 전체, member = 운영 도메인만, viewer = read-only 일부? 또는 시스템 권한과 직교?
4. **UI**: 조직·권한 페이지 inspector에서 사용자별 체크박스? 또는 별도 메뉴 관리 페이지?
5. **가드 위치**: `dashboard/[slug]/page.tsx` + 정적 page들 모두에 추가? layout에서 통합 처리?
6. **사이드바 노출**: 권한 없는 메뉴는 사이드바에서 hide? 또는 보이되 클릭 시 차단?
7. **시드/마이그레이션**: 기존 17명 operators의 allowed_menus 디폴트 어떻게?

## 영향 추정

- DB 마이그레이션 (operators 컬럼 또는 신규 테이블)
- features/auth/permission.ts 확장 (canViewMenu(slug))
- middleware 또는 dashboard layout에 메뉴 가드
- 사이드바 hide 로직
- team page inspector에 메뉴 권한 편집 UI
- e2e (admin/member/viewer 별 메뉴 접근 차이)

= ~15 파일 추정. HARD-GATE 전체 설계 등급 + worktree 격리 권장.

## 시작 시 first action

`/brainstorm "조직·권한에 메뉴별 접근 권한 추가"` 또는 직접 의도/제약/대안 4문항 자기검증.
