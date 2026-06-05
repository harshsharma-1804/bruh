# =============================================================================
# BRUH — registry.sh
# All reads and writes to registry/state.json go through this file.
# Requires: jq, core.sh
# =============================================================================

BRUH_REGISTRY="$BRUH_HOME/registry/state.json"

_registry_read() {
  jq -r "$1" "$BRUH_REGISTRY" 2>/dev/null
}

_registry_write() {
  local tmp
  tmp=$(mktemp)
  jq "$1" "$BRUH_REGISTRY" > "$tmp" && mv "$tmp" "$BRUH_REGISTRY"
}

registry_get() {
  local tool="$1" field="$2"
  _registry_read ".${tool}.${field} // empty"
}

registry_get_exact() {
  local tool="$1"
  _registry_read ".${tool}.current_exact // empty"
}

registry_set() {
  local tool="$1" field="$2" value="$3"
  if [ "$value" = "null" ] || [ -z "$value" ]; then
    _registry_write ".${tool}.${field} = null"
  else
    _registry_write ".${tool}.${field} = \"${value}\""
  fi
}

registry_set_exact() {
  local tool="$1" value="$2"
  if [ -z "$value" ] || [ "$value" = "null" ]; then
    _registry_write ".${tool}.current_exact = null"
  else
    _registry_write ".${tool}.current_exact = \"${value}\""
  fi
}

registry_is_installed() {
  local tool="$1" version="$2"
  local result
  result=$(_registry_read ".${tool}.installed | index(\"${version}\")")
  [ "$result" != "null" ] && [ -n "$result" ]
}

registry_is_bruh_installed() {
  local tool="$1" version="$2"
  local result
  result=$(_registry_read ".${tool}.bruh_installed | index(\"${version}\")")
  [ "$result" != "null" ] && [ -n "$result" ]
}

registry_add_installed() {
  local tool="$1" version="$2"
  if ! registry_is_installed "$tool" "$version"; then
    _registry_write ".${tool}.installed += [\"${version}\"]"
  fi
}

registry_add_bruh_installed() {
  local tool="$1" version="$2"
  if ! registry_is_bruh_installed "$tool" "$version"; then
    _registry_write ".${tool}.bruh_installed += [\"${version}\"]"
  fi
}

registry_remove_installed() {
  local tool="$1" version="$2"
  _registry_write "
    .${tool}.installed      = (.${tool}.installed      | map(select(. != \"${version}\"))) |
    .${tool}.bruh_installed = (.${tool}.bruh_installed | map(select(. != \"${version}\")))
  "
}

registry_list_installed() {
  local tool="$1"
  _registry_read ".${tool}.installed[]" 2>/dev/null
}

registry_list_bruh_installed() {
  local tool="$1"
  _registry_read ".${tool}.bruh_installed[]" 2>/dev/null
}

registry_record_install() {
  local tool="$1" version="$2"
  registry_add_installed "$tool" "$version"
  registry_add_bruh_installed "$tool" "$version"
  registry_set "$tool" "current" "$version"
}

registry_record_activate() {
  local tool="$1" version="$2"
  registry_add_installed "$tool" "$version"
  registry_set "$tool" "current" "$version"
}

# -----------------------------------------------------------------------------
# Java provider tracking
# Stores which provider (temurin, openjdk, etc.) was used per version
# Uses the java.providers object: { "21": "temurin", "17": "openjdk" }
# -----------------------------------------------------------------------------

registry_set_java_provider() {
  local version="$1" provider="$2"
  # Ensure providers object exists then set the key
  _registry_write "
    if .java.providers == null then .java.providers = {} else . end |
    .java.providers[\"${version}\"] = \"${provider}\"
  "
}

registry_get_java_provider() {
  local version="$1"
  local result
  result=$(_registry_read ".java.providers[\"${version}\"] // empty")
  # Default to openjdk if not recorded
  [ -z "$result" ] && echo "openjdk" || echo "$result"
}

registry_remove_java_provider() {
  local version="$1"
  _registry_write "
    if .java.providers then .java.providers |= del(.[\"${version}\"]) else . end
  "
}
