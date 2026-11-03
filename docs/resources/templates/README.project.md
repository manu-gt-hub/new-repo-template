# {{PROJECT_NAME}}

{{ONE_PARAGRAPH_DESCRIPTION}}

## Status

See [milestones]({{REPO_URL}}/milestones) and [.harness/state/feature_list.json](.harness/state/feature_list.json).

## Getting started

```bash
git clone {{REPO_URL}}.git
cd {{PROJECT_NAME}}
bash docs/resources/templates/init.sh   # installs git hooks and harness state
{{INSTALL_COMMANDS}}
```

| Task | Command |
|---|---|
| Lint | `{{LINT_CMD}}` |
| Format check | `{{FORMAT_CHECK_CMD}}` |
| Test | `{{TEST_CMD}}` |
| Build | `{{BUILD_CMD}}` |
| Run locally | `{{RUN_CMD}}` |

## Documentation

All documentation lives in [docs/](docs/) and is also available as a browsable site with diagrams, search, and light and dark themes. Nothing to install:

- **Online:** {{DOCS_URL}}
- **Offline:** double-click [docs-site/index.html](docs-site/index.html).

Highlights:

- [Business overview](docs/business/overview.md) · [User journeys](docs/business/user-journeys.md) · [Roadmap](docs/business/roadmap.md)
- [Backlog](docs/backlog/index.md): all epics, stories and tasks with status and dependencies
- [Project context](docs/project-context/PROJECT_CONTEXT.md) — scope and cross-cutting decisions
- [Architecture](docs/architecture/overview.md) (including ADRs)
- [Definition of Ready](docs/process/definition-of-ready.md) · [Definition of Done](docs/process/definition-of-done.md)
- [Work item template](docs/process/work-item-template.md)

## Working with AI agents

This repository uses an agent harness. Agents must follow [AGENTS.md](AGENTS.md); session state lives in [.harness/state/](.harness/state/).

## License

{{LICENSE}}
