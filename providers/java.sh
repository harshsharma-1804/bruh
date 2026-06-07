# =============================================================================
# BRUH — providers/java.sh
# Java JDK provider — Homebrew backend, multi-distribution support
# Supported providers: openjdk, temurin, corretto, zulu, graalvm, oracle
# =============================================================================

JAVA_RUNTIME_HOME="$BRUH_HOME/runtimes/java"
HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-$(bruh_homebrew_prefix)}"

# Known providers and their Homebrew formula patterns
# Format: "provider:formula_prefix"
JAVA_PROVIDERS="openjdk temurin corretto zulu graalvm oracle"

# -----------------------------------------------------------------------------
# Internal helpers
# -----------------------------------------------------------------------------

_java_formula() {
  local version="$1"
  local provider="${2:-openjdk}"
  case "$provider" in
    openjdk)  echo "openjdk@${version}" ;;
    temurin)  echo "temurin@${version}" ;;
    corretto) echo "corretto@${version}" ;;
    zulu)     echo "zulu@${version}" ;;
    graalvm)  echo "graalvm-jdk@${version}" ;;
    oracle)   echo "oracle-jdk@${version}" ;;
    *) bruh_die "Unknown JDK provider: '$provider'. Run: bruh search java" ;;
  esac
}

_java_brew_path() {
  local version="$1" provider="${2:-openjdk}"
  local formula; formula=$(_java_formula "$version" "$provider")
  case "$provider" in
    openjdk)  echo "$HOMEBREW_PREFIX/opt/${formula}/libexec/openjdk.jdk" ;;
    temurin)  echo "$HOMEBREW_PREFIX/Caskroom/${formula}/Contents/Home" ;;
    corretto) echo "$HOMEBREW_PREFIX/Caskroom/${formula}/Contents/Home" ;;
    zulu)     echo "$HOMEBREW_PREFIX/Caskroom/${formula}/Contents/Home" ;;
    graalvm)  echo "$HOMEBREW_PREFIX/opt/${formula}/libexec/graalvm.jdk" ;;
    oracle)   echo "$HOMEBREW_PREFIX/Caskroom/${formula}/Contents/Home" ;;
    *)        echo "$HOMEBREW_PREFIX/opt/${formula}" ;;
  esac
}

_java_jvm_link()  { echo "/Library/Java/JavaVirtualMachines/bruh-${1}-${2:-openjdk}.jdk"; }
_java_home_path() { /usr/libexec/java_home -v "$1" 2>/dev/null; }

_java_resolve_version() {
  case "$1" in
    latest)
      brew search '/openjdk@/' 2>/dev/null | grep -oE '[0-9]+' | sort -n | tail -1 ;;
    stable|lts)
      for v in 21 17 11 8; do
        /usr/libexec/java_home -v "$v" >/dev/null 2>&1 && echo "$v" && return
      done
      echo "21" ;;
    *) echo "$1" ;;
  esac
}

# Parse "21:temurin" → sets _JAVA_VERSION and _JAVA_PROVIDER
_java_parse_version_provider() {
  local input="$1"
  if echo "$input" | grep -q ':'; then
    _JAVA_VERSION=$(echo "$input" | cut -d':' -f1)
    _JAVA_PROVIDER=$(echo "$input" | cut -d':' -f2)
  else
    _JAVA_VERSION="$(_java_resolve_version "$input")"
    _JAVA_PROVIDER="openjdk"
  fi
}

_java_link() {
  local version="$1" provider="${2:-openjdk}"
  local brew_path; brew_path=$(_java_brew_path "$version" "$provider")
  local jvm_link; jvm_link=$(_java_jvm_link "$version" "$provider")

  if [ ! -d "$brew_path" ]; then
    bruh_die "$provider JDK $version not found at $brew_path"
  fi

  bruh_info "Linking $provider JDK $version (requires sudo)..."
  sudo ln -sfn "$brew_path" "$jvm_link" || bruh_die "Failed to link $provider JDK $version"
  bruh_ok "Linked $provider JDK $version"
}

