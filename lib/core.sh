# =============================================================================
# BRUH — core.sh
# Shared utilities: colours, logging, OS/arch detection, guards
# =============================================================================

# -----------------------------------------------------------------------------
# Colours
# -----------------------------------------------------------------------------
BRUH_RED="\033[0;31m"
BRUH_GREEN="\033[0;32m"
BRUH_YELLOW="\033[0;33m"
BRUH_BLUE="\033[0;34m"
BRUH_BOLD="\033[1m"
BRUH_DIM="\033[2m"
BRUH_RESET="\033[0m"

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
bruh_log() {
  printf "  %b\n" "$*"
}

bruh_ok() {
  printf "  ${BRUH_GREEN}✓${BRUH_RESET} %b\n" "$*"
}

bruh_err() {
  printf "  ${BRUH_RED}✗${BRUH_RESET} %b\n" "$*" >&2
}

bruh_warn() {
  printf "  ${BRUH_YELLOW}!${BRUH_RESET} %b\n" "$*"
}

bruh_info() {
  printf "  ${BRUH_BLUE}→${BRUH_RESET} %b\n" "$*"
}

bruh_header() {
  printf "\n${BRUH_BOLD}%b${BRUH_RESET}\n" "$*"
}

bruh_die() {
  bruh_err "$*"
  exit 1
}

bruh_divider() {
  printf "  ${BRUH_DIM}─────────────────────────────────────${BRUH_RESET}\n"
}

# -----------------------------------------------------------------------------
# OS and architecture detection
# -----------------------------------------------------------------------------
bruh_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *)      echo "unsupported" ;;
  esac
}

bruh_arch() {
  case "$(uname -m)" in
    arm64)  echo "arm64" ;;
    x86_64) echo "x86_64" ;;
    *)      echo "unknown" ;;
  esac
}

bruh_homebrew_prefix() {
  if [ "$(bruh_arch)" = "arm64" ]; then
    echo "/opt/homebrew"
  else
    echo "/usr/local"
  fi
}

# -----------------------------------------------------------------------------
# Dependency guards
# -----------------------------------------------------------------------------
bruh_require() {
  local cmd="$1"
  local hint="${2:-}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    if [ -n "$hint" ]; then
      bruh_die "'$cmd' is required but not found. $hint"
    else
      bruh_die "'$cmd' is required but not found."
    fi
  fi
}

bruh_require_brew() {
  bruh_require "brew" "Install Homebrew from https://brew.sh"
}

bruh_require_jq() {
  bruh_require "jq" "Run: brew install jq"
}

# -----------------------------------------------------------------------------
# Version helpers
# -----------------------------------------------------------------------------
bruh_major_version() {
  echo "$1" | cut -d'.' -f1
}

bruh_minor_version() {
  echo "$1" | cut -d'.' -f1-2
}

bruh_is_exact_version() {
  case "$1" in
    *.*) return 0 ;;
    *)   return 1 ;;
  esac
}

bruh_npm_latest() {
  local pkg="$1"
  local tag="${2:-latest}"
  curl -fsSL "https://registry.npmjs.org/$pkg" 2>/dev/null \
    | jq -r ".\"dist-tags\".\"$tag\" // empty" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Path helpers
# -----------------------------------------------------------------------------
bruh_path_remove() {
  local remove="$1"
  export PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "$remove" | paste -sd ':' -)
}

bruh_path_prepend() {
  local add="$1"
  bruh_path_remove "$add"
  export PATH="$add:$PATH"
}
