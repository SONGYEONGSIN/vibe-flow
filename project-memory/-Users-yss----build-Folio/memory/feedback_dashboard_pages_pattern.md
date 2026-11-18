---
name: Dashboard dynamic [slug] + 4 패턴 demo 패턴
description: 사이드바 22 항목 동적 라우트 + slug → 패턴 lookup + 셸 layout.tsx 추출
type: feedback
originSessionId: fa4d7468-5d81-4499-b474-305dc529d2ce
---
Folio /dashboard 22 메뉴 페이지 작업(2026-04-28~29)에서 발견한 재사용 패턴.

## slug → 메타 lookup (findSidebarMeta)

사이드바 데이터에 slug + pattern 필드 추가하고 평탄화 helper로 lookup. group 안 sub-item 재귀 탐색:

```ts
export function findSidebarMeta(slug: string) {
  for (const section of sidebarSections) {
    for (const entry of section.entries) {
      if (entry.kind === "item" && entry.slug === slug && entry.pattern) {
        return { label: entry.label, pattern: entry.pattern };
      }
      if (entry.kind === "group") {
        for (const item of entry.items) {
          if (item.slug === slug && item.pattern) return { label: item.label, pattern: item.pattern };
        }
      }
    }
  }
  return null;
}
```

**Why:** 22 페이지를 단일 [slug] 라우트로 처리. 페이지 추가 시 _data.ts만 수정.
**How to apply:** 사이드바 메뉴 많은 admin 앱에서 페이지 추가 자동화. group/sub-group 재귀 필수.

## 4 패턴 demo 분류

22 페이지를 콘텐츠 깊이로 분류 — 단일 컴포넌트로 수렴:
- **list** (14개): 테이블 + 필터칩 + Inspector 행 상세
- **dash** (4개): 카드 위젯 grid + Inspector 위젯 상세
- **log** (2개): 풀 너비 monospace stream + 검색/레벨 필터
- **settings** (1개): 좌 nav + 우 form (select/radio/toggle 3 field type)

각 패턴 단일 컴포넌트 + 단일 mock data 재사용. 22 페이지 작업이 사실상 4 컴포넌트 + 22 라우트.

**Why:** 콘텐츠 비슷한 페이지 다수일 때 차별화는 future scope, demo는 패턴화.
**How to apply:** 신규 페이지 추가 시 어느 패턴인지 분류 → _data.ts에 slug+pattern 한 줄 추가.

## layout.tsx 추출 (App Router)

dashboard처럼 셸 일정한 라우트 그룹은 layout.tsx로 추출 — 페이지 전환 시 셸 unmount/remount 없음:

```tsx
// dashboard/layout.tsx
"use client";
export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  return (
    <div className="grid h-screen grid-rows-[34px_auto_1fr_26px]">
      <TitleBar />
      <MenuBar />
      <main className="grid lg:grid-cols-[240px_1fr]">
        <Sidebar sections={sidebarSections} open={sidebarOpen} ... />
        <div className="overflow-y-auto">{children}</div>
      </main>
      <StatusBar />
      <Scrim open={sidebarOpen} onClick={...} />
    </div>
  );
}
```

`sidebarOpen` state는 layout 보유 (모든 페이지 공유). `inspectorOpen` 같은 페이지별 state는 각 page에 둠.

**함정**: AppBar의 inspector toggle 버튼 같이 layout↔page 양방향 state 공유는 어색 — Context 또는 callback prop 필요. 단순화 옵션: 버튼 제거 (상세 toggle은 page가 자체 처리).

**How to apply:** admin 라우트 그룹(dashboard, settings 등) 모두 layout.tsx로 셸 추출.

## Sidebar Link + active (usePathname)

```tsx
const pathname = usePathname();
const isActive = slug
  ? pathname === `/dashboard/${slug}`
  : (label === "실시간 현황" && pathname === "/dashboard");

<Link href={`/dashboard/${slug}`} prefetch={false}
  aria-current={isActive ? "page" : undefined}
  className={isActive ? "border-l-2 border-vermilion bg-vermilion/10 text-vermilion" : "..."}>
```

`prefetch={false}`로 22 Link 모두 prefetch 부담 회피.

**미래 리스크**: "실시간 현황" label 매칭은 라벨 변경 시 깨짐. 해결: `_data.ts`에 `isIndexRoot: true` 명시 플래그 (현재는 hardcoded label OK).

## Inspector 패턴별 ON/OFF

모든 페이지에 Inspector를 강제하지 말고 패턴별 결정:
- list/dash: Inspector ON (selection 기반, `lg:grid-cols-[1fr_320px]`)
- log: Inspector OFF (풀 너비 `<section>`)
- settings: Inspector OFF (자체 좌 nav + 우 form split)

각 패턴 컴포넌트 안에서 grid 자체를 다르게.

**Why:** Inspector 의미 없는 패턴(log/settings)에 강제하면 부자연.
**How to apply:** 페이지 컴포넌트가 자체 grid 결정. layout은 컨텐츠 영역만 children으로 비워둠.

## dynamic [slug] cast 패턴

Next.js 16 dynamic route에서 useParams + 메타 lookup + 패턴별 분기 시 type cast 필요 (union 타입 narrowing):

```tsx
if (meta.pattern === "list") {
  const data = getPatternMockData(params.slug, "list") as { rows: ListRow[] };
  return <ListPattern title={meta.label} data={data} />;
}
// pattern별 분기 — 각 분기에서 cast
```

**Why:** `getPatternMockData` 반환이 union이라 컴파일러는 narrowing 못 함. `as` cast가 가장 단순.
**How to apply:** generic helper로 더 안전 처리 가능하지만 단순 cast가 충분 (cast 위치가 패턴 분기 안이라 mismatch 발생 불가).

## e2e 함정 — sub-item button → Link

Sidebar sub-item을 button → Link로 바꾸면 e2e selector도 갱신해야:
- 기존: `getByRole("button", { name: /DB · 저장소/ })`
- 변경: `getByRole("link", { name: /DB · 저장소/ })`

**How to apply:** Sidebar 또는 일반 메뉴 selector role 변경 시 e2e 일괄 grep + 갱신.

## design-sync 영향

Sidebar Link wrapping은 mockup(button)과 약간 시각 차이 발생 — login desktop 99.4% → 97.8% (-1.6%p). 받아들일 만한 수준 (mockup은 정적이라 Link semantic은 mockup에서 표현 안 됨).
