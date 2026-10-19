---
name: ""
metadata: 
  node_type: memory
  originSessionId: 98c9586b-c501-4328-a0e9-9855aaf89fc6
---

Folio에서 "서버 쪽 에러 나는 것 같다" 신고를 받으면, 추측·코드 수정 전에 **`.next/dev/logs/next-development.log`(사용자 dev 서버가 남기는 로그)를 직접 읽어** 실제 스택/에러를 확인한다.

**Why**: 2026-05-21 총괄장 페이지 "에러"는 코드 버그가 아니라 **Microsoft Graph 토큰 만료**(`401 InvalidAuthenticationToken — Lifetime validation failed, the token is expired`)였다. 로그를 보니 assignments뿐 아니라 contracts/receivables/menu-counts **모든 SharePoint 연동이 같은 시각 동일 401** — 즉 앱 전역 인증 만료. 페이지는 설계대로 null→ErrorBox 폴백을 보여준 것(크래시 아님).

**How to apply**:
- 증상이 SharePoint/Graph 의존 페이지면 먼저 **여러 Graph 메뉴가 동시에 깨지는지** 확인 → 그렇다면 코드 아닌 토큰/자격증명 이슈
- `getGraphToken`(`src/lib/microsoft/auth.ts`)은 토큰을 **Node 프로세스 메모리에 캐시** → **dev 서버 재시작**이 1차 해결책(캐시 비우고 재발급). 그래도 401이면 AZURE_AD_CLIENT_SECRET 만료 등 자격증명 점검
- 별도 무관 이슈와 섞지 말 것: 같은 로그의 `AutoRefreshCountdown` setState-in-render 에러는 PageHeader autoRefresh의 사전 버그로 총괄장과 무관
- 인증 게이트된 페이지는 curl로 재현 불가(=/login 리다이렉트) → 로그 파일 읽기가 가장 빠른 관찰 경로. 관련 [[supabase-auth-gotchas]]