# -----------------------------------------------------------------------------
# java_search [version_filter]
# Show all available JDK distributions from Homebrew, grouped by version
# -----------------------------------------------------------------------------
java_search() {
  local filter="${1:-}"

  bruh_header "Available JDK Distributions"
  bruh_divider

  printf "  ${BRUH_BOLD}%-8s  %-12s  %-28s  %s${BRUH_RESET}\n" "Version" "Provider" "Formula" "Available"
  printf "  %-8s  %-12s  %-28s  %s\n" "───────" "───────────" "───────────────────────────" "─────────"

  # Check each known provider/version combo
  local versions="8 11 17 21 22 23"
  local found=0

  for version in $versions; do
    # Skip if version filter is set and doesn't match
    [ -n "$filter" ] && [ "$filter" != "$version" ] && continue

    for provider in $JAVA_PROVIDERS; do
      local formula; formula=$(_java_formula "$version" "$provider")
      local available=false

      # Check formulae (openjdk, graalvm)
      case "$provider" in
        openjdk|graalvm)
          brew info "$formula" >/dev/null 2>&1 && available=true ;;
        *)
          # Cask-based providers
          brew info --cask "$formula" >/dev/null 2>&1 && available=true ;;
      esac

      if $available; then
        # Mark if already installed under Bruh
        local marker=""
        local installed_provider
        installed_provider=$(registry_get_java_provider "$version" 2>/dev/null || echo "")
        local current; current=$(registry_get "java" "current")
        if registry_is_installed "java" "$version" && [ "$installed_provider" = "$provider" ]; then
          [ "$current" = "$version" ] \
            && marker="${BRUH_GREEN} ▸ installed (active)${BRUH_RESET}" \
            || marker="${BRUH_BLUE} ✓ installed${BRUH_RESET}"
        fi

        printf "  %-8s  %-12s  %-28s %b\n" "$version" "$provider" "$formula" "$marker"
        found=1
      fi
    done
  done

  if [ "$found" -eq 0 ]; then
    if [ -n "$filter" ]; then
      bruh_log "No JDK distributions found for version $filter."
    else
      bruh_log "No JDK distributions found. Check your Homebrew setup."
    fi
  fi

  printf "\n"
  printf "  ${BRUH_BOLD}Install with:${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh java 21 temurin${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh java 21 corretto${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh java 21            (defaults to openjdk)${BRUH_RESET}\n"
  printf "\n"
}

# -----------------------------------------------------------------------------
# java_install <version_or_version:provider>
# -----------------------------------------------------------------------------
java_install() {
  local input="$1"
  _java_parse_version_provider "$input"
  local version="$_JAVA_VERSION"
  local provider="$_JAVA_PROVIDER"

  bruh_require_brew
  [ "$(bruh_os)" != "macos" ] && bruh_die "Java management is macOS only."

  # Already installed under Bruh with same provider
  if registry_is_installed "java" "$version"; then
    local existing_provider; existing_provider=$(registry_get_java_provider "$version")
    if [ "$existing_provider" = "$provider" ]; then
      bruh_warn "Java $version ($provider) already installed."
      java_activate "$input"; return
    fi
    # Different provider — allow installing alongside
    bruh_info "Java $version already installed with $existing_provider. Installing $provider alongside..."
  fi

  local formula; formula=$(_java_formula "$version" "$provider")

  # Check if already in Homebrew (pre-existing)
  local already=false
  case "$provider" in
    openjdk|graalvm) brew info "$formula" >/dev/null 2>&1 && [ -d "$HOMEBREW_PREFIX/opt/$formula" ] && already=true ;;
    *)               brew info --cask "$formula" >/dev/null 2>&1 && already=true ;;
  esac

  if $already; then
    bruh_info "Java $version ($provider) found pre-existing. Registering..."
  else
    bruh_info "Installing Java $version ($provider) via Homebrew..."
    case "$provider" in
      openjdk|graalvm) brew install "$formula" || bruh_die "Failed to install $formula" ;;
      *)               brew install --cask "$formula" || bruh_die "Failed to install $formula" ;;
    esac
  fi

  _java_link "$version" "$provider"

  if $already; then
    registry_record_activate "java" "$version"
  else
    registry_record_install "java" "$version"
  fi
  registry_set_java_provider "$version" "$provider"

  bruh_ok "Java $version ($provider) installed."
  java_activate "$input"
}

