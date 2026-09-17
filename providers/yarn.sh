# =============================================================================
# BRUH — providers/yarn.sh
# =============================================================================

YARN_RUNTIME_HOME="$BRUH_HOME/runtimes/yarn"

_yarn_require_corepack() {
  command -v corepack >/dev/null 2>&1 || bruh_die "corepack not found. Install Node first: bruh node <version>"
}

_yarn_resolve_version() {
  case "$1" in
    latest|berry|stable) bruh_npm_latest "yarn" "latest" ;;
    classic) curl -fsSL "https://registry.npmjs.org/yarn" 2>/dev/null \
               | jq -r '[.versions | keys[] | select(startswith("1."))] | last' 2>/dev/null ;;
    lts) bruh_npm_latest "yarn" "latest" ;;
    *) echo "$1" ;;
  esac
}

_yarn_major() { echo "$1" | cut -d'.' -f1; }

yarn_install() {
  local input="${1:-latest}"
  command -v node >/dev/null 2>&1 || bruh_die "Node.js required for Yarn. Install: bruh node <version>"
  _yarn_require_corepack
  local exact; exact=$(_yarn_resolve_version "$input")
  [ -z "$exact" ] && bruh_die "Could not resolve Yarn version for: $input"
  local major; major=$(_yarn_major "$exact")
  if registry_is_installed "yarn" "$major"; then
    bruh_warn "Yarn $major ($exact) already installed."; yarn_activate "$major"; return
  fi
  bruh_info "Installing Yarn $exact via corepack..."
  corepack enable yarn 2>/dev/null || true
  corepack prepare "yarn@${exact}" --activate || bruh_die "Failed to install Yarn $exact"
  registry_record_install "yarn" "$major"
  registry_set_exact "yarn" "$exact"
  bruh_ok "Yarn $exact installed."
  yarn_activate "$major"
}

yarn_activate() {
  local input="${1:-}"
  _yarn_require_corepack
  local major exact
  if bruh_is_exact_version "$input"; then
    major=$(_yarn_major "$input"); exact="$input"
    corepack prepare "yarn@${exact}" --activate || bruh_die "Failed to activate Yarn $exact"
    registry_set_exact "yarn" "$exact"
  else
    major="$input"
    exact=$(registry_get_exact "yarn")
    [ -n "$exact" ] && [ "$(_yarn_major "$exact")" = "$major" ] \
      && corepack prepare "yarn@${exact}" --activate || true
  fi
  registry_set "yarn" "current" "$major"
  hash -r 2>/dev/null || true
  bruh_ok "Using Yarn $major"
  yarn --version 2>/dev/null || true
}

yarn_set_default() {
  local input="${1:-}"
  local major
  bruh_is_exact_version "$input" && major=$(_yarn_major "$input") || major="$input"
  if ! registry_is_installed "yarn" "$major"; then
    bruh_err "Yarn $major not installed."; return 1
  fi
  echo "$major" > "$YARN_RUNTIME_HOME/.default"
  registry_set "yarn" "default" "$major"
  bruh_ok "Default Yarn set to $major"
}

yarn_remove() {
  local input="${1:-}"
  local major
  bruh_is_exact_version "$input" && major=$(_yarn_major "$input") || major="$input"
  local default; default=$(registry_get "yarn" "default")
  [ "$default" = "$major" ] && bruh_err "Yarn $major is the default. Change first." && return 1
  if ! registry_is_installed "yarn" "$major"; then
    bruh_err "Yarn $major not installed under Bruh."; return 1
  fi
  if registry_is_bruh_installed "yarn" "$major"; then
    local exact; exact=$(registry_get_exact "yarn")
    [ -n "$exact" ] && corepack remove "yarn@${exact}" 2>/dev/null || true
  fi
  registry_remove_installed "yarn" "$major"
  bruh_ok "Yarn $major removed."
}

