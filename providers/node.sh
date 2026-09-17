# =============================================================================
# BRUH — providers/node.sh
# =============================================================================

NODE_RUNTIME_HOME="$BRUH_HOME/runtimes/node"
HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-$(bruh_homebrew_prefix)}"

_node_formula() {
  case "$1" in
    latest|stable|lts) echo "node" ;;
    *)
      if brew info "node@$1" >/dev/null 2>&1; then echo "node@$1"
      else echo "node_not_found"; fi ;;
  esac
}

_node_symlink()   { echo "$NODE_RUNTIME_HOME/v$1"; }
_node_brew_path() { echo "$HOMEBREW_PREFIX/opt/$1"; }

_node_resolve_version() {
  case "$1" in
    latest)
      brew info --json=v2 node 2>/dev/null | jq -r '.formulae[0].versions.stable' | cut -d'.' -f1 ;;
    stable|lts)
      local ver
      ver=$(brew info --json=v2 node 2>/dev/null | jq -r '.formulae[0].versions.stable' | cut -d'.' -f1)
      while [ $(( ver % 2 )) -ne 0 ]; do ver=$(( ver - 1 )); done
      echo "$ver" ;;
    *) echo "$1" ;;
  esac
}

node_install() {
  local version; version=$(_node_resolve_version "$1")
  bruh_require_brew
  
  local formula; formula=$(_node_formula "$version")
  if [ "$formula" = "node_not_found" ]; then
    bruh_err "Node version $version is not available via Homebrew formulas."; return 1
  fi

  if registry_is_installed "node" "$version"; then
    # Even if registry says installed, verify the actual binary exists and is the right version
    local symlink; symlink=$(_node_symlink "$version")
    if [ -L "$symlink" ] || [ -d "$symlink" ]; then
      local actual_ver; actual_ver=$("$symlink/bin/node" -v 2>/dev/null | sed 's/v//')
      if [[ "$actual_ver" == "$version"* ]]; then
        bruh_warn "Node $version already installed."; node_activate "$version"; return
      fi
    fi
  fi

  local brew_path; brew_path=$(_node_brew_path "$formula")
  local symlink; symlink=$(_node_symlink "$version")
  if [ -d "$brew_path" ]; then
    # Verify this pre-existing path actually matches the requested version
    local actual_ver; actual_ver=$("$brew_path/bin/node" -v 2>/dev/null | sed 's/v//')
    if [[ "$actual_ver" == "$version"* ]]; then
      bruh_info "Node $version found (pre-existing). Registering..."
      ln -sfn "$brew_path" "$symlink"
      registry_record_activate "node" "$version"
      node_activate "$version"; return
    fi
  fi
  bruh_info "Installing Node $version via Homebrew..."
  brew install "$formula" || bruh_die "Failed to install Node $version"
  ln -sfn "$brew_path" "$symlink"
  registry_record_install "node" "$version"
  bruh_ok "Node $version installed."
  node_activate "$version"
}

node_activate() {
  local version; version=$(_node_resolve_version "$1")
  local symlink; symlink=$(_node_symlink "$version")
  if [ ! -L "$symlink" ] && [ ! -d "$symlink" ]; then
    bruh_err "Node $version not installed. Run: bruh node $version"; return 1
  fi
  ln -sfn "$symlink" "$NODE_RUNTIME_HOME/current"
  if [ "$(readlink "$NODE_RUNTIME_HOME/current")" != "$symlink" ]; then
    bruh_err "Failed to update Node symlink to $version"; return 1
  fi
  registry_set "node" "current" "$version"
  # Write hash -r to .activate_env so the bruh() shell function wrapper in
  # bruh.env clears the parent shell's command cache after the symlink update.
  printf 'hash -r 2>/dev/null || true\n' > "$BRUH_HOME/.activate_env"
  bruh_ok "Using Node $version"
  node -v 2>/dev/null || true
}

node_set_default() {
  local version; version=$(_node_resolve_version "$1")
  if ! registry_is_installed "node" "$version"; then
    bruh_err "Node $version not installed."; return 1
  fi
  echo "$version" > "$NODE_RUNTIME_HOME/.default"
  registry_set "node" "default" "$version"
  bruh_ok "Default Node set to $version"
  bruh_info "Run 'source ~/.zshrc' to apply in the current terminal."
  node_activate "$version"
}

