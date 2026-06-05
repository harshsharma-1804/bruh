#!/usr/bin/env bash
# =============================================================================
# BRUH — install.sh
#
# Local clone:
#   bash install.sh
#   bash install.sh --dir /your/custom/path
#
# Custom path via env var:
#   BRUH_DIR=/your/custom/path bash install.sh
#
# One-line remote:
#   curl -fsSL https://raw.githubusercontent.com/harshsharma-1804/bruh/develop/install.sh | bash
# =============================================================================

# ── Release config ────────────────────────────────────────────────────────────
# Update these two values whenever you cut a new release or switch branches.
BRUH_GITHUB_REPO="harshsharma-1804/bruh"
BRUH_GITHUB_BRANCH="${BRUH_BRANCH:-main}"
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

_RED="\033[0;31m"
_GREEN="\033[0;32m"
_YELLOW="\033[0;33m"
_BLUE="\033[0;34m"
_BOLD="\033[1m"
_DIM="\033[2m"
_RESET="\033[0m"

_ok()   { printf "  ${_GREEN}✓${_RESET} %b\n" "$*"; }
_err()  { printf "  ${_RED}✗${_RESET} %b\n" "$*" >&2; }
_info() { printf "  ${_BLUE}→${_RESET} %b\n" "$*"; }
_warn() { printf "  ${_YELLOW}!${_RESET} %b\n" "$*"; }
_die()  { _err "$*"; exit 1; }
_bold() { printf "\n${_BOLD}%b${_RESET}\n" "$*"; }

printf "\n"
printf "  ${_BOLD}Installing Bruh${_RESET}\n"
printf "  ${_DIM}Runtime environment manager${_RESET}\n"
printf "\n"

# -----------------------------------------------------------------------------
# 1. OS + arch
# -----------------------------------------------------------------------------
_bold "Checking system..."

OS="$(uname -s)"
ARCH="$(uname -m)"

[ "$OS" != "Darwin" ] && _die "Bruh currently supports macOS only. (Detected: $OS)"
_ok "macOS detected ($ARCH)"

case "$ARCH" in
  arm64)  HOMEBREW_PREFIX="/opt/homebrew" ; BRUH_DEFAULT="/opt/bruh" ;;
  x86_64) HOMEBREW_PREFIX="/usr/local"   ; BRUH_DEFAULT="/usr/local/bruh" ;;
  *)      _die "Unknown architecture: $ARCH" ;;
esac

# -----------------------------------------------------------------------------
# 2. Determine install path
# Resolution order:
#   1. --dir <path> argument
#   2. BRUH_DIR environment variable
#   3. Finder folder picker (GUI — macOS only, skipped in headless/curl-pipe)
#   4. Arch-aware default (/opt/bruh on arm64, /usr/local/bruh on x86_64)
# -----------------------------------------------------------------------------
_bold "Choosing install location..."

BRUH_HOME=""

# -- Check for --dir argument -------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      shift
      [ -z "${1:-}" ] && _die "--dir requires a path argument"
      BRUH_HOME="$1"
      shift
      ;;
    --dir=*)
      BRUH_HOME="${1#--dir=}"
      shift
      ;;
    *) shift ;;
  esac
done

# -- Check BRUH_DIR env var ---------------------------------------------------
if [ -z "$BRUH_HOME" ] && [ -n "${BRUH_DIR:-}" ]; then
  BRUH_HOME="$BRUH_DIR"
fi

