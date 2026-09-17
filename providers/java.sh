# =============================================================================
# BRUH — providers/java.sh
# Standalone JDK provider — official binary downloads (no Homebrew, no sudo)
# Supported providers: temurin (default "openjdk"), corretto, oracle
#   zulu/graalvm are not yet available via direct download
# Layout: $BRUH_HOME/runtimes/java/v<major>       (extracted JDK home)
#         $BRUH_HOME/runtimes/java/current        (symlink → active v<major>)
# =============================================================================

JAVA_RUNTIME_HOME="$BRUH_HOME/runtimes/java"
JAVA_PROVIDERS="openjdk temurin corretto oracle"

# -----------------------------------------------------------------------------
# Platform mapping
# -----------------------------------------------------------------------------
# $1 = provider; echoes "<os> <arch>" in the provider's own vocabulary
_java_target() {
  case "$(bruh_platform)" in
    darwin-arm64) case "$1" in corretto|oracle) echo "macos aarch64" ;; *) echo "mac aarch64" ;; esac ;;
    darwin-x64)   case "$1" in corretto|oracle) echo "macos x64"    ;; *) echo "mac x64"    ;; esac ;;
    linux-x64)    echo "linux x64" ;;
    linux-arm64)  echo "linux aarch64" ;;
    *)            echo "unsupported" ;;
  esac
}

# -----------------------------------------------------------------------------
# Catalog helpers
# -----------------------------------------------------------------------------
# Latest GA release line for a major version, via the Adoptium API.
# Prints full version like "21.0.5+11" on success, empty on failure.
_java_adoptium_version() {
  local major="$1" os arch
  os=$(_java_target openjdk | cut -d' ' -f1)
  arch=$(_java_target openjdk | cut -d' ' -f2)
  [ "$os" = "unsupported" ] && return 1
  curl -fsSL "https://api.adoptium.net/v3/assets/latest/${major}/hotspot?os=${os}&architecture=${arch}&image_type=jdk" 2>/dev/null \
    | jq -r '[.[]][0].release_name' 2>/dev/null | sed 's/+.*//'
}

_java_resolve_version() {
  case "$1" in
    latest)
      curl -fsSL "https://api.adoptium.net/v3/info/available_releases" 2>/dev/null \
        | jq -r '.most_recent_feature_release' 2>/dev/null ;;
    stable|lts)
      curl -fsSL "https://api.adoptium.net/v3/info/available_releases" 2>/dev/null \
        | jq -r '.most_recent_lts' 2>/dev/null ;;
    *) echo "${1%%:*}" ;;
  esac
}

# -----------------------------------------------------------------------------
# Download URL resolution — echoes url, or returns 1
# -----------------------------------------------------------------------------
_java_download_url() {
  local major="$1" provider="$2"
  local full os arch
  read -r os arch < <(_java_target "$provider")
  [ "$os" = "unsupported" ] && return 1

  case "$provider" in
    temurin)
      full=$(_java_adoptium_version "$major")
      [ -z "$full" ] && return 1
      echo "https://api.adoptium.net/v3/binary/latest/${major}/ga/${os}/${arch}/jdk/hotspot/normal/eclipse"
      ;;
    corretto)
      echo "https://corretto.aws/downloads/latest/amazon-corretto-${major}-${arch}-${os}-jdk.tar.gz"
      ;;
    oracle)
      echo "https://download.oracle.com/java/${major}/latest/jdk-${major}_${os}-${arch}_bin.tar.gz"
      ;;
    *)
      return 1
      ;;
  esac
}

