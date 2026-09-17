# =============================================================================
# BRUH — providers/go.sh
# Standalone provider: official Go distribution tarballs from go.dev
# Layout: $BRUH_HOME/runtimes/go/v<major.minor>   (extracted Go root)
#         $BRUH_HOME/runtimes/go/current          (symlink → active)
# =============================================================================

GO_RUNTIME_HOME="$BRUH_HOME/runtimes/go"
GO_DL_JSON="https://go.dev/dl/?mode=json&include=all"

# -----------------------------------------------------------------------------
# Platform mapping → go.dev file naming
# -----------------------------------------------------------------------------
_go_target() {
  case "$(bruh_platform)" in
    darwin-arm64) echo "darwin arm64" ;;
    darwin-x64)   echo "darwin amd64" ;;
    linux-x64)    echo "linux amd64" ;;
    linux-arm64)  echo "linux arm64" ;;
    *)            echo "unsupported" ;;
  esac
}

# -----------------------------------------------------------------------------
# Catalog: "go1.23.4<TAB>go1.23.4.darwin-arm64.tar.gz" lines
# -----------------------------------------------------------------------------
_go_catalog() {
  local os arch
  read -r os arch < <(_go_target)
  [ "$os" = "unsupported" ] && bruh_die "Unsupported platform: $(uname -s)/$(uname -m)"
  curl -fsSL "$GO_DL_JSON" 2>/dev/null | jq -r --arg os "$os" --arg arch "$arch" '
    .[]
    | select(.stable)
    | .version as $v
    | .files[]
    | select(.os == $os and .arch == $arch and .kind == "archive")
    | ($v + "\t" + .filename)
  ' 2>/dev/null
}

_go_resolve_full() {
  local req="${1:-latest}"
  case "$req" in
    latest|stable|lts)
      _go_catalog | head -1 | cut -f1 | sed 's/^go//'
      ;;
    *)
      local v="${req#go}"
      case "$v" in
        *[!0-9.]*|"") echo "" ;;
        *.*.*) echo "$v" ;;
        *) # major.minor or major → highest matching
          _go_catalog | awk -F'\t' -v p="go$v" '$1 ~ "^"p"[.!]" || $1 == p {print $1}' \
            | sort -V | tail -1 | sed 's/^go//'
          ;;
      esac
      ;;
  esac
}

_go_resolve_version() {
  local full; full=$(_go_resolve_full "$1")
  [ -z "$full" ] && { echo ""; return; }
  echo "$full" | cut -d'.' -f1-2
}

# -----------------------------------------------------------------------------
# Install
# -----------------------------------------------------------------------------
go_install() {
  [ "$(bruh_platform)" = "unsupported" ] && \
    bruh_die "Unsupported platform: $(uname -s)/$(uname -m)"

  local full; full=$(_go_resolve_full "$1")
  if [ -z "$full" ]; then
    bruh_err "Go version '$1' not found. Try: bruh search go"; return 1
  fi
  local version; version=$(echo "$full" | cut -d'.' -f1-2)

  local dir="$GO_RUNTIME_HOME/v$version"

  if registry_is_installed "go" "$version" && registry_verify "go" "$version" "bin/go"; then
    local actual; actual=$("$dir/bin/go" version 2>/dev/null | sed 's/^go\([0-9.]*\).*/\1/')
    if [ "$actual" = "$full" ]; then
      bruh_warn "Go $version already installed ($full)."
      go_activate "$version"; return
    fi
    bruh_info "Go $version is stale ($actual) — updating to $full..."
  fi

  local os arch
  read -r os arch < <(_go_target)
  local url="https://go.dev/dl/go${full}.${os}-${arch}.tar.gz"
  local tmp_tar="$GO_RUNTIME_HOME/.go-$full.tar.gz"
  mkdir -p "$GO_RUNTIME_HOME"

  bruh_info "Downloading Go $full ($os-$arch)..."
  if ! bruh_download "$url" "$tmp_tar"; then
    rm -f "$tmp_tar"
    bruh_err "Failed to download $url"; return 1
  fi

  bruh_info "Extracting to $dir..."
  rm -rf "$dir"
  # Go tarballs contain a single go/ top-level directory
  if ! bruh_extract "$tmp_tar" "$dir" 1; then
    rm -rf "$dir" "$tmp_tar"
    bruh_err "Failed to extract Go archive."; return 1
  fi
  rm -f "$tmp_tar"

  "$dir/bin/go" version >/dev/null 2>&1 || { rm -rf "$dir"; bruh_err "Go binary failed verification."; return 1; }

  registry_record_install "go" "$version"
  bruh_ok "Go $full installed."
  go_activate "$version"
}

