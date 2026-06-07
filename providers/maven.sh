# =============================================================================
# BRUH — providers/maven.sh
# Maven provider — Homebrew backend
# Supported versions: 3.8 (maven@3.8), 3.9 / latest / stable (maven)
# =============================================================================

MAVEN_RUNTIME_HOME="$BRUH_HOME/runtimes/maven"
HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-$(bruh_homebrew_prefix)}"

# -----------------------------------------------------------------------------
# Internal helpers
# -----------------------------------------------------------------------------

_maven_formula() {
  case "$1" in
    latest|stable|3.9|3) echo "maven" ;;
    3.8)                  echo "maven@3.8" ;;
    *)                    echo "maven@$1" ;;
  esac
}

_maven_brew_path() {
  echo "$HOMEBREW_PREFIX/opt/$(_maven_formula "$1")"
}

_maven_symlink() {
  echo "$MAVEN_RUNTIME_HOME/v$1"
}

_maven_resolve_version() {
  case "$1" in
    latest|stable|3|3.9|"")
      brew info --json=v2 maven 2>/dev/null \
        | jq -r '.formulae[0].versions.stable' 2>/dev/null \
        | cut -d'.' -f1-2 ;;
    *) echo "$1" ;;
  esac
}

# -----------------------------------------------------------------------------
# maven_search [version_filter]
# -----------------------------------------------------------------------------
maven_search() {
  local filter="${1:-}"

  bruh_header "Available Maven versions"
  bruh_divider

  printf "  ${BRUH_BOLD}%-10s  %-20s  %s${BRUH_RESET}\n" "Version" "Formula" "Status"
  printf "  %-10s  %-20s  %s\n" "─────────" "───────────────────" "──────────────"

  local current; current=$(registry_get "maven" "current")

  for formula in maven maven@3.8; do
    brew info "$formula" >/dev/null 2>&1 || continue
    local ver
    case "$formula" in
      maven)     ver=$(brew info --json=v2 maven 2>/dev/null | jq -r '.formulae[0].versions.stable' | cut -d'.' -f1-2) ;;
      maven@3.8) ver="3.8" ;;
    esac
    [ -n "$filter" ] && [ "$filter" != "$ver" ] && continue
    local status=""
    if registry_is_installed "maven" "$ver"; then
      [ "$ver" = "$current" ] \
        && status="${BRUH_GREEN}▸ installed (active)${BRUH_RESET}" \
        || status="${BRUH_BLUE}✓ installed${BRUH_RESET}"
    fi
    printf "  %-10s  %-20s  %b\n" "$ver" "$formula" "$status"
  done

  printf "\n"
  printf "  ${BRUH_BOLD}Install with:${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh maven 3.9${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh maven 3.8${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh maven latest${BRUH_RESET}\n"
  printf "\n"
}

# -----------------------------------------------------------------------------
# maven_install <version>
# -----------------------------------------------------------------------------
maven_install() {
  local version; version=$(_maven_resolve_version "$1")
  bruh_require_brew

  if registry_is_installed "maven" "$version"; then
    bruh_warn "Maven $version already installed."
    maven_activate "$version"; return
  fi

  local formula; formula=$(_maven_formula "$version")
  local brew_path; brew_path=$(_maven_brew_path "$version")
  local symlink; symlink=$(_maven_symlink "$version")

  if [ -d "$brew_path" ]; then
    bruh_info "Maven $version found (pre-existing). Registering..."
    ln -sfn "$brew_path" "$symlink"
    registry_record_activate "maven" "$version"
    maven_activate "$version"; return
  fi

  bruh_info "Installing Maven $version via Homebrew..."
  brew install "$formula" || bruh_die "Failed to install Maven $version"
  ln -sfn "$brew_path" "$symlink"
  registry_record_install "maven" "$version"
  bruh_ok "Maven $version installed."
  maven_activate "$version"
}

# -----------------------------------------------------------------------------
# maven_activate <version>
# -----------------------------------------------------------------------------
maven_activate() {
  local version; version=$(_maven_resolve_version "$1")
  local symlink; symlink=$(_maven_symlink "$version")

  if [ ! -L "$symlink" ] && [ ! -d "$symlink" ]; then
    bruh_err "Maven $version not installed. Run: bruh maven $version"; return 1
  fi

  ln -sfn "$symlink" "$MAVEN_RUNTIME_HOME/current"
  registry_set "maven" "current" "$version"

  # Write activation exports to .activate_env so the bruh() shell function
  # wrapper in bruh.env can source them into the current terminal session.
  {
    printf 'export MAVEN_HOME="%s/current"\n' "$MAVEN_RUNTIME_HOME"
    printf 'export PATH="$MAVEN_HOME/bin:$PATH"\n'
    printf 'hash -r 2>/dev/null || true\n'
  } > "$BRUH_HOME/.activate_env"

  bruh_ok "Using Maven $version"
  mvn --version 2>/dev/null | head -1 || true
}