# -- Finder picker (only when running interactively, not in curl pipe) --------
if [ -z "$BRUH_HOME" ]; then
  # Detect if we have a GUI available (not a headless/pipe session)
  _GUI_AVAILABLE=false
  if [ -n "${TERM_PROGRAM:-}" ] || [ -n "${TERM:-}" ] && [ -t 0 ]; then
    _GUI_AVAILABLE=true
  fi

  if $_GUI_AVAILABLE; then
    _info "Opening folder picker — select where to install Bruh..."
    _info "${_DIM}(Click Cancel to use the default: $BRUH_DEFAULT)${_RESET}"
    printf "\n"

    _PICKED=""
    _PICKED=$(osascript 2>/dev/null <<'APPLESCRIPT'
tell application "Finder"
  activate
  set _folder to choose folder with prompt "Select where to install Bruh:" default location (path to home folder)
  return POSIX path of _folder
end tell
APPLESCRIPT
    ) || _PICKED=""

    if [ -n "$_PICKED" ]; then
      # Strip trailing slash, then append /bruh
      _PICKED="${_PICKED%/}"
      # If user picked a folder already named bruh, use as-is
      if [ "$(basename "$_PICKED")" = "bruh" ]; then
        BRUH_HOME="$_PICKED"
      else
        BRUH_HOME="${_PICKED}/bruh"
      fi
      _ok "Selected: $BRUH_HOME"
    else
      _warn "No folder selected. Using default: $BRUH_DEFAULT"
      BRUH_HOME="$BRUH_DEFAULT"
    fi
  else
    # Headless / curl pipe — skip picker, use default
    BRUH_HOME="$BRUH_DEFAULT"
    _info "Non-interactive session detected. Using default: $BRUH_HOME"
    _info "To choose a custom path: BRUH_DIR=/your/path bash install.sh"
  fi
fi

# Ensure BRUH_HOME ends with /bruh
if [ "$(basename "$BRUH_HOME")" != "bruh" ]; then
  BRUH_HOME="${BRUH_HOME}/bruh"
fi

_ok "Install path: $BRUH_HOME"

# -----------------------------------------------------------------------------
# 3. Reinstall check
# -----------------------------------------------------------------------------
if [ -d "$BRUH_HOME/bin" ] && [ -f "$BRUH_HOME/bin/bruh" ]; then
  _warn "Bruh is already installed at $BRUH_HOME"
  printf "  Reinstall / update? [y/N] "
  read -r confirm
  case "$confirm" in
    [yY]|[yY][eE][sS]) _info "Proceeding with reinstall..." ;;
    *) _info "Aborted."; exit 0 ;;
  esac
fi

# -----------------------------------------------------------------------------
# 4. Homebrew
# -----------------------------------------------------------------------------
_bold "Checking Homebrew..."

if command -v brew >/dev/null 2>&1; then
  _ok "Homebrew found ($(brew --version | head -1))"
else
  _warn "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || _die "Homebrew installation failed."
  if [ "$ARCH" = "arm64" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  command -v brew >/dev/null 2>&1 || _die "brew still not found after install. Restart terminal and re-run."
  _ok "Homebrew installed."
fi

# -----------------------------------------------------------------------------
# 5. jq
# -----------------------------------------------------------------------------
_bold "Checking jq..."

if command -v jq >/dev/null 2>&1; then
  _ok "jq found ($(jq --version))"
else
  _info "Installing jq..."
  brew install jq || _die "Failed to install jq"
  _ok "jq installed."
fi

# -----------------------------------------------------------------------------
# 6. Source detection — Mode A (local clone) or Mode B (curl pipe)
# -----------------------------------------------------------------------------
_bold "Locating source files..."

_SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "-" ]; then
  _SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
fi

INSTALL_DIR=""
_TMP_DIR=""

if [ -n "$_SCRIPT_DIR" ] && [ -f "$_SCRIPT_DIR/bin/bruh" ]; then
  INSTALL_DIR="$_SCRIPT_DIR"
  _ok "Local source found at $INSTALL_DIR"
else
  [ "$BRUH_GITHUB_REPO" = "BRUH_REPO_PLACEHOLDER" ] && \
    _die "install.sh has no GitHub repo configured.\nSet BRUH_GITHUB_REPO at the top of this file before publishing."

  _info "Downloading Bruh from github.com/${BRUH_GITHUB_REPO}..."
  _TMP_DIR="$(mktemp -d)"
  ARCHIVE_URL="https://github.com/${BRUH_GITHUB_REPO}/archive/refs/heads/${BRUH_GITHUB_BRANCH}.tar.gz"
  curl -fsSL "$ARCHIVE_URL" | tar -xz -C "$_TMP_DIR" --strip-components=1 \
    || _die "Failed to download from $ARCHIVE_URL"
  INSTALL_DIR="$_TMP_DIR"
  _ok "Downloaded to temp directory."
