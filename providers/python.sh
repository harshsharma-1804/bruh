# =============================================================================
# BRUH — providers/python.sh
# Standalone provider: precompiled CPython from python-build-standalone
# (github.com/astral-sh/python-build-standalone)
# Layout: $BRUH_HOME/runtimes/python/v<major.minor>   (extracted CPython)
#         $BRUH_HOME/runtimes/python/current          (symlink → active)
# =============================================================================

PYTHON_RUNTIME_HOME="$BRUH_HOME/runtimes/python"
_PY_PBS_RELEASES="https://api.github.com/repos/astral-sh/python-build-standalone/releases/latest"

# -----------------------------------------------------------------------------
# Platform mapping → python-build-standalone triple
# -----------------------------------------------------------------------------
_python_triple() {
  case "$(bruh_platform)" in
    darwin-arm64) echo "aarch64-apple-darwin" ;;
    darwin-x64)   echo "x86_64-apple-darwin" ;;
    linux-x64)    echo "x86_64-unknown-linux-gnu" ;;
    linux-arm64)  echo "aarch64-unknown-linux-gnu" ;;
    *)            echo "unsupported" ;;
  esac
}

# -----------------------------------------------------------------------------
# Catalog: fetch asset names from the latest pbs release
# Prints lines of "<tag>\t<version>\t<asset-name>"
# -----------------------------------------------------------------------------
_python_catalog() {
  local triple; triple=$(_python_triple)
  [ "$triple" = "unsupported" ] && bruh_die "Unsupported platform: $(uname -s)/$(uname -m)"
  curl -fsSL "$_PY_PBS_RELEASES" 2>/dev/null | jq -r --arg t "$triple" '
    .tag_name as $tag
    | .assets[]
    | select(.name | test("^cpython-[0-9.]+\\+[^-]+-" + $t + "-install_only\\.tar\\.gz$"))
    | ($tag + "\t" + .name)
  ' 2>/dev/null | while IFS=$'\t' read -r tag name; do
    local ver
    ver=$(echo "$name" | sed -E 's/^cpython-([0-9.]+)\+.*/\1/')
    printf '%s\t%s\t%s\n' "$tag" "$ver" "$name"
  done
  return 0
}

_python_resolve_full() {
  local req="${1:-latest}"
  case "$req" in
    latest|stable|lts)
      _python_catalog | sort -t$'\t' -k2,2V | tail -1 | cut -f2
      ;;
    *)
      local v="${req#v}"
      case "$v" in
        *.*.*) echo "$v" ;;
        *[!0-9.]*|"") echo "" ;;
        *) # major or major.minor → highest matching
          _python_catalog | awk -F'\t' -v p="$v." '$2 ~ "^"p' \
            | sort -t$'\t' -k2,2V | tail -1 | cut -f2
          ;;
      esac
      ;;
  esac
}

_python_resolve_version() {
  local full; full=$(_python_resolve_full "$1")
  [ -z "$full" ] && { echo ""; return; }
  echo "$full" | cut -d'.' -f1-2
}

# -----------------------------------------------------------------------------
# Install
# -----------------------------------------------------------------------------
python_install() {
  [ "$(bruh_platform)" = "unsupported" ] && \
    bruh_die "Unsupported platform: $(uname -s)/$(uname -m)"

  local full; full=$(_python_resolve_full "$1")
  if [ -z "$full" ]; then
    bruh_err "Python version '$1' not found. Try: bruh search python"; return 1
  fi
  local version; version=$(echo "$full" | cut -d'.' -f1-2)

  local dir="$PYTHON_RUNTIME_HOME/v$version"

  if registry_is_installed "python" "$version" && registry_verify "python" "$version" "bin/python3"; then
    bruh_warn "Python $version already installed."
    python_activate "$version"; return
  fi

  local triple; triple=$(_python_triple)
  local tag asset
  tag=$(_python_catalog | awk -F'\t' -v v="$full" '$2 == v {print $1; exit}')
  asset=$(_python_catalog | awk -F'\t' -v v="$full" '$2 == v {print $3; exit}')
  if [ -z "$asset" ]; then
    bruh_err "No prebuilt CPython $full for $triple."; return 1
  fi
  local url="https://github.com/astral-sh/python-build-standalone/releases/download/${tag}/${asset}"

  local tmp_tar="$PYTHON_RUNTIME_HOME/.cpython-$full.tar.gz"
  mkdir -p "$PYTHON_RUNTIME_HOME"

  bruh_info "Downloading CPython $full ($triple)..."
  if ! bruh_download "$url" "$tmp_tar"; then
    rm -f "$tmp_tar"
    bruh_err "Failed to download $url"; return 1
  fi

  bruh_info "Extracting to $dir..."
  rm -rf "$dir"
  # install_only archives extract to python/... — strip that top dir
  if ! bruh_extract "$tmp_tar" "$dir" 1; then
    rm -rf "$dir" "$tmp_tar"
    bruh_err "Failed to extract Python archive."; return 1
  fi
  rm -f "$tmp_tar"

  "$dir/bin/python3" --version >/dev/null 2>&1 || { rm -rf "$dir"; bruh_err "Python binary failed verification."; return 1; }

  registry_record_install "python" "$version"
  bruh_ok "Python $full installed."
  python_activate "$version"
}

