---
name: local-test-baseline
description: "로컬 `npm test` 가 늘 25건 실패하는 이유 — Node 26 의 localStorage 전역. CI(Node 22)는 초록"
metadata: 
  node_type: memory
  type: reference
  originSessionId: d4e408f0-fbc3-4552-ad3e-5eb1ff9b999a
  modified: 2026-09-21T22:35:52.750Z
---

이 맥에서 `npm test` 를 돌리면 **항상 25건이 실패**한다. **제품 버그가 아니고 CI 는 초록이다.**

```
TypeError: Cannot read properties of undefined (reading 'setItem')
  at open-tabs-context.tsx:49   localStorage.setItem(...)
```

## 원인

**Node 26 이 `localStorage` 전역을 새로 넣었는데 `--localstorage-file` 없이는 비활성**이다.
그 전역이 jsdom 의 것을 가려 `undefined` 가 된다. 실측:

```
typeof window            : object      ← jsdom 정상
typeof localStorage      : undefined   ← 여기서 죽는다
window.localStorage      : undefined
ExperimentalWarning: localStorage is not available because --localstorage-file was not provided
```

| | |
|---|---|
| 로컬 | **Node 26.7.0** → 25건 실패 |
| CI (`build-check.yml:30`) | **Node 22** → 전부 통과 |

소스가 `window.` 없이 쓰는 건 브라우저에서 정상이다. **제품 코드를 고칠 일이 아니다.**

## 실패하는 7개 파일 (전부 `open-tabs-context` 를 거친다)

`CrumbBar 2 · open-tabs-context 8 · PageHeader 1 · PageTabs 3 · use-auto-add-tab 4 ·
TutorialTour 4 · DashboardShell 3` = **25**

## 쓰는 법

PR 검증은 **전후 대조**로 한다 — 숫자가 25면 회귀 없음.

```bash
grep -E "^ ❯ .*failed" <log> | sed -E 's/ [0-9]+ms$//' | sort   # 전후 diff
```

**주의 둘**

- **worktree 를 남겨 두면 vitest 가 그것까지 훑어 수가 두 배가 된다** (6,900 → 13,900,
  실패 25 → 50). 실제로 한 번 "실패가 두 배" 로 잘못 읽을 뻔했다. 에이전트 worktree 는
  쓰고 나면 `git worktree remove` 로 지운다.
- 이 25건은 **로컬에서 그 7개 파일의 커버리지가 0** 이라는 뜻이기도 하다. 탭 저장 로직을
  깨도 내 화면에선 안 보이고 CI 가 잡는다.

고치려면 `vitest.config` setup 에서 jsdom 의 `localStorage` 를 `globalThis` 에 다시 박으면
된다. 아직 안 했다.

관련: [[work-assignment-project]]