# -----------------------------------------------------------------------------
# Extract a JDK tarball into $dir, normalising the macOS Contents/Home layout
# -----------------------------------------------------------------------------
_java_extract() {
  local archive="$1" dir="$2"
  local tmp; tmp=$(mktemp -d)
  if ! bruh_extract "$archive" "$tmp"; then
    rm -rf "$tmp"; return 1
  fi
  mkdir -p "$dir"
  # macOS JDK tarballs nest the home under Contents/Home — unwrap it
  local home
  home=$(find "$tmp" -type d -name Home -maxdepth 5 | head -1)
  if [ -n "$home" ]; then
    ( shopt -s dotglob; mv "$home"/* "$dir"/ )
  else
    # Linux layout: single top-level directory — move its contents up
    local top; top=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -1)
    if [ -n "$top" ]; then
      ( shopt -s dotglob; mv "$top"/* "$dir"/ )
    else
      ( shopt -s dotglob; mv "$tmp"/* "$dir"/ )
    fi
  fi
  rm -rf "$tmp"
}

# -----------------------------------------------------------------------------
# java_search [version_filter]
# -----------------------------------------------------------------------------
java_search() {
  local filter="${1:-}"

  bruh_header "Available JDK Distributions"
  bruh_divider

  printf "  ${BRUH_BOLD}%-8s  %-12s  %-24s  %s${BRUH_RESET}\n" "Version" "Provider" "Source" "Available"
  printf "  %-8s  %-12s  %-24s  %s\n" "───────" "───────────" "──────────────────────" "─────────"

  local versions="8 11 17 21 22 23 24 25 26"
  local found=0

  for version in $versions; do
    [ -n "$filter" ] && [ "$filter" != "$version" ] && continue
    for provider in temurin corretto oracle; do
      local source=""
      case "$provider" in
        temurin)  source="Adoptium (Temurin)" ;;
        corretto) source="Amazon Corretto" ;;
        oracle)   source="Oracle JDK" ;;
      esac
      local marker=""
      local installed_provider
      installed_provider=$(registry_get_java_provider "$version" 2>/dev/null || echo "")
      local current; current=$(registry_get "java" "current")
      if registry_is_installed "java" "$version" && [ "$installed_provider" = "$provider" ]; then
        [ "$current" = "$version" ] \
          && marker="${BRUH_GREEN} ▸ installed (active)${BRUH_RESET}" \
          || marker="${BRUH_BLUE} ✓ installed${BRUH_RESET}"
      fi
      printf "  %-8s  %-12s  %-24s  %b\n" "$version" "$provider" "$source" "$marker"
      found=1
    done
  done

  if [ "$found" -eq 0 ]; then
    bruh_log "No JDK distributions found for version $filter."
  fi

  printf "\n"
  printf "  ${BRUH_BOLD}Install with:${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh java 21 temurin${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh java 21 corretto${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh java 21            (defaults to temurin)${BRUH_RESET}\n"
  printf "\n"
}

# -----------------------------------------------------------------------------
# java_install <version_or_version:provider>
# -----------------------------------------------------------------------------
java_install() {
  local input="$1"
  local provider="${input#*:}"
  [ "$provider" = "$input" ] && provider="temurin"
  case "$provider" in
    temurin|corretto|oracle) ;;
    openjdk) provider="temurin" ;;
    *)
      bruh_err "Provider '$provider' is not available via direct download yet."
      bruh_log "Supported: temurin, corretto, oracle"; return 1 ;;
  esac
  local req="${input%%:*}"

  [ "$(bruh_platform)" = "unsupported" ] && \
    bruh_die "Unsupported platform: $(uname -s)/$(uname -m)"

  local version; version=$(_java_resolve_version "$req")
  if [ -z "$version" ] || [ "$version" = "null" ]; then
    bruh_err "Java version '$req' not found."; return 1
  fi

  # Already installed and healthy?
  if registry_is_installed "java" "$version" \
     && [ "$(registry_get_java_provider "$version")" = "$provider" ] \
     && registry_verify "java" "$version" "bin/java"; then
    bruh_warn "Java $version ($provider) already installed."
    java_activate "$version"; return
  fi

  local url; url=$(_java_download_url "$version" "$provider")
  if [ -z "$url" ]; then
    bruh_err "Could not resolve a $provider download URL for Java $version."; return 1
  fi

  local dir="$JAVA_RUNTIME_HOME/v$version"
  local tmp_tar="$JAVA_RUNTIME_HOME/.jdk-$version.tar.gz"
  mkdir -p "$JAVA_RUNTIME_HOME"

  bruh_info "Downloading Java $version ($provider)..."
  if ! bruh_download "$url" "$tmp_tar"; then
    rm -f "$tmp_tar"
    bruh_err "Failed to download $url"; return 1
  fi

  bruh_info "Extracting to $dir..."
  rm -rf "$dir"
  if ! _java_extract "$tmp_tar" "$dir"; then
    rm -rf "$dir" "$tmp_tar"
    bruh_err "Failed to extract JDK archive."; return 1
  fi
  rm -f "$tmp_tar"

  "$dir/bin/java" -version >/dev/null 2>&1 || { rm -rf "$dir"; bruh_err "JDK binary failed verification."; return 1; }

  registry_record_install "java" "$version"
  registry_set_java_provider "$version" "$provider"
  bruh_ok "Java $version ($provider) installed."
  java_activate "$version"
}

# -----------------------------------------------------------------------------
# java_activate <version>
# -----------------------------------------------------------------------------
java_activate() {
  local input="$1"
  local provider=""
  if echo "$input" | grep -q ':'; then
    input="${input%%:*}"
    provider="${2:-}"
  fi
  local version="$input"

  local dir="$JAVA_RUNTIME_HOME/v$version"
  if [ ! -d "$dir" ] || ! registry_verify "java" "$version" "bin/java"; then
    bruh_err "Java $version not installed. Run: bruh java $version"; return 1
  fi

  [ -z "$provider" ] && provider=$(registry_get_java_provider "$version")

  ln -sfn "$dir" "$JAVA_RUNTIME_HOME/current"

  # Write activation exports to .activate_env so the bruh() shell function
  # wrapper in bruh.env can source them into the current terminal session.
  {
    printf 'export JAVA_HOME="%s"\n' "$dir"
    printf 'export PATH=$(echo "$PATH" | tr '"'"':'"'"' '"'"'\n'"'"' | grep -v '"'"'/Contents/Home/bin'"'"' | paste -sd '"'"':'"'"' -)\n'
    printf 'export PATH="$JAVA_HOME/bin:$PATH"\n'
    printf 'hash -r 2>/dev/null || true\n'
  } > "$BRUH_HOME/.activate_env"

  registry_set "java" "current" "$version"
  bruh_ok "Using Java $version ($provider)"
  "$dir/bin/java" -version 2>&1 | head -1 || true
}

# -----------------------------------------------------------------------------
# java_set_default <version>
# -----------------------------------------------------------------------------
java_set_default() {
  local version="${1%%:*}"
  if ! registry_is_installed "java" "$version"; then
    bruh_err "Java $version not installed. Run: bruh java $version"
    return 1
  fi
  echo "$version" > "$JAVA_RUNTIME_HOME/.default"
  registry_set "java" "default" "$version"
  local provider; provider=$(registry_get_java_provider "$version")
  bruh_ok "Default Java set to $version ($provider)"
  bruh_info "Run 'source ~/.zshrc' to apply in the current terminal."
  java_activate "$version"
}

# -----------------------------------------------------------------------------
# java_remove <version> — pure rm -rf, no sudo
# -----------------------------------------------------------------------------
java_remove() {
  local version="${1%%:*}"
  local default; default=$(registry_get "java" "default")
  if [ "$default" = "$version" ]; then
    bruh_err "Java $version is the default. Change default first."; return 1
  fi
  if ! registry_is_installed "java" "$version"; then
    bruh_err "Java $version not installed under Bruh."; return 1
  fi
  rm -rf "$JAVA_RUNTIME_HOME/v$version"
  registry_remove_installed "java" "$version"
  registry_remove_java_provider "$version"
  bruh_ok "Java $version removed."
}

# -----------------------------------------------------------------------------
# java_lookup
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
    if ! registry_verify "java" "$v" "bin/java"; then
      status="${BRUH_RED}(missing — reinstall)${BRUH_RESET}"
    elif [ "$v" = "$current" ] && [ "$v" = "$default" ]; then
      status="${BRUH_GREEN}▸ active  ${BRUH_RESET}${BRUH_BLUE}(default)${BRUH_RESET}"
    elif [ "$v" = "$current" ]; then
      status="${BRUH_GREEN}▸ active${BRUH_RESET}"
    elif [ "$v" = "$default" ]; then
      status="${BRUH_BLUE}(default)${BRUH_RESET}"
    fi
    printf "  ${BRUH_BOLD}%-8s${BRUH_RESET}  %-12s  %b\n" "$v" "${provider:-temurin}" "$status"
  done

  printf "\n"
  printf "  ${BRUH_DIM}Current : ${current:-not set}${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}Default : ${default:-not set}${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}JAVA_HOME: ${JAVA_HOME:-not set}${BRUH_RESET}\n"
  printf "\n"
  printf "  Run ${BRUH_BOLD}bruh search java${BRUH_RESET} to see all available distributions.\n"
  printf "\n"
}

java_locate() {
  bruh_header "Java location"
  local dir="$JAVA_RUNTIME_HOME/current"
  bruh_log "JAVA_HOME: $([ -d "$dir" ] && echo "$dir" || echo 'not installed')"
  bruh_log "Binary   : $(command -v java 2>/dev/null || echo 'not found')"
  java -version 2>&1 | head -1 | sed 's/^/  /'
}

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
# java_update [version|all] — refresh each installed major to latest GA
# -----------------------------------------------------------------------------
java_update() {
  local version="${1:-}"
  local majors
  if [ -z "$version" ] || [ "$version" = "all" ]; then
    majors=$(registry_list_installed "java")
    [ -z "$majors" ] && { bruh_warn "No Java versions installed."; return 0; }
  else
    majors="${version%%:*}"
  fi

  for m in $majors; do
    local provider; provider=$(registry_get_java_provider "$m")
    local url; url=$(_java_download_url "$m" "$provider")
    if [ -z "$url" ]; then
      bruh_warn "Could not resolve update for Java $m ($provider)."; continue
    fi
    # Adoptium URL is version-agnostic (always latest GA); corretto/oracle too.
    bruh_info "Updating Java $m ($provider) to latest GA..."
    java_install "$m:$provider" || bruh_warn "Java $m update failed."
  done
  bruh_ok "Done."
}

java_install_or_activate() {
  local input="$1"
  local version; version=$(_java_resolve_version "${input%%:*}")
  if [ -n "$version" ] && registry_is_installed "java" "$version" \
     && registry_verify "java" "$version" "bin/java"; then
    java_activate "$version"
  else
    java_install "$input"
  fi
}