# -----------------------------------------------------------------------------
# maven_set_default <version>
# -----------------------------------------------------------------------------
maven_set_default() {
  local version; version=$(_maven_resolve_version "$1")

  if ! registry_is_installed "maven" "$version"; then
    bruh_err "Maven $version not installed. Run: bruh maven $version"
    return 1
  fi

  echo "$version" > "$MAVEN_RUNTIME_HOME/.default"
  registry_set "maven" "default" "$version"
  bruh_ok "Default Maven set to $version"
  bruh_info "Run 'source ~/.zshrc' to apply in the current terminal."
  maven_activate "$version"
}

# -----------------------------------------------------------------------------
# maven_remove <version>
# -----------------------------------------------------------------------------
maven_remove() {
  local version; version=$(_maven_resolve_version "$1")
  local default; default=$(registry_get "maven" "default")

  if [ "$default" = "$version" ]; then
    bruh_err "Maven $version is the default. Change default first."; return 1
  fi

  if ! registry_is_installed "maven" "$version"; then
    bruh_err "Maven $version not installed under Bruh."; return 1
  fi

  if registry_is_bruh_installed "maven" "$version"; then
    local formula; formula=$(_maven_formula "$version")
    bruh_info "Uninstalling Maven $version..."
    brew uninstall "$formula" 2>/dev/null || bruh_warn "Homebrew uninstall failed."
  fi

  rm -f "$(_maven_symlink "$version")" 2>/dev/null || true
  registry_remove_installed "maven" "$version"
  bruh_ok "Maven $version removed."
}

# -----------------------------------------------------------------------------
# maven_lookup
# -----------------------------------------------------------------------------
maven_lookup() {
  bruh_header "Installed Maven versions"
  bruh_divider

  local installed; installed=$(registry_list_installed "maven")
  local current; current=$(registry_get "maven" "current")
  local default; default=$(registry_get "maven" "default")

  if [ -z "$installed" ]; then
    bruh_log "No Maven versions installed under Bruh."
    bruh_log ""
    bruh_log "Run ${BRUH_BOLD}bruh search maven${BRUH_RESET} to see available versions."
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
  printf "  ${BRUH_DIM}Path    : $(command -v mvn 2>/dev/null || echo 'not found')${BRUH_RESET}\n"
  printf "\n"
  printf "  Run ${BRUH_BOLD}bruh search maven${BRUH_RESET} to see all available versions.\n"
  printf "\n"
}

# -----------------------------------------------------------------------------
# maven_locate
# -----------------------------------------------------------------------------
maven_locate() {
  bruh_header "Maven location"
  bruh_log "Binary      : $(command -v mvn 2>/dev/null || echo 'not found')"
  bruh_log "MAVEN_HOME  : ${MAVEN_HOME:-not set}"
  mvn --version 2>/dev/null | head -1 | sed 's/^/  /' || true
}

# -----------------------------------------------------------------------------
# maven_status
# -----------------------------------------------------------------------------
maven_status() {
  bruh_header "Maven"
  bruh_log "Current    : $(registry_get maven current || echo 'not set')"
  bruh_log "Default    : $(registry_get maven default || echo 'not set')"
  bruh_log "MAVEN_HOME : ${MAVEN_HOME:-not set}"
  bruh_log "Path       : $(command -v mvn 2>/dev/null || echo 'not found')"
}

# -----------------------------------------------------------------------------
# maven_update [version|all]
# -----------------------------------------------------------------------------
maven_update() {
  local version="${1:-}"
  if [ -z "$version" ] || [ "$version" = "all" ]; then
    registry_list_installed "maven" | while read -r v; do
      local formula; formula=$(_maven_formula "$v")
      bruh_info "Updating Maven $v..."
      brew upgrade "$formula" 2>/dev/null || bruh_warn "Maven $v already up to date."
    done
  else
    local formula; formula=$(_maven_formula "$version")
    brew upgrade "$formula" 2>/dev/null || bruh_warn "Maven $version already up to date."
  fi
  bruh_ok "Done."
}

# -----------------------------------------------------------------------------
# maven_install_or_activate <version>
# -----------------------------------------------------------------------------
maven_install_or_activate() {
  local version; version=$(_maven_resolve_version "$1")
  if registry_is_installed "maven" "$version"; then
    maven_activate "$version"
  else
    maven_install "$version"
  fi
}
