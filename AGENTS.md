# AGENTS.md — Entry point for AI agents

This file is the **single source of truth** for how any AI agent (Claude Code, Cursor, Copilot, Codex, etc.) must behave in this repository. `CLAUDE.md` and `.cursorrules` point here. Read it fully before doing anything.

---

## 0. First: which mode are you in?

| Situation | What to do |
|---|---|
| The user asks you to **create a new project using this repo as a template** | Follow [BOOTSTRAP.md](BOOTSTRAP.md) step by step. Do not improvise. |
| `BOOTSTRAP.md` exists and the user asks you to **change the template itself** | You are maintaining the template. The `TODO` placeholders are intentional; keep everything generic and stack-agnostic, and run `bash tests/harness/run.sh` after changes. |
| `.harness/state/` does **not** exist, or [docs/project-context/PROJECT_CONTEXT.md](docs/project-context/PROJECT_CONTEXT.md) still contains `TODO` placeholders | The project is **not initialized**. Stop and tell the user. Offer to run the discovery phase from [BOOTSTRAP.md](BOOTSTRAP.md#phase-1--discovery). |
| The project is initialized | Follow the **Session workflow** (section 3) below. |

---

## 1. Golden rules (non-negotiable)

1. **Do only what the user asked.** No scope creep: no "while I was here" refactors, no extra features, no unrequested dependencies, no renaming, no reformatting of untouched code.
2. **Ask before doing anything the user did not explicitly request.** If you believe something extra is needed (a refactor, a new dependency, a schema change, touching another module), *propose* it and wait for a yes. Silence is not consent.
3. **Ask when in doubt.** If a requirement is ambiguous, incomplete or contradicts [PROJECT_CONTEXT.md](docs/project-context/PROJECT_CONTEXT.md), ask clarifying questions *before* writing code. Prefer one short round of precise questions over guessing.
4. **Lint, format-check and test before every commit.** Use the commands defined in [.harness/env/sandbox.config](.harness/env/sandbox.config). The `pre-commit` git hook enforces this. **Never** use `--no-verify` or otherwise bypass hooks.
5. **Never commit secrets** (API keys, tokens, passwords, `.env` files, private keys, real personal data). Use environment variables / a secret manager as defined in PROJECT_CONTEXT.
6. **Never push directly to protected branches** (`main` by default) after bootstrap, never force-push, never rewrite shared history — unless the user explicitly asks for that specific action.
7. **Destructive or outward-facing actions require explicit confirmation**: deleting files/branches/data, migrations on shared databases, deploying, publishing, sending messages, creating/closing issues, changing CI or infrastructure.
8. **One work item at a time.** Every change maps to a GitHub issue. Check the [Definition of Ready](docs/process/definition-of-ready.md) before starting and the [Definition of Done](docs/process/definition-of-done.md) + [clean-state checklist](.harness/templates/clean-state-checklist.md) before declaring it done.
9. **Never fabricate results.** If a test fails, a command errors or a step was skipped, say so with the actual output. "Done" means verified.
10. **Leave a trail.** Update the progress log and session handoff (section 4) at the end of every session.
11. **Everything written to the repository or GitHub is in English** (docs, backlog, issues, PRs, commit messages, code, comments), unless the user explicitly asks for another language. The language the user chats in does **not** count as that request: you may reply in their language, but the artifacts stay in English. If the project chose another language, it is recorded in [PROJECT_CONTEXT.md](docs/project-context/PROJECT_CONTEXT.md) and applies from then on.

If a user instruction conflicts with these rules, point out the conflict and ask how to proceed.

---

## 2. Repository map

The repository holds **everything** about the project: the **code** (`src/`, `tests/`), the **documentation** (`docs/`, rendered into `docs-site/index.html`: one file that opens offline or is published online with Cloudflare Pages) and the **backlog** (`docs/backlog/backlog.json` plus `.harness/state/feature_list.json`, mirrored to GitHub issues). As an agent, treat `docs/` as your primary context; business pages explain the *why*, technical pages the *how*.

```
AGENTS.md                      ← you are here (rules + map)
docs-site/                     ← GENERATED documentation site (index.html + Cloudflare files). Never edit by hand.
src/                           ← application code (created by the first foundation task)
CLAUDE.md / .cursorrules       ← tool-specific pointers to this file
BOOTSTRAP.md                   ← procedure to create a new project from this template
.harness/
  templates/                   ← blank templates (do not edit per-session; copy instead)
    feature_list.json          ← global state of features & milestones
    claude-progress.md         ← running progress log / agent journal
    session-handoff.md         ← context transferable between sessions
    clean-state-checklist.md   ← strict criteria before a task is considered finished
  state/                       ← LIVE copies of the templates for this project (created by init.sh)
  env/sandbox.config           ← project commands (lint/test/build) + sandbox policy
  hooks/pre-agent.sh           ← runs at session start (context + sanity checks)
  hooks/post-agent.sh          ← runs at session end (validation)
  scripts/create_issues.py     ← creates GitHub labels/milestones/issues from a backlog JSON
  scripts/apply_ruleset.sh     ← creates/updates the GitHub ruleset from .github/rulesets/main.json
  scripts/build_docs.py        ← generates docs/backlog/index.md + docs-site/ (stdlib only; run by pre-commit)
  docs-viewer/                 ← viewer template + vendored libraries (marked, Mermaid)
.githooks/                     ← git hooks (pre-commit lint/secrets, commit-msg format)
.github/
  ISSUE_TEMPLATE/              ← epic, user story, task, bug forms
  pull_request_template.md
  workflows/ci.yml             ← CI: harness checks + project lint/test (job names = required checks)
  rulesets/main.json           ← model ruleset protecting main (applied with scripts/apply_ruleset.sh)
  CODEOWNERS                   ← reviewers requested on every PR
docs/                          ← project wiki (Markdown + Mermaid). See docs/process/documentation-guide.md
  index.md                     ← home page: where to start for each audience
  business/                    ← PLAIN LANGUAGE for non-technical readers
    overview.md                ← problem, solution, personas, value, scope, constraints
    user-journeys.md           ← flowcharts of how people use the product
    roles-and-permissions.md   ← who can do what (business view)
    roadmap.md                 ← milestones and timeline
    glossary.md                ← shared vocabulary (use these terms in code too)
  backlog/
    backlog.json               ← SOURCE of epics/stories/tasks (definitions)
    index.md                   ← GENERATED page (never edit by hand)
  project-context/
    PROJECT_CONTEXT.md         ← WHAT we build and the cross-cutting decisions (read every session)
    discovery-questionnaire.md ← questions to ask before starting a project
  process/
    definition-of-ready.md     ← DoR (editable per project)
    definition-of-done.md      ← DoD (editable per project)
    work-item-template.md      ← mandatory structure for every epic/story/task
  architecture/
    overview.md                ← system architecture
    decisions/                 ← ADRs, created from docs/resources/templates/adr-template.md
  process/documentation-guide.md ← how and where to write docs
  resources/templates/
    init.sh                    ← harness bootstrap script for new environments
    backlog.example.json       ← input format for create_issues.py
    README.project.md          ← README template for the generated project
tests/                         ← mandatory verification system (success criterion)
```

---

## 3. Session workflow

### 3.1 Start of session
1. Run (or let the hook run) `bash .harness/hooks/pre-agent.sh`.
2. Read, in this order:
   - `.harness/state/session-handoff.md` — what the previous session left for you.
   - `.harness/state/claude-progress.md` — last entries only.
   - `.harness/state/feature_list.json` — current status of features.
   - [docs/project-context/PROJECT_CONTEXT.md](docs/project-context/PROJECT_CONTEXT.md) — constraints you must respect.
3. Confirm with the user which issue you are working on. If none is specified, propose the next unblocked `todo` item from `feature_list.json` and **wait for confirmation**.

### 3.2 Before writing code
1. Read the issue. Check it against the [Definition of Ready](docs/process/definition-of-ready.md). If it fails, list what is missing and ask the user — do not start.
2. Create a branch: `<type>/<issue-number>-<short-slug>` (e.g. `feat/42-user-login`).
3. Share a short plan (files to touch, approach, tests to add). For anything non-trivial, wait for approval.

### 3.3 While working
- Stay inside the scope of the issue. Note out-of-scope findings in the progress log and propose a new issue instead of fixing them.
- Write/extend tests in `tests/` alongside the code. Acceptance criteria must map to tests.
- Respect the constraints in PROJECT_CONTEXT (data location, security, access control, cost limits, UI guidelines).
- Record significant technical decisions as an ADR in `docs/architecture/decisions/NNNN-title.md` (copy `docs/resources/templates/adr-template.md`).
- **Keep docs in sync in the same change**: if behaviour, scope, roles, user flows, costs or architecture change, update the matching page (`docs/business/*` in plain language, `docs/architecture/*` technically). Follow [documentation-guide.md](docs/process/documentation-guide.md).
- **Backlog changes**: new or changed work items go into `docs/backlog/backlog.json` (proposed to the user first). Run `create_issues.py` to sync GitHub (after confirmation), then `python .harness/scripts/build_docs.py`.

### 3.4 Before committing
- Run `LINT_CMD`, `FORMAT_CHECK_CMD`, `TYPECHECK_CMD` and `TEST_CMD` from `sandbox.config`. Fix failures; do not disable rules or skip tests to get green.
- Commit messages follow Conventional Commits and reference the issue: `feat(auth): add login form (#42)`.

### 3.5 Before saying "done"
- Walk through `.harness/templates/clean-state-checklist.md` and the [Definition of Done](docs/process/definition-of-done.md). Report each item honestly.
- Open a PR using the PR template (only if the user asked you to, or the workflow in PROJECT_CONTEXT says so). Link it with `Closes #<n>`.
- Update `feature_list.json` status and regenerate the docs: `python .harness/scripts/build_docs.py` (pre-commit also does it).

### 3.6 End of session (always)
1. Append an entry to `.harness/state/claude-progress.md`.
2. Overwrite `.harness/state/session-handoff.md` with the current situation.
3. Run (or let the hook run) `bash .harness/hooks/post-agent.sh` and report its result.

---

## 4. State files

| File | Owner | Update when |
|---|---|---|
| `docs/backlog/backlog.json` | agent (with user approval) | a work item is added, split or redefined |
| `.harness/state/feature_list.json` | agent + user | a feature changes status, a new issue is created, a milestone moves |
| `docs/backlog/index.md` | generated | after any change to the two files above (`build_docs.py`) |
| `.harness/state/claude-progress.md` | agent | end of each session or meaningful step (append-only, newest at top) |
| `.harness/state/session-handoff.md` | agent | end of each session (overwrite) |

Never delete history from `claude-progress.md`.

---

## 5. Project-specific rules

> Add rules specific to this project below (coding conventions, forbidden libraries, naming, etc.). Keep the golden rules above intact unless the team agrees to change them.

- _None yet._
