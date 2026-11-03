# CLAUDE.md

All agent instructions live in **AGENTS.md** (imported below) so that every AI tool shares the same rules.

@AGENTS.md

## Claude Code specifics

- Hooks in `.claude/settings.json` run `.harness/hooks/pre-agent.sh` on session start and `.harness/hooks/post-agent.sh` when you stop. Read their output; do not ignore warnings.
- Use the TodoWrite/task list for multi-step work, but the persistent record is `.harness/state/claude-progress.md`.
- If you are asked to bootstrap a new project, follow `BOOTSTRAP.md` and use the `AskUserQuestion` tool for discovery questions when available.