go_activate() {
  local version; version=$(_go_resolve_version "$1")
  if [ -z "$version" ]; then
    bruh_err "Unknown Go version: $1"; return 1
  fi
  local dir="$GO_RUNTIME_HOME/v$version"
  if [ ! -d "$dir" ] || ! registry_verify "go" "$version" "bin/go"; then
    bruh_err "Go $version not installed. Run: bruh go $version"; return 1
  fi
  ln -sfn "$dir" "$GO_RUNTIME_HOME/current"
  registry_set "go" "current" "$version"
  # Write activation exports to .activate_env so the bruh() shell function
  # wrapper in bruh.env can source them into the current terminal session.
  {
    printf 'export GOROOT="%s"\n' "$dir"
    printf 'export GOPATH="%s/go"\n' "$HOME"
    printf 'export PATH="$GOROOT/bin:$GOPATH/bin:$PATH"\n'
    printf 'hash -r 2>/dev/null || true\n'
  } > "$BRUH_HOME/.activate_env"
  bruh_ok "Using Go $version"
  "$dir/bin/go" version 2>/dev/null || true
}

go_set_default() {
  local version; version=$(_go_resolve_version "$1")
  if [ -z "$version" ] || ! registry_is_installed "go" "$version"; then
    bruh_err "Go $1 not installed."; return 1
  fi
  echo "$version" > "$GO_RUNTIME_HOME/.default"
  registry_set "go" "default" "$version"
  bruh_ok "Default Go set to $version"
  bruh_info "Run 'source ~/.zshrc' to apply in the current terminal."
  go_activate "$version"
}

# Remove — just delete the version directory
go_remove() {
  local version; version=$(_go_resolve_version "$1")
  local default; default=$(registry_get "go" "default")
  [ "$default" = "$version" ] && bruh_err "Go $version is the default. Change first." && return 1
  if ! registry_is_installed "go" "$version"; then
    bruh_err "Go $version not installed under Bruh."; return 1
  fi
  rm -rf "$GO_RUNTIME_HOME/v$version"
  registry_remove_installed "go" "$version"
  bruh_ok "Go $version removed."
}

go_lookup() {
  bruh_header "Installed Go versions"
  bruh_divider

  local installed; installed=$(registry_list_installed "go")
  local current; current=$(registry_get "go" "current")
  local default; default=$(registry_get "go" "default")

  if [ -z "$installed" ]; then
    bruh_log "No Go versions installed under Bruh."
    bruh_log ""; bruh_log "Run ${BRUH_BOLD}bruh search go${BRUH_RESET} to see available versions."
    return
  fi

  printf "  ${BRUH_BOLD}%-10s  %s${BRUH_RESET}\n" "Version" "Status"
  printf "  %-10s  %s\n" "─────────" "──────────────"

  echo "$installed" | while read -r v; do
    [ -z "$v" ] && continue
    local status=""
    if ! registry_verify "go" "$v" "bin/go"; then
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
  printf "  ${BRUH_DIM}GOROOT  : ${GOROOT:-not set}${BRUH_RESET}\n"
  printf "\n"
  printf "  Run ${BRUH_BOLD}bruh search go${BRUH_RESET} to see all available versions.\n"
  printf "\n"
}

