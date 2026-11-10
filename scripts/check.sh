#!/usr/bin/env bash
# Project checks. Run before every commit; also run by the pre-commit hook and CI.
# Fill the commands once the stack is chosen. An empty command is skipped with a warning.
#   Node:   LINT="npm run lint"  FORMAT="npx prettier --check ."  TEST="npm test"
#   Python: LINT="ruff check ."  FORMAT="ruff format --check ."   TEST="pytest"
set -u
cd "$(dirname "$0")/.." || exit 1

LINT=""
FORMAT=""
TEST=""

rc=0
run() {
  if [ -z "$2" ]; then
    echo "[skip] $1: no command configured in scripts/check.sh"
  elif bash -c "$2"; then
    echo "[ ok ] $1"
  else
    echo "[FAIL] $1 ($2)"
    rc=1
  fi
}
run "Lint" "$LINT"
run "Format" "$FORMAT"
[ "${SKIP_TESTS:-0}" = "1" ] || run "Tests" "$TEST"
exit $rc