python_activate() {
  local version; version=$(_python_resolve_version "$1")
  if [ -z "$version" ]; then
    bruh_err "Unknown Python version: $1"; return 1
  fi
  local dir="$PYTHON_RUNTIME_HOME/v$version"
  if [ ! -d "$dir" ] || ! registry_verify "python" "$version" "bin/python3"; then
    bruh_err "Python $version not installed. Run: bruh python $version"; return 1
  fi
  ln -sfn "$dir" "$PYTHON_RUNTIME_HOME/current"
  registry_set "python" "current" "$version"
  printf 'hash -r 2>/dev/null || true\n' > "$BRUH_HOME/.activate_env"
  bruh_ok "Using Python $version"
  "$dir/bin/python3" --version 2>/dev/null || true
}

python_set_default() {
  local version; version=$(_python_resolve_version "$1")
  if [ -z "$version" ] || ! registry_is_installed "python" "$version"; then
    bruh_err "Python $1 not installed."; return 1
  fi
  echo "$version" > "$PYTHON_RUNTIME_HOME/.default"
  registry_set "python" "default" "$version"
  bruh_ok "Default Python set to $version"
  bruh_info "Run 'source ~/.zshrc' to apply in the current terminal."
  python_activate "$version"
}

# Remove — just delete the version directory
python_remove() {
  local version; version=$(_python_resolve_version "$1")
  local default; default=$(registry_get "python" "default")
  [ "$default" = "$version" ] && bruh_err "Python $version is the default. Change first." && return 1
  if ! registry_is_installed "python" "$version"; then
    bruh_err "Python $version not installed under Bruh."; return 1
  fi
  rm -rf "$PYTHON_RUNTIME_HOME/v$version"
  registry_remove_installed "python" "$version"
  bruh_ok "Python $version removed."
}

python_lookup() {
  bruh_header "Installed Python versions"
  bruh_divider

  local installed; installed=$(registry_list_installed "python")
  local current; current=$(registry_get "python" "current")
  local default; default=$(registry_get "python" "default")

  if [ -z "$installed" ]; then
    bruh_log "No Python versions installed under Bruh."
    bruh_log ""; bruh_log "Run ${BRUH_BOLD}bruh search python${BRUH_RESET} to see available versions."
    return
  fi

  printf "  ${BRUH_BOLD}%-10s  %s${BRUH_RESET}\n" "Version" "Status"
  printf "  %-10s  %s\n" "─────────" "──────────────"

  echo "$installed" | while read -r v; do
    [ -z "$v" ] && continue
    local status=""
    if ! registry_verify "python" "$v" "bin/python3"; then
      status="${BRUH_RED}(missing — reinstall)${BRUH_RESET}"
    elif [ "$v" = "$current" ] && [ "$v" = "$default" ]; then
      status="${BRUH_GREEN}▸ active  ${BRUH_RESET}${BRUH_BLUE}(default)${BRUH_RESET}"
    elif [ "$v" = "$current" ]; then
      status="${BRUH_GREEN}▸ active${BRUH_RESET}"
    elif [ "$v" = "$default" ]; then
      status="${BRUH_BLUE}(default)${BRUH_RESET}"
    fi
    printf "  ${BRUH_BOLD}%-10s${BRUH_RESET}  %b\n" "$v" "$status"
  done

  printf "\n"
  printf "  ${BRUH_DIM}Current : ${current:-not set}${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}Default : ${default:-not set}${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}Path    : $(command -v python3 2>/dev/null || echo 'not found')${BRUH_RESET}\n"
  printf "\n"
  printf "  Run ${BRUH_BOLD}bruh search python${BRUH_RESET} to see all available versions.\n"
  printf "\n"
}

