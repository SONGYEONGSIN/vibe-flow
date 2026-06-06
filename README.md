English | [한국어](README.ko.md)

# vibe-flow

> A vibe coder's workflow — from novice to senior, enforced mechanically

[![CI](https://github.com/SONGYEONGSIN/vibe-flow/actions/workflows/eval-regression.yml/badge.svg)](https://github.com/SONGYEONGSIN/vibe-flow/actions)
[![Skills](https://img.shields.io/badge/Skills-44-blue)](docs/REFERENCE.md)
[![Extensions](https://img.shields.io/badge/Extensions-7-purple)](extensions/)
[![Hooks](https://img.shields.io/badge/Hooks-29-orange)](docs/REFERENCE.md)
[![Agents](https://img.shields.io/badge/Agents-22-green)](docs/REFERENCE.md)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

## ⚡ 30-second start

**Option A — Claude Code plugin marketplace (recommended):**

```bash
/plugin marketplace add https://github.com/SONGYEONGSIN/vibe-flow
/plugin install vibe-flow
```

**Option B — Manual setup:**

```bash
git clone https://github.com/SONGYEONGSIN/vibe-flow.git
cd /your/project
bash /path/to/vibe-flow/setup.sh
```

→ 44 skills + 22 agents + 29 hooks + 7 rules are activated immediately.

## 🎯 First cycle (5 minutes)

```bash
claude
> /brainstorm "add user authentication"  # explore intent (4 questions + 2 alternatives)
> /plan from-brainstorm <file>            # break into steps
# ...write code...
> /verify                                 # lint + tsc + test
> /commit                                 # Conventional commit
> /finish                                 # PR/merge decision tree
```

## 🎬 What it actually does

```text
$ /brainstorm "add password reset flow"
  → 4 questions: 무엇/누가/왜 지금/성공 기준
  → 2 alternatives compared (e.g. magic link vs OTP)
  → spec saved to .claude/memory/brainstorms/20260606-...-password-reset.md

$ /plan from-brainstorm .claude/memory/brainstorms/...md
  → 6 steps decomposed (T1~T6) with HARD-GATE level
  → plan_created event → .claude/events.jsonl

$ /verify
  ✓ lint (eslint, prettier)
  ✓ typecheck (tsc --noEmit)
  ✓ test (vitest)
  ✓ no console.log / any / @ts-ignore (rules/donts.md)
  ✓ browser console clean (Playwright)

$ /commit
  → Conventional Commit auto-generated:
    "feat(auth): password reset via email OTP — TTL 10min"

$ /finish
  → decision tree: PR | direct merge | release | cleanup
  → branch state, test status, plan completion 모두 점검 후 안내

[session ends] →
  💡 학습 저장 권장 (활동 신호 감지):
    - /learn save pattern "<password reset pattern>"
```

Hooks 가 매 `Write/Edit` 후 자동 검증 — `/verify` 안 돌려도 prettier/eslint/typecheck/test/design-lint/security-lint 모두 실시간. TDD strict 모드 — 테스트 없이 코드 수정 차단.

**Generate your own demo GIF:**

```bash
# install asciinema (recommended) or terminalizer
brew install asciinema
asciinema rec demo.cast --command "claude"
# ...run a real cycle...
# upload to asciinema.org and link in your PR / docs
```

## 📦 Core skills — default install

| Category | Skills |
|----------|--------|
| Cycle | `/brainstorm` `/plan` `/finish` `/release` |
| Tasks | `/scaffold` `/test` `/worktree` |
| Verify | `/verify` `/security` `/perf-audit` |
| Git | `/commit` `/review-pr` `/receive-review` |
| Meta | `/status` `/learn` `/onboard` `/menu` `/inbox` `/budget` `/telemetry` |

Full command reference → [docs/REFERENCE.md](docs/REFERENCE.md)

## 🔌 Extensions (7) — opt-in

```bash
bash setup.sh --list-extensions       # show available
bash setup.sh --extensions <name>     # add one
bash setup.sh --all                   # install all
```

| Extension | Purpose |
|-----------|---------|
| `meta-quality` | measure skill quality + self-evolve (`/eval`, `/evolve`) |
| `design-system` | match reference designs to code quantitatively (`/design-sync`, `/design-audit`) |
| `deep-collaboration` | Builder/Validator pair, structured debate (`/pair`, `/discuss`) |
| `learning-loop` | long-term metrics, retrospectives (`/metrics`, `/retrospective`) |
| `code-feedback` | git-diff-based quality analysis (`/feedback`) |
| `i18n` | detect missing / unused translation keys (`/i18n-audit`) |
| `k8s` | k8s manifest 5 anti-pattern audit (`/k8s-audit`) |

Each extension → [extensions/](extensions/)

## 🔧 CI templates (opt-in)

`templates/.github/workflows/` provides 4 stack-agnostic GitHub Actions:

| File | Role |
|------|------|
| `verify.yml` | lint + typecheck + test (npm/yarn/pnpm auto-detected) |
| `eval-regression.yml` | regression check on your SKILL.md / agents.md / evals.json structure |
| `security.yml` | npm audit + secret pattern grep + OWASP-style static grep (warn-only by default) |
| `perf.yml` | Lighthouse perf check (`workflow_dispatch` or weekly schedule, warning on threshold miss) |

```bash
# copy into your project (manual, opt-in)
mkdir -p .github/workflows
cp /path/to/vibe-flow/templates/.github/workflows/*.yml .github/workflows/
```

→ [templates/.github/workflows/](templates/.github/workflows/)

## 🚀 Learning path

```
Day 1     → Core 6 (brainstorm, commit, verify, finish, status, learn)
Day 3     → + plan, test, security
Week 1    → + scaffold, worktree, review-pr, receive-review, release
Month 1   → enable extensions (meta-quality / learning-loop etc.)
```

Step-by-step guide → [docs/ONBOARDING.md](docs/ONBOARDING.md)

## 📐 Architecture

```
brainstorm → plan → implement → verify → commit → finish → release
   │                            │                   │
   ↓                            ↓                   ↓
 memory ─────────────────  events.jsonl ─────  retrospective
                                  ↓
                        /eval → /evolve (extensions/meta-quality)
```

Data flow → [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

## 🤝 Agent delegation (22)

`@developer`, `@qa`, `@security`, `@validator`, `@planner`, `@feedback`,
`@moderator`, `@comparator`, `@designer`, `@retrospective`, plus domain
specialists (`@api-architect`, `@frontend-design-specialist`,
`@security-specialist`, `@performance-optimizer`, `@supabase-db-specialist`,
`@devops-engineer`, `@product-strategist`, `@ux-researcher`,
`@architecture-reviewer`, `@technical-writer`, `@test-writer`,
`@project-planner`)
+ extensions: `@skill-reviewer`, `@grader`

## 🛠 Automatic enforcement (29 hooks)

Runs without `/verify`:
- every `Write/Edit` → prettier, eslint, typecheck, test, design-lint
- TDD strict — code edits without a test are blocked
- 27 dangerous-command patterns blocked (`git push --force`, `rm -rf /`, ...)
- metrics auto-collected (events.jsonl + SQLite + JSON)

## 🆙 Upgrade

```bash
cd /path/to/vibe-flow && git pull
cd /your/project && bash /path/to/vibe-flow/setup.sh
# → user edits auto-backed up to .bak, extension state preserved
```

## 📚 Further reading

- [docs/REFERENCE.md](docs/REFERENCE.md) — full command / rule reference
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — self-improving loop in detail
- [docs/MIGRATION.md](docs/MIGRATION.md) — flat `.claude/` → vibe-flow migration
- [docs/ONBOARDING.md](docs/ONBOARDING.md) — vibe coder stage-by-stage guide
- [extensions/](extensions/) — extension usage

## Credits

The core principles in this build mechanically enforce patterns from:

- Surgical change / Goal-driven: [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills)
- TDD Iron Law: [obra/superpowers](https://github.com/obra/superpowers)
- Self-evolution: [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)
- Pair mode: [disler/claude-code-hooks-mastery](https://github.com/disler/claude-code-hooks-mastery)
- Full mapping in [CHANGELOG.md](CHANGELOG.md) 1.0.0

## License

MIT — see [LICENSE](LICENSE).
