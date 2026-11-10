# new-repo-template

Minimal starting point for AI-assisted projects: agent rules, a project context file, a progress log, a pre-commit hook and CI.

## Use it

1. Create a repo from this template (GitHub: *Use this template*) and clone it.
2. Install the git hooks: `git config core.hooksPath .githooks`
3. Fill [docs/PROJECT_CONTEXT.md](docs/PROJECT_CONTEXT.md), or ask your agent to interview you and fill it.
4. Once the stack is chosen, set the lint/format/test commands in [scripts/check.sh](scripts/check.sh) and the toolchain setup in [.github/workflows/ci.yml](.github/workflows/ci.yml).
5. Replace this README with your project's own.

## What's inside

| Path | Purpose |
|---|---|
| `AGENTS.md` | Rules and workflow for every AI agent (`CLAUDE.md` imports it) |
| `docs/PROJECT_CONTEXT.md` | What is being built, stack, constraints, decisions |
| `docs/PROGRESS.md` | Session log; the top entry is the handoff for the next session |
| `scripts/check.sh` | Lint / format / test commands, shared by the hook and CI |
| `.githooks/` | `pre-commit` (blocks commits on main, secrets, failing checks), `commit-msg` (Conventional Commits) |
| `.github/workflows/ci.yml` | Runs `scripts/check.sh` on pushes to main and on PRs |
| `.claude/settings.json` | Claude Code guardrails (no force-push, no `--no-verify`, no reading `.env`) |

## License

[MIT](LICENSE)
