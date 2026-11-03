#!/usr/bin/env bash
# .harness/scripts/preflight.sh — check that this machine is ready to bootstrap a project.
#
#   bash .harness/scripts/preflight.sh [owner/repo]
#
# Checks git, bash, Python 3.8+, the GitHub CLI (also when installed but not on PATH), its login
# and token scopes and, if a repository is given, your access to it. For anything missing it
# prints the exact command to install or fix it on this OS. Changes nothing.
# Exit 0 = ready (warnings allowed), 1 = something blocks the bootstrap.

set -u
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
# shellcheck source=../hooks/lib.sh
. "$ROOT/.harness/hooks/lib.sh"
REPO="${1:-}"
blockers=0
logged_in=0
fixes=""
block() { h_fail "$1"; blockers=$((blockers+1)); fixes="$fixes
  - $2"; }

echo "=== Bootstrap preflight ($(h_os)) ==="

h_section "Tools"
command -v git >/dev/null 2>&1 && h_ok "git $(git --version | awk '{print $3}')" \
  || block "git not found" "$(h_install_hint git)"
h_ok "bash ${BASH_VERSION%%(*}"

if py="$(h_python)"; then
  h_ok "Python $("$py" -c 'import platform; print(platform.python_version())') ($py)"
else
  stub="$(command -v python 2>/dev/null || true)"
  case "$stub" in
    *WindowsApps*) block "Python not installed: 'python' is only the Microsoft Store shortcut" "$(h_install_hint python)" ;;
    *) block "Python 3.8+ not found" "$(h_install_hint python)" ;;
  esac
fi

GH=""
if GH="$(h_gh)"; then
  h_ok "GitHub CLI $("$GH" --version | head -1 | awk '{print $3}') ($GH)"
  if ! command -v gh >/dev/null 2>&1; then
    h_warn "gh is installed but not on PATH (harness scripts find it anyway). To use it by hand:"
    h_info "echo 'export PATH=\"\$PATH:$(dirname "$GH")\"' >> ~/.bashrc && source ~/.bashrc"
  fi
else
  block "GitHub CLI (gh) not found" "$(h_install_hint gh)"
fi

if [ -n "$GH" ]; then
  h_section "GitHub login"
  status="$("$GH" auth status 2>&1)"
  if printf '%s' "$status" | grep -q "Logged in"; then
    logged_in=1
    h_ok "$(printf '%s\n' "$status" | grep -m1 'Logged in' | sed 's/^[^A-Za-z]*//')"
    scopes="$(printf '%s\n' "$status" | grep -m1 'Token scopes' | sed 's/.*Token scopes: //')"
    if [ -z "$scopes" ]; then
      h_warn "Could not read the token scopes (token from GH_TOKEN?). Needed: repo, workflow, project"
    else
      missing=""
      for s in repo workflow project; do
        printf '%s' "$scopes" | grep -q "'$s'" || missing="$missing $s"
      done
      if [ -z "$missing" ]; then
        h_ok "Token scopes include repo, workflow, project"
      else
        # shellcheck disable=SC2086
        block "Token is missing scope(s):$missing (workflow: push CI files; project: Kanban board)" \
          "gh auth refresh -h github.com -s $(echo $missing | tr ' ' ',')"
      fi
    fi
  else
    block "gh is not logged in" "gh auth login   (choose GitHub.com, HTTPS, login with a web browser)"
  fi
fi

if [ -n "$REPO" ] && [ "$logged_in" = 1 ]; then
  h_section "Target repository $REPO"
  info="$("$GH" repo view "$REPO" --json viewerPermission,isEmpty,isPrivate,defaultBranchRef \
    --jq '"\(.viewerPermission) \(.isEmpty) \(.isPrivate) \(.defaultBranchRef.name // "")"' 2>/dev/null)"
  if [ -z "$info" ]; then
    block "Repository not found or no access" "create it (empty is fine): gh repo create $REPO --private   (ask the user first)"
  else
    read -r perm empty private branch <<EOF
$info
EOF
    case "$perm" in
      ADMIN) h_ok "Permission: ADMIN" ;;
      MAINTAIN|WRITE) h_warn "Permission: $perm. Fine for the scaffold and issues; applying the ruleset needs ADMIN" ;;
      *) block "Permission: $perm (need WRITE or more)" "ask the repository owner for write or admin access" ;;
    esac
    [ "$empty" = "true" ] && h_ok "Repository is empty" || h_warn "Repository is NOT empty: ask the user whether to merge the harness into it"
    if [ "$private" = "true" ]; then
      h_warn "Private repository: the ruleset and GitHub Pages need GitHub Pro/Team on private repos (they are skipped otherwise; Cloudflare Pages still works for the docs)"
    fi
    if [ "$empty" != "true" ]; then
      rules="$("$GH" api "repos/$REPO/rules/branches/${branch:-main}" 2>/dev/null || echo '[]')"
      [ "$rules" = "[]" ] && h_ok "No protection on ${branch:-main} yet" \
        || h_warn "${branch:-main} is already protected: bootstrap pushes will be rejected (see BOOTSTRAP.md Phase 0)"
    fi
  fi
fi

echo
if [ $blockers -eq 0 ]; then
  echo "Preflight: READY"
  exit 0
fi
echo "Preflight: $blockers blocker(s). Fix them, then re-run this script:$fixes"
exit 1
