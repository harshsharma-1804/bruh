# =============================================================================
# BRUH — providers/maven.sh
# Standalone provider: official Maven binary tarballs from Apache
# Layout: $BRUH_HOME/runtimes/maven/v<major.minor>   (extracted Maven home)
#         $BRUH_HOME/runtimes/maven/current          (symlink → active)
# =============================================================================

MAVEN_RUNTIME_HOME="$BRUH_HOME/runtimes/maven"
MAVEN_METADATA="https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/maven-metadata.xml"

# -----------------------------------------------------------------------------
# Catalog: all release versions from Maven Central metadata
# (alpha/beta/rc/cr milestones excluded)
# -----------------------------------------------------------------------------
_maven_catalog() {
  curl -fsSL "$MAVEN_METADATA" 2>/dev/null \
    | grep -oE '<version>[^<]+</version>' \
    | sed -E 's#</?version>##g' \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -V
}

# Resolve user input → full version (e.g. 3.9 → 3.9.9)
_maven_resolve_full() {
  local req="${1:-latest}"
  case "$req" in
    latest|stable)
      _maven_catalog | tail -1
      ;;
    lts|3|3.9|"")
      _maven_catalog | grep "^3\.9\." | tail -1
      ;;
    3.8)
      _maven_catalog | grep "^3\.8\." | tail -1
      ;;
    *)
      local v="${req%.x}"
      case "$v" in
        *[!0-9.]*) echo "" ;;
        *.*.*)     echo "$v" ;;
        *)         _maven_catalog | grep "^${v}\." | tail -1 ;;
      esac
      ;;
  esac
}

_maven_resolve_version() {
  local full; full=$(_maven_resolve_full "$1")
  [ -z "$full" ] && { echo ""; return; }
  echo "$full" | cut -d'.' -f1-2
}

# -----------------------------------------------------------------------------
# maven_search [version_filter]
# -----------------------------------------------------------------------------
maven_search() {
  local filter="${1:-}"
  bruh_header "Available Maven versions"
  bruh_divider

  local current; current=$(registry_get "maven" "current")

  printf "  ${BRUH_BOLD}%-10s  %-12s  %s${BRUH_RESET}\n" "Version" "Release" "Status"
  printf "  %-10s  %-12s  %s\n" "─────────" "───────────" "──────────────"

  # One row per minor line: highest release in that line
  _maven_catalog | sort -V -r | while read -r full; do
    local minor; minor=$(echo "$full" | cut -d'.' -f1-2)
    [ "$minor" = "${_mvn_last_minor:-}" ] && continue
    _mvn_last_minor="$minor"
    [ -n "$filter" ] && [ "$filter" != "$minor" ] && continue
    local status=""
    registry_is_installed "maven" "$minor" && {
      [ "$minor" = "$current" ] \
        && status="${BRUH_GREEN}▸ installed (active)${BRUH_RESET}" \
        || status="${BRUH_BLUE}✓ installed${BRUH_RESET}"
    }
    printf "  %-10s  %-12s  %b\n" "$minor" "$full" "${status:-}"
  done || true

  printf "\n"
  printf "  ${BRUH_BOLD}Install with:${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh maven 3.9${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh maven latest${BRUH_RESET}\n"
  printf "\n"
}

# -----------------------------------------------------------------------------
# Install
# -----------------------------------------------------------------------------
maven_install() {
  local full; full=$(_maven_resolve_full "$1")
  if [ -z "$full" ]; then
    bruh_err "Maven version '$1' not found. Try: bruh search maven"; return 1
  fi
  local version; version=$(echo "$full" | cut -d'.' -f1-2)

  local dir="$MAVEN_RUNTIME_HOME/v$version"

  if registry_is_installed "maven" "$version" && registry_verify "maven" "$version" "bin/mvn"; then
    bruh_warn "Maven $version already installed ($full)."
    maven_activate "$version"; return
  fi

  # dlcdn only hosts current releases; archive.apache.org has everything
  local url="https://dlcdn.apache.org/maven/maven-3/${full}/binaries/apache-maven-${full}-bin.tar.gz"
  local fallback="https://archive.apache.org/dist/maven/maven-3/${full}/binaries/apache-maven-${full}-bin.tar.gz"
  local tmp_tar="$MAVEN_RUNTIME_HOME/.maven-$full.tar.gz"
  mkdir -p "$MAVEN_RUNTIME_HOME"

  bruh_info "Downloading Maven $full..."
  if ! bruh_download "$url" "$tmp_tar"; then
    bruh_info "Not on dlcdn — trying archive.apache.org..."
    if ! bruh_download "$fallback" "$tmp_tar"; then
      rm -f "$tmp_tar"
      bruh_err "Failed to download Maven $full"; return 1
    fi
  fi

  bruh_info "Extracting to $dir..."
  rm -rf "$dir"
  # Maven bin tarballs contain a single apache-maven-<ver>/ top directory
  if ! bruh_extract "$tmp_tar" "$dir" 1; then
    rm -rf "$dir" "$tmp_tar"
    bruh_err "Failed to extract Maven archive."; return 1
  fi
  rm -f "$tmp_tar"

  # mvn is a script that needs Java at runtime — verify presence/exec bit only
  [ -x "$dir/bin/mvn" ] || { rm -rf "$dir"; bruh_err "Maven binary failed verification."; return 1; }

  registry_record_install "maven" "$version"
  bruh_ok "Maven $full installed."
  maven_activate "$version"
}

