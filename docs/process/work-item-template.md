# Work item template

Every epic, user story, task and bug **must** follow this structure. The GitHub issue forms in [.github/ISSUE_TEMPLATE/](../../.github/ISSUE_TEMPLATE/) implement it for humans; [.harness/scripts/create_issues.py](../../.harness/scripts/create_issues.py) renders it for issues created by agents.

## Types and hierarchy

```
Milestone (M0 Foundations, M1 MVP, …)
└── Epic            large capability; spans several stories
    └── User story  user-visible value, fits in one iteration
        └── Task    technical unit of work, ideally ≤ 1 day
Bug                 defect in existing behaviour (linked to the story/epic it affects)
```

## Sections

| Section | Epic | Story | Task | Bug | Content |
|---|---|---|---|---|---|
| **Description** | ✔ | ✔ | ✔ | ✔ | What and why. Stories use *As a … I want … so that …*. |
| **Acceptance criteria** | ✔ | ✔ | ✔ | ✔ | Testable statements, preferably Given / When / Then. |
| **Checklist** | ✔ | ✔ | ✔ | ✔ | Concrete sub-steps to complete (implementation, tests, docs…). For epics: list of child stories. |
| **Dependencies** | ✔ | ✔ | ✔ | opt. | Items that must be done first (`Depends on #N`) and items this one blocks. External dependencies too (accounts, API keys, decisions). |
| **Estimation** | ✔ | ✔ | ✔ | ✔ | Story points (Fibonacci) — see scale below. Epics: sum of children or T-shirt size. |
| **How to test** | ✔ | ✔ | ✔ | ✔ | Automated tests to add/run + manual verification steps + test data. |
| **Out of scope** | opt. | ✔ | opt. | opt. | What this item explicitly does not cover. |
| **Technical notes** | opt. | opt. | ✔ | opt. | Approach, affected modules, risks. |
| **Security / access** | opt. | ✔ | opt. | opt. | Which roles can do this; data sensitivity. |
| **Steps to reproduce / Expected / Actual** | | | | ✔ | Bug-specific. |
| **Definition of Ready** | ✔ | ✔ | ✔ | ✔ | Checkbox confirming the [DoR](definition-of-ready.md) is met. |

## Estimation scale (story points)

| Points | Size | Meaning |
|---|---|---|
| 1 | XS | Trivial, well understood, < 2h |
| 2 | S | Small, clear approach, ~half day |
| 3 | M | About a day, some unknowns |
| 5 | L | 2–3 days, several components |
| 8 | XL | ~1 week, significant unknowns — consider splitting |
| 13 | XXL | Too big — **must** be split before it is Ready |

## Labels

| Prefix | Values |
|---|---|
| `type:` | `epic`, `story`, `task`, `bug`, `spike` |
| `priority:` | `p0` (critical), `p1` (high), `p2` (normal), `p3` (low) |
| `size:` | `xs`, `s`, `m`, `l`, `xl` |
| `area:` | project-specific (e.g. `frontend`, `backend`, `infra`, `auth`, `data`, `docs`) |

## Markdown body (rendered by agents)

```markdown
## Description
As a <persona>, I want <capability>, so that <benefit>.
<context and motivation>

## Acceptance criteria
- [ ] Given <context>, when <action>, then <outcome>.
- [ ] ...

## Checklist
- [ ] Implementation
- [ ] Unit / integration tests
- [ ] Docs updated

## Dependencies
- Depends on: #12, #13
- Blocks: #20
- External: <API key from X>

## Estimation
**3 points** (M)

## How to test
1. Automated: `<test command or test file>`
2. Manual: <steps> → expected <result>

## Out of scope
- ...

## Technical notes
...

## Security / access
Roles allowed: ...

---
Parent: #<epic>  ·  Milestone: <M1 MVP>
- [x] Meets the Definition of Ready
```