# -----------------------------------------------------------------------------
# java_activate <version_or_version:provider>
# -----------------------------------------------------------------------------
java_activate() {
  local input="$1"
  _java_parse_version_provider "$input"
  local version="$_JAVA_VERSION"

  local jhp; jhp=$(_java_home_path "$version")
  if [ -z "$jhp" ]; then
    bruh_err "Java $version not found by /usr/libexec/java_home"
    bruh_log "Available JVMs:"
    /usr/libexec/java_home -V 2>&1 | grep -v "^Matching" | sed 's/^/  /'
    return 1
  fi

  # Write activation exports to .activate_env so the bruh() shell function
  # wrapper in bruh.env can source them into the current terminal session.
  {
    printf 'export JAVA_HOME="%s"\n' "$jhp"
    printf 'export PATH=$(echo "$PATH" | tr '"'"':'"'"' '"'"'\n'"'"' | grep -v '"'"'/Contents/Home/bin'"'"' | paste -sd '"'"':'"'"' -)\n'
    printf 'export PATH="$JAVA_HOME/bin:$PATH"\n'
    printf 'hash -r 2>/dev/null || true\n'
  } > "$BRUH_HOME/.activate_env"

  registry_set "java" "current" "$version"
  local provider; provider=$(registry_get_java_provider "$version")
  bruh_ok "Using Java $version ($provider)"
  java -version 2>&1 | head -1
}

# -----------------------------------------------------------------------------
# java_set_default <version>
# -----------------------------------------------------------------------------
java_set_default() {
  _java_parse_version_provider "$1"
  local version="$_JAVA_VERSION"

  if ! registry_is_installed "java" "$version"; then
    bruh_err "Java $version not installed. Run: bruh java $version"
    return 1
  fi
  echo "$version" > "$JAVA_RUNTIME_HOME/.default"
  registry_set "java" "default" "$version"
  local provider; provider=$(registry_get_java_provider "$version")
  bruh_ok "Default Java set to $version ($provider)"
  java_activate "$version"
}

# -----------------------------------------------------------------------------
# java_remove <version>
# -----------------------------------------------------------------------------
java_remove() {
  _java_parse_version_provider "$1"
  local version="$_JAVA_VERSION"
  local provider="$_JAVA_PROVIDER"

  local default; default=$(registry_get "java" "default")
  if [ "$default" = "$version" ]; then
    bruh_err "Java $version is the default. Change default first."; return 1
  fi

  if ! registry_is_installed "java" "$version"; then
    bruh_err "Java $version not installed under Bruh."; return 1
  fi

  if registry_is_bruh_installed "java" "$version"; then
    local formula; formula=$(_java_formula "$version" "$provider")
    bruh_info "Uninstalling Java $version ($provider)..."
    case "$provider" in
      openjdk|graalvm) brew uninstall "$formula" 2>/dev/null || bruh_warn "Homebrew uninstall failed." ;;
      *)               brew uninstall --cask "$formula" 2>/dev/null || bruh_warn "Homebrew cask uninstall failed." ;;
    esac
  fi

  local jvm_link; jvm_link=$(_java_jvm_link "$version" "$provider")
  ( [ -e "$jvm_link" ] || [ -L "$jvm_link" ] ) && sudo rm -f "$jvm_link"

  registry_remove_installed "java" "$version"
  registry_remove_java_provider "$version"
  bruh_ok "Java $version ($provider) removed."
}

