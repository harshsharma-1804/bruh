# =============================================================================
# BRUH — providers/go.sh
# =============================================================================

GO_RUNTIME_HOME="$BRUH_HOME/runtimes/go"
HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-$(bruh_homebrew_prefix)}"

_go_formula() {
  case "$1" in
    latest|stable|lts) echo "go" ;;
    *)
      if brew info "go@$1" >/dev/null 2>&1; then echo "go@$1"; else echo "go"; fi ;;
  esac
}

_go_symlink()   { echo "$GO_RUNTIME_HOME/v$1"; }
_go_brew_path() { echo "$HOMEBREW_PREFIX/opt/$(_go_formula "$1")"; }

_go_resolve_version() {
  case "$1" in
    latest|stable|lts)
      brew info --json=v2 go 2>/dev/null | jq -r '.formulae[0].versions.stable' | cut -d'.' -f1-2 ;;
    *) echo "$1" ;;
  esac
}

go_install() {
  local version; version=$(_go_resolve_version "$1")
  bruh_require_brew
  if registry_is_installed "go" "$version"; then
    bruh_warn "Go $version already installed."; go_activate "$version"; return
  fi
  local brew_path; brew_path=$(_go_brew_path "$version")
  if [ -d "$brew_path" ]; then
    bruh_info "Go $version found (pre-existing). Registering..."
    ln -sfn "$brew_path" "$(_go_symlink "$version")"
    registry_record_activate "go" "$version"
    go_activate "$version"; return
  fi
  bruh_info "Installing Go $version via Homebrew..."
  brew install "$(_go_formula "$version")" || bruh_die "Failed to install Go $version"
  ln -sfn "$brew_path" "$(_go_symlink "$version")"
  registry_record_install "go" "$version"
  bruh_ok "Go $version installed."
  go_activate "$version"
}

go_activate() {
  local version; version=$(_go_resolve_version "$1")
  local symlink; symlink=$(_go_symlink "$version")
  if [ ! -L "$symlink" ] && [ ! -d "$symlink" ]; then
    bruh_err "Go $version not installed. Run: bruh go $version"; return 1
  fi
  ln -sfn "$symlink" "$GO_RUNTIME_HOME/current"
  export GOROOT="$GO_RUNTIME_HOME/current"
  export GOPATH="$HOME/go"
  bruh_path_remove "$GO_RUNTIME_HOME"
  bruh_path_remove "$GOPATH/bin"
  export PATH="$GOROOT/bin:$GOPATH/bin:$PATH"
  hash -r 2>/dev/null || true
  registry_set "go" "current" "$version"
  bruh_ok "Using Go $version"
  go version 2>/dev/null || true
}

go_set_default() {
  local version; version=$(_go_resolve_version "$1")
  if ! registry_is_installed "go" "$version"; then
    bruh_err "Go $version not installed."; return 1
  fi
  echo "$version" > "$GO_RUNTIME_HOME/.default"
  registry_set "go" "default" "$version"
  bruh_ok "Default Go set to $version"
}

go_remove() {
  local version; version=$(_go_resolve_version "$1")
  local default; default=$(registry_get "go" "default")
  [ "$default" = "$version" ] && bruh_err "Go $version is the default. Change first." && return 1
  if ! registry_is_installed "go" "$version"; then
    bruh_err "Go $version not installed under Bruh."; return 1
  fi
  registry_is_bruh_installed "go" "$version" \
    && brew uninstall "$(_go_formula "$version")" || bruh_warn "Skipping Homebrew uninstall."
  rm -f "$(_go_symlink "$version")" 2>/dev/null || true
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
    if [ "$v" = "$current" ] && [ "$v" = "$default" ]; then
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

  printf "  ${BRUH_BOLD}%-10s  %-22s  %s${BRUH_RESET}\n" "Version" "Formula" "Status"
  printf "  %-10s  %-22s  %s\n" "─────────" "─────────────────────" "──────────────"

  brew search '/go@/' 2>/dev/null | grep -E '^go@' | sort -V | while read -r formula; do
    [ -z "$formula" ] && continue
    local ver; ver=$(echo "$formula" | sed 's/go@//')
    [ -n "$filter" ] && [ "$filter" != "$ver" ] && continue
    local status=""
    registry_is_installed "go" "$ver" && {
      [ "$ver" = "$current" ] \
        && status="${BRUH_GREEN}▸ installed (active)${BRUH_RESET}" \
        || status="${BRUH_BLUE}✓ installed${BRUH_RESET}"
    }
    printf "  %-10s  %-22s  %b\n" "$ver" "$formula" "$status"
  done

  # Latest
  [ -z "$filter" ] && printf "  %-10s  %-22s\n" "latest" "go"

  printf "\n"
  printf "  ${BRUH_BOLD}Install with:${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh go 1.23${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh go latest${BRUH_RESET}\n"
  printf "\n"
}

go_locate() {
  bruh_header "Go location"
  bruh_log "Binary : $(command -v go 2>/dev/null || echo 'not found')"
  bruh_log "GOROOT : ${GOROOT:-not set}"
  bruh_log "GOPATH : ${GOPATH:-not set}"
  go version 2>/dev/null | sed 's/^/  /' || true
}

go_status() {
  bruh_header "Go"
  bruh_log "Current : $(registry_get go current || echo 'not set')"
  bruh_log "Default : $(registry_get go default || echo 'not set')"
  bruh_log "GOROOT  : ${GOROOT:-not set}"
  bruh_log "Path    : $(command -v go 2>/dev/null || echo 'not found')"
}

go_update() {
  local version="${1:-}"
  if [ -z "$version" ] || [ "$version" = "all" ]; then
    registry_list_installed "go" | while read -r v; do
      brew upgrade "$(_go_formula "$v")" 2>/dev/null || bruh_warn "Go $v already up to date."
    done
  else
    brew upgrade "$(_go_formula "$version")" 2>/dev/null || bruh_warn "Already up to date."
  fi
  bruh_ok "Done."
}

go_install_or_activate() {
  local version; version=$(_go_resolve_version "$1")
  if registry_is_installed "go" "$version"; then go_activate "$version"
  else go_install "$version"; fi
}
