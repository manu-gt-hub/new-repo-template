#!/usr/bin/env bash
# .harness/hooks/post-agent.sh
#
# Runs AFTER the agent finishes (Claude Code: Stop hook; other tools: run manually).
# Validates the state of the working tree.
#
# Exit codes:
#   0  everything fine, or failures found but HARNESS_STRICT=0 (report only)
#   2  failures found and HARNESS_STRICT=1 -> Claude Code keeps the agent working and shows it stderr

set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
cd "$HARNESS_ROOT" || exit 0
h_load_config >/dev/null 2>&1 || true

# Claude Code passes JSON on stdin. Avoid infinite loops when we already blocked once.
input=""
if [ ! -t 0 ]; then input="$(cat 2>/dev/null || true)"; fi
if printf '%s' "$input" | grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi

failures=0
report="$(
  echo "=== HARNESS POST-AGENT CHECK ($(date '+%Y-%m-%d %H:%M')) ==="

  h_section "Checks (POST_AGENT_CHECKS=${POST_AGENT_CHECKS:-lint})"
  rc=0
  case "${POST_AGENT_CHECKS:-lint}" in
    none) h_info "Checks disabled" ;;
    lint)
      h_run_check "Lint" "${LINT_CMD:-}" || rc=1
      h_run_check "Format check" "${FORMAT_CHECK_CMD:-}" || rc=1
      ;;
    all)
      h_run_check "Lint" "${LINT_CMD:-}" || rc=1
      h_run_check "Format check" "${FORMAT_CHECK_CMD:-}" || rc=1
      h_run_check "Type check" "${TYPECHECK_CMD:-}" || rc=1
      h_run_check "Tests" "${TEST_CMD:-}" || rc=1
      h_run_check "Build" "${BUILD_CMD:-}" || rc=1
      ;;
  esac

  h_section "Hygiene"
  h_scan_secrets worktree || rc=1
  h_check_forbidden_paths worktree || rc=1

  h_section "Records"
  status="$(git status --porcelain 2>/dev/null)"
  if [ -n "$status" ]; then
    h_info "$(printf '%s\n' "$status" | wc -l | tr -d ' ') uncommitted change(s)."
    if ! printf '%s\n' "$status" | grep -q '.harness/state/claude-progress.md'; then
      h_warn "Code changed but .harness/state/claude-progress.md was not updated."
    fi
    if ! printf '%s\n' "$status" | grep -q '.harness/state/session-handoff.md'; then
      h_warn "Remember to overwrite .harness/state/session-handoff.md before ending the session."
    fi
  else
    h_ok "Working tree clean"
  fi
  branch="$(h_current_branch)"
  if h_is_protected_branch "$branch"; then
    ahead="$(git rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
    if [ "${ahead:-0}" -gt 0 ]; then
      h_warn "$ahead local commit(s) on protected branch '$branch'. Do not push unless the user explicitly asked."
    fi
  fi

  echo
  echo "Before saying 'done', walk through .harness/templates/clean-state-checklist.md."
  exit $rc
)"
failures=$?

if [ $failures -ne 0 ] && [ "${HARNESS_STRICT:-0}" = "1" ]; then
  printf '%s\n' "$report" >&2
  echo "Post-agent checks FAILED (HARNESS_STRICT=1). Fix the failures above before finishing." >&2
  exit 2
fi
printf '%s\n' "$report"
exit 0
