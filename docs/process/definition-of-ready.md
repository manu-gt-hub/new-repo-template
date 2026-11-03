# Definition of Ready (DoR)

A work item (epic, user story, task or bug) is **Ready** when it can be picked up and finished without further clarification. Agents must check this list before starting work and must **not** start an item that fails it — instead, list what is missing and ask the user.

> This is the template baseline. Each project may adapt it; record changes in the changelog at the bottom.

## All work items

- [ ] **Title** is short, specific and starts with a verb (tasks) or describes the user outcome (stories).
- [ ] **Description** explains the *what* and the *why*; a reader without prior context understands it.
- [ ] **Acceptance criteria** are listed, testable and unambiguous (Given / When / Then preferred).
- [ ] **How to test** describes how a reviewer can verify the result (automated tests + manual steps if any).
- [ ] **Dependencies** are identified and each blocking dependency is either done or explicitly accepted as parallel work.
- [ ] **Estimate** is assigned (story points or size) and the item fits in one iteration; otherwise it is split.
- [ ] **Out of scope** is stated when there is any risk of misunderstanding.
- [ ] **Labels** for type, priority and area are set; it belongs to a **milestone**.
- [ ] No open questions remain in the item (or they are resolved in comments).
- [ ] It does not contradict [PROJECT_CONTEXT.md](../project-context/PROJECT_CONTEXT.md) (hosting, security, access control, cost, UI). If it does, the context is updated first.

## User stories (additionally)

- [ ] Written as *As a `<persona>`, I want `<capability>`, so that `<benefit>`*.
- [ ] Follows INVEST (Independent, Negotiable, Valuable, Estimable, Small, Testable).
- [ ] UI stories reference a mockup/wireframe or describe the expected UI states (empty, loading, error, success).
- [ ] Security / permission implications are noted (who may do this?).

## Tasks (additionally)

- [ ] Linked to its parent story or epic.
- [ ] Technical approach is outlined when non-obvious.

## Bugs (additionally)

- [ ] Steps to reproduce, expected vs actual behaviour, environment/version.
- [ ] Severity is set.

---

## Changelog

| Date | Change | Agreed by |
|---|---|---|
| — | Template baseline | — |
