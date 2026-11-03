#!/usr/bin/env bash
# Shared helpers for harness scripts. Source it, do not execute it.
# shellcheck disable=SC2034

HARNESS_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
HARNESS_CONFIG="$HARNESS_ROOT/.harness/env/sandbox.config"
HARNESS_STATE="$HARNESS_ROOT/.harness/state"
HARNESS_TEMPLATES="$HARNESS_ROOT/.harness/templates"

h_info() { printf '  [info] %s\n' "$*"; }
h_ok()   { printf '  [ ok ] %s\n' "$*"; }
h_warn() { printf '  [warn] %s\n' "$*"; }
h_fail() { printf '  [FAIL] %s\n' "$*"; }
h_section() { printf '\n== %s ==\n' "$*"; }

# Load sandbox.config (KEY="VALUE" lines).
h_load_config() {
  if [ -f "$HARNESS_CONFIG" ]; then
    # shellcheck source=/dev/null
    . "$HARNESS_CONFIG"
    return 0
  fi
  h_warn "Missing $HARNESS_CONFIG"
  return 1
}

# Find a working Python 3 interpreter (skips the Windows Store stub).
h_python() {
  local p
  for p in python3 python py; do
    if command -v "$p" >/dev/null 2>&1 && "$p" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

# Operating system family: windows | macos | linux | unknown.
h_os() {
  case "$(uname -s 2>/dev/null)" in
    MINGW*|MSYS*|CYGWIN*) echo windows ;;
    Darwin) echo macos ;;
    Linux) echo linux ;;
    *) echo unknown ;;
  esac
}

# Print the install command for a tool (python | gh | git) on this OS.
h_install_hint() {
  local tool="$1" os
  os="$(h_os)"
  case "$tool:$os" in
    python:windows) echo "winget install -e --id Python.Python.3.12   (then reopen the terminal; if 'python' opens the Microsoft Store, disable it in Settings > Apps > Advanced app settings > App execution aliases)" ;;
    python:macos)   echo "brew install python" ;;
    python:linux)   echo "sudo apt install -y python3   (Fedora: sudo dnf install -y python3)" ;;
    gh:windows)     echo "winget install -e --id GitHub.cli   (then reopen the terminal and run: gh auth login)" ;;
    gh:macos)       echo "brew install gh   (then: gh auth login)" ;;
    gh:linux)       echo "sudo apt install -y gh   (Fedora: sudo dnf install -y gh; other distros: https://github.com/cli/cli#installation), then: gh auth login" ;;
    git:windows)    echo "winget install -e --id Git.Git   (includes Git Bash)" ;;
    git:macos)      echo "xcode-select --install   (or: brew install git)" ;;
    git:linux)      echo "sudo apt install -y git   (Fedora: sudo dnf install -y git)" ;;
    *)              echo "see the official install page for $tool" ;;
  esac
}

# Find the GitHub CLI even when it is installed but not on PATH (common in Git Bash on Windows
# right after installing). Prints the path to use; returns 1 if it is not installed.
# HARNESS_GH overrides the lookup.
h_gh() {
  local c
  for c in "${HARNESS_GH:-}" "$(command -v gh 2>/dev/null)" \
           "/c/Program Files/GitHub CLI/gh.exe" "/c/Program Files (x86)/GitHub CLI/gh.exe" \
           "${LOCALAPPDATA:+$(cygpath -u "$LOCALAPPDATA" 2>/dev/null)/Programs/GitHub CLI/gh.exe}" \
           "$HOME/scoop/shims/gh.exe" /opt/homebrew/bin/gh /usr/local/bin/gh /usr/bin/gh; do
    if [ -n "$c" ] && [ -x "$c" ]; then echo "$c"; return 0; fi
  done
  return 1
}

h_current_branch() { git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"; }

h_is_protected_branch() {
  local branch="${1:-$(h_current_branch)}" b
  for b in ${PROTECTED_BRANCHES:-main master}; do
    [ "$branch" = "$b" ] && return 0
  done
  return 1
}

# Run a configured command by name. Empty command => SKIP (warn), never a silent pass.
# Usage: h_run_check "Lint" "$LINT_CMD"   -> returns the command's exit status (0 when skipped)
h_run_check() {
  local name="$1" cmd="$2" out status
  if [ -z "$cmd" ]; then
    h_warn "$name: SKIPPED (no command configured in sandbox.config)"
    return 0
  fi
  out="$(cd "$HARNESS_ROOT" && bash -c "$cmd" 2>&1)"
  status=$?
  if [ $status -eq 0 ]; then
    h_ok "$name passed ($cmd)"
  else
    h_fail "$name failed ($cmd), exit $status. Last lines:"
    printf '%s\n' "$out" | tail -n 25 | sed 's/^/         /'
  fi
  return $status
}

# Scan added lines for secrets. Mode: staged | worktree. Prints matches; returns 1 if any.
h_scan_secrets() {
  local mode="$1" diff matches
  [ -z "${SECRET_PATTERNS:-}" ] && return 0
  if [ "$mode" = "staged" ]; then
    diff="$(git diff --cached -U0 --no-color -- . ':(exclude).harness/env/sandbox.config' 2>/dev/null)"
  else
    diff="$(git diff HEAD -U0 --no-color -- . ':(exclude).harness/env/sandbox.config' 2>/dev/null)"
  fi
  matches="$(printf '%s\n' "$diff" | grep -E '^\+' | grep -vE '^\+\+\+' | grep -nE -- "$SECRET_PATTERNS" || true)"
  if [ -n "$matches" ]; then
    h_fail "Possible secrets in $mode changes:"
    printf '%s\n' "$matches" | head -n 10 | sed 's/^/         /'
    return 1
  fi
  h_ok "No secret patterns in $mode changes"
  return 0
}

# Check that no file matching FORBIDDEN_PATHS is staged (mode=staged) or pending (mode=worktree).
h_check_forbidden_paths() {
  local mode="$1" files f pat found=0
  [ -z "${FORBIDDEN_PATHS:-}" ] && return 0
  if [ "$mode" = "staged" ]; then
    files="$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null)"
  else
    files="$(git status --porcelain 2>/dev/null | sed 's/^...//')"
  fi
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    # Example/sample files are allowed (e.g. .env.example).
    case "$f" in *.example|*.sample|*.template) continue ;; esac
    for pat in $FORBIDDEN_PATHS; do
      # shellcheck disable=SC2254
      if [ "${pat%/}" != "$pat" ]; then
        # Directory pattern: anything inside it.
        case "$f" in $pat*|*/$pat*) h_fail "Forbidden path in $mode changes: $f (matches '$pat')"; found=1 ;; esac
      else
        case "$f" in $pat|*/$pat) h_fail "Forbidden path in $mode changes: $f (matches '$pat')"; found=1 ;; esac
      fi
    done
  done <<EOF
$files
EOF
  [ $found -eq 0 ] && h_ok "No forbidden paths in $mode changes"
  return $found
}
