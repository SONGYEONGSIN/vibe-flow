# vibe-flow

> vibe coder의 작업 흐름 — 초보부터 상급자까지, mechanical enforcement로

## ⚡ 30초 시작

```bash
git clone https://github.com/SONGYEONGSIN/vibe-flow.git
cd /your/project
bash /path/to/vibe-flow/setup.sh
```

→ Core 14 스킬 + 22 훅 + 10 에이전트 + 6 규칙 즉시 활성화

## 🎯 첫 사이클 (5분)

```bash
claude
> /brainstorm "사용자 인증 기능 추가"   # 의도 탐색 (4문항 + 대안 2개)
> /plan from-brainstorm <file>           # 단계 분해
# ...코드 작성...
> /verify                                # lint + tsc + test
> /commit                                # Conventional commit
> /finish                                # PR/머지 결정 트리
```

## 📦 Core 14 — 기본 설치

| 카테고리 | 스킬 |
|---------|------|
| 사이클 | `/brainstorm` `/plan` `/finish` `/release` |
| 작업 | `/scaffold` `/test` `/worktree` |
| 검증 | `/verify` `/security` |
| Git | `/commit` `/review-pr` `/receive-review` |
| 메타 | `/status` `/learn` |

자세한 명령 → [docs/REFERENCE.md](docs/REFERENCE.md)

## 🔌 Extensions 5 — opt-in

```bash
bash setup.sh --list-extensions       # 사용 가능한 것 보기
bash setup.sh --extensions <name>     # 추가
bash setup.sh --all                   # 전체 설치
```

| Extension | 용도 |
|-----------|------|
| `meta-quality` | 스킬 자체 품질 측정 + 자가 진화 (`/eval`, `/evolve`) |
| `design-system` | 참고 디자인 → 코드 정량 매칭 (`/design-sync`, `/design-audit`) |
| `deep-collaboration` | Builder/Validator 페어, 토론 (`/pair`, `/discuss`) |
| `learning-loop` | 장기 메트릭, 회고 (`/metrics`, `/retrospective`) |
| `code-feedback` | git diff 기반 품질 분석 (`/feedback`) |

각 extension 상세 → [extensions/](extensions/)

## 🚀 학습 경로

```
첫날     → Core 6 (brainstorm, commit, verify, finish, status, learn)
3일차    → + plan, test, security
1주차    → + scaffold, worktree, review-pr, receive-review, release
1개월    → Extensions 활성화 (meta-quality / learning-loop 등)
```

자세한 단계별 가이드 → [docs/ONBOARDING.md](docs/ONBOARDING.md)

## 📐 아키텍처

```
brainstorm → plan → 구현 → verify → commit → finish → release
   │                            │                   │
   ↓                            ↓                   ↓
 memory ─────────────────  events.jsonl ─────  retrospective
                                  ↓
                        /eval → /evolve (extensions/meta-quality)
```

자세한 데이터 흐름 → [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

## 🤝 에이전트 위임 (12개)

`@developer`, `@qa`, `@security`, `@validator`, `@planner`, `@feedback`,
`@moderator`, `@comparator`, `@designer`, `@retrospective`
+ extensions: `@skill-reviewer`, `@grader`

## 🛠 자동 강제 (Hooks 22개)

`/verify` 안 돌려도 자동:
- 매 `Write/Edit` → prettier, eslint, typecheck, test, design-lint
- TDD strict — 테스트 없이 코드 수정 차단
- 위험 명령 27 패턴 차단 (`git push --force`, `rm -rf /`, ...)
- 메트릭 자동 수집 (events.jsonl + SQLite + JSON)

## 🆙 업그레이드

```bash
cd /path/to/vibe-flow && git pull
cd /your/project && bash /path/to/vibe-flow/setup.sh
# → 사용자 수정본 자동 .bak 백업, extensions state 보존
```

## 📚 더 읽기

- [docs/REFERENCE.md](docs/REFERENCE.md) — 전체 명령/규칙 레퍼런스
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — self-improving 루프 상세
- [docs/MIGRATION.md](docs/MIGRATION.md) — 평면 .claude/ → vibe-flow 마이그레이션
- [docs/ONBOARDING.md](docs/ONBOARDING.md) — vibe coder 단계별 가이드
- [extensions/](extensions/) — 각 extension 사용법

## 출처

이 빌드의 핵심 원칙은 다음 패턴을 mechanical enforcement로 통합한 것:

- Surgical change / Goal-driven: [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills)
- TDD Iron Law: [obra/superpowers](https://github.com/obra/superpowers)
- Self-evolution: [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)
- Pair mode: [disler/claude-code-hooks-mastery](https://github.com/disler/claude-code-hooks-mastery)
- 자세한 매핑은 [CHANGELOG.md](CHANGELOG.md) 1.0.0

## 라이선스

MIT
