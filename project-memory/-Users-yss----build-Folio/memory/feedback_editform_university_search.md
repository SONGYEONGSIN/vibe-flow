---
name: editform-dropdown
description: 모든 도메인 EditForm에 universityName 또는 대학명 입력 시 자유 텍스트 X. services pattern (검색 + dropdown + 자유 입력 fallback) 표준 적용
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8a18890a-c371-4590-bb5c-6cf1f23166ac
---

## 규칙

도메인 EditForm에 *대학명 입력 필드*가 들어가면 **항상** 검색 dropdown 형태. text input 단독 X.

**Why**: 사용자(2026-05-15) 명시 — "인스펙터 화면에 대학명 항목 들어가는거는 무조건 검색으로 기본 구현해주고". 자유 입력은 *오타·표기 불일치*로 distinct 매핑 깨짐 (예: "가천대학교" vs "가천대학교 대학원" vs "가천대").

**구현 패턴** (services EditForm 기준):

```tsx
const [universityQuery, setUniversityQuery] = useState("");
const [justSelected, setJustSelected] = useState(false);
const trimmed = universityQuery.trim();
const matches = universityNameSuggestions
  .filter((u) => trimmed.length === 0 || u.includes(trimmed))
  .slice(0, 10);

<input
  type="search"
  value={universityQuery || (row.universityName ?? "")}
  onChange={(e) => {
    setUniversityQuery(e.target.value);
    setRow({ ...row, universityName: e.target.value });
    setJustSelected(false);
  }}
  placeholder="대학명을 검색하거나 직접 입력"
  required
/>
{!justSelected && matches.length > 0 && (
  <ul aria-label="대학명 검색 결과">
    {matches.map((u) => (
      <button onClick={() => {
        setRow({ ...row, universityName: u });
        setUniversityQuery(u);
        setJustSelected(true);
      }}>{u}</button>
    ))}
  </ul>
)}
```

**핵심**:
- `justSelected` state로 선택 후 dropdown close
- **빈 query에서는 dropdown 미노출** — 입력 시에만 검색 결과 표시 (사용자 2026-05-15 명시: "services 미리 노출은 어색, backup처럼 입력 시에만")
- 정확 일치 entry도 검색 결과에 포함 (자기 자신 제외 X)
- 자유 입력 허용 — 검색 매칭 없으면 그대로 등록 (placeholder "검색하거나 직접 입력")

**데이터 source 표준**:
- 1차: `services.university_name` distinct (services 도메인이 대학 마스터 역할)
- 자신 도메인의 distinct도 합집합 (예: contacts 도메인이면 services + contacts 합)
- 향후 별도 대학 마스터 도메인 신설 시 그것을 source로 일원화

**적용 도메인**:
- services (대학명 검색 + service_id 자동 부여) — 구현됨
- contacts (대학명 검색) — 구현됨
- 향후 대학 마스터 도메인 신설 / 다른 도메인에서 대학명 입력 시 동일 패턴

**금지**:
- 단순 `<input type="text">` 또는 datalist 단독 X
- 자유 입력만 허용 X (검색 시도조차 안 함)
- 도메인별 별도 검색 컴포넌트 만들지 말 것 — services EditForm 또는 contacts EditForm 패턴 복제

## 관련

- 위치: `src/app/dashboard/_components/inspector/list-variants/services/EditForm.tsx` + `.../contacts/EditForm.tsx`
- prop: `universityNameSuggestions: readonly string[]` (page.tsx에서 services + 자기 도메인 distinct 합집합 전달)
- 관련 표준: [[feedback_list_search_design]] (목록 검색) / [[feedback_list_select_design]] / [[feedback_list_pagination_pattern]] / [[feedback_scope_chips_pattern]]