maven_activate() {
  local version; version=$(_maven_resolve_version "$1")
  if [ -z "$version" ]; then
    bruh_err "Unknown Maven version: $1"; return 1
  fi
  local dir="$MAVEN_RUNTIME_HOME/v$version"
  if [ ! -d "$dir" ] || ! registry_verify "maven" "$version" "bin/mvn"; then
    bruh_err "Maven $version not installed. Run: bruh maven $version"; return 1
  fi
  ln -sfn "$dir" "$MAVEN_RUNTIME_HOME/current"
  registry_set "maven" "current" "$version"
  # Write activation exports to .activate_env so the bruh() shell function
  # wrapper in bruh.env can source them into the current terminal session.
  {
    printf 'export MAVEN_HOME="%s"\n' "$dir"
    printf 'export PATH="$MAVEN_HOME/bin:$PATH"\n'
    printf 'hash -r 2>/dev/null || true\n'
  } > "$BRUH_HOME/.activate_env"
  bruh_ok "Using Maven $version"
  "$dir/bin/mvn" --version 2>/dev/null | head -1 || true
}

maven_set_default() {
  local version; version=$(_maven_resolve_version "$1")
  if [ -z "$version" ] || ! registry_is_installed "maven" "$version"; then
    bruh_err "Maven $1 not installed. Run: bruh maven $version"
    return 1
  fi
  echo "$version" > "$MAVEN_RUNTIME_HOME/.default"
  registry_set "maven" "default" "$version"
  bruh_ok "Default Maven set to $version"
  bruh_info "Run 'source ~/.zshrc' to apply in the current terminal."
  maven_activate "$version"
}

# Remove — just delete the version directory
maven_remove() {
  local version; version=$(_maven_resolve_version "$1")
  local default; default=$(registry_get "maven" "default")
  if [ "$default" = "$version" ]; then
    bruh_err "Maven $version is the default. Change default first."; return 1
  fi
  if ! registry_is_installed "maven" "$version"; then
    bruh_err "Maven $version not installed under Bruh."; return 1
  fi
  rm -rf "$MAVEN_RUNTIME_HOME/v$version"
  registry_remove_installed "maven" "$version"
  bruh_ok "Maven $version removed."
}

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
    if ! registry_verify "maven" "$v" "bin/mvn"; then
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
  printf "  ${BRUH_DIM}Path    : $(command -v mvn 2>/dev/null || echo 'not found')${BRUH_RESET}\n"
  printf "\n"
  printf "  Run ${BRUH_BOLD}bruh search maven${BRUH_RESET} to see all available versions.\n"
  printf "\n"
}

maven_locate() {
  bruh_header "Maven location"
  local dir="$MAVEN_RUNTIME_HOME/current"
  bruh_log "MAVEN_HOME : $([ -d "$dir" ] && echo "$dir" || echo 'not installed')"
  bruh_log "Binary     : $(command -v mvn 2>/dev/null || echo 'not found')"
  mvn --version 2>/dev/null | head -1 | sed 's/^/  /' || true
}

maven_status() {
  bruh_header "Maven"
  local current; current=$(registry_get maven current)
  local dir="$MAVEN_RUNTIME_HOME/v${current:-}"
  bruh_log "Current    : ${current:-not set} ($(mvn --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo n/a))"
  bruh_log "Default    : $(registry_get maven default || echo 'not set')"
  bruh_log "MAVEN_HOME : ${MAVEN_HOME:-not set}"
  bruh_log "Path       : $(command -v mvn 2>/dev/null || echo 'not found')"
  bruh_log "Home       : $([ -d "$dir" ] && echo "$dir" || echo 'not installed')"
}

# Update — refresh each installed minor to the latest release in that line
maven_update() {
  local version="${1:-}"
  local minors
  if [ -z "$version" ] || [ "$version" = "all" ]; then
    minors=$(registry_list_installed "maven")
    [ -z "$minors" ] && { bruh_warn "No Maven versions installed."; return 0; }
  else
    minors=$(_maven_resolve_version "$version")
  fi
  echo "$minors" | while read -r m; do
    [ -z "$m" ] && continue
    local latest_full; latest_full=$(_maven_resolve_full "$m")
    local current_full
    current_full=$("$MAVEN_RUNTIME_HOME/v$m/bin/mvn" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [ "$current_full" = "$latest_full" ]; then
      bruh_ok "Maven $m already at latest ($latest_full)."
    else
      bruh_info "Updating Maven $m: ${current_full:-missing} → $latest_full..."
      maven_install "$m"
    fi
  done
  bruh_ok "Done."
}

maven_install_or_activate() {
  local version; version=$(_maven_resolve_version "$1")
  if [ -n "$version" ] && registry_is_installed "maven" "$version" \
     && registry_verify "maven" "$version" "bin/mvn"; then
    maven_activate "$version"
  else
    maven_install "$1"
  fi
}
