# BOOTSTRAP.md — Creating a new project from this template

**Audience:** the AI agent that receives a request like:

> "I want to build a project that does X and Y, it will have a UI, user management, etc.
> Create it on `https://github.com/<owner>/<new-repo>` and use `https://github.com/<owner>/new-repo-template` as the template."

Follow the phases **in order**. Each phase ends with a checkpoint where you must get the user's confirmation before moving on. Never skip discovery, even if the user seems in a hurry — instead, propose defaults they can accept in one go.

---

## Phase 0 — Inputs and preflight

Collect and verify:

| Input | Required | Notes |
|---|---|---|
| Project description | yes | Free text from the user. |
| Target repository URL | yes | Must exist and you must have push access. If it does not exist, **ask** before creating it (`gh repo create`). |
| Template repository URL | yes | This repository. |
| Default branch of target | no | Assume `main`. |
| Artifact language | no | **English**, unless the user explicitly asks for another language. Docs, backlog, issues, commits and code all use it. Writing to you in Spanish (or any language) is **not** a request to change it; if in doubt, ask. Record the choice in PROJECT_CONTEXT. |

### Preflight

Get the template (reused in Phase 3) and run the preflight script. It needs only `git` and `bash`:

```bash
WORK=$(mktemp -d)
git clone <template-url> "$WORK/template"
bash "$WORK/template/.harness/scripts/preflight.sh" <owner>/<new-repo>
```

It checks git, Python 3.8+, the GitHub CLI (also when it is installed but not on `PATH`), the login, the token scopes (`repo`, `workflow`, `project`) and your access to the target repository. For anything missing it prints the exact install or fix command for this OS (for example `winget install -e --id GitHub.cli`, `brew install gh`, `gh auth refresh -s project`). The harness scripts find `gh` even when it is not on `PATH`.

- **Exit 1 (blockers):** show the user the list of fixes the script printed. **Offer to run them for them** (installing software and `gh auth` changes need their explicit yes; `gh auth login`/`refresh` open a browser, so the user completes them). After installing, the terminal may need to be reopened. Re-run the preflight until it says `READY`. Do not continue with blockers.
- **Warnings:**
  - *Permission WRITE/MAINTAIN:* fine, but the ruleset in Phase 5 needs ADMIN.
  - *Branch already protected:* bootstrap pushes to `main` will be rejected. Ask the user whether to disable the protection temporarily (Phase 5 re-applies the model ruleset) or to deliver the scaffold through a pull request instead.
  - *Repository not empty:* tell the user what is there and ask whether to merge the harness into it or abort. Never overwrite existing files without explicit permission.
  - *Repository not found:* ask before creating it (`gh repo create <owner>/<new-repo> --private`).

### Tell the user what is manual, before starting

Show this list right after the preflight, so nothing surprises them later. Everything else is automated.

| When | Manual step | Why |
|---|---|---|
| Now, if the preflight asks | Install Python / `gh`, run `gh auth login` or `gh auth refresh -s project` | Logins open a browser; installing needs their consent |
| Phase 4, ~1 min | In the Kanban board: **Workflows → Auto-add to project** → on, filter `is:issue` | GitHub has no API for it; without it, issues created later are not added to the board automatically |
| Phase 5, optional | Publish the docs site: **GitHub Pages** (the agent can switch it on with one command, public site) or **Cloudflare Pages** (dashboard steps, can be private) | Outward-facing; needs their choice and account |
| Phase 5, if the project needs them | Add CI secrets (Settings → Secrets and variables → Actions) | Agents never handle secret values |
| Only on **private** repos with a free plan | Nothing to do, but the ruleset and GitHub Pages are unavailable (need GitHub Pro/Team); `main` stays unprotected and docs go to Cloudflare or offline | Plan limitation |

---

## Phase 1 — Discovery

Goal: fill every section of [docs/project-context/PROJECT_CONTEXT.md](docs/project-context/PROJECT_CONTEXT.md) with real decisions, not guesses.

1. Read [docs/project-context/discovery-questionnaire.md](docs/project-context/discovery-questionnaire.md).
2. Map the user's description against it. For every question classify the answer as:
   - **Answered** — clearly stated by the user.
   - **Implied** — reasonably inferable; you will state it as an assumption for confirmation.
   - **Missing** — not stated and not inferable.
3. Ask about **Missing** items and confirm **Implied** ones. Rules for asking:
   - Group questions by area, in the order of the questionnaire. Max ~8 questions per round.
   - For every question, offer a **recommended default** and 2–3 alternatives, so the user can answer "accept defaults".
   - Mandatory areas that must never be silently assumed: **data hosting & residency, scalability, security, cost control, access control, user interface**.
   - If the user's answers create new ambiguity, do another round. Stop when nothing mandatory is missing.
4. Present a **Discovery summary** (one table per area: decision / source = user | default accepted | assumption).

**Checkpoint 1:** the user confirms the discovery summary.

---

## Phase 2 — Planning

Produce, in your scratch space (not yet in the target repo):

