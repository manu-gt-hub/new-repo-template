# Clean-state checklist

Strict criteria the agent must verify **before declaring any task finished** (and before ending a session). Report every item as ✅ / ❌ / N/A with evidence. One ❌ means the task is **not** done.

This complements the team-level [Definition of Done](../../docs/process/definition-of-done.md): the DoD says *what* done means; this checklist is the agent's mechanical pre-flight to prove it.

## 1. Scope
- [ ] Every change maps to the current issue's acceptance criteria.
- [ ] No unrequested refactors, renames, reformatting, features or dependencies.
- [ ] Out-of-scope findings were logged, not fixed.

## 2. Verification (run, don't assume)
- [ ] `LINT_CMD` passes — paste the summary line.
- [ ] `FORMAT_CHECK_CMD` passes.
- [ ] `TYPECHECK_CMD` passes (if configured).
- [ ] `TEST_CMD` passes — paste passed/failed counts.
- [ ] New/changed behaviour has tests; each acceptance criterion is covered by at least one test.
- [ ] The issue's "How to test" steps were executed.
- [ ] `BUILD_CMD` succeeds (if configured).

## 3. Hygiene
- [ ] No debug prints, commented-out code, temporary files, or `TODO` without an issue reference.
- [ ] No secrets, tokens, `.env` files or personal data in the diff (`git diff --cached` reviewed).
- [ ] No large binaries or generated artifacts committed unintentionally.
- [ ] `git status` shows only intended changes; no untracked leftovers.

## 4. Constraints from PROJECT_CONTEXT
- [ ] Data is stored where the hosting/residency decision says.
- [ ] Authorization follows the permission matrix.
- [ ] No new paid service or cost increase without approval.
- [ ] UI changes follow the design system / accessibility target.

## 5. Records
- [ ] Commits follow Conventional Commits and reference the issue.
- [ ] Docs / ADRs updated if behaviour or decisions changed (technical docs and, in plain language, `docs/business/`).
- [ ] `.harness/state/feature_list.json` status updated.
- [ ] Generated docs committed and up to date: `docs/backlog/index.md` and `docs-site/` (`build_docs.py --check`).
- [ ] `.harness/state/claude-progress.md` entry appended.
- [ ] `.harness/state/session-handoff.md` overwritten with the current situation.

## 6. Communication
- [ ] Summary for the user states what was done, what was verified (with real output) and what was not.
- [ ] Any skipped step or failing check is reported explicitly.
