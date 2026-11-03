# tests/ — mandatory verification system

Tests are the **success criterion** of every work item: a task is not done until its acceptance criteria are covered by tests that pass (see the [Definition of Done](../docs/process/definition-of-done.md)).

## Layout

```
tests/
├── harness/        # self-test of the agent harness (structure, config, state). Do not delete.
│   ├── run.sh
│   └── validate_json.py
├── unit/           # fast, isolated tests of single units (create when the stack is chosen)
├── integration/    # tests across modules / with real dependencies (DB, queues) in containers
└── e2e/            # critical user flows through the real UI / API
```

> Some stacks keep tests next to the source (e.g. `src/**/*.test.ts`, Go `_test.go`). That is fine: document the convention in `AGENTS.md` section 5 and keep `tests/` for harness, integration and e2e tests.

## Rules

1. Every acceptance criterion maps to at least one automated test. Name tests after the behaviour, e.g. `test_admin_can_disable_user`.
2. Bugs get a regression test that fails before the fix.
3. Tests must be deterministic: no reliance on wall-clock time, randomness without a seed, or external services without mocks/containers.
4. Never delete, skip or weaken a test to make the suite pass. If a test is wrong, explain why and ask the user.
5. The full suite is run by `TEST_CMD` (see [sandbox.config](../.harness/env/sandbox.config)) and by CI on every PR.
6. Test data must not contain real personal data or secrets.

## Running

```bash
bash tests/harness/run.sh                       # harness self-test only
. .harness/env/sandbox.config && bash -c "$TEST_CMD"   # full suite as configured
```
