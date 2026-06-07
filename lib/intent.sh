# =============================================================================
# BRUH — intent.sh
# Normalizer, intent parser, synonym tables
# Output: prints "action|tool|version" to stdout
# =============================================================================

BRUH_TOOLS="node java python go rust yarn pnpm maven"

bruh_normalize() {
  echo "$*" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[!?,.]//g' \
    | sed 's/\bplease\b//g' \
    | sed 's/\bfor me\b//g' \
    | sed 's/\bme\b//g' \
    | tr -s ' ' \
    | sed 's/^ //;s/ $//'
}

_resolve_tool() {
  case "$1" in
    node|nodejs|node.js)       echo "node" ;;
    java|jdk|openjdk)          echo "java" ;;
    python|python3|py)         echo "python" ;;
    go|golang)                 echo "go" ;;
    rust|cargo)                echo "rust" ;;
    yarn)                      echo "yarn" ;;
    pnpm)                      echo "pnpm" ;;
    maven|mvn)                 echo "maven" ;;
    *)                         echo "" ;;
  esac
}

_resolve_action() {
  case "$1" in
    install|get|setup|add|download)  echo "install" ;;
    use|switch|activate|switch-to)   echo "activate" ;;
    remove|uninstall|delete|rm)      echo "remove" ;;
    where|path|locate|find|which)    echo "locate" ;;
    lookup|list|ls|show)             echo "lookup" ;;
    search|find-available|available) echo "search" ;;
    default)                         echo "set_default" ;;
    status|info|current|version)     echo "status" ;;
    update|upgrade)                  echo "update" ;;
    installed)                       echo "lookup" ;;
    set)                             echo "set_project" ;;
    goodbye|bye|uninstall-bruh)      echo "goodbye" ;;
    help|h|\?)                       echo "help" ;;
    runtimes|tools|all)              echo "runtimes" ;;
    latest)                          echo "latest" ;;
    stable|lts)                      echo "stable" ;;
    classic)                         echo "classic" ;;
    berry)                           echo "berry" ;;
    *)                               echo "" ;;
  esac
}

_resolve_version() {
  case "$1" in
    latest)         echo "latest" ;;
    stable|lts)     echo "stable" ;;
    classic)        echo "classic" ;;
    berry)          echo "berry" ;;
    "")             echo "" ;;
    *)              echo "$1" ;;
  esac
}

_is_tool() {
  [ -n "$(_resolve_tool "$1")" ]
}

_is_version() {
  case "$1" in
    latest|stable|lts|classic|berry) return 0 ;;
    [0-9]*)                          return 0 ;;
    *)                               return 1 ;;
  esac
}

# Known JDK providers — used to detect provider token in java commands
_is_java_provider() {
  case "$1" in
    openjdk|temurin|corretto|zulu|graalvm|oracle) return 0 ;;
    *) return 1 ;;
  esac
}