1. **PROJECT_CONTEXT.md** — filled from the discovery summary. Replace every `TODO`.
2. **Business documentation** (`docs/business/*.md` + `docs/index.md`), in **plain language for non-technical readers**, with Mermaid diagrams. See [documentation-guide.md](docs/process/documentation-guide.md):
   - `overview.md`: problem, solution, personas, value and success metrics, scope, and constraints (data location, growth, security, costs, access) in business terms.
   - `user-journeys.md`: one flowchart (or sequence diagram) per key journey from discovery, linked to backlog keys.
   - `roles-and-permissions.md`: roles, capability matrix and account lifecycle (consistent with PROJECT_CONTEXT §6).
   - `roadmap.md`: milestones, what users get in each, and a timeline.
   - `glossary.md`: domain terms collected during discovery.
   - `index.md`: the "project at a glance" table.
   Replace every `TODO`. Remove example rows and diagrams that do not apply.
3. **docs/architecture/overview.md**: high-level components, data flow, hosting and integrations, as text plus a Mermaid diagram.
4. **ADRs**: one ADR per major decision (stack, hosting, auth provider, database). Copy `docs/resources/templates/adr-template.md` to `docs/architecture/decisions/NNNN-title.md`.
5. **Backlog** (`backlog.json`, format in [docs/resources/templates/backlog.example.json](docs/resources/templates/backlog.example.json); set `"repository": "<owner>/<new-repo>"` so the docs link to issues):
   - Milestones (e.g. `M0 Foundations`, `M1 MVP`, `M2 …`).
   - Epics → user stories → tasks. Every item follows [docs/process/work-item-template.md](docs/process/work-item-template.md): description, acceptance criteria, checklist, dependencies, estimation, how to test.
   - The first milestone **must** include foundation work: repo tooling (lint/format/test commands wired into `sandbox.config`), CI, environments, auth skeleton, observability baseline, as applicable.
   - Every item must satisfy the [Definition of Ready](docs/process/definition-of-ready.md).
   - Dependencies reference other items by their backlog `key` (e.g. `"depends_on": ["US-001"]`). No cycles.
6. **sandbox.config commands**: proposed `LINT_CMD`, `FORMAT_CHECK_CMD`, `TYPECHECK_CMD`, `TEST_CMD` and `BUILD_CMD` for the chosen stack. They may point to tooling that a foundation task will install.
7. **DoR / DoD adjustments**: ask whether the user wants to change the defaults. Apply only what they ask.

Show the user: the backlog as a table (key, type, title, estimate, depends on, milestone), a summary of the business overview and user journeys, and the list of files that will be written.

**Checkpoint 2:** the user approves the plan and backlog (they may edit it first).

---

## Phase 3 — Scaffold the target repository

```bash
# $WORK/template was cloned in Phase 0
git clone <target-url> "$WORK/target"
```

Copy everything from the template **except**:

