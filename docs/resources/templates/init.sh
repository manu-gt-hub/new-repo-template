#!/usr/bin/env bash
# docs/resources/templates/init.sh — harness bootstrap script for new environments.
#
# Run from anywhere inside the repository (fresh clone, new machine, CI, new project):
#   bash docs/resources/templates/init.sh
#   PROJECT_NAME="my-app" bash docs/resources/templates/init.sh
#
# What it does (idempotent — safe to re-run):
#   1. Checks prerequisites (git, bash, python3; gh only for bootstrap/maintainers).
#   2. Installs git hooks (core.hooksPath=.githooks) and makes scripts executable.
#   3. Creates .harness/state/ from .harness/templates/ if missing (never overwrites).
#   4. Creates a local .env from .env.example if present and .env is missing.
#   5. Sets the project name in the docs site and renders the backlog page.
#   6. Runs the harness self-test (tests/harness/run.sh).

set -u
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "init.sh: run inside a git repository."; exit 1; }
cd "$ROOT" || exit 1
# shellcheck source=../../../.harness/hooks/lib.sh
. "$ROOT/.harness/hooks/lib.sh"

PROJECT_NAME="${PROJECT_NAME:-$(basename "$ROOT")}"
TODAY="$(date '+%Y-%m-%d')"
errors=0

echo "=== Harness init: $PROJECT_NAME ==="

h_section "1. Prerequisites"
for tool in git bash; do
  if command -v "$tool" >/dev/null 2>&1; then h_ok "$tool found"; else h_fail "$tool not found"; errors=$((errors+1)); fi
done
if py="$(h_python)"; then h_ok "python found ($py)"; else h_fail "Python 3.8+ not found (needed by harness scripts)"; errors=$((errors+1)); fi
if command -v gh >/dev/null 2>&1; then
  h_ok "gh found"
  gh auth status >/dev/null 2>&1 && h_ok "gh authenticated" || h_warn "gh not authenticated (needed for bootstrap, backlog sync to GitHub issues, ruleset and PRs): gh auth login"
else
  h_warn "gh (GitHub CLI) not found — not needed for daily coding, but required for bootstrap, backlog sync to GitHub issues, ruleset and PRs. https://cli.github.com"
fi

h_section "2. Git hooks"
git config core.hooksPath .githooks && h_ok "core.hooksPath=.githooks"
chmod +x .githooks/* .harness/hooks/*.sh docs/resources/templates/init.sh tests/harness/*.sh 2>/dev/null || true
h_ok "Scripts marked executable"

h_section "3. Harness state"
mkdir -p "$HARNESS_STATE"
for f in feature_list.json claude-progress.md session-handoff.md; do
  if [ -f "$HARNESS_STATE/$f" ]; then
    h_info "$f exists, kept"
  else
    sed -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" -e "s/{{DATE}}/$TODAY/g" "$HARNESS_TEMPLATES/$f" > "$HARNESS_STATE/$f"
    h_ok "Created .harness/state/$f"
  fi
done

h_section "3b. Documentation site"
for f in docs/index.md; do
  if [ -f "$f" ] && grep -q '{{PROJECT_NAME}}' "$f"; then
    sed -i.bak "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$f" && rm -f "$f.bak"
    h_ok "Project name set in $f"
  fi
done
if py="$(h_python)"; then
  "$py" .harness/scripts/build_docs.py >/dev/null && h_ok "Docs built (backlog page + docs-site/index.html)"
fi

h_section "4. Local environment"
if [ -f .env.example ] && [ ! -f .env ]; then
  cp .env.example .env && h_ok "Created .env from .env.example (git-ignored; fill in local values)"
else
  h_info "No .env to create"
fi

h_section "5. Self-test"
if bash tests/harness/run.sh; then
  h_ok "Harness self-test passed"
else
  h_fail "Harness self-test failed"
  errors=$((errors+1))
fi

echo
if [ $errors -gt 0 ]; then
  echo "=== init finished with $errors error(s) ==="
  exit 1
fi
echo "=== init finished OK. Next: read AGENTS.md ==="
