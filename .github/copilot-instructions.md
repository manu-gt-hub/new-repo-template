# Copilot instructions

All rules for AI agents in this repository live in [AGENTS.md](../AGENTS.md). Read it fully before acting; it wins over anything else. The rules are not copied here on purpose, so they cannot drift.

Copilot does not run the harness hooks automatically, so also run `bash .harness/hooks/pre-agent.sh` at the start of a session (read its output) and `bash .harness/hooks/post-agent.sh` at the end (report its result).
