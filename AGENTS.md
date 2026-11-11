# AGENTS.md

Rules for any AI agent (Claude Code, Cursor, Copilot, Codex…) working in this repository. Read it fully before acting.

## Before anything

If [docs/PROJECT_CONTEXT.md](docs/PROJECT_CONTEXT.md) still contains `TODO`, the project is not set up yet. Tell the user and offer to fill it by asking them short questions. Do not build features until it is filled.

## Golden rules

1. **Do only what the user asked.** No unrequested refactors, features, dependencies, renames or reformatting.
2. **Ask before doing anything extra**, and ask when a requirement is ambiguous or conflicts with PROJECT_CONTEXT.
3. **Run `bash scripts/check.sh` before every commit.** Never bypass git hooks (`--no-verify`).
4. **Never commit secrets** (`.env`, keys, tokens, real personal data).
5. **Never push to `main` directly, force-push or rewrite shared history** unless the user explicitly asks.
6. **Confirm destructive or outward-facing actions** (deleting files/branches/data, deploying, publishing, creating issues or PRs).
7. **Never fabricate results.** If a check fails or a step was skipped, say so with the real output.
8. **Keep [compliance.yml](compliance.yml) true.** If a change adds or alters personal data, special categories (health, biometrics…), AI features, payments, trackers, hosting regions or third parties, update `compliance.yml` in the same PR and say so in the PR description. Never send real personal data or client code to external services unless `evaluation.send_to_llm` is `true`.
9. **Write everything in the repo in English** (code, docs, commits), even if the user chats in another language, unless PROJECT_CONTEXT says otherwise.

## Workflow

1. **Start:** read [docs/PROJECT_CONTEXT.md](docs/PROJECT_CONTEXT.md) and the latest entry of [docs/PROGRESS.md](docs/PROGRESS.md). Confirm with the user what to work on.
2. **Branch:** `<type>/<short-slug>` (e.g. `feat/user-login`); add the issue number if there is one (`feat/42-user-login`).
3. **Plan:** for anything non-trivial, share a short plan (files, approach, tests) and wait for approval.
4. **Build:** add or update tests with the code. Keep docs in sync when behaviour or decisions change.
5. **Commit:** run `bash scripts/check.sh`; use [Conventional Commits](https://www.conventionalcommits.org) (`feat(auth): add login form (#42)`).
6. **End of session:** add an entry at the top of [docs/PROGRESS.md](docs/PROGRESS.md).

## Map

```
AGENTS.md                 rules for agents (this file); CLAUDE.md imports it
docs/PROJECT_CONTEXT.md   what we build, stack, constraints, decisions
docs/PROGRESS.md          session log + current state (newest first)
docs/architecture/        architecture as Markdown + Mermaid (source of truth); slides/ for decks
compliance.yml            compliance profile: facts about the project, read by compliance-hub
scripts/check.sh          lint / format / test commands (used by pre-commit and CI)
.githooks/                pre-commit (secrets + check.sh), commit-msg (Conventional Commits)
.github/workflows/ci.yml  runs scripts/check.sh on push and PR
.github/workflows/compliance.yml  opt-in compliance evaluation (PR, weekly, on rule updates)
```

## Project-specific rules

- _None yet._
