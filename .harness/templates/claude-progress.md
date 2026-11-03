# Progress log — {{PROJECT_NAME}}

Running journal of the AI agent(s). **Append-only, newest entry at the top.** Never delete past entries.

Entry format:

```markdown
## YYYY-MM-DD HH:MM — <agent/tool> — <issue #N or "bootstrap">
**Goal:** what the session set out to do
**Done:**
- ...
**Verification:** commands run and their real result (lint/tests/manual)
**Decisions:** decisions taken (link ADRs) and who approved them
**Out-of-scope findings:** things noticed but not touched (proposed issues)
**Blocked / open questions:** ...
**Next:** ...
```

---

## {{DATE}} — harness — init
**Goal:** initialize the agent harness.
**Done:**
- Created `.harness/state/` from templates.
- Installed git hooks (`core.hooksPath=.githooks`).
**Verification:** `bash tests/harness/run.sh` executed by `init.sh`.
**Next:** run discovery / pick the first issue.
