# Circuit Breaker + Graduation Runbook (T6)

자율 auto-merge 의 **점진 개방(graduation)**과 **회로 차단기(circuit breaker)** 운영 가이드.

## 개념

- `graduation.sh` 가 tier 를 점진 개방: `off → docs → structural → generative`.
- 각 tier 는 **M(기본 3)밤 연속 클린** 후 다음 개방. `merge-gate`/`self-update` 가 현재 tier 를 읽어 실제 자율머지/릴리즈를 결정한다.
- **default-safe**: 상태는 `disarmed` 로 시작 → `tier=off` → 자율머지 안 켜짐. 운영자가 명시 `arm` 해야 시작.
- **circuit breaker**: health regression(또는 auto-revert 발생) 감지 시 **trip** → `tier=off` 로 freeze, 이후 `tick` no-op. 운영자 `reset` 전까지 자율머지 정지.

## 명령

```bash
G=core/skills/audit/scripts/graduation.sh
bash $G status              # 현재 상태(armed/current_tier/clean_nights/tripped)
bash $G arm                 # graduation 시작 (docs 부터 클린-밤 집계)
bash $G disarm              # 중단 (tier=off, current_tier 보존 — 재arm 시 재개)
bash $G tick clean          # (야간 루프) 클린 밤 1 기록 → M 충족 시 다음 tier
bash $G tick regressed      # health regression → 즉시 trip
bash $G reset               # breaker 해제 + off 부터 재graduation (조사 후 운영자만)
bash $G tier                # 실효 tier (disarmed/tripped 면 off)
```

## graduation 시작 (arm) 절차

1. `bash $G status` 로 disarmed 확인.
2. baseline 안정 확인: 최근 며칠 CI green + auto-revert 0 + dimension 점수 비-감소.
3. `bash $G arm` — 이때부터 야간 `tick clean` 이 누적. 3밤 클린 → `docs` tier 개방(docs PR 자율머지 시작).
4. 이후 자동으로 `structural`(3밤 더) → `generative`(3밤 더) 개방. 총 ~9밤에 전체 개방.

## breaker 발화 시 (tripped) 대응

1. 알림 수신(message-bus `retrospective` regression) 또는 `status` 의 `tripped:true` 확인.
2. `tripped_reason` + 직전 `post-merge-verify` auto-revert 커밋 조사 — **무엇이 health 를 깼는가**.
3. 근인 fix PR 을 **사람이 리뷰·머지**(자율머지는 tier=off 로 정지 중).
4. 안정 확인 후 `bash $G reset` — off 부터 재graduation(보수적 재시작). **바로 이전 tier 로 복귀하지 않는다** (재발 방지).

## 안전 불변식

- graduation.sh / merge-gate / post-merge-verify / self-update 는 `.claude/evolution-protected` denylist 로 보호 — 자율 루프가 개방 게이트 자체를 수정 불가(사람만).
- 안전코어 touch PR 은 tier·CI 무관 항상 REJECT (merge-gate).
- reset 은 항상 사람 판단 — 자동 reset 없음.
