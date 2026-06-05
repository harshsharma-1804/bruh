# =============================================================================
# BRUH — providers/pnpm.sh
# =============================================================================

PNPM_RUNTIME_HOME="$BRUH_HOME/runtimes/pnpm"

_pnpm_require_corepack() {
  command -v corepack >/dev/null 2>&1 || bruh_die "corepack not found. Install Node first: bruh node <version>"
}

_pnpm_resolve_version() {
  case "$1" in
    latest|stable|lts) bruh_npm_latest "pnpm" "latest" ;;
    *) echo "$1" ;;
  esac
}

_pnpm_major() { echo "$1" | cut -d'.' -f1; }

pnpm_install() {
  local input="${1:-latest}"
  command -v node >/dev/null 2>&1 || bruh_die "Node.js required for pnpm. Install: bruh node <version>"
  _pnpm_require_corepack
  local exact; exact=$(_pnpm_resolve_version "$input")
  [ -z "$exact" ] && bruh_die "Could not resolve pnpm version for: $input"
  local major; major=$(_pnpm_major "$exact")
  if registry_is_installed "pnpm" "$major"; then
    bruh_warn "pnpm $major ($exact) already installed."; pnpm_activate "$major"; return
  fi
  bruh_info "Installing pnpm $exact via corepack..."
  corepack enable pnpm 2>/dev/null || true
  corepack prepare "pnpm@${exact}" --activate || bruh_die "Failed to install pnpm $exact"
  registry_record_install "pnpm" "$major"
  registry_set_exact "pnpm" "$exact"
  bruh_ok "pnpm $exact installed."
  pnpm_activate "$major"
}

pnpm_activate() {
  local input="${1:-}"
  _pnpm_require_corepack
  local major exact
  if bruh_is_exact_version "$input"; then
    major=$(_pnpm_major "$input"); exact="$input"
    corepack prepare "pnpm@${exact}" --activate || bruh_die "Failed to activate pnpm $exact"
    registry_set_exact "pnpm" "$exact"
  else
    major="$input"
    exact=$(registry_get_exact "pnpm")
    [ -n "$exact" ] && [ "$(_pnpm_major "$exact")" = "$major" ] \
      && corepack prepare "pnpm@${exact}" --activate || true
  fi
  registry_set "pnpm" "current" "$major"
  hash -r 2>/dev/null || true
  bruh_ok "Using pnpm $major"
  pnpm --version 2>/dev/null || true
}

pnpm_set_default() {
  local input="${1:-}"
  local major
  bruh_is_exact_version "$input" && major=$(_pnpm_major "$input") || major="$input"
  if ! registry_is_installed "pnpm" "$major"; then
    bruh_err "pnpm $major not installed."; return 1
  fi
  echo "$major" > "$PNPM_RUNTIME_HOME/.default"
  registry_set "pnpm" "default" "$major"
  bruh_ok "Default pnpm set to $major"
}

pnpm_remove() {
  local input="${1:-}"
  local major
  bruh_is_exact_version "$input" && major=$(_pnpm_major "$input") || major="$input"
  local default; default=$(registry_get "pnpm" "default")
  [ "$default" = "$major" ] && bruh_err "pnpm $major is the default. Change first." && return 1
  if ! registry_is_installed "pnpm" "$major"; then
    bruh_err "pnpm $major not installed under Bruh."; return 1
  fi
  if registry_is_bruh_installed "pnpm" "$major"; then
    local exact; exact=$(registry_get_exact "pnpm")
    [ -n "$exact" ] && corepack remove "pnpm@${exact}" 2>/dev/null || true
  fi
  registry_remove_installed "pnpm" "$major"
  bruh_ok "pnpm $major removed."
}

pnpm_set_project() {
  local input="${1:-latest}"
  [ ! -f "$(pwd)/package.json" ] && bruh_die "No package.json in current directory."
  command -v node >/dev/null 2>&1 || bruh_die "Node.js required for pnpm set-project."
  local exact; exact=$(_pnpm_resolve_version "$input")
  [ -z "$exact" ] && exact="$input"
  bruh_info "Pinning pnpm@${exact} for this project..."
  node -e "
    const fs = require('fs');
    const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
    pkg.packageManager = 'pnpm@${exact}';
    fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
  " || bruh_die "Failed to update package.json"
  bruh_ok "pnpm@${exact} pinned (package.json updated)."
}