yarn_set_project() {
  local input="${1:-stable}"
  [ ! -f "$(pwd)/package.json" ] && bruh_die "No package.json in current directory."
  command -v yarn >/dev/null 2>&1 || bruh_die "No active Yarn. Install one first: bruh yarn <version>"
  bruh_info "Pinning Yarn $input for this project..."
  yarn set version "$input" || bruh_die "Failed to pin Yarn $input"
  bruh_ok "Yarn $input pinned (.yarnrc.yml updated)."
}

yarn_lookup() {
  bruh_header "Installed Yarn versions"
  bruh_divider

  local installed; installed=$(registry_list_installed "yarn")
  local current; current=$(registry_get "yarn" "current")
  local default; default=$(registry_get "yarn" "default")
  local exact; exact=$(registry_get_exact "yarn")

  if [ -z "$installed" ]; then
    bruh_log "No Yarn versions installed under Bruh."
    bruh_log ""; bruh_log "Run ${BRUH_BOLD}bruh search yarn${BRUH_RESET} to see available versions."
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
  printf "  Run ${BRUH_BOLD}bruh search yarn${BRUH_RESET} to see all available versions.\n"
  printf "\n"
}

yarn_search() {
  local filter="${1:-}"
  bruh_header "Available Yarn versions"
  bruh_divider

  local current; current=$(registry_get "yarn" "current")

  printf "  ${BRUH_BOLD}%-10s  %-14s  %s${BRUH_RESET}\n" "Alias" "Latest version" "Status"
  printf "  %-10s  %-14s  %s\n" "─────────" "─────────────" "──────────────"

  local latest_modern; latest_modern=$(bruh_npm_latest "yarn" "latest" 2>/dev/null || echo "n/a")
  local latest_classic; latest_classic=$(curl -fsSL "https://registry.npmjs.org/yarn" 2>/dev/null \
    | jq -r '[.versions | keys[] | select(startswith("1."))] | last' 2>/dev/null || echo "n/a")

  local aliases="berry:latest classic:1.x"
  for entry in $aliases; do
    local alias_name; alias_name=$(echo "$entry" | cut -d: -f1)
    local alias_desc; alias_desc=$(echo "$entry" | cut -d: -f2)
    [ -n "$filter" ] && [ "$filter" != "$alias_name" ] && continue

    local ver=""
    [ "$alias_name" = "berry" ] && ver="$latest_modern"
    [ "$alias_name" = "classic" ] && ver="$latest_classic"

    local major; major=$(echo "$ver" | cut -d'.' -f1)
    local status=""
    registry_is_installed "yarn" "$major" 2>/dev/null && {
      [ "$major" = "$current" ] \
        && status="${BRUH_GREEN}▸ installed (active)${BRUH_RESET}" \
        || status="${BRUH_BLUE}✓ installed${BRUH_RESET}"
    }
    printf "  %-10s  %-14s  %b\n" "$alias_name ($alias_desc)" "${ver:-n/a}" "$status"
  done

  printf "\n"
  printf "  ${BRUH_BOLD}Install with:${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh yarn berry      (latest modern)${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh yarn classic    (v1.x)${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh yarn 4          (major version)${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh yarn 4.3.1      (exact version)${BRUH_RESET}\n"
  printf "\n"
}

yarn_locate() {
  bruh_header "Yarn location"
  bruh_log "Binary  : $(command -v yarn 2>/dev/null || echo 'not found')"
  bruh_log "Version : $(yarn --version 2>/dev/null || echo 'n/a')"
}

yarn_status() {
  bruh_header "Yarn"
  local exact; exact=$(registry_get_exact "yarn")
  bruh_log "Current : $(registry_get yarn current || echo 'not set') (${exact:-n/a})"
  bruh_log "Default : $(registry_get yarn default || echo 'not set')"
  bruh_log "Path    : $(command -v yarn 2>/dev/null || echo 'not found')"
}

yarn_update() { yarn_install "${1:-latest}"; }

yarn_install_or_activate() {
  local input="${1:-latest}"
  local exact; exact=$(_yarn_resolve_version "$input")
  [ -z "$exact" ] && exact="$input"
  local major; major=$(_yarn_major "$exact")
  if registry_is_installed "yarn" "$major"; then yarn_activate "$major"
  else yarn_install "$input"; fi
}
