---
name: dev-tools-menu
description: "/dashboard/tools — 레포 .claude/ 의 스킬·에이전트·훅·룰 카탈로그. 커밋된 생성물 + 토글은 로컬 apply 필요"
metadata:
  node_type: memory
  type: project
  originSessionId: ec85b534-6819-4191-82d9-815a5d99874c
  modified: 2026-08-19T22:34:47.188Z
---

`/dashboard/tools` (admin only) — 사이드바 **AI & 자동화 > 에이전트 아래 '도구'**. 스킬 53 · 에이전트 24 · 훅 28 · 룰 7 = **112개**를 4탭으로 본다 (#1037).

## 목록은 커밋된 생성물이다

`npm run tools:scan` 이 레포 `.claude/` 를 훑어 `src/features/dev-tools/catalog.generated.ts` 를 만든다. **Vercel 함수는 `.claude/` 를 못 읽는다** — Next 가 코드에서 참조하지 않는 파일을 번들에 안 넣기 때문. 빌드 때 만들고 gitignore 하면 fresh clone 의 typecheck·test 가 깨진다([[db-migration-apply]] 아닌 `next-env.d.ts` 와 같은 계열). 그래서 커밋하고 **CI(build-check)가 드리프트를 잡는다**.

파싱은 `scan.ts` 하나뿐. 생성 스크립트가 `node --experimental-strip-types` 로 그 TS를 그대로 불러 쓴다 — 복사하면 테스트가 있는 쪽과 도는 쪽이 갈라진다.

## MCP·플러그인은 못 보여준다

둘 다 `~/.claude.json` 과 `~/.claude/settings.json` 에 있어 **git 에 안 들어오고 Vercel 은 홈 디렉터리를 못 본다.** 스크린샷의 86/67 을 보려면 스냅샷 업로드 경로가 따로 필요하다 — [[knowledge-vault-project]] 볼트와 같은 제약이다.

## 끌 수 있는 건 스킬뿐

`permissions.deny: ["Skill(이름)"]` 로 막힌다. 에이전트·훅·룰은 **파일 존재가 곧 활성**이라 끄려면 파일을 옮겨야 하고 그건 git 변경이다 → 그 종류에는 스위치를 안 보여준다(눌러도 안 되는 버튼은 없는 것만 못하다).

## 토글은 즉시 반영되지 않는다

실제 스위치인 `.claude/settings.local.json` 은 **gitignore 라 Vercel 이 만질 수 없다.** 웹은 `dev_tool_toggles` 에 결정만 적고, 그 PC에서 `npm run tools:apply` → **Claude Code 재시작**.

그 파일에는 permissions·env·hooks 가 함께 있어 **한 번 잘못 쓰면 Claude Code 가 안 뜨고 그때는 고칠 도구까지 함께 망가진다.** 그래서 손대는 범위를 순수 함수(`apply.ts`)로 못박았다 — 카탈로그에 있는 스킬의 `Skill(…)` 만. 사람이 손으로 넣은 차단은 남기고 덮어쓰기 전 `.bak` 을 만든다.

**세션 시작 훅으로 자동화하지 않았다** — 훅이 자기 설정이 든 파일을 고치게 되고, 세션마다 Supabase 호출이 붙어 네트워크가 죽으면 시작이 막힌다. 대신 화면이 `dev_tool_applies`(PC별 반영 시각)로 **'아직 반영 안 된 변경 N건'** 을 띄운다 — 수동의 유일한 약점이 그것이라 거기만 막았다.

**Why:** 웹에서 로컬 개발환경을 만지는 구조라 "화면과 실제가 갈라지는" 위험이 본질이고, 그걸 어디서 어떻게 막았는지가 이 기능의 전부다. **How to apply:** MCP·플러그인 요청이 다시 오면 스냅샷 경로 신설이 필요하고, 토글이 "안 먹는다"는 말이 나오면 apply 실행 여부부터 본다.

관련: [[claude-agent-sdk-hardening]] · [[knowledge-vault-project]] · [[standard-list-inspector-design]]
