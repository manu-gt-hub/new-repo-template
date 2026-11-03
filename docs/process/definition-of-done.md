# Definition of Done (DoD)

A work item is **Done** only when every applicable item below is true. Agents verify it together with the [clean-state checklist](../../.harness/templates/clean-state-checklist.md) and report each point honestly. If something cannot be met, the item is **not** done — explain why and ask the user.

> This is the template baseline. Each project may adapt it; record changes in the changelog at the bottom.

## Code

- [ ] All acceptance criteria are met and demonstrated.
- [ ] Code follows project conventions; no dead code, commented-out blocks, debug output or stray `TODO`s without a linked issue.
- [ ] Lint, format check and type check pass (`LINT_CMD`, `FORMAT_CHECK_CMD`, `TYPECHECK_CMD`).
- [ ] No new warnings introduced.
- [ ] Only changes within the scope of the item; unrelated changes are split out.

## Tests

- [ ] Automated tests cover every acceptance criterion (unit and/or integration; e2e for critical user flows).
- [ ] The full test suite passes locally (`TEST_CMD`) and in CI.
- [ ] Edge cases and error paths are tested, not only the happy path.
- [ ] The "How to test" section of the issue has been executed and the result recorded.

## Security, data & cost

- [ ] No secrets, credentials or personal data committed.
- [ ] Input validation and authorization checks are in place for new endpoints/actions (per the permission matrix in PROJECT_CONTEXT).
- [ ] New dependencies were approved by the user and have no known critical vulnerabilities.
- [ ] Any new paid service or usage increase was approved and has a spending limit.
- [ ] Data storage respects the hosting/residency decisions.

## Documentation

- [ ] README / docs updated if behaviour, setup or configuration changed.
- [ ] Business docs (`docs/business/`) updated in plain language if scope, user flows, roles or roadmap changed; diagrams updated.
- [ ] Generated docs are up to date: `docs/backlog/index.md` and `docs-site/` (the pre-commit hook does this; CI verifies it).
- [ ] Significant technical decisions recorded as an ADR.
- [ ] Public APIs documented.

## Delivery

- [ ] Commits follow Conventional Commits and reference the issue.
- [ ] Pull request opened with the PR template filled in, linked to the issue (`Closes #N`), CI green.
- [ ] Reviewed and approved per the project's git workflow.
- [ ] `.harness/state/feature_list.json` and `.harness/state/claude-progress.md` updated.
- [ ] Deployed to the target environment (if the workflow includes deployment) and smoke-tested.

---

## Changelog

| Date | Change | Agreed by |
|---|---|---|
| — | Template baseline | — |