| Exclude | Reason |
|---|---|
| `.git/` | belongs to the template |
| `BOOTSTRAP.md` | template-only procedure |
| `README.md` | replaced by a project README generated from `docs/resources/templates/README.project.md` |
| `LICENSE` | ask the user which license (default: keep the same one with the user's name/year) |
| `.harness/state/` | regenerated by `init.sh` |

Then, inside `$WORK/target`:

1. Write the files produced in Phase 2: PROJECT_CONTEXT, business docs, architecture overview, ADRs, README and adjusted DoR/DoD.
   Save the approved backlog as **`docs/backlog/backlog.json`**. It is committed, so the repository holds code, docs and backlog together.
2. Set the commands in `.harness/env/sandbox.config`. If the tooling does not exist yet (it will be installed by a foundation task), leave `LINT_CMD`/`FORMAT_CHECK_CMD`/`TYPECHECK_CMD` empty for now. Hooks report empty commands as SKIPPED, and the foundation task fills them in.
3. In `AGENTS.md` section 0, delete the rows about bootstrapping and maintaining the template (the project is now initialized). Add project-specific rules in section 5 if discovery produced any.
4. In `.gitignore`, delete the `# TEMPLATE-ONLY` comment and the `.harness/state/` line under it, so the project's state is committed.
5. Run the harness initializer:
   ```bash
   PROJECT_NAME="<name>" bash docs/resources/templates/init.sh
   ```
   It installs git hooks, creates `.harness/state/` from the templates and runs the harness self-test.
6. Generate `.harness/state/feature_list.json` and the backlog page from the backlog (issue numbers stay `null` until Phase 4):
   ```bash
   python .harness/scripts/create_issues.py --backlog docs/backlog/backlog.json --validate-only \
       --write-feature-list .harness/state/feature_list.json
   ```
   Then build the documentation site: `python .harness/scripts/build_docs.py`. It writes `docs-site/` (committed; the pre-commit hook also keeps it up to date). Open `docs-site/index.html` to check it renders.
7. Commit on `main`. The pre-commit hook blocks commits on protected branches, so use the one-off override. It is authorized here because the user asked for the project on `main`:
   ```bash
   git add -A
   HARNESS_ALLOW_PROTECTED_COMMIT=1 git commit -m "chore: bootstrap project from harness template"
   ```

**Checkpoint 3:** show `git show --stat HEAD` and ask for confirmation to push to `main`. Then `git push origin main`.

> Pushing to `main` is allowed **only** here, during bootstrap, because the user explicitly requested it. After bootstrap, golden rule 6 applies.

---

## Phase 4 — Create GitHub issues

1. The approved backlog is already in `docs/backlog/backlog.json` (Phase 3).
2. Dry run first and show the output:
   ```bash
   python .harness/scripts/create_issues.py --repo <owner>/<new-repo> --backlog docs/backlog/backlog.json --dry-run
   ```
3. **Checkpoint 4:** the user confirms. Then run without `--dry-run`. The script:
   - creates labels (`type:*`, `priority:*`, `size:*`, `area:*`) and milestones,
   - creates issues in dependency order with the work-item body structure,
   - links dependencies (`Depends on #N` in the body and, when the API is available, GitHub "blocked by" relationships),
   - links stories to their epic (task list in the epic body + sub-issues when available),
   - writes a mapping `key → issue number` to `--out` (default `issue-map.json`),
   - creates a GitHub Project named **Kanban board** (`--project-title` to rename it), links it to the repo so it shows in the **Projects** tab, adds every backlog issue (new ones in the **Todo** column) and adds a **Board** view with one column per Status. If it exits with code 2, the issues are fine but the board failed (usually the missing `project` scope): fix it and re-run, nothing is duplicated.
   Tell the user one manual step: in the project, **Workflows → Auto-add to project** (filter `is:issue`) so issues created later are added automatically. GitHub does not expose this through the API.
   Pass `--write-feature-list .harness/state/feature_list.json` so the feature list gets the issue numbers, then run `python .harness/scripts/build_docs.py` so the docs link to the issues.
4. Commit with `HARNESS_ALLOW_PROTECTED_COMMIT=1 git commit -m "chore: link feature list to GitHub issues"` and push to `main`. The Checkpoint 3 authorization covers this; tell the user.

---

## Phase 5 — Handoff

1. Append the bootstrap entry to `.harness/state/claude-progress.md` and write `.harness/state/session-handoff.md` (next recommended issue, open questions, assumptions to validate). Commit and push them together with the step 4 commit if possible.
2. **Protect `main` with the model ruleset**, the last step because from now on `main` only accepts pull requests. Show the user what `.github/rulesets/main.json` enforces: no deletion, no force-push, PR required (0 approvals, Code Owners review), and the CI checks `Harness self-test…` and `Lint, test, build` required with the branch up to date. Ask whether to adjust it, then run a dry run.
   ```bash
   bash .harness/scripts/apply_ruleset.sh <owner>/<new-repo> --dry-run
   ```
   **Checkpoint 5:** after confirmation, run it without `--dry-run`. Also set `.github/CODEOWNERS` to the project owner(s) (ask; default: the user). If the API answers 403/404 on a private repo, rulesets need GitHub Pro/Team: tell the user and skip.
   In the same checkpoint, switch on GitHub **secret scanning and push protection** (GitHub blocks pushes that contain known token formats, a stronger net than the local regex in `sandbox.config`):
   ```bash
   echo '{"security_and_analysis":{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}}' \
     | gh api -X PATCH repos/<owner>/<new-repo> --input - >/dev/null
   ```
   Free on public repositories. On private ones it needs GitHub Secret Protection; if the API refuses, tell the user and skip.
3. **Acceptance check (mandatory).** In `$WORK/target`, run:
   ```bash
   bash .harness/scripts/verify_bootstrap.sh
   ```
   It checks template leftovers, `TODO`s, state files, hooks, backlog, docs, language, issues, the Kanban board, the ruleset and that everything is pushed. Fix every `[FAIL]` and re-run until it prints `PASS`. **Do not report the bootstrap as done before that**; if something cannot be fixed (for example the ruleset on a free private repo), tell the user exactly which check and why.
4. Report to the user:
   - target repo URL and commit SHA(s),
   - how to view the documentation: double-click `docs-site/index.html`, or publish it online (`docs/process/documentation-guide.md`, section *Publishing online*). Ask which option they want: **GitHub Pages** (public; you can switch it on with its two commands after their yes) or **Cloudflare Pages** (private; walk them through it). Do not publish anything without explicit permission,
   - number of issues/milestones created with links,
   - assumptions that still need validation,
   - suggested first issue to start with,
   - whether the ruleset was applied (link to `https://github.com/<owner>/<new-repo>/rules`),
   - the remaining manual steps from the Phase 0 list (auto-add workflow on the board, CI secrets, docs publishing if not done).
5. Delete `$WORK` only after the user confirms everything is in place.

---

## Failure handling

- If any step fails, stop, show the exact error, and propose a fix. Do not continue to the next phase.
- `create_issues.py` is idempotent: it finds existing issues by backlog key (or exact title) and skips them, and reuses the board. Use this to resume a partial run.
- Never delete issues or force-push to recover; ask the user.
