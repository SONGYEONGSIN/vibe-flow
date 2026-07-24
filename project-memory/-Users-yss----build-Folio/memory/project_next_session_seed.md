---
name: 다음 세션 시드 — 2026-05-20 (실시간 현황 재설계 + 검색/알림 통합)
description: 2026-05-20 세션. 실시간 현황 재설계 + 알림 실데이터 + 검색 통합 + 인수인계 복제. 이어진 세션에서 dead 컴포넌트 정리(PR #198) + 검색 receivables(PR #199) 작업 — 둘 다 main 4943fbe 기준 OPEN
metadata:
  type: project
  originSessionId: 2026-05-20
---

## 종료 시점

2026-05-20. main HEAD `4943fbe` (PR #197). 이 세션에서 PR #139~#197 (약 50건) 머지 — 실시간 현황 UI 반복 + 검색/알림.

### 후속 세션 (이어서 진행, 모두 main 4943fbe 기준 독립 브랜치, 머지 전 OPEN)
- **PR #198** `chore/dead-component-cleanup` — dead 컴포넌트 35파일 삭제 (index/ 신문 1면 + hud/ + live extras + patterns.ts orphan export). ScopeToggle은 살아있어 보존
- **PR #199** `feat/search-receivables` — 상단 검색에 receivables(5번째 도메인) 추가. 시트 fetch+표시컬럼 매칭, fetchReceivablesSheet React cache 래핑, ?q 페이지 필터, matchesReceivablesQuery 순수함수 공유
- **PR #200** `fix/insights-videos-list-batch` — `scripts/insights-fetch.mjs`의 videos.list가 dedupe된 video ID 전체를 한 번에 보내 50개 초과일(오늘 87개) HTTP 400 → 조회수 fetch 실패로 popularity 필터(>=10,000뷰) 무력화. ID 50개씩 batch 분할로 수정. 오늘치는 로컬 실행으로 백필 완료
- **PR #201** `chore/ci-build-check-cost` — build-check가 feat/fix/chore push+PR 이중 실행되던 것 제거(push: main만) + concurrency cancel-in-progress. Actions 분 절감용
- **PR #202** `feat/assignments` — 총괄장 메뉴(사이드바 "서비스" 위, slug `assignments`). SHAREPOINT_ASSIGNMENTS 엑셀 3탭: 대학배정(5시트 조인, 대학×5서비스 운영/개발 그리드, 원서접수=수시 기준, 대학명·담당자명 양방향 검색+내배정+페이지네이션) / 업무분장 / 가격정책(시트 raw 그리드). 실시간 Graph fetch + React cache, 읽기전용. 공용 `PageTabs`(표준 탭 디자인=기본형식), SheetGrid 음영=bg-washi(연한 그레이). brainstorm→plan(docs/superpowers/)→subagent-driven 실행. **롤아웃: 비-admin은 allowed_menus에 assignments 추가 필요**
- 검색 지원 도메인: services/contacts/incidents/handover/**receivables**(#199). contracts는 여전히 미지원

### GitHub Actions billing 차단 (2026-05-20 발생, 미해결)
- private 저장소 Folio의 Actions 무료분 소진 + 지출 한도 $0 → **모든 workflow가 job 시작 전 차단** (insights-fetch 스케줄 + build-check CI 전부). 결제 카드 실패 아님 (Free 플랜, Next payment "-")
- cost driver = build-check CI 누적 ($12/월, vibe-flow 무관). YouTube job(~30초/일)은 무관
- **해제 방법**: github.com/settings/billing/spending_limit 한도 상향 또는 6/1 무료분 리셋. 미해제 시 위 4 PR의 CI는 계속 red (코드는 로컬 검증 통과 — 정상)

## 이번 세션 핵심 결과

### 실시간 현황 (/dashboard) 완전 재설계 — 여러 번 반복
최종 형태: **카드 그리드 + 영역 그룹 + 인스펙터** (`_components/live/`).
- `LiveDashboard` (client) — 영역 그룹별 3-col 카드 + 우측 InspectorPanel 통합. row 클릭 → variant 기반 인스펙터 슬라이드인 (open 시 본문 md:pr-[400px] drawer-padding)
- `LiveCard` — 헤더(label+count+countSub) + `SimpleTable`. placeholder 모드. 외곽 border 없음(헤더 border-b-2 border-ink만), bg-cream, p-4
- `SimpleTable` — 통일 mini-table (text-sm body / text-xs 헤더 / 첫 컬럼 강조). **일자·금액 font-mono 금지** ([[no-mono-date-amount]])
- 그룹 라벨 = 카드 나열("서비스 · 계약 · 미수채권" 등), description 없음
- 기본 mine=true (`?mine=false`로 전체). 각 카드 count = 그 카드 **리스트 실제 모수**(헤더↔리스트 일치)
- 도메인 카드 컬럼은 도메인 의미 맞춤 (계약=구분/대학명/계약여부, 미수=청구일자/거래처/청구금액, 연락처=대학명/고객명/직책)
- worklog 카드는 variant "worklog" (전용 View 신설), services 카드는 write_start_at **연도 +1 shift**(DB 2025 → UI 다음 시즌, [[live-services-year-offset 패턴]])
- **신문 1면 / HUD / 풀스크린은 모두 폐기** — 이전 컴포넌트(Masthead/Lede/TriageList/HudShell 등) dead. 다음 세션에 정리 가능

### alerts 메뉴 제거 + 종 아이콘 실데이터
- `/dashboard/alerts` 별도 페이지 삭제. AlertsBell 클릭 → dropdown 토글(실 알림)
- `features/alerts/queries.ts getOpsAlerts` — 신규 사고 + 본인 수신 인수인계 + 본인 worklog 종합
- 배지 = 처리 필요 액션(urgent+review, worklog=ok 제외) 수

### 상단 검색 도메인 통합
- `features/search/queries.ts searchAll` + `action.ts searchAllAction` — services/contacts/incidents/handover 병렬 q 매칭. SearchBox debounce(250ms) dropdown 섹션별
- ⌘K 표시 제거 (장식 문자 미사용 정책)
- contracts/receivables(sheet)/backup(검색 미지원)은 제외

### 인수인계 내용 복제
- `copyHandoverRecord(fromServiceId, toServiceIds[])` — 14필드 복사 upsert(덮어쓰기)
- HandoverEditForm 하단 "다른 서비스로 복제" 섹션 (전체 검색 + 멀티선택 + 작성됨 뱃지 + 덮어쓰기 confirm)

### 사이드바 IA 변경
- 자료 보관 group화 (자료실/회의록/경위서) — 회의록 이동, 경위서(statements) 신설
- 백업 요청 → 인수인계 바로 아래 이동

### 사용자 dropdown (ChromeUser)
- 이메일 노출 + admin만 "시스템 설정"(settings) 메뉴. ⚙/⇧⌘Q 보조 아이콘 제거

## 재사용 자산 / 패턴

1. **연도 shift 패턴**: services DB가 직전 시즌(2025) → UI 표시 시 write_start_at/end_at 연도 +1. `shiftYmdYear(ymd, delta)` 헬퍼 (schedule/my-todo/실시간현황 page.tsx 각각 정의). SERVICES_YEAR_OFFSET=1
2. **카운트↔리스트 모수 일치**: 카드 헤더 숫자는 그 카드 리스트의 실제 필터 모수여야 함 (getMineCounts 같은 별도 count와 리스트 기준 다르면 "데이터 없음인데 N" 불일치 발생)
3. **services 전체 fetch**: services 2500+건 — pageSize 제한 시 본인 담당이 앞 N건 밖이면 누락. chunk loop(1000×N) 전체 fetch 필요 (대학연락처 mine 필터 등)
4. **검색 지원 도메인**: services(search) / contacts(search) / incidents(q) / handover(q) / worklog(q). backup·contracts·receivables는 미지원
5. **row mapper 모듈 추출**: 도메인 page.tsx inline `xToListRow`를 `{domain}/_row-mapper.ts`로 추출하면 실시간 현황 등에서 재사용 (services/incidents/contracts/contacts/schedule/my-todo/receivables 완료)

## 다음 세션 후보 (사용자 요청 대기)

- ~~dead 컴포넌트 정리~~ → **DONE PR #198** (alertsWidgets mock은 살아있는 getPatternMockData가 소비 → 제외)
- ~~검색에 receivables 포함~~ → **DONE PR #199**. 검색에 contracts 포함은 미완 (sheet 검색 로직 필요)
- 경위서(statements) 실 도메인 promote (현재 mock list)
- 실시간 현황 카드 실 query 정밀화 (handover/receivables mine 필터 일관화)
- (정리거리) alertsWidgets + getPatternMockData dash+alerts 분기 — alerts 페이지 제거됐으나 데이터/테스트 잔존

## 보류 (자연 시점)

- ai-insight 60일 cleanup (자동 동작)
- Discord 봇 DM (Developer Portal 확인 후 재개)
