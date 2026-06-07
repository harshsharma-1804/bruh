# =============================================================================
# BRUH — providers/rust.sh
# =============================================================================

RUST_RUNTIME_HOME="$BRUH_HOME/runtimes/rust"

_rust_ensure_rustup() {
  if ! command -v rustup >/dev/null 2>&1; then
    bruh_info "rustup not found. Installing..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --no-modify-path || bruh_die "Failed to install rustup"
    export PATH="$HOME/.cargo/bin:$PATH"
    hash -r 2>/dev/null || true
    bruh_ok "rustup installed."
  fi
}

_rust_resolve_toolchain() {
  case "$1" in
    stable|lts|latest|"") echo "stable" ;;
    beta)    echo "beta" ;;
    nightly) echo "nightly" ;;
    *)       echo "$1" ;;
  esac
}

rust_install() {
  local toolchain; toolchain=$(_rust_resolve_toolchain "${1:-stable}")
  _rust_ensure_rustup
  if registry_is_installed "rust" "$toolchain"; then
    bruh_warn "Rust $toolchain already installed."; rust_activate "$toolchain"; return
  fi
  if rustup toolchain list 2>/dev/null | grep -q "^${toolchain}"; then
    bruh_info "Rust $toolchain found (pre-existing). Registering..."
    registry_record_activate "rust" "$toolchain"
    rust_activate "$toolchain"; return
  fi
  bruh_info "Installing Rust $toolchain via rustup..."
  rustup install "$toolchain" || bruh_die "Failed to install Rust $toolchain"
  registry_record_install "rust" "$toolchain"
  bruh_ok "Rust $toolchain installed."
  rust_activate "$toolchain"
}

rust_activate() {
  local toolchain; toolchain=$(_rust_resolve_toolchain "${1:-stable}")
  _rust_ensure_rustup
  rustup default "$toolchain" || bruh_die "Failed to set Rust $toolchain"
  registry_set "rust" "current" "$toolchain"
  echo "$toolchain" > "$RUST_RUNTIME_HOME/.default"
  bruh_ok "Using Rust $toolchain"
  rustc --version 2>/dev/null || true
}

rust_set_default() {
  local toolchain; toolchain=$(_rust_resolve_toolchain "${1:-stable}")
  if ! registry_is_installed "rust" "$toolchain"; then
    bruh_err "Rust $toolchain not installed."; return 1
  fi
  rustup default "$toolchain"
  echo "$toolchain" > "$RUST_RUNTIME_HOME/.default"
  registry_set "rust" "default" "$toolchain"
  bruh_ok "Default Rust set to $toolchain"
  bruh_info "Run 'source ~/.zshrc' to apply in the current terminal."
}

rust_remove() {
  local toolchain; toolchain=$(_rust_resolve_toolchain "${1:-stable}")
  local default; default=$(registry_get "rust" "default")
  [ "$default" = "$toolchain" ] && bruh_err "Rust $toolchain is the default. Change first." && return 1
  if ! registry_is_installed "rust" "$toolchain"; then
    bruh_err "Rust $toolchain not installed under Bruh."; return 1
  fi
  registry_is_bruh_installed "rust" "$toolchain" \
    && rustup toolchain uninstall "$toolchain" || bruh_warn "Skipping rustup uninstall."
  registry_remove_installed "rust" "$toolchain"
  bruh_ok "Rust $toolchain removed."
}