# -----------------------------------------------------------------------------
# java_lookup — installed versions with active/default markers
# -----------------------------------------------------------------------------
java_lookup() {
  bruh_header "Installed Java versions"
  bruh_divider

  local installed; installed=$(registry_list_installed "java")
  local current; current=$(registry_get "java" "current")
  local default; default=$(registry_get "java" "default")

  if [ -z "$installed" ]; then
    bruh_log "No Java versions installed under Bruh."
    bruh_log ""
    bruh_log "Run ${BRUH_BOLD}bruh search java${BRUH_RESET} to see available distributions."
    return
  fi

  printf "  ${BRUH_BOLD}%-8s  %-12s  %s${BRUH_RESET}\n" "Version" "Provider" "Status"
  printf "  %-8s  %-12s  %s\n" "───────" "───────────" "──────────────"

  echo "$installed" | while read -r v; do
    [ -z "$v" ] && continue
    local provider; provider=$(registry_get_java_provider "$v")
    local status=""
    local prefix="  "

    if [ "$v" = "$current" ] && [ "$v" = "$default" ]; then
      status="${BRUH_GREEN}▸ active  ${BRUH_RESET}${BRUH_BLUE}(default)${BRUH_RESET}"
      prefix="${BRUH_GREEN}  "
    elif [ "$v" = "$current" ]; then
      status="${BRUH_GREEN}▸ active${BRUH_RESET}"
      prefix="${BRUH_GREEN}  "
    elif [ "$v" = "$default" ]; then
      status="${BRUH_BLUE}(default)${BRUH_RESET}"
    fi

    printf "  ${BRUH_BOLD}%-8s${BRUH_RESET}  %-12s  %b\n" "$v" "${provider:-openjdk}" "$status"
  done

  printf "\n"
  printf "  ${BRUH_DIM}Current : ${current:-not set}${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}Default : ${default:-not set}${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}JAVA_HOME: ${JAVA_HOME:-not set}${BRUH_RESET}\n"
  printf "\n"
  printf "  Run ${BRUH_BOLD}bruh search java${BRUH_RESET} to see all available distributions.\n"
  printf "\n"
}

# -----------------------------------------------------------------------------
# java_locate
# -----------------------------------------------------------------------------
java_locate() {
  bruh_header "Java location"
  bruh_log "JAVA_HOME: ${JAVA_HOME:-not set}"
  bruh_log "Binary   : $(command -v java 2>/dev/null || echo 'not found')"
  java -version 2>&1 | head -1 | sed 's/^/  /'
}

# -----------------------------------------------------------------------------
# java_status
# -----------------------------------------------------------------------------
java_status() {
  local current; current=$(registry_get "java" "current")
  local default; default=$(registry_get "java" "default")
  local provider=""
  [ -n "$current" ] && [ "$current" != "null" ] && provider=$(registry_get_java_provider "$current")

  bruh_header "Java"
  bruh_log "Current  : ${current:-not set}${provider:+ ($provider)}"
  bruh_log "Default  : ${default:-not set}"
  bruh_log "JAVA_HOME: ${JAVA_HOME:-not set}"
  bruh_log "Path     : $(command -v java 2>/dev/null || echo 'not found')"
  java -version 2>&1 | head -1 | sed 's/^/  /' || true
}

# -----------------------------------------------------------------------------
# java_update
# -----------------------------------------------------------------------------
java_update() {
  local version="${1:-}"
  if [ -z "$version" ] || [ "$version" = "all" ]; then
    registry_list_installed "java" | while read -r v; do
      local p; p=$(registry_get_java_provider "$v")
      local formula; formula=$(_java_formula "$v" "$p")
      bruh_info "Updating Java $v ($p)..."
      case "$p" in
        openjdk|graalvm) brew upgrade "$formula" 2>/dev/null || bruh_warn "Java $v already up to date." ;;
        *)               brew upgrade --cask "$formula" 2>/dev/null || bruh_warn "Java $v already up to date." ;;
      esac
    done
  else
    _java_parse_version_provider "$version"
    local p; p=$(registry_get_java_provider "$_JAVA_VERSION")
    local formula; formula=$(_java_formula "$_JAVA_VERSION" "$p")
    case "$p" in
      openjdk|graalvm) brew upgrade "$formula" 2>/dev/null || bruh_warn "Already up to date." ;;
      *)               brew upgrade --cask "$formula" 2>/dev/null || bruh_warn "Already up to date." ;;
    esac
  fi
  bruh_ok "Done."
}

# -----------------------------------------------------------------------------
# java_install_or_activate
# -----------------------------------------------------------------------------
java_install_or_activate() {
  local input="$1"
  _java_parse_version_provider "$input"
  local version="$_JAVA_VERSION"

  if registry_is_installed "java" "$version"; then
    java_activate "$input"
  else
    java_install "$input"
  fi
}
