# =============================================================================
# BRUH — providers/node.sh
# Standalone provider: official binaries from nodejs.org (no Homebrew)
# Layout: $BRUH_HOME/runtimes/node/v<major>  (real dir, extracted tarball)
#         $BRUH_HOME/runtimes/node/current   (symlink → active v<major>)
# =============================================================================

NODE_RUNTIME_HOME="$BRUH_HOME/runtimes/node"
NODE_DIST_URL="https://nodejs.org/dist"

# -----------------------------------------------------------------------------
# Catalog helpers
# -----------------------------------------------------------------------------
_node_catalog() {
  curl -fsSL "$NODE_DIST_URL/index.json" 2>/dev/null \
    || bruh_die "Could not fetch Node version catalog. Check your connection."
}

_node_query() {
  _node_catalog | jq -r "$1" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Version resolution
# -----------------------------------------------------------------------------
# Resolve user input → full version WITH 'v' prefix (e.g. v22.14.0)
# Accepts: latest | stable | lts | <major> | <major.minor.patch>
_node_resolve_full() {
  local req="${1:-}"
  case "$req" in
    latest)
      _node_query '.[0].version'
      ;;
    stable|lts)
      _node_query '[.[] | select(.lts != false)][0].version'
      ;;
    *)
      local v="${req#v}"
      case "$v" in
        # Exact semver — use as-is
        *.*)
          case "$v" in
            *[!0-9.]*) echo ""; return ;;
            *)         echo "v$v" ;;
          esac
          ;;
        # Major only — validate numeric, resolve to latest in that line
        '')
          echo ""; return ;;
        *[!0-9]*)
          echo ""; return ;;
        *)
          _node_query "[.[] | select(.version | startswith(\"v$v.\"))][0].version"
          ;;
      esac
      ;;
  esac
}

# Resolve user input → major version (registry + symlink key)
_node_resolve_version() {
  local full
  full=$(_node_resolve_full "$1")
  [ -z "$full" ] || [ "$full" = "null" ] && { echo ""; return; }
  bruh_major_version "${full#v}"
}

# -----------------------------------------------------------------------------
# Install
# -----------------------------------------------------------------------------
node_install() {
  local platform; platform=$(bruh_platform)
  [ "$platform" = "unsupported" ] && \
    bruh_die "Unsupported platform: $(uname -s)/$(uname -m)"

  local full; full=$(_node_resolve_full "$1")
  if [ -z "$full" ] || [ "$full" = "null" ]; then
    bruh_err "Node version '$1' not found. Try: bruh search node"; return 1
  fi
  local major; major=$(bruh_major_version "${full#v}")

  local dir="$NODE_RUNTIME_HOME/v$major"

  # Already installed and healthy?
  if registry_is_installed "node" "$major" && registry_verify "node" "$major" "bin/node"; then
    local actual; actual=$("$dir/bin/node" -v 2>/dev/null)
    if [ "$actual" = "$full" ]; then
      bruh_warn "Node $major already installed ($full)."
      node_activate "$major"; return
    fi
    bruh_info "Node $major is stale ($actual) — updating to $full..."
  fi

  local url="$NODE_DIST_URL/$full/node-$full-$platform.tar.gz"
  local tmp_tar="$NODE_RUNTIME_HOME/.node-$full.tar.gz"
  mkdir -p "$NODE_RUNTIME_HOME"

  bruh_info "Downloading Node $full ($platform)..."
  if ! bruh_download "$url" "$tmp_tar"; then
    rm -f "$tmp_tar"
    bruh_err "Failed to download $url"; return 1
  fi

  bruh_info "Extracting to $dir..."
  rm -rf "$dir"
  if ! bruh_extract "$tmp_tar" "$dir" 1; then
    rm -rf "$dir" "$tmp_tar"
    bruh_err "Failed to extract Node archive."; return 1
  fi
  rm -f "$tmp_tar"

  # Verify the binary actually runs before registering
  "$dir/bin/node" -v >/dev/null 2>&1 || { rm -rf "$dir"; bruh_err "Node binary failed verification."; return 1; }

  registry_record_install "node" "$major"
  bruh_ok "Node $full installed."
  node_activate "$major"
}

