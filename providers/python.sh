# =============================================================================
# BRUH — providers/python.sh
# =============================================================================

PYTHON_RUNTIME_HOME="$BRUH_HOME/runtimes/python"
HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-$(bruh_homebrew_prefix)}"

_python_formula() { case "$1" in latest|stable) echo "python" ;; *) echo "python@$1" ;; esac; }
_python_symlink()   { echo "$PYTHON_RUNTIME_HOME/v$1"; }
_python_brew_path() { echo "$HOMEBREW_PREFIX/opt/$(_python_formula "$1")"; }

_python_resolve_version() {
  case "$1" in
    latest|stable)
      brew info --json=v2 python 2>/dev/null | jq -r '.formulae[0].versions.stable' | cut -d'.' -f1-2 ;;
    lts) echo "3.12" ;;
    *)   echo "$1" ;;
  esac
}

python_install() {
  local version; version=$(_python_resolve_version "$1")
  bruh_require_brew
  if registry_is_installed "python" "$version"; then
    bruh_warn "Python $version already installed."; python_activate "$version"; return
  fi
  local brew_path; brew_path=$(_python_brew_path "$version")
  if [ -d "$brew_path" ]; then
    bruh_info "Python $version found (pre-existing). Registering..."
    ln -sfn "$brew_path" "$(_python_symlink "$version")"
    registry_record_activate "python" "$version"
    python_activate "$version"; return
  fi
  bruh_info "Installing Python $version via Homebrew..."
  brew install "$(_python_formula "$version")" || bruh_die "Failed to install Python $version"
  ln -sfn "$brew_path" "$(_python_symlink "$version")"
  registry_record_install "python" "$version"
  bruh_ok "Python $version installed."
  python_activate "$version"
}

python_activate() {
  local version; version=$(_python_resolve_version "$1")
  local symlink; symlink=$(_python_symlink "$version")
  if [ ! -L "$symlink" ] && [ ! -d "$symlink" ]; then
    bruh_err "Python $version not installed. Run: bruh python $version"; return 1
  fi
  ln -sfn "$symlink" "$PYTHON_RUNTIME_HOME/current"
  hash -r 2>/dev/null || true
  registry_set "python" "current" "$version"
  bruh_ok "Using Python $version"
  python3 --version 2>/dev/null || true
}

python_set_default() {
  local version; version=$(_python_resolve_version "$1")
  if ! registry_is_installed "python" "$version"; then
    bruh_err "Python $version not installed."; return 1
  fi
  echo "$version" > "$PYTHON_RUNTIME_HOME/.default"
  registry_set "python" "default" "$version"
  bruh_ok "Default Python set to $version"
}

python_remove() {
  local version; version=$(_python_resolve_version "$1")
  local default; default=$(registry_get "python" "default")
  [ "$default" = "$version" ] && bruh_err "Python $version is the default. Change first." && return 1
  if ! registry_is_installed "python" "$version"; then
    bruh_err "Python $version not installed under Bruh."; return 1
  fi
  registry_is_bruh_installed "python" "$version" \
    && brew uninstall "$(_python_formula "$version")" || bruh_warn "Skipping Homebrew uninstall."
  rm -f "$(_python_symlink "$version")" 2>/dev/null || true
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

  printf "  ${BRUH_BOLD}%-10s  %-22s  %s${BRUH_RESET}\n" "Version" "Formula" "Status"
  printf "  %-10s  %-22s  %s\n" "─────────" "─────────────────────" "──────────────"

  brew search '/python@/' 2>/dev/null | grep -E '^python@' | sort -V | while read -r formula; do
    [ -z "$formula" ] && continue
    local ver; ver=$(echo "$formula" | sed 's/python@//')
    [ -n "$filter" ] && [ "$filter" != "$ver" ] && continue
    local status=""
    registry_is_installed "python" "$ver" && {
      [ "$ver" = "$current" ] \
        && status="${BRUH_GREEN}▸ installed (active)${BRUH_RESET}" \
        || status="${BRUH_BLUE}✓ installed${BRUH_RESET}"
    }
    printf "  %-10s  %-22s  %b\n" "$ver" "$formula" "$status"
  done

  printf "\n"
  printf "  ${BRUH_BOLD}Install with:${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh python 3.12${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh python latest${BRUH_RESET}\n"
  printf "\n"
}

python_locate() {
  bruh_header "Python location"
  bruh_log "Binary : $(command -v python3 2>/dev/null || echo 'not found')"
  bruh_log "Version: $(python3 --version 2>/dev/null || echo 'n/a')"
  bruh_log "pip    : $(command -v pip3 2>/dev/null || echo 'not found')"
}

python_status() {
  bruh_header "Python"
  bruh_log "Current : $(registry_get python current || echo 'not set')"
  bruh_log "Default : $(registry_get python default || echo 'not set')"
  bruh_log "Path    : $(command -v python3 2>/dev/null || echo 'not found')"
}

python_update() {
  local version="${1:-}"
  if [ -z "$version" ] || [ "$version" = "all" ]; then
    registry_list_installed "python" | while read -r v; do
      brew upgrade "$(_python_formula "$v")" 2>/dev/null || bruh_warn "Python $v already up to date."
    done
  else
    brew upgrade "$(_python_formula "$version")" 2>/dev/null || bruh_warn "Already up to date."
  fi
  bruh_ok "Done."
}

python_install_or_activate() {
  local version; version=$(_python_resolve_version "$1")
  if registry_is_installed "python" "$version"; then python_activate "$version"
  else python_install "$version"; fi
}