fi

# -----------------------------------------------------------------------------
# 7. Directory structure
# -----------------------------------------------------------------------------
_bold "Scaffolding..."
_info "Creating directory structure at $BRUH_HOME..."

mkdir -p \
  "$BRUH_HOME/bin" \
  "$BRUH_HOME/lib" \
  "$BRUH_HOME/providers" \
  "$BRUH_HOME/env" \
  "$BRUH_HOME/registry" \
  "$BRUH_HOME/runtimes/node" \
  "$BRUH_HOME/runtimes/java" \
  "$BRUH_HOME/runtimes/python" \
  "$BRUH_HOME/runtimes/go" \
  "$BRUH_HOME/runtimes/rust" \
  "$BRUH_HOME/runtimes/yarn" \
  "$BRUH_HOME/runtimes/pnpm"

_ok "Directories created."

# -----------------------------------------------------------------------------
# 8. Copy files
# -----------------------------------------------------------------------------
_info "Copying files..."

cp "$INSTALL_DIR/bin/bruh"            "$BRUH_HOME/bin/bruh"  && chmod +x "$BRUH_HOME/bin/bruh"
cp "$INSTALL_DIR/lib/core.sh"         "$BRUH_HOME/lib/core.sh"
cp "$INSTALL_DIR/lib/registry.sh"     "$BRUH_HOME/lib/registry.sh"
cp "$INSTALL_DIR/lib/intent.sh"       "$BRUH_HOME/lib/intent.sh"
cp "$INSTALL_DIR/providers/node.sh"   "$BRUH_HOME/providers/node.sh"
cp "$INSTALL_DIR/providers/java.sh"   "$BRUH_HOME/providers/java.sh"
cp "$INSTALL_DIR/providers/python.sh" "$BRUH_HOME/providers/python.sh"
cp "$INSTALL_DIR/providers/go.sh"     "$BRUH_HOME/providers/go.sh"
cp "$INSTALL_DIR/providers/rust.sh"   "$BRUH_HOME/providers/rust.sh"
cp "$INSTALL_DIR/providers/yarn.sh"   "$BRUH_HOME/providers/yarn.sh"
cp "$INSTALL_DIR/providers/pnpm.sh"   "$BRUH_HOME/providers/pnpm.sh"
cp "$INSTALL_DIR/env/bruh.env"        "$BRUH_HOME/env/bruh.env"
cp "$INSTALL_DIR/env/node.env"        "$BRUH_HOME/env/node.env"
cp "$INSTALL_DIR/env/java.env"        "$BRUH_HOME/env/java.env"
cp "$INSTALL_DIR/env/python.env"      "$BRUH_HOME/env/python.env"
cp "$INSTALL_DIR/env/go.env"          "$BRUH_HOME/env/go.env"
cp "$INSTALL_DIR/env/rust.env"        "$BRUH_HOME/env/rust.env"
[ -f "$INSTALL_DIR/install.sh" ]  && cp "$INSTALL_DIR/install.sh"  "$BRUH_HOME/install.sh"
[ -f "$INSTALL_DIR/BRUH.md" ]     && cp "$INSTALL_DIR/BRUH.md"     "$BRUH_HOME/BRUH.md"
[ -f "$INSTALL_DIR/README.md" ]   && cp "$INSTALL_DIR/README.md"   "$BRUH_HOME/README.md"
[ -f "$INSTALL_DIR/COMMANDS.md" ] && cp "$INSTALL_DIR/COMMANDS.md" "$BRUH_HOME/COMMANDS.md"

_ok "Files copied."