# -----------------------------------------------------------------------------
# Activate
# -----------------------------------------------------------------------------
node_activate() {
  local major; major=$(_node_resolve_version "$1")
  if [ -z "$major" ]; then
    bruh_err "Unknown Node version: $1"; return 1
  fi
  local dir="$NODE_RUNTIME_HOME/v$major"
  if [ ! -d "$dir" ] || ! registry_verify "node" "$major" "bin/node"; then
    bruh_err "Node $major not installed. Run: bruh node $major"; return 1
  fi
  ln -sfn "$dir" "$NODE_RUNTIME_HOME/current"
  if [ "$(readlink "$NODE_RUNTIME_HOME/current")" != "$dir" ]; then
    bruh_err "Failed to update Node symlink to $major"; return 1
  fi
  registry_set "node" "current" "$major"
  # Write hash -r to .activate_env so the bruh() shell function wrapper in
  # bruh.env clears the parent shell's command cache after the symlink update.
  printf 'hash -r 2>/dev/null || true\n' > "$BRUH_HOME/.activate_env"
  bruh_ok "Using Node $major"
  "$dir/bin/node" -v 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# Default
# -----------------------------------------------------------------------------
node_set_default() {
  local major; major=$(_node_resolve_version "$1")
  if [ -z "$major" ] || ! registry_is_installed "node" "$major"; then
    bruh_err "Node $1 not installed."; return 1
  fi
  echo "$major" > "$NODE_RUNTIME_HOME/.default"
  registry_set "node" "default" "$major"
  bruh_ok "Default Node set to $major"
  bruh_info "Run 'source ~/.zshrc' to apply in the current terminal."
  node_activate "$major"
}

# -----------------------------------------------------------------------------
# Remove — just delete the version directory
# -----------------------------------------------------------------------------
node_remove() {
  local major; major=$(_node_resolve_version "$1")
  local default; default=$(registry_get "node" "default")
  if [ "$default" = "$major" ]; then
    bruh_err "Node $major is the default. Change default first."; return 1
  fi
  if ! registry_is_installed "node" "$major"; then
    bruh_err "Node $major not installed under Bruh."; return 1
  fi
  rm -rf "$NODE_RUNTIME_HOME/v$major"
  registry_remove_installed "node" "$major"
  bruh_ok "Node $major removed."
}

# -----------------------------------------------------------------------------
# Lookup
# -----------------------------------------------------------------------------
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
    if ! registry_verify "node" "$v" "bin/node"; then
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
  printf "  ${BRUH_DIM}Path    : $(command -v node 2>/dev/null || echo 'not found')${BRUH_RESET}\n"
  printf "\n"
  printf "  Run ${BRUH_BOLD}bruh search node${BRUH_RESET} to see all available versions.\n"
  printf "\n"
}

# -----------------------------------------------------------------------------
# Search — list available versions from the nodejs.org catalog
# -----------------------------------------------------------------------------
node_search() {
  local filter="${1:-}"
  bruh_header "Available Node.js versions"
  bruh_divider

  local current; current=$(registry_get "node" "current")

  printf "  ${BRUH_BOLD}%-8s  %-12s  %-12s  %s${BRUH_RESET}\n" "Version" "Release" "LTS" "Status"
  printf "  %-8s  %-12s  %-12s  %s\n" "───────" "───────────" "───────────" "──────────────"

  _node_catalog | jq -r '
    reduce .[] as $e ({};
      .[($e.version | ltrimstr("v") | split(".")[0])] //= $e)
    | to_entries[]
    | "\(.key)\t\(.value.version | ltrimstr("v"))\t\(if .value.lts then .value.lts else "" end)"
  ' 2>/dev/null | sort -rn | while IFS=$'\t' read -r major full lts; do
    [ -n "$filter" ] && [ "$filter" != "$major" ] && continue
    local status=""
    registry_is_installed "node" "$major" && {
      [ "$major" = "$current" ] \
        && status="${BRUH_GREEN}▸ installed (active)${BRUH_RESET}" \
        || status="${BRUH_BLUE}✓ installed${BRUH_RESET}"
    }
    printf "  %-8s  %-12s  %-12s  %b\n" "$major" "$full" "${lts:--}" "${status:-}"
  done

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
  local dir="$NODE_RUNTIME_HOME/current"
  bruh_log "Home   : $([ -d "$dir" ] && echo "$dir" || echo 'not installed')"
  bruh_log "Binary : $(command -v node 2>/dev/null || echo 'not found')"
  bruh_log "Version: $(node -v 2>/dev/null || echo 'n/a')"
  bruh_log "npm    : $(command -v npm 2>/dev/null || echo 'not found')"
}

node_status() {
  bruh_header "Node"
  local current; current=$(registry_get node current)
  local dir="$NODE_RUNTIME_HOME/v${current:-}"
  bruh_log "Current : ${current:-not set} ($(node -v 2>/dev/null || echo n/a))"
  bruh_log "Default : $(registry_get node default || echo 'not set')"
  bruh_log "Path    : $(command -v node 2>/dev/null || echo 'not found')"
  bruh_log "Home    : $([ -d "$dir" ] && echo "$dir" || echo 'not installed')"
}

# -----------------------------------------------------------------------------
# Update — re-resolve latest in each installed major line and refresh if stale
# -----------------------------------------------------------------------------
node_update() {
  local version="${1:-}"
  local majors
  if [ -z "$version" ] || [ "$version" = "all" ]; then
    majors=$(registry_list_installed "node")
    if [ -z "$majors" ]; then
      bruh_warn "No Node versions installed."; return 0
    fi
  else
    majors=$(_node_resolve_version "$version")
  fi

  echo "$majors" | while read -r m; do
    [ -z "$m" ] && continue
    local latest_full; latest_full=$(_node_resolve_full "$m")
    local current_full; current_full=$("$NODE_RUNTIME_HOME/v$m/bin/node" -v 2>/dev/null)
    if [ "$current_full" = "$latest_full" ]; then
      bruh_ok "Node $m already at latest ($latest_full)."
    else
      bruh_info "Updating Node $m: ${current_full:-missing} → $latest_full..."
      node_install "$m"
    fi
  done
  bruh_ok "Done."
}

node_install_or_activate() {
  local major; major=$(_node_resolve_version "$1")
  if [ -n "$major" ] && registry_is_installed "node" "$major" \
     && registry_verify "node" "$major" "bin/node"; then
    node_activate "$major"
  else
    node_install "$1"
  fi
}
