#!/usr/bin/env bash
# =============================================================================
# BRUH — install.sh
#
# Local clone:
#   bash install.sh
#
# One-line remote (after publishing):
#   curl -fsSL https://raw.githubusercontent.com/BRUH_REPO_PLACEHOLDER/main/install.sh | bash
# =============================================================================

# PLACEHOLDER — replace with your GitHub repo before publishing e.g. "harshvardhansharma/bruh"
BRUH_GITHUB_REPO="BRUH_REPO_PLACEHOLDER"
BRUH_GITHUB_BRANCH="main"

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
  arm64)  HOMEBREW_PREFIX="/opt/homebrew" ;;
  x86_64) HOMEBREW_PREFIX="/usr/local" ;;
  *)      _die "Unknown architecture: $ARCH" ;;
esac

# -----------------------------------------------------------------------------
# 2. Homebrew
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
# 3. jq
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
# 4. Install target
# -----------------------------------------------------------------------------
BRUH_HOME="$HOME/tools/bruh"
_bold "Installing Bruh..."
_info "Target: $BRUH_HOME"

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
# 5. Source detection — Mode A (local) or Mode B (curl pipe)
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
# 6. Directory structure
# -----------------------------------------------------------------------------
_info "Creating directory structure..."
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
# 7. Copy files
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
[ -f "$INSTALL_DIR/install.sh" ] && cp "$INSTALL_DIR/install.sh" "$BRUH_HOME/install.sh"
[ -f "$INSTALL_DIR/BRUH.md" ]    && cp "$INSTALL_DIR/BRUH.md"    "$BRUH_HOME/BRUH.md"

_ok "Files copied."

# -----------------------------------------------------------------------------
# 8. Registry
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
# 9. Shell integration
# -----------------------------------------------------------------------------
_bold "Shell integration..."

SOURCE_LINE='source "$HOME/tools/bruh/env/bruh.env"'

_add_source_line() {
  local rc="$1"
  [ ! -f "$rc" ] && return
  if grep -qF 'tools/bruh/env/bruh.env' "$rc" 2>/dev/null; then
    _ok "Already present in $rc"
  else
    printf "\n# Bruh — runtime environment manager\n%s\n" "$SOURCE_LINE" >> "$rc"
    _ok "Added to $rc"
  fi
}

[ -f "$HOME/.zshrc" ]        && _add_source_line "$HOME/.zshrc"
[ -f "$HOME/.bashrc" ]       && _add_source_line "$HOME/.bashrc"
[ -f "$HOME/.bash_profile" ] && _add_source_line "$HOME/.bash_profile"

if [ ! -f "$HOME/.zshrc" ] && [ ! -f "$HOME/.bashrc" ]; then
  _warn "No shell config found. Creating ~/.zshrc..."
  printf "# Bruh — runtime environment manager\n%s\n" "$SOURCE_LINE" > "$HOME/.zshrc"
  _ok "Created ~/.zshrc"
fi

# -----------------------------------------------------------------------------
# 10. Cleanup temp dir (Mode B only)
# -----------------------------------------------------------------------------
[ -n "$_TMP_DIR" ] && [ -d "$_TMP_DIR" ] && rm -rf "$_TMP_DIR"

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
printf "\n"
printf "  ${_BOLD}${_GREEN}Bruh is installed.${_RESET}\n"
printf "\n"
printf "  ${_BOLD}Activate now:${_RESET}\n"
printf "  ${_DIM}source ~/tools/bruh/env/bruh.env${_RESET}\n"
printf "\n"
printf "  ${_BOLD}Then try:${_RESET}\n"
printf "  ${_DIM}bruh node 22${_RESET}\n"
printf "  ${_DIM}bruh java 21${_RESET}\n"
printf "  ${_DIM}bruh runtimes${_RESET}\n"
printf "  ${_DIM}bruh help${_RESET}\n"
printf "\n"
