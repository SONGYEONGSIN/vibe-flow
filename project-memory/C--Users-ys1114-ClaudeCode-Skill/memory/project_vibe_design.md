---
name: vibe-design skill (own creation)
description: vibe-design — user's own thin-orchestrator skill at C:\Users\ys1114\ClaudeCode\Skill\vibe-design\, v0.1.0 complete, symlinked into Claude Code as junction
type: project
originSessionId: 31d8f8df-1fce-462c-8211-720f4b89583a
---
vibe-design is a skill the user built earlier in this conversation thread. It chains `extract-design-system` (token extraction from a URL) + `ui-ux-pro-max` (component generation reference) to produce a Next.js + shadcn/ui starter kit. Located at `C:\Users\ys1114\ClaudeCode\Skill\vibe-design\`. Tagged `v0.1.0-p1` (initial release).

**Architecture**: Markdown SKILL.md instructs Claude on a 5-phase workflow. Heavy lifting lives in 8 Python scripts (testable via pytest, 42 tests passing). Output drops into `.design-clone/YYYY-MM-DD-{host}/` of caller's CWD. Includes ko/en i18n for COMPONENTS.md and prototype.html (default ko).

**Important wrapper**: scripts run via `bash ~/.claude/skills/vibe-design/bin/run.sh scripts.<module>` — handles venv activation + PYTHONPATH so it works from any user CWD.

**Symlink**: Registered as Claude Code skill via Windows junction at `~/.claude/skills/vibe-design` → real project dir. Created with `cmd.exe //c "mklink /J ..."` (NOT `ln -s` which silently copies on Git Bash).

**Why**: User wanted "Stripe처럼 만들어줘" → instant starter kit. Was the entry point that established their interest in design-to-code workflows; later led to OPS console + Stitch workflow exploration.

**How to apply**: If user revisits this skill, P2-P4 of original plan exist but aren't started — those would add stack flexibility, agent-browser fallback for SPAs, plugin-namespace-aware deps check (current deps.py only checks `~/.agents/skills/`, missing Claude Code plugin locations). v0.1.0 has known deviation in `components.md.j2` template (`Detected from:` line de-bolded to match a test assertion).