pnpm_lookup() {
  bruh_header "Installed pnpm versions"
  bruh_divider

  local installed; installed=$(registry_list_installed "pnpm")
  local current; current=$(registry_get "pnpm" "current")
  local default; default=$(registry_get "pnpm" "default")
  local exact; exact=$(registry_get_exact "pnpm")

  if [ -z "$installed" ]; then
    bruh_log "No pnpm versions installed under Bruh."
    bruh_log ""; bruh_log "Run ${BRUH_BOLD}bruh search pnpm${BRUH_RESET} to see available versions."
    return
  fi

  printf "  ${BRUH_BOLD}%-10s  %-12s  %s${BRUH_RESET}\n" "Version" "Exact" "Status"
  printf "  %-10s  %-12s  %s\n" "─────────" "───────────" "──────────────"

  echo "$installed" | while read -r v; do
    [ -z "$v" ] && continue
    local ev=""
    [ "$v" = "$current" ] && ev="$exact"
    local status=""
    if [ "$v" = "$current" ] && [ "$v" = "$default" ]; then
      status="${BRUH_GREEN}▸ active  ${BRUH_RESET}${BRUH_BLUE}(default)${BRUH_RESET}"
    elif [ "$v" = "$current" ]; then
      status="${BRUH_GREEN}▸ active${BRUH_RESET}"
    elif [ "$v" = "$default" ]; then
      status="${BRUH_BLUE}(default)${BRUH_RESET}"
    fi
    printf "  ${BRUH_BOLD}%-10s${BRUH_RESET}  %-12s  %b\n" "$v" "${ev:-—}" "$status"
  done

  printf "\n"
  printf "  ${BRUH_DIM}Current : ${current:-not set} (${exact:-n/a})${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}Default : ${default:-not set}${BRUH_RESET}\n"
  printf "\n"
  printf "  Run ${BRUH_BOLD}bruh search pnpm${BRUH_RESET} to see all available versions.\n"
  printf "\n"
}

pnpm_search() {
  local filter="${1:-}"
  bruh_header "Available pnpm versions"
  bruh_divider

  local current; current=$(registry_get "pnpm" "current")
  local latest; latest=$(bruh_npm_latest "pnpm" "latest" 2>/dev/null || echo "n/a")
  local latest_major; latest_major=$(echo "$latest" | cut -d'.' -f1)

  printf "  ${BRUH_BOLD}%-10s  %-14s  %s${BRUH_RESET}\n" "Channel" "Latest version" "Status"
  printf "  %-10s  %-14s  %s\n" "─────────" "─────────────" "──────────────"

  local channels="latest"
  for ch in $channels; do
    [ -n "$filter" ] && [ "$filter" != "$ch" ] && continue
    local status=""
    registry_is_installed "pnpm" "$latest_major" 2>/dev/null && {
      [ "$latest_major" = "$current" ] \
        && status="${BRUH_GREEN}▸ installed (active)${BRUH_RESET}" \
        || status="${BRUH_BLUE}✓ installed${BRUH_RESET}"
    }
    printf "  %-10s  %-14s  %b\n" "$ch" "${latest:-n/a}" "$status"
  done

  printf "\n"
  printf "  ${BRUH_DIM}Specific major/exact versions also supported${BRUH_RESET}\n"
  printf "\n"
  printf "  ${BRUH_BOLD}Install with:${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh pnpm latest${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh pnpm 9${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh pnpm 9.1.0${BRUH_RESET}\n"
  printf "\n"
}

pnpm_locate() {
  bruh_header "pnpm location"
  bruh_log "Binary  : $(command -v pnpm 2>/dev/null || echo 'not found')"
  bruh_log "Version : $(pnpm --version 2>/dev/null || echo 'n/a')"
}

pnpm_status() {
  bruh_header "pnpm"
  local exact; exact=$(registry_get_exact "pnpm")
  bruh_log "Current : $(registry_get pnpm current || echo 'not set') (${exact:-n/a})"
  bruh_log "Default : $(registry_get pnpm default || echo 'not set')"
  bruh_log "Path    : $(command -v pnpm 2>/dev/null || echo 'not found')"
}

pnpm_update() { pnpm_install "${1:-latest}"; }

pnpm_install_or_activate() {
  local input="${1:-latest}"
  local exact; exact=$(_pnpm_resolve_version "$input")
  [ -z "$exact" ] && exact="$input"
  local major; major=$(_pnpm_major "$exact")
  if registry_is_installed "pnpm" "$major"; then pnpm_activate "$major"
  else pnpm_install "$input"; fi
}
