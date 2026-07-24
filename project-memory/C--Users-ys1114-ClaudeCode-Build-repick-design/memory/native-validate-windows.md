---
name: native-validate-windows
description: repick-design native/ 검증 — Windows에서 validate.sh는 npx serve 프롬프트로 멈춤. 게이트 개별 실행 + 툴체인 사전설치 필요
metadata: 
  node_type: memory
  type: project
  originSessionId: b8c3bb7d-b570-4cc1-a298-cf50cd5a2791
  modified: 2026-07-24T06:03:42.623Z
---

`native/scripts/validate.sh`(4-게이트: tsc·expo export·serve+render·iframe)는 **Windows Git Bash에서 통째로 돌리면 5분+ 멈춘다** — 게이트 3의 `npx serve`가 serve 미캐시 시 "Ok to proceed?" 설치 프롬프트에서 stdin 대기하기 때문. 또 cleanup의 `lsof`도 Windows에 없다(`|| true`라 무해).

**Why:** native 코드 검증을 validate.sh 한 방으로 기대하면 타임아웃으로 착각한다. 실제 게이트는 정상.

**How to apply:** native 검증은 다음을 먼저 갖춘 뒤 **게이트를 개별 실행**한다 —
1. `cd native && npm install` + `npx expo install react-native-svg`(차트 시). 루트에 `npm install` + `npx playwright install chromium`(render/iframe 게이트가 루트 playwright 사용).
2. tsc: `cd native && npx tsc --noEmit`. export: `EXPO_PUBLIC_SCREEN=<slug> npx expo export --platform web --output-dir dist --clear`.
3. render: node http 정적 서버(native/dist)로 8091 서빙 + playwright로 검사(포트 kill 이슈 회피 — `npx serve` 말고 node 서버). polyline/좌표/stroke 직접 확인이 텍스트-only보다 강함.
4. iframe: `node native/scripts/iframe-check.mjs http://localhost:8091/ "<check>"`.

react-native-svg는 SDK 57 기준 `15.15.4`(`npx expo install`이 자동 선택). 관련: [[wiki-lint-windows-path-bug]]
