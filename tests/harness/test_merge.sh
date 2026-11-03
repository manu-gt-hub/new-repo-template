#!/usr/bin/env bash
# tests/harness/test_merge.sh — two branches change different docs pages; merging them must not
# conflict on the generated docs, and the merge commit must carry up-to-date generated docs.
# Runs in a throwaway copy of the repository. Exit 0 = pass.

set -eu
SRC="$(git rev-parse --show-toplevel)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$SRC"
git ls-files -co --exclude-standard -z | xargs -0 -I{} cp --parents {} "$TMP" 2>/dev/null \
  || { git ls-files -co --exclude-standard | while IFS= read -r f; do mkdir -p "$TMP/$(dirname "$f")"; cp "$f" "$TMP/$f"; done; }
cd "$TMP"
. .harness/hooks/lib.sh
py="$(h_python)"
q() { "$@" >/dev/null 2>&1; }
q git init -b base
git config user.email t@t; git config user.name t; git config commit.gpgsign false
git config core.hooksPath .githooks; chmod +x .githooks/*
git config merge.harness-generated.driver true
"$py" .harness/scripts/build_docs.py >/dev/null
q git add -A; q git commit -m "chore: base"

q git checkout -b feat/1-a
echo "Branch A line." >> docs/business/glossary.md
q git commit -am "docs: a"
q git checkout base
q git checkout -b feat/2-b
echo "Branch B line." >> docs/business/roadmap.md
q git commit -am "docs: b"

git merge --no-edit feat/1-a >/dev/null 2>&1 || { echo "merge conflicted"; git status --short; exit 1; }
"$py" .harness/scripts/build_docs.py --check >/dev/null || { echo "generated docs stale after merge"; exit 1; }
git diff --quiet HEAD || { echo "merge left uncommitted changes"; exit 1; }
grep -q "Branch A line" docs-site/index.html && grep -q "Branch B line" docs-site/index.html \
  || { echo "docs-site misses a side of the merge"; exit 1; }
[ "$(git rev-list --parents -n 1 HEAD | wc -w)" -eq 3 ] || { echo "merge commit lost a parent"; exit 1; }
git log -1 --format=%s | grep -q "^Merge branch 'feat/1-a'" || { echo "merge message changed"; exit 1; }