rust_lookup() {
  bruh_header "Installed Rust toolchains"
  bruh_divider

  local current; current=$(registry_get "rust" "current")
  local default; default=$(registry_get "rust" "default")

  if ! command -v rustup >/dev/null 2>&1; then
    bruh_log "rustup not installed."
    bruh_log ""; bruh_log "Run ${BRUH_BOLD}bruh rust stable${BRUH_RESET} to install Rust."
    return
  fi

  local toolchains
  toolchains=$(rustup toolchain list 2>/dev/null)

  if [ -z "$toolchains" ]; then
    bruh_log "No Rust toolchains installed."
    return
  fi

  printf "  ${BRUH_BOLD}%-20s  %s${BRUH_RESET}\n" "Toolchain" "Status"
  printf "  %-20s  %s\n" "───────────────────" "──────────────"

  echo "$toolchains" | while read -r line; do
    [ -z "$line" ] && continue
    local tc; tc=$(echo "$line" | awk '{print $1}')
    local status=""
    if [ "$tc" = "$current" ] && [ "$tc" = "$default" ]; then
      status="${BRUH_GREEN}▸ active  ${BRUH_RESET}${BRUH_BLUE}(default)${BRUH_RESET}"
    elif [ "$tc" = "$current" ]; then
      status="${BRUH_GREEN}▸ active${BRUH_RESET}"
    elif [ "$tc" = "$default" ]; then
      status="${BRUH_BLUE}(default)${BRUH_RESET}"
    fi
    printf "  ${BRUH_BOLD}%-20s${BRUH_RESET}  %b\n" "$tc" "$status"
  done

  printf "\n"
  printf "  ${BRUH_DIM}Current : ${current:-not set}${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}Default : ${default:-not set}${BRUH_RESET}\n"
  printf "\n"
  printf "  Run ${BRUH_BOLD}bruh search rust${BRUH_RESET} to see available channels.\n"
  printf "\n"
}

rust_search() {
  local filter="${1:-}"
  bruh_header "Available Rust toolchains"
  bruh_divider

  local current; current=$(registry_get "rust" "current")

  printf "  ${BRUH_BOLD}%-20s  %-20s  %s${BRUH_RESET}\n" "Channel" "Description" "Status"
  printf "  %-20s  %-20s  %s\n" "───────────────────" "───────────────────" "──────────────"

  local channels="stable beta nightly"
  for ch in $channels; do
    [ -n "$filter" ] && [ "$filter" != "$ch" ] && continue
    local desc=""
    case "$ch" in
      stable)  desc="Latest stable release" ;;
      beta)    desc="Next release candidate" ;;
      nightly) desc="Latest nightly build" ;;
    esac
    local status=""
    registry_is_installed "rust" "$ch" && {
      [ "$ch" = "$current" ] \
        && status="${BRUH_GREEN}▸ installed (active)${BRUH_RESET}" \
        || status="${BRUH_BLUE}✓ installed${BRUH_RESET}"
    }
    printf "  %-20s  %-20s  %b\n" "$ch" "$desc" "$status"
  done

  printf "\n"
  printf "  ${BRUH_DIM}Specific versions also supported: e.g. bruh rust 1.78.0${BRUH_RESET}\n"
  printf "\n"
  printf "  ${BRUH_BOLD}Install with:${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh rust stable${BRUH_RESET}\n"
  printf "  ${BRUH_DIM}bruh rust nightly${BRUH_RESET}\n"
  printf "\n"
}

rust_locate() {
  bruh_header "Rust location"
  bruh_log "rustc  : $(command -v rustc 2>/dev/null || echo 'not found')"
  bruh_log "cargo  : $(command -v cargo 2>/dev/null || echo 'not found')"
  rustc --version 2>/dev/null | sed 's/^/  /' || true
}

rust_status() {
  bruh_header "Rust"
  bruh_log "Current   : $(registry_get rust current || echo 'not set')"
  bruh_log "Default   : $(registry_get rust default || echo 'not set')"
  bruh_log "CARGO_HOME: ${CARGO_HOME:-$HOME/.cargo}"
  bruh_log "Path      : $(command -v rustc 2>/dev/null || echo 'not found')"
}

rust_update() {
  _rust_ensure_rustup
  bruh_info "Updating all Rust toolchains..."
  rustup update || bruh_warn "rustup update failed."
  bruh_ok "Done."
}

rust_install_or_activate() {
  local toolchain; toolchain=$(_rust_resolve_toolchain "${1:-stable}")
  if registry_is_installed "rust" "$toolchain"; then rust_activate "$toolchain"
  else rust_install "$toolchain"; fi
}
