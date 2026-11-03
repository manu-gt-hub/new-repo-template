#!/usr/bin/env bash
# .harness/scripts/verify_bootstrap.sh — acceptance check of a freshly bootstrapped project.
#
#   bash .harness/scripts/verify_bootstrap.sh [--offline]
#
# Run inside the GENERATED repository at the end of BOOTSTRAP.md. The bootstrap is not "done"
# until this passes. Local checks always run; GitHub checks (issues, Kanban board, ruleset,
# pushed commits) run unless --offline. Changes nothing. Exit 0 = pass, 1 = something to fix.

set -u
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "Run inside a git repository."; exit 1; }
cd "$ROOT" || exit 1
# shellcheck source=../hooks/lib.sh
. "$ROOT/.harness/hooks/lib.sh"
OFFLINE=0; [ "${1:-}" = "--offline" ] && OFFLINE=1
fails=0
ok()   { h_ok "$1"; }
bad()  { h_fail "$1"; fails=$((fails+1)); }
need() { if eval "$2"; then ok "$1"; else bad "$1${3:+ -> $3}"; fi; }
py="$(h_python)" || { echo "Python 3.8+ is required. Install: $(h_install_hint python)"; exit 1; }
FL=.harness/state/feature_list.json

echo "=== Bootstrap acceptance check ==="

h_section "Template leftovers"
need "BOOTSTRAP.md removed" "[ ! -f BOOTSTRAP.md ]" "delete it (template-only)"
need ".gitignore no longer ignores .harness/state/" "! grep -q 'TEMPLATE-ONLY' .gitignore" "delete the TEMPLATE-ONLY lines"
need "AGENTS.md section 0 has no template rows" "! grep -q 'create a new project using this repo as a template' AGENTS.md"
left="$(grep -rlE '(^|[^`])TODO([^`]|$)|\{\{[A-Z_]+\}\}' docs --include=*.md | grep -v '^docs/resources/' || true)"
need "no TODO or {{PLACEHOLDER}} left in docs/" "[ -z \"\$left\" ]" "$(echo $left)"

h_section "Harness"
need "state files committed" "git ls-files --error-unmatch $FL .harness/state/claude-progress.md .harness/state/session-handoff.md >/dev/null 2>&1"
need "git hooks installed" "[ \"\$(git config core.hooksPath)\" = .githooks ]" "bash docs/resources/templates/init.sh"
need "merge driver for generated docs" "[ -n \"\$(git config merge.harness-generated.driver)\" ]" "bash docs/resources/templates/init.sh"
need "backlog valid" "\"$py\" .harness/scripts/create_issues.py --backlog docs/backlog/backlog.json --validate-only >/dev/null 2>&1"
need "generated docs up to date" "\"$py\" .harness/scripts/build_docs.py --check >/dev/null" "python .harness/scripts/build_docs.py"
need "harness self-test passes" "bash tests/harness/run.sh >/dev/null 2>&1" "bash tests/harness/run.sh"
missing="$("$py" -c 'import json,sys; print(" ".join(f["key"] for f in json.load(open(sys.argv[1],encoding="utf-8"))["features"] if not f.get("issue")))' "$FL" 2>/dev/null)"
need "every feature has a GitHub issue number" "[ -z \"\$missing\" ]" "missing: $missing (run create_issues.py with --write-feature-list)"

# Language heuristic: docs are English unless PROJECT_CONTEXT records another language.
lang="$(grep -i 'Artifact language' docs/project-context/PROJECT_CONTEXT.md | cut -d'|' -f3 | tr -d ' ')"
if [ "${lang:-English}" = "English" ]; then
  ratio="$("$py" - <<'PY'
import glob, re
en = set("the and of to is for with that this are be in on it as by or".split())
other = set("que los las del para con por una son como pero más este esta les des une est pour dans avec der die und ist nicht mit für dem não uma com".split())
words = [w for f in glob.glob("docs/**/*.md", recursive=True) if not f.replace("\\", "/").startswith("docs/resources/")
         for w in re.findall(r"[a-záéíóúñçàèâêôüöä]+", open(f, encoding="utf-8").read().lower())]
e, o = sum(w in en for w in words), sum(w in other for w in words)
print(round(o / max(e + o, 1), 2))
PY
)"
  need "docs are written in English (non-English ratio $ratio)" "\"$py\" -c 'import sys; sys.exit(0 if float(sys.argv[1]) < 0.2 else 1)' $ratio" \
    "AGENTS.md rule 11: translate the docs, or record the chosen language in PROJECT_CONTEXT"
fi

if [ $OFFLINE -eq 0 ]; then
  h_section "GitHub"
  repo="$("$py" -c 'import json; print(json.load(open("docs/backlog/backlog.json", encoding="utf-8")).get("repository",""))' 2>/dev/null)"
  if ! GH="$(h_gh)"; then
    bad "GitHub CLI not found -> $(h_install_hint gh)"
  elif [ -z "$repo" ]; then
    bad "'repository' not set in docs/backlog/backlog.json"
  else
    gh() { "$GH" "$@"; }
    owner="${repo%%/*}"
    want="$("$py" -c 'import json,sys; print(" ".join(str(f["issue"]) for f in json.load(open(sys.argv[1],encoding="utf-8"))["features"] if f.get("issue")))' "$FL")"
    have=" $(gh issue list --repo "$repo" --state all --limit 2000 --json number --jq '.[].number' 2>/dev/null | tr '\n' ' ') "
    absent=""; for n in $want; do case "$have" in *" $n "*) ;; *) absent="$absent #$n" ;; esac; done
    need "all feature issues exist on GitHub" "[ -z \"\$absent\" ]" "not found:$absent"
    pnum="$(gh project list --owner "$owner" --format json --jq '.projects[] | select(.title == "Kanban board") | .number' 2>/dev/null | head -1)"
    if [ -z "$pnum" ]; then
      bad "Kanban board project exists -> python .harness/scripts/create_issues.py (needs gh scope 'project')"
    else
      items="$(gh project item-list "$pnum" --owner "$owner" --limit 2000 --format json --jq '.items | length' 2>/dev/null || echo 0)"
      count="$(echo $want | wc -w | tr -d ' ')"
      need "Kanban board has all $count issues ($items items)" "[ \"${items:-0}\" -ge \"$count\" ]" "re-run create_issues.py"
    fi
    if gh api "repos/$repo/rulesets" --jq '.[].name' 2>/dev/null | grep -qx main; then ok "ruleset 'main' applied"
    else h_warn "ruleset 'main' not applied (fine only on a private repo without GitHub Pro/Team)"; fi
    if [ "$(gh api "repos/$repo" --jq '.security_and_analysis.secret_scanning_push_protection.status' 2>/dev/null)" = enabled ]; then
      ok "secret scanning push protection on"
    else h_warn "secret scanning push protection off (free on public repos; see BOOTSTRAP.md Phase 5)"; fi
    git fetch -q origin 2>/dev/null
    ahead="$(git rev-list --count '@{u}..HEAD' 2>/dev/null || echo '?')"
    need "all commits pushed" "[ \"$ahead\" = 0 ]" "$ahead local commit(s) not on the remote"
  fi
fi

echo
if [ $fails -eq 0 ]; then echo "Bootstrap acceptance: PASS"; exit 0; fi
echo "Bootstrap acceptance: $fails problem(s). Fix them and re-run before reporting the bootstrap as done."
exit 1
