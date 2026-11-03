#!/usr/bin/env bash
# tests/harness/run.sh — self-test of the agent harness.
# Verifies that the harness structure, configuration and state files are present and valid.
# Runs in CI and from init.sh. Exit 0 = all checks pass.

set -u
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1
# shellcheck source=../../.harness/hooks/lib.sh
. "$ROOT/.harness/hooks/lib.sh"

pass=0; fail=0
check() {  # check "<description>" <command...>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then pass=$((pass+1)); h_ok "$desc"; else fail=$((fail+1)); h_fail "$desc"; fi
}

echo "=== Harness self-test ==="

h_section "Required files"
required="AGENTS.md CLAUDE.md .cursorrules
.harness/templates/feature_list.json .harness/templates/claude-progress.md
.harness/templates/session-handoff.md .harness/templates/clean-state-checklist.md
.harness/env/sandbox.config .harness/hooks/lib.sh .harness/hooks/pre-agent.sh .harness/hooks/post-agent.sh
.harness/scripts/create_issues.py .githooks/pre-commit .githooks/commit-msg
.github/ISSUE_TEMPLATE/epic.yml .github/ISSUE_TEMPLATE/user-story.yml .github/ISSUE_TEMPLATE/task.yml
.github/ISSUE_TEMPLATE/bug.yml .github/pull_request_template.md
docs/project-context/PROJECT_CONTEXT.md docs/project-context/discovery-questionnaire.md
docs/process/definition-of-ready.md docs/process/definition-of-done.md docs/process/work-item-template.md
docs/resources/templates/init.sh docs/resources/templates/backlog.example.json
docs/index.md docs/business/overview.md docs/business/user-journeys.md
docs/business/roles-and-permissions.md docs/business/roadmap.md docs/business/glossary.md
docs/backlog/index.md docs/process/documentation-guide.md
.harness/docs-viewer/viewer.html .harness/docs-viewer/vendor/marked.min.js .harness/docs-viewer/vendor/mermaid.min.js
.harness/scripts/render_backlog.py .harness/scripts/build_docs.py
docs-site/index.html docs-site/_headers docs-site/robots.txt"
for f in $required; do check "exists: $f" test -f "$f"; done

h_section "Shell scripts"
for f in .harness/hooks/*.sh .githooks/* docs/resources/templates/init.sh tests/harness/*.sh; do
  check "bash syntax: $f" bash -n "$f"
  check "LF line endings: $f" sh -c "! grep -q \$'\r' '$f'"
done

h_section "Configuration"
check "sandbox.config is sourceable" bash -c ". .harness/env/sandbox.config"
for key in LINT_CMD FORMAT_CHECK_CMD TYPECHECK_CMD TEST_CMD BUILD_CMD PROTECTED_BRANCHES SECRET_PATTERNS FORBIDDEN_PATHS; do
  check "sandbox.config defines $key" grep -Eq "^$key=" .harness/env/sandbox.config
done

h_section "Issue templates contain mandatory sections"
for f in .github/ISSUE_TEMPLATE/epic.yml .github/ISSUE_TEMPLATE/user-story.yml .github/ISSUE_TEMPLATE/task.yml .github/ISSUE_TEMPLATE/bug.yml; do
  for id in description acceptance checklist dependencies estimate how_to_test; do
    check "$(basename "$f"): $id" grep -Eq "id: $id\$" "$f"
  done
done

h_section "Secret detection"
h_load_config >/dev/null 2>&1
fake_token="ghp_$(printf 'a%.0s' $(seq 1 36))"
check "detects a GitHub token" sh -c "printf '%s\n' 'x = \"$fake_token\"' | grep -Eq -- \"\$1\"" _ "$SECRET_PATTERNS"
check "ignores a normal line" sh -c "! printf '%s\n' 'const token = getToken(user)' | grep -Eq -- \"\$1\"" _ "$SECRET_PATTERNS"

h_section "JSON files"
if py="$(h_python)"; then
  check "feature_list template is valid" "$py" tests/harness/validate_json.py feature-list .harness/templates/feature_list.json
  if [ -f .harness/state/feature_list.json ]; then
    check "feature_list state is valid" "$py" tests/harness/validate_json.py feature-list .harness/state/feature_list.json
  fi
  check "backlog example is valid" "$py" .harness/scripts/create_issues.py --backlog docs/resources/templates/backlog.example.json --validate-only
  if [ -f docs/backlog/backlog.json ]; then
    check "project backlog is valid" "$py" .harness/scripts/create_issues.py --backlog docs/backlog/backlog.json --validate-only
  fi

  h_section "Documentation"
  check "generated docs are up to date (run build_docs.py)" "$py" .harness/scripts/build_docs.py --check
else
  h_warn "Python 3 not found: JSON checks skipped"
  fail=$((fail+1))
fi

echo
echo "Harness self-test: $pass passed, $fail failed"
[ $fail -eq 0 ]