# -----------------------------------------------------------------------------
# 9. Registry
# -----------------------------------------------------------------------------
if [ ! -f "$BRUH_HOME/registry/state.json" ]; then
  _info "Initialising registry..."
  cat > "$BRUH_HOME/registry/state.json" <<'REGISTRY'
{
  "node":   { "installed": [], "bruh_installed": [], "current": null, "default": null },
  "java":   { "installed": [], "bruh_installed": [], "current": null, "default": null },
  "python": { "installed": [], "bruh_installed": [], "current": null, "default": null },
  "go":     { "installed": [], "bruh_installed": [], "current": null, "default": null },
  "rust":   { "installed": [], "bruh_installed": [], "current": null, "default": null },
  "yarn":   { "installed": [], "bruh_installed": [], "current": null, "current_exact": null, "default": null },
  "pnpm":   { "installed": [], "bruh_installed": [], "current": null, "current_exact": null, "default": null }
}
REGISTRY
  _ok "Registry initialised."
else
  _ok "Registry already exists — skipping."
fi

# -----------------------------------------------------------------------------
# 10. Shell integration — write 3 lines: comment + BRUH_HOME export + source
# -----------------------------------------------------------------------------
_bold "Shell integration..."

_add_shell_integration() {
  local rc="$1"
  [ ! -f "$rc" ] && return

  # Already integrated — skip
  if grep -qF "BRUH_HOME=\"${BRUH_HOME}\"" "$rc" 2>/dev/null; then
    _ok "Already present in $rc"
    return
  fi

  # Remove any previous Bruh integration block (different path) cleanly
  if grep -q 'BRUH_HOME=' "$rc" 2>/dev/null; then
    _info "Updating existing Bruh entry in $rc..."
    # Remove old 3-line block: comment, export BRUH_HOME, source bruh.env
    grep -v '# Bruh — runtime environment manager' "$rc" \
      | grep -v 'export BRUH_HOME=' \
      | grep -v 'source.*bruh.env' \
      > "${rc}.bruh_tmp" && mv "${rc}.bruh_tmp" "$rc"
  fi

  printf "\n# Bruh — runtime environment manager\nexport BRUH_HOME=\"%s\"\nsource \"%s/env/bruh.env\"\n" \
    "$BRUH_HOME" "$BRUH_HOME" >> "$rc"
  _ok "Added to $rc"
}

[ -f "$HOME/.zshrc" ]        && _add_shell_integration "$HOME/.zshrc"
[ -f "$HOME/.bashrc" ]       && _add_shell_integration "$HOME/.bashrc"
[ -f "$HOME/.bash_profile" ] && _add_shell_integration "$HOME/.bash_profile"

# No shell config found — create .zshrc
if [ ! -f "$HOME/.zshrc" ] && [ ! -f "$HOME/.bashrc" ] && [ ! -f "$HOME/.bash_profile" ]; then
  _warn "No shell config found. Creating ~/.zshrc..."
  printf "# Bruh — runtime environment manager\nexport BRUH_HOME=\"%s\"\nsource \"%s/env/bruh.env\"\n" \
    "$BRUH_HOME" "$BRUH_HOME" > "$HOME/.zshrc"
  _ok "Created ~/.zshrc"
fi

# -----------------------------------------------------------------------------
# 11. Cleanup temp dir (Mode B only)
# -----------------------------------------------------------------------------
[ -n "$_TMP_DIR" ] && [ -d "$_TMP_DIR" ] && rm -rf "$_TMP_DIR"

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
printf "\n"
printf "  ${_BOLD}${_GREEN}Bruh is installed.${_RESET}\n"
printf "  ${_DIM}Installed to: $BRUH_HOME${_RESET}\n"
printf "\n"
printf "  ${_BOLD}Activate now:${_RESET}\n"
printf "  ${_DIM}export BRUH_HOME=\"$BRUH_HOME\"${_RESET}\n"
printf "  ${_DIM}source \"$BRUH_HOME/env/bruh.env\"${_RESET}\n"
printf "\n"
printf "  ${_BOLD}Then try:${_RESET}\n"
printf "  ${_DIM}bruh node 22${_RESET}\n"
printf "  ${_DIM}bruh java 21${_RESET}\n"
printf "  ${_DIM}bruh runtimes${_RESET}\n"
printf "  ${_DIM}bruh help${_RESET}\n"
printf "\n"
