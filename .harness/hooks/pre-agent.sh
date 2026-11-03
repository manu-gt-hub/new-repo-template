#!/usr/bin/env bash
# .harness/hooks/pre-agent.sh
#
# Runs BEFORE the agent starts working (Claude Code: SessionStart hook; other tools: run manually).
# Its stdout is meant to be read by the agent as session context.
# It never blocks: it reports state and warnings, always exits 0.

set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
cd "$HARNESS_ROOT" || exit 0
h_load_config >/dev/null 2>&1 || true

echo "=== HARNESS PRE-AGENT CHECK ($(date '+%Y-%m-%d %H:%M')) ==="
echo "Rules: read AGENTS.md. Do only what was asked; ask before anything else; lint+test before commit."

# --- Initialization -----------------------------------------------------------
h_section "Initialization"
initialized=1
if [ ! -d "$HARNESS_STATE" ]; then
  initialized=0
  h_warn "Harness NOT initialized (.harness/state/ missing)."
  h_info "If this is a fresh project, see AGENTS.md section 0 / BOOTSTRAP.md."
  h_info "To initialize the harness only: bash docs/resources/templates/init.sh"
fi
ctx="docs/project-context/PROJECT_CONTEXT.md"
if [ -f "$ctx" ]; then
  todos="$(grep -c 'TODO' "$ctx" 2>/dev/null || true)"
  if [ "${todos:-0}" -gt 0 ]; then
    h_warn "$ctx still has $todos TODO placeholder(s): discovery is incomplete. Ask the user before building features."
  else
    h_ok "PROJECT_CONTEXT.md filled"
  fi
else
  h_warn "Missing $ctx"
fi
if [ "$(git config --get core.hooksPath 2>/dev/null)" = ".githooks" ]; then
  h_ok "Git hooks installed (.githooks)"
else
  h_warn "Git hooks NOT installed. Run: bash docs/resources/templates/init.sh"
fi

# --- Git state ------------------------------------------------------------------
h_section "Git"
branch="$(h_current_branch)"
h_info "Branch: $branch"
if h_is_protected_branch "$branch"; then
  h_warn "You are on protected branch '$branch'. Create a feature branch before changing code: <type>/<issue>-<slug>."
elif [ -n "${BRANCH_PATTERN:-}" ] && ! printf '%s' "$branch" | grep -Eq "$BRANCH_PATTERN"; then
  h_warn "Branch name does not match convention: $BRANCH_PATTERN"
fi
changes="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
if [ "$changes" -gt 0 ]; then
  h_warn "$changes uncommitted change(s) from a previous session:"
  git status --short 2>/dev/null | head -n 15 | sed 's/^/         /'
else
  h_ok "Working tree clean"
fi

if [ $initialized -eq 1 ]; then
  # --- Handoff ------------------------------------------------------------------
  h_section "Session handoff (.harness/state/session-handoff.md)"
  if [ -f "$HARNESS_STATE/session-handoff.md" ]; then
    sed -n '1,60p' "$HARNESS_STATE/session-handoff.md"
  else
    h_warn "missing"
  fi

  # --- Latest progress entry ------------------------------------------------------
  h_section "Latest progress entry (.harness/state/claude-progress.md)"
  if [ -f "$HARNESS_STATE/claude-progress.md" ]; then
    # Print the first "## " entry after the '---' separator.
    awk 'f && /^## / {n++} f && n==2 {exit} f && n==1 {print} /^---$/ {f=1}' "$HARNESS_STATE/claude-progress.md" | head -n 30
  fi

  # --- Feature status --------------------------------------------------------------
  h_section "Features (.harness/state/feature_list.json)"
  if py="$(h_python)"; then
    "$py" - "$HARNESS_STATE/feature_list.json" <<'PY'
import json, sys
from collections import Counter
try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception as e:  # noqa: BLE001
    print(f"  [FAIL] cannot read feature_list.json: {e}")
    sys.exit(0)
feats = data.get("features", [])
counts = Counter(f.get("status", "todo") for f in feats)
print("  " + ", ".join(f"{k}: {v}" for k, v in sorted(counts.items())) if feats else "  (no features)")
done = {f["key"] for f in feats if f.get("status") == "done"}
for f in feats:
    if f.get("status") == "in_progress":
        print(f"  IN PROGRESS: {f['key']} {'#' + str(f['issue']) if f.get('issue') else '(no issue)'} {f.get('title')}")
ready = [f for f in feats if f.get("status") == "todo" and set(f.get("depends_on", [])) <= done and f.get("type") != "epic"]
for f in ready[:5]:
    print(f"  next candidate: {f['key']} {'#' + str(f['issue']) if f.get('issue') else '(no issue)'} {f.get('title')}")
PY
  else
    h_warn "Python 3 not found; skipping feature summary."
  fi
fi

echo
echo "=== Confirm with the user which issue to work on before changing anything. ==="
exit 0