bruh_parse_intent() {
  local raw
  raw=$(bruh_normalize "$@")

  local t1 t2 t3 t4
  t1=$(echo "$raw" | awk '{print $1}')
  t2=$(echo "$raw" | awk '{print $2}')
  t3=$(echo "$raw" | awk '{print $3}')
  t4=$(echo "$raw" | awk '{print $4}')

  # ── No args ─────────────────────────────────────────────────────────────────
  [ -z "$t1" ] && echo "status|all|" && return

  # ── Top-level fixed commands ─────────────────────────────────────────────────
  case "$t1" in
    goodbye|bye)           echo "goodbye||";  return ;;
    help|--help|-h)        echo "help||";     return ;;
    runtimes|tools)        echo "runtimes||"; return ;;
  esac

  # ── search <tool> [version] — top-level search ───────────────────────────────
  if [ "$t1" = "search" ]; then
    if [ -z "$t2" ]; then
      echo "search|all|"; return
    fi
    local stool; stool=$(_resolve_tool "$t2")
    if [ -n "$stool" ]; then
      echo "search|${stool}|$(_resolve_version "$t3")"; return
    fi
    echo "search|all|"; return
  fi

  # ── lookup <tool> — top-level lookup ─────────────────────────────────────────
  if [ "$t1" = "lookup" ]; then
    if [ -z "$t2" ]; then
      echo "lookup|all|"; return
    fi
    local ltool; ltool=$(_resolve_tool "$t2")
    [ -n "$ltool" ] && echo "lookup|${ltool}|" && return
    echo "lookup|all|"; return
  fi

  # ── <tool> only → status ────────────────────────────────────────────────────
  if _is_tool "$t1" && [ -z "$t2" ]; then
    echo "status|$(_resolve_tool "$t1")|"; return
  fi

  # ── java <version> <provider> → install_or_activate with provider encoding ──
  if [ "$(_resolve_tool "$t1")" = "java" ] && _is_version "$t2" && _is_java_provider "$t3"; then
    echo "install_or_activate|java|${t2}:${t3}"; return
  fi

  # ── install java <version> <provider> ────────────────────────────────────────
  if [ "$(_resolve_action "$t1")" = "install" ] && [ "$(_resolve_tool "$t2")" = "java" ] && _is_version "$t3" && _is_java_provider "$t4"; then
    echo "install|java|${t3}:${t4}"; return
  fi

  # ── <tool> search [version] ──────────────────────────────────────────────────
  if _is_tool "$t1" && [ "$t2" = "search" ]; then
    echo "search|$(_resolve_tool "$t1")|$(_resolve_version "$t3")"; return
  fi

  # ── <tool> lookup ────────────────────────────────────────────────────────────
  if _is_tool "$t1" && [ "$(_resolve_action "$t2")" = "lookup" ] && [ -z "$t3" ]; then
    echo "lookup|$(_resolve_tool "$t1")|"; return
  fi

  # ── <tool> <version> → install-or-activate ───────────────────────────────────
  if _is_tool "$t1" && _is_version "$t2" && [ -z "$t3" ]; then
    echo "install_or_activate|$(_resolve_tool "$t1")|$(_resolve_version "$t2")"; return
  fi

  # ── <tool> <action> ──────────────────────────────────────────────────────────
  if _is_tool "$t1" && [ -n "$(_resolve_action "$t2")" ] && [ -z "$t3" ]; then
    echo "$(_resolve_action "$t2")|$(_resolve_tool "$t1")|"; return
  fi

  # ── <tool> <action> <version> ────────────────────────────────────────────────
  if _is_tool "$t1" && [ -n "$(_resolve_action "$t2")" ] && [ -n "$t3" ]; then
    echo "$(_resolve_action "$t2")|$(_resolve_tool "$t1")|$(_resolve_version "$t3")"; return
  fi

  # ── <action> <tool> <version> ────────────────────────────────────────────────
  if [ -n "$(_resolve_action "$t1")" ] && _is_tool "$t2"; then
    echo "$(_resolve_action "$t1")|$(_resolve_tool "$t2")|$(_resolve_version "$t3")"; return
  fi

  # ── NLP patterns ─────────────────────────────────────────────────────────────
  if [ "$t1" = "i" ] && [ "$t2" = "need" ] && _is_tool "$t3"; then
    echo "install_or_activate|$(_resolve_tool "$t3")|$(_resolve_version "$t4")"; return
  fi
  if [ "$t1" = "get" ] && _is_tool "$t2"; then
    echo "install_or_activate|$(_resolve_tool "$t2")|$(_resolve_version "$t3")"; return
  fi
  if [ "$t1" = "where" ] && [ "$t2" = "is" ] && _is_tool "$t3"; then
    echo "locate|$(_resolve_tool "$t3")|"; return
  fi
  if [ "$t1" = "what" ] && _is_tool "$t2"; then
    echo "status|$(_resolve_tool "$t2")|"; return
  fi

  bruh_err "Unknown command: '$*'"
  bruh_log "Try: bruh help"
  exit 1
}