go_search() {
  local filter="${1:-}"
  bruh_header "Available Go versions"
  bruh_divider

  local current; current=$(registry_get "go" "current")

  printf "  ${BRUH_BOLD}%-10s  %-12s  %s${BRUH_RESET}\n" "Version" "Release" "Status"
  printf "  %-10s  %-12s  %s\n" "─────────" "───────────" "──────────────"

  # One row per minor line: highest release in that line
  _go_catalog | sed 's/^go//' | sort -t$'\t' -k1,1Vr | while IFS=$'\t' read -r full _; do
    local minor; minor=$(echo "$full" | cut -d'.' -f1-2)
    [ "$minor" = "${_go_last_minor:-}" ] && continue
    _go_last_minor="$minor"
    [ -n "$filter" ] && [ "$filter" != "$minor" ] && continue
    local status=""
    registry_is_installed "go" "$minor" && {
      [ "$minor" = "$current" ] \
        && status="${BRUH_GREEN}▸ installed (active)${BRUH_RESET}" \
        || status="${BRUH_BLUE}✓ installed${BRUH_RESET}"
    }
    printf "  %-10s  %-12s  %b\n" "$minor" "$full" "${status:-}"
  done || true

  printf "\n"
  printf "  ${BRUH_BOLD}Install with:${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh go 1.23${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh go latest${BRUH_RESET}\n"
  printf "\n"
}

go_locate() {
  bruh_header "Go location"
  local dir="$GO_RUNTIME_HOME/current"
  bruh_log "GOROOT : $([ -d "$dir" ] && echo "$dir" || echo 'not installed')"
  bruh_log "Binary : $(command -v go 2>/dev/null || echo 'not found')"
  bruh_log "GOPATH : ${GOPATH:-not set}"
  go version 2>/dev/null | sed 's/^/  /' || true
}

go_status() {
  bruh_header "Go"
  local current; current=$(registry_get go current)
  local dir="$GO_RUNTIME_HOME/v${current:-}"
  bruh_log "Current : ${current:-not set} ($(go version 2>/dev/null | sed 's/^go//' || echo n/a))"
  bruh_log "Default : $(registry_get go default || echo 'not set')"
  bruh_log "GOROOT  : ${GOROOT:-not set}"
  bruh_log "Path    : $(command -v go 2>/dev/null || echo 'not found')"
  bruh_log "Home    : $([ -d "$dir" ] && echo "$dir" || echo 'not installed')"
}

# Update — refresh each installed minor to the latest release in that line
go_update() {
  local version="${1:-}"
  local minors
  if [ -z "$version" ] || [ "$version" = "all" ]; then
    minors=$(registry_list_installed "go")
    [ -z "$minors" ] && { bruh_warn "No Go versions installed."; return 0; }
  else
    minors=$(_go_resolve_version "$version")
  fi
  echo "$minors" | while read -r m; do
    [ -z "$m" ] && continue
    local latest_full; latest_full=$(_go_resolve_full "$m")
    local current_full; current_full=$("$GO_RUNTIME_HOME/v$m/bin/go" version 2>/dev/null | sed 's/^go\([0-9.]*\).*/\1/')
    if [ "$current_full" = "$latest_full" ]; then
      bruh_ok "Go $m already at latest ($latest_full)."
    else
      bruh_info "Updating Go $m: ${current_full:-missing} → $latest_full..."
      go_install "$m"
    fi
  done
  bruh_ok "Done."
}

go_install_or_activate() {
  local version; version=$(_go_resolve_version "$1")
  if [ -n "$version" ] && registry_is_installed "go" "$version" \
     && registry_verify "go" "$version" "bin/go"; then
    go_activate "$version"
  else
    go_install "$1"
  fi
}