python_search() {
  local filter="${1:-}"
  bruh_header "Available Python versions"
  bruh_divider

  local current; current=$(registry_get "python" "current")

  printf "  ${BRUH_BOLD}%-10s  %-12s  %s${BRUH_RESET}\n" "Version" "Release" "Status"
  printf "  %-10s  %-12s  %s\n" "─────────" "───────────" "──────────────"

  # One row per minor line: highest full version in that line
  _python_catalog | sort -t$'\t' -k2,2Vr | while IFS=$'\t' read -r _ full _; do
    local minor; minor=$(echo "$full" | cut -d'.' -f1-2)
    [ "$minor" = "${_py_last_minor:-}" ] && continue
    _py_last_minor="$minor"
    [ -n "$filter" ] && [ "$filter" != "$minor" ] && continue
    local status=""
    registry_is_installed "python" "$minor" && {
      [ "$minor" = "$current" ] \
        && status="${BRUH_GREEN}▸ installed (active)${BRUH_RESET}" \
        || status="${BRUH_BLUE}✓ installed${BRUH_RESET}"
    }
    printf "  %-10s  %-12s  %b\n" "$minor" "$full" "${status:-}"
  done || true

  printf "\n"
  printf "  ${BRUH_BOLD}Install with:${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh python 3.12${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh python latest${BRUH_RESET}\n"
  printf "\n"
}

python_locate() {
  bruh_header "Python location"
  local dir="$PYTHON_RUNTIME_HOME/current"
  bruh_log "Home   : $([ -d "$dir" ] && echo "$dir" || echo 'not installed')"
  bruh_log "Binary : $(command -v python3 2>/dev/null || echo 'not found')"
  bruh_log "Version: $(python3 --version 2>/dev/null || echo 'n/a')"
  bruh_log "pip    : $(command -v pip3 2>/dev/null || echo 'not found')"
}

python_status() {
  bruh_header "Python"
  local current; current=$(registry_get python current)
  local dir="$PYTHON_RUNTIME_HOME/v${current:-}"
  bruh_log "Current : ${current:-not set} ($(python3 --version 2>/dev/null || echo n/a))"
  bruh_log "Default : $(registry_get python default || echo 'not set')"
  bruh_log "Path    : $(command -v python3 2>/dev/null || echo 'not found')"
  bruh_log "Home    : $([ -d "$dir" ] && echo "$dir" || echo 'not installed')"
}

# Update — refresh each installed minor to the latest patch release
python_update() {
  local version="${1:-}"
  local minors
  if [ -z "$version" ] || [ "$version" = "all" ]; then
    minors=$(registry_list_installed "python")
    [ -z "$minors" ] && { bruh_warn "No Python versions installed."; return 0; }
  else
    minors=$(_python_resolve_version "$version")
  fi
  echo "$minors" | while read -r m; do
    [ -z "$m" ] && continue
    local latest_full; latest_full=$(_python_resolve_full "$m")
    local current_full; current_full=$("$PYTHON_RUNTIME_HOME/v$m/bin/python3" --version 2>/dev/null | sed 's/Python //')
    if [ "$current_full" = "$latest_full" ]; then
      bruh_ok "Python $m already at latest ($latest_full)."
    else
      bruh_info "Updating Python $m: ${current_full:-missing} → $latest_full..."
      python_install "$m"
    fi
  done
  bruh_ok "Done."
}

python_install_or_activate() {
  local version; version=$(_python_resolve_version "$1")
  if [ -n "$version" ] && registry_is_installed "python" "$version" \
     && registry_verify "python" "$version" "bin/python3"; then
    python_activate "$version"
  else
    python_install "$1"
  fi
}
