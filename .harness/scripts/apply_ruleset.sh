#!/usr/bin/env bash
# .harness/scripts/apply_ruleset.sh — create or update a GitHub ruleset from a JSON file.
#
#   bash .harness/scripts/apply_ruleset.sh <owner/repo> [ruleset.json] [--dry-run]
#
# Default file: .github/rulesets/main.json (the model ruleset for the default branch).
# Idempotent: if a ruleset with the same "name" exists it is updated (PUT), otherwise created (POST).
# Requires an authenticated GitHub CLI with admin rights on the repository.
# Note: rulesets on PRIVATE repositories need GitHub Pro, Team or Enterprise.

set -euo pipefail
REPO="${1:?usage: apply_ruleset.sh <owner/repo> [ruleset.json] [--dry-run]}"
FILE=".github/rulesets/main.json"
DRY=0
for arg in "${@:2}"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    *) FILE="$arg" ;;
  esac
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
# shellcheck source=../hooks/lib.sh
. "$ROOT/.harness/hooks/lib.sh"
py="$(h_python)" || { echo "Python 3.8+ is required. Install: $(h_install_hint python)"; exit 1; }
GH="$(h_gh)" || { echo "GitHub CLI (gh) is required. Install: $(h_install_hint gh)"; exit 1; }
gh() { "$GH" "$@"; }

name="$("$py" -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["name"])' "$FILE")"
id="$(gh api "repos/$REPO/rulesets" --jq ".[] | select(.name == \"$name\") | .id")"

if [ -n "$id" ]; then action="update ruleset '$name' (id $id)"; else action="create ruleset '$name'"; fi
if [ "$DRY" = "1" ]; then
  echo "DRY-RUN: would $action on $REPO from $FILE"
  exit 0
fi
if [ -n "$id" ]; then
  gh api -X PUT "repos/$REPO/rulesets/$id" --input "$FILE" >/dev/null
else
  gh api -X POST "repos/$REPO/rulesets" --input "$FILE" >/dev/null
fi
echo "Done: $action on $REPO"
echo "Review it at https://github.com/$REPO/rules"
