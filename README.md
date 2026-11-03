# new-repo-template

A **project template with an agent harness** for AI-assisted development. Instead of creating an empty repo and vibe-coding, you give an AI agent a description of your project and this template. The agent then:

1. **Interviews you** about anything missing: data hosting, scalability, security, cost control, access control, user interface, and so on.
2. **Plans** the project: project context, architecture, ADRs, and a backlog of epics, stories and tasks that meet the Definition of Ready.
3. **Scaffolds** the new repository on `main` with rules, harness, hooks, CI and DoR/DoD. It also writes a **project wiki**: business docs in plain language with flowcharts, architecture, and the backlog. The wiki is viewable as a pretty offline site and doubles as AI context. The resulting repo holds **code + documentation + backlog** together.
4. **Creates the GitHub issues** with description, acceptance criteria, checklist, dependencies, estimation and how-to-test, plus labels and milestones.

It asks for your confirmation at each checkpoint.

## How to use it

Prerequisites on the machine where the agent runs: `git`, `bash` (Git Bash on Windows), Python 3.8+, and the [GitHub CLI](https://cli.github.com) authenticated with `gh auth login`. The target repository must exist (it can be empty).

Then ask your agent something like:

> I want to build a project that does X and Y. It will have a UI, user management, etc.
> Create it on `https://github.com/<you>/<new-repo>` using `https://github.com/manu-gt-hub/new-repo-template` as the template.
> Follow the template's BOOTSTRAP.md.

The agent follows [BOOTSTRAP.md](BOOTSTRAP.md).

## What's inside

```
├── AGENTS.md / CLAUDE.md / .cursorrules   # rules + system map for AI agents
├── BOOTSTRAP.md                           # procedure to create a project from this template
├── .claude/settings.json                  # Claude Code hooks + permission guardrails
├── .harness/
│   ├── templates/                         # feature_list.json, claude-progress.md,
│   │                                      # session-handoff.md, clean-state-checklist.md
│   ├── env/sandbox.config                 # lint/test/build commands + sandbox policy
│   ├── hooks/pre-agent.sh, post-agent.sh  # session start / end checks
│   └── scripts/create_issues.py           # backlog JSON → labels, milestones, issues
├── .githooks/pre-commit, commit-msg       # lint + secrets before commit, Conventional Commits
├── .github/ISSUE_TEMPLATE/                # epic, user story, task, bug forms
├── .github/workflows/ci.yml               # harness self-test + configured checks
├── docs-site/                            # GENERATED docs site: one index.html (offline or Cloudflare Pages)
├── docs/                                  # project wiki: Markdown, for humans and AI agents
│   ├── index.md                           # home: where to start per audience
│   ├── business/                          # plain-language overview, user journeys, roles, roadmap, glossary
│   ├── backlog/                           # backlog.json (source) → index.md (generated, with dependency map)
│   ├── project-context/                   # PROJECT_CONTEXT.md + discovery questionnaire
│   ├── process/                           # Definition of Ready, Definition of Done, work item template
│   ├── architecture/                      # overview + ADRs
│   └── resources/templates/               # init.sh, backlog.example.json, README.project.md
└── tests/                                 # mandatory verification system (harness self-test included)
```

## Documentation site (project wiki)

Every generated project includes a documentation site. Business people get flowcharts, roadmap and backlog progress; developers and AI agents read the same Markdown files in the repo.

Readers install nothing:

- **Online:** connect the repository to **Cloudflare Pages** (build command: *none*, output directory: `docs-site`). Every push to `main` updates the site, and access can be restricted to your company with Cloudflare Access. Steps are in [documentation-guide.md](docs/process/documentation-guide.md#publishing-online-cloudflare-pages).
- **Offline:** double-click `docs-site/index.html`.

`docs-site/` is generated from `docs/` by `.harness/scripts/build_docs.py` (Python standard library only), and the pre-commit hook regenerates it automatically. It includes navigation, search, Mermaid diagrams and light/dark themes, and everything is embedded, so no CDN or internet is needed.

## Key rules for agents (summary of [AGENTS.md](AGENTS.md))

- Do only what the user asked, and ask before doing anything else.
- Ask clarifying questions when requirements are unclear.
- Run lint, format check, type check and tests before every commit. Never bypass hooks.
- Never commit secrets. Never push to `main` or force-push without explicit permission.
- One issue at a time. Check the DoR before starting, and the DoD plus the clean-state checklist before calling it done.
- Leave a trail: progress log and session handoff at the end of every session.

## Customizing per project

Everything is meant to be adapted in the generated repository:

- [Definition of Ready](docs/process/definition-of-ready.md) and [Definition of Done](docs/process/definition-of-done.md). Record changes in their changelog.
- Project-specific agent rules: [AGENTS.md section 5](AGENTS.md#5-project-specific-rules).
- Commands and policies: [.harness/env/sandbox.config](.harness/env/sandbox.config).

## Maintaining the template

```bash
bash docs/resources/templates/init.sh   # install hooks and create local state
bash tests/harness/run.sh               # self-test
```

In this template repository, `.harness/state/` is git-ignored (the entry is marked `TEMPLATE-ONLY` in `.gitignore`). Generated projects remove that line and commit their own state. The `TODO` placeholders in `PROJECT_CONTEXT.md` and `docs/architecture/overview.md` are intentional here.

Tip: mark this repository as a template on GitHub (Settings → Template repository) so it can also be used with "Use this template".

## License

[MIT](LICENSE)
