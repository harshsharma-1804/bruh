# =============================================================================
# BRUH — core.sh
# Shared utilities: colours, logging, OS/arch detection, guards
# =============================================================================

# Bumped at every release. `bruh upgrade` compares this against the
# latest GitHub release tag.
BRUH_VERSION="1.1.0"

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
# Release channels & versioning
# -----------------------------------------------------------------------------
# stable → releases tagged on main;  beta → pre-releases published from develop
bruh_channel() {
  case "${BRUH_CHANNEL:-stable}" in
    beta|dev|develop) echo "beta" ;;
    *)                echo "stable" ;;
  esac
}

# Prints 0 if equal, 1 if $1 > $2, -1 if $1 < $2 (semver x.y.z, ignores -beta.N)
bruh_vercmp() {
  local a b
  a=$(echo "$1" | sed 's/^v//;s/-.*//')
  b=$(echo "$2" | sed 's/^v//;s/-.*//')
  local a1 a2 a3 b1 b2 b3
  a1=$(echo "$a" | cut -d. -f1); a2=$(echo "$a" | cut -d. -f2); a3=$(echo "$a" | cut -d. -f3)
  b1=$(echo "$b" | cut -d. -f1); b2=$(echo "$b" | cut -d. -f2); b3=$(echo "$b" | cut -d. -f3)
  a2=${a2:-0}; a3=${a3:-0}; b2=${b2:-0}; b3=${b3:-0}
  if [ "$a1" -ne "$b1" ]; then [ "$a1" -gt "$b1" ] && echo 1 || echo -1; return; fi
  if [ "$a2" -ne "$b2" ]; then [ "$a2" -gt "$b2" ] && echo 1 || echo -1; return; fi
  if [ "$a3" -ne "$b3" ]; then [ "$a3" -gt "$b3" ] && echo 1 || echo -1; return; fi
  echo 0
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

# Canonical platform triple used to pick binary downloads:
# matches the naming used by nodejs.org and most upstream projects.
bruh_platform() {
  case "$(uname -s)/$(uname -m)" in
    Darwin/arm64)              echo "darwin-arm64" ;;
    Darwin/x86_64)             echo "darwin-x64" ;;
    Linux/x86_64)              echo "linux-x64" ;;
    Linux/arm64|Linux/aarch64) echo "linux-arm64" ;;
    *)                         echo "unsupported" ;;
  esac
}

# -----------------------------------------------------------------------------
# Download & extract infrastructure (self-reliant runtime installs)
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

bruh_require_jq() {
  bruh_require "jq" "Install it from https://jqlang.github.io/jq/download/"
}

# -----------------------------------------------------------------------------
# Download & extract infrastructure (self-reliant runtime installs)
# -----------------------------------------------------------------------------
bruh_download() { # bruh_download <url> <dest-file>
  if command -v curl >/dev/null 2>&1; then
    curl -fSL --retry 3 -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$2" "$1"
  else
    bruh_die "Neither curl nor wget found. Install one and retry."
  fi
}

bruh_extract() { # bruh_extract <archive> <dest-dir> [strip-components]
  local archive="$1" dest="$2" strip="${3:-0}"
  mkdir -p "$dest"
  case "$archive" in
    *.tar.gz|*.tgz)
      if [ "$strip" -gt 0 ]; then
        tar -xzf "$archive" -C "$dest" --strip-components="$strip"
      else
        tar -xzf "$archive" -C "$dest"
      fi
      ;;
    *.zip)
      if [ "$strip" -gt 0 ]; then
        local tmp inner
        tmp=$(mktemp -d)
        unzip -qo "$archive" -d "$tmp"
        inner=$(ls "$tmp" | head -1)
        ( shopt -s dotglob; mv "$tmp/$inner"/* "$dest"/ )
        rm -rf "$tmp"
      else
        unzip -qo "$archive" -d "$dest"
      fi
      ;;
    *)
      bruh_die "Unsupported archive format: $archive"
      ;;
  esac
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
