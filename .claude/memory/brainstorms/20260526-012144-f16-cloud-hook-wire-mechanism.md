# Brainstorm: F16 — cloud session hook wire 메커니즘 fix

작성: 2026-05-25T16:21:44Z (KST 2026-05-26 01:21)
주제: cloud session에 `.claude/hooks/auto-build-safety.sh` + `.claude/settings.json` 부재 → PreToolUse hook wire 자체 불가능. R11(PR #78)에서 PASS stderr 미출력으로 발견.

## 의도

- **무엇을**: cloud cron-triggered remote agent session에서 auto-build PreToolUse hook(`auto-build-safety.sh`)이 정상 wire되어 PASS/BLOCKED stderr 출력되도록 메커니즘 구축
- **누가**: cloud remote agent (cron firing 자율 사이클)
- **왜 지금**: R11에서 발견된 핵심 gap. F14/F15 코드(PR #77)는 이미 OK이므로 wire만 되면 즉시 검증 가능. 다음 dogfooding(R12) 전 해소 필수.
- **성공**: R12 firing 시 cloud session log에 `[auto-build-safety] PASS — tool=<X> reason=<Y>` stderr 명시 출력 + destructive op 시도 시 `BLOCKED` 메시지 + cycle abort

## 제약

- **기술**: cloud session = fresh git clone + working dir 자동 설정 + setup.sh 실행 단계 없음. `.claude/settings.json`(PreToolUse 등록) + `.claude/hooks/*.sh`(실 hook script) 둘 다 cloud에 도달해야 함.
- **비즈니스**: 다른 vibe-flow 사용자(setup.sh 통해 install)에게 영향 최소화. user-specific 설정 강제 회피.
- **코드베이스**: `.claude/`는 traditional하게 git untracked (user-specific state). `.claude/settings.local.json`은 secret 가능 — 절대 commit X. setup.sh "skip if exists" 정책 보존.

## 대안 비교

### 대안 A: `.claude/hooks/*` + `.claude/settings.json` git tracked
- **핵심**: 두 파일을 force-add + commit. `.gitignore`에 예외 추가.
- **비용**: 작음. 1~2 파일 commit + `.gitignore` 1줄.
- **위험**: user-specific 설정이 commit되어 다른 사용자에게 강제 적용. setup.sh "skip if exists" 정책과 충돌 (template + tracked file 동시 = 이중 install). `.claude/settings.local.json`처럼 secret 가능 파일은 별도라 OK이나, `.claude/settings.json` 안에 user-machine-specific 설정(예: `/Users/yss/`)이 들어 있으면 위험.
- **가역성**: 높음 (git rm + revert).

### 대안 B (Recommended): `core/skills/auto-build/scripts/cloud-init.sh` 신설 + `cloud-prompt-template.md`에서 호출
- **핵심**: 새 가벼운 init script. cloud-prompt-template.md에서 run-cloud.sh 호출 직전에 `bash core/skills/auto-build/scripts/cloud-init.sh` 1줄 추가. init은 다음만 수행:
  - `mkdir -p .claude/hooks`
  - `cp core/hooks/auto-build-safety.sh .claude/hooks/` (필요 hook만 minimal)
  - `cp settings/settings.template.json .claude/settings.json` (또는 PreToolUse만 추출한 sub-settings)
  - `chmod +x .claude/hooks/auto-build-safety.sh`
- **비용**: 새 script 1개 (~20 줄) + cloud-prompt-template.md 1줄 + 옵션으로 smoke test.
- **위험**: cloud session 매번 init 5~10초 추가. init 실패 시 cycle abort (단 정확한 exit code로 abort 메시지 명확).
- **가역성**: 높음 (script 제거).

### 대안 C: `run-cloud.sh` 시작 부분에 init 통합
- **핵심**: run-cloud.sh 진입 직후 `.claude/` 부재 시 자동 생성 + settings/hooks install.
- **비용**: run-cloud.sh에 init 함수 ~20 라인 추가.
- **위험**: run-cloud.sh 단일 책임 위반 ("queue 처리 + cycle 실행" + "session bootstrap" 혼합). 향후 다른 cloud entry point 추가 시 init 중복.
- **가역성**: 높음.

### 대안 Z (do nothing)
- F16 미해소 → F14/F15 cloud-side 무효 → safety hook 차단 cloud에서 영원히 안 됨 → R12 destructive 차단 검증 불가
- 임시 우회: 코드 review로만 검증 + cloud log 직접 trust. dogfooding 가치 0.

| 항목 | 대안 A | 대안 B | 대안 C | 대안 Z |
|------|--------|--------|--------|--------|
| 구현 비용 | 작음 | 중간 (script 1개) | 중간 | 0 |
| 다른 사용자 영향 | **강제 적용** | 영향 없음 | 영향 없음 | 없음 |
| setup.sh 정책 충돌 | **있음** | 없음 | 없음 | 없음 |
| 단일 책임 | 명확 | 명확 (init 분리) | **위반** | n/a |
| 가역성 | 높음 | 높음 | 높음 | n/a |
| cycle 부하 | 0 | +5~10s | +5~10s | 0 |
| R12 검증 가능 | ✓ | ✓ | ✓ | ✗ |

## 추천 + 근거

**대안 B (cloud-init.sh 신설)**.

**근거**:
1. **다른 사용자에게 강제 적용 X** — setup.sh "skip if exists" 정책 보존. cloud session 전용 init script로 cloud-side 책임만 분리.
2. **단일 책임 준수** — cloud-init.sh = bootstrap, run-cloud.sh = cycle 실행. 향후 다른 cloud entry point 추가 시 cloud-init.sh 재사용 가능.
3. **가장 작은 영향 범위** — local dev workflow 0 영향. cloud session에서만 init 5~10초 추가.

**기각 — 대안 A**: `.claude/settings.json` git track은 user-machine-specific 설정 commit 위험 + setup.sh 이중 install 충돌. `.claude/hooks/*.sh`만 track하는 옵션도 partial fix (settings.json 부재 문제 남음).

**기각 — 대안 C**: run-cloud.sh 단일 책임 위반. 향후 cloud entry point 다양화 시 init 중복 또는 wrapper 필요.

**기각 — 대안 Z**: 본 phase에서 dogfooding 핵심 미해소. safety hook이 cloud에서 영원히 무효이면 destructive op 자동 cycle의 안전 보장이 코드 review에만 의존 → 자율 사이클의 신뢰성 무너짐.

## 다음 단계

- 저장됨: `.claude/memory/brainstorms/20260526-012144-f16-cloud-hook-wire-mechanism.md`
- 권장: **직접 구현** (예상 변경 2~3 파일 — cloud-init.sh + cloud-prompt-template.md + 옵션 smoke test → 인라인 설계 등급)

### 구현 윤곽

1. `core/skills/auto-build/scripts/cloud-init.sh` 신설:
   ```bash
   #!/bin/bash
   set -u
   mkdir -p .claude/hooks
   cp core/hooks/auto-build-safety.sh .claude/hooks/
   chmod +x .claude/hooks/auto-build-safety.sh
   cp settings/settings.template.json .claude/settings.json
   echo "[cloud-init] PreToolUse hook installed + settings.json staged" >&2
   ```
2. `core/skills/auto-build/data/cloud-prompt-template.md`에 `run-cloud.sh` 호출 직전 1줄 추가:
   ```bash
   bash core/skills/auto-build/scripts/cloud-init.sh
   AUTO_BUILD_QUEUE_CRON_FIRING=1 bash core/skills/auto-build/scripts/run-cloud.sh
   ```
3. 검증: cloud-init.sh smoke test (mkdir 멱등, 파일 copy 멱등). settings.template.json의 hook path가 `.claude/hooks/auto-build-safety.sh` 인지 재확인.

### R12 트리거 조건

F16 fix 머지 + cloud-prompt-template.md update → 새 routine 등록 → R12 firing 시 cloud session log에 `[cloud-init] PreToolUse hook installed` + `[auto-build-safety] PASS — tool=Bash` stderr 양쪽 명시 확인.