node_remove() {
  local version; version=$(_node_resolve_version "$1")
  local default; default=$(registry_get "node" "default")
  if [ "$default" = "$version" ]; then
    bruh_err "Node $version is the default. Change default first."; return 1
  fi
  if ! registry_is_installed "node" "$version"; then
    bruh_err "Node $version not installed under Bruh."; return 1
  fi
  if registry_is_bruh_installed "node" "$version"; then
    brew uninstall "$(_node_formula "$version")" || bruh_warn "Homebrew uninstall failed."
  fi
  rm -f "$(_node_symlink "$version")" 2>/dev/null || true
  registry_remove_installed "node" "$version"
  bruh_ok "Node $version removed."
}

node_lookup() {
  bruh_header "Installed Node versions"
  bruh_divider

  local installed; installed=$(registry_list_installed "node")
  local current; current=$(registry_get "node" "current")
  local default; default=$(registry_get "node" "default")

  if [ -z "$installed" ]; then
    bruh_log "No Node versions installed under Bruh."
    bruh_log ""
    bruh_log "Run ${BRUH_BOLD}bruh search node${BRUH_RESET} to see available versions."
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
  printf "  ${BRUH_DIM}Path    : $(command -v node 2>/dev/null || echo 'not found')${BRUH_RESET}\n"
  printf "\n"
  printf "  Run ${BRUH_BOLD}bruh search node${BRUH_RESET} to see all available versions.\n"
  printf "\n"
}

node_search() {
  local filter="${1:-}"
  bruh_header "Available Node.js versions"
  bruh_divider

  local current; current=$(registry_get "node" "current")

  printf "  ${BRUH_BOLD}%-10s  %-22s  %s${BRUH_RESET}\n" "Version" "Formula" "Status"
  printf "  %-10s  %-22s  %s\n" "─────────" "─────────────────────" "──────────────"

  # Versioned formulae from Homebrew
  local formulae
  formulae=$(brew search '/node@/' 2>/dev/null | grep -E '^node@' | sort -V)

  echo "$formulae" | while read -r formula; do
    [ -z "$formula" ] && continue
    local ver; ver=$(echo "$formula" | grep -oE '[0-9]+')
    [ -n "$filter" ] && [ "$filter" != "$ver" ] && continue
    local status=""
    registry_is_installed "node" "$ver" && {
      [ "$ver" = "$current" ] \
        && status="${BRUH_GREEN}▸ installed (active)${BRUH_RESET}" \
        || status="${BRUH_BLUE}✓ installed${BRUH_RESET}"
    }
    printf "  %-10s  %-22s  %b\n" "$ver" "$formula" "$status"
  done

  # Latest (unversioned)
  [ -z "$filter" ] && {
    local status=""
    registry_is_installed "node" "latest" && status="${BRUH_BLUE}✓ installed${BRUH_RESET}"
    printf "  %-10s  %-22s  %b\n" "latest" "node" "$status"
  }

  printf "\n"
  printf "  ${BRUH_BOLD}Install with:${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh node 22${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh node latest${BRUH_RESET}\n"
  printf "\n"
}

node_installed() {
  bruh_header "Installed Node versions"
  local installed; installed=$(registry_list_installed "node")
  local current; current=$(registry_get "node" "current")
  local default; default=$(registry_get "node" "default")
  [ -z "$installed" ] && bruh_log "No Node versions installed under Bruh." && return
  echo "$installed" | while read -r v; do
    local m=""
    [ "$v" = "$current" ] && m="${m} ${BRUH_GREEN}(active)${BRUH_RESET}"
    [ "$v" = "$default" ] && m="${m} ${BRUH_BLUE}(default)${BRUH_RESET}"
    bruh_log "  $v$m"
  done
}

node_locate() {
  bruh_header "Node location"
  bruh_log "Binary : $(command -v node 2>/dev/null || echo 'not found')"
  bruh_log "Version: $(node -v 2>/dev/null || echo 'n/a')"
  bruh_log "npm    : $(command -v npm 2>/dev/null || echo 'not found')"
}

node_status() {
  bruh_header "Node"
  bruh_log "Current : $(registry_get node current || echo 'not set') ($(node -v 2>/dev/null || echo n/a))"
  bruh_log "Default : $(registry_get node default || echo 'not set')"
  bruh_log "Path    : $(command -v node 2>/dev/null || echo 'not found')"
}

node_update() {
  local version="${1:-}"
  if [ -z "$version" ] || [ "$version" = "all" ]; then
    registry_list_installed "node" | while read -r v; do
      brew upgrade "$(_node_formula "$v")" 2>/dev/null || bruh_warn "Node $v already up to date."
    done
  else
    brew upgrade "$(_node_formula "$version")" 2>/dev/null || bruh_warn "Node $version already up to date."
  fi
  bruh_ok "Done."
}

node_install_or_activate() {
  local version; version=$(_node_resolve_version "$1")
  if registry_is_installed "node" "$version"; then node_activate "$version"
  else node_install "$version"; fi
}
