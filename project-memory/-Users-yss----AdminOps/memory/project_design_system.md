---
name: 디자인 시스템 통일 기준
description: AdminOps 전체 페이지에 적용되는 UI 스타일 기준 — 테이블 헤더, 검색/필터, 탭, radius 등
type: project
---

2026-03-20 기준 전체 페이지 디자인 통일 작업 진행.

## 통일 기준 (미수채권 페이지 기준)

- **테이블 헤더**: `bg-[#334155]` + `text-white`
- **검색 Input**: `bg-[#f3f3f5] border-transparent focus:border-primary/30 focus:bg-white transition-all`
- **SelectTrigger**: `bg-[#f3f3f5] border-transparent`
- **탭 선택 상태**: `bg-[#334155]` + `text-white` (tabs.tsx TabsTrigger active state)
- **테이블 컨테이너 radius**: `rounded-md`
- **비고/특이사항 컬럼**: `max-w-[80px]` ~ `max-w-[150px] truncate`

## 적용 완료 페이지

services, contracts, receivables, contacts, admin/assignments, handover, handover/history,
activity-log, reports, ai/insights, ai/smart-alerts, communication, notifications,
performance, documents, help, settings, onboarding(Glossary, ServiceMap), LastYearServiceDialog

## 회사 PC 미커밋 가능성

2026-03-20 회사에서 17:37 커밋 시 일부 파일 누락. 서브탭/로테이션탭 테이블 너비 등 추가 변경사항이 회사 PC에 남아있을 수 있음.

**Why:** 회사에서 작업 후 git add 시 일부 파일 누락됨
**How to apply:** 회사 PC에서 `git diff`, `git status`로 미커밋 변경사항 확인 필요
