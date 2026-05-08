#!/usr/bin/env bash
# Dependency license checker: parses manifests, checks licenses against
# allow/deny config, and generates a compliance report.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the license database (override with LICENSE_DB env var)
# shellcheck source=license-db.sh
source "${LICENSE_DB:-$SCRIPT_DIR/license-db.sh}"

usage() {
  cat >&2 <<'EOF'
Usage: dependency-license-checker.sh -m <manifest> -c <config>

Options:
  -m <manifest>  Path to dependency manifest (package.json, requirements.txt)
  -c <config>    Path to license config JSON with allow_list and deny_list
  -h             Show this help
EOF
  return 1
}

parse_package_json() {
  local manifest="$1"
  if ! command -v jq &>/dev/null; then
    echo "Error: jq is required to parse package.json" >&2
    return 1
  fi
  jq -r '(.dependencies // {}) + (.devDependencies // {}) | to_entries[] | "\(.key) \(.value)"' "$manifest" 2>/dev/null || true
}

parse_requirements_txt() {
  local manifest="$1"
  while IFS= read -r line; do
    line="${line%%#*}"
    line="${line// /}"
    [[ -z "$line" ]] && continue
    if [[ "$line" =~ ^([a-zA-Z0-9._-]+)[=~\>\<\!]+(.+)$ ]]; then
      echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
    elif [[ "$line" =~ ^([a-zA-Z0-9._-]+)$ ]]; then
      echo "${BASH_REMATCH[1]} *"
    fi
  done < "$manifest"
}

parse_manifest() {
  local manifest="$1"
  local basename
  basename="$(basename "$manifest")"

  if [[ "$basename" == *.json ]]; then
    parse_package_json "$manifest"
  elif [[ "$basename" == requirements*.txt ]]; then
    parse_requirements_txt "$manifest"
  else
    echo "Error: Unsupported manifest format: $basename" >&2
    echo "Supported formats: *.json (package.json style), requirements*.txt" >&2
    return 1
  fi
}

read_config() {
  local config="$1"
  if ! command -v jq &>/dev/null; then
    echo "Error: jq is required to parse config" >&2
    return 1
  fi
  if ! jq empty "$config" 2>/dev/null; then
    echo "Error: Invalid JSON in config file: $config" >&2
    return 1
  fi
  ALLOW_LIST=$(jq -r '.allow_list[]?' "$config" 2>/dev/null)
  DENY_LIST=$(jq -r '.deny_list[]?' "$config" 2>/dev/null)
}

license_in_list() {
  local license="$1"
  local list="$2"
  [[ -n "$list" ]] && echo "$list" | grep -qxF "$license"
}

check_license_status() {
  local license="$1"
  if [[ "$license" == "UNKNOWN" ]]; then
    echo "unknown"
  elif license_in_list "$license" "$DENY_LIST"; then
    echo "denied"
  elif license_in_list "$license" "$ALLOW_LIST"; then
    echo "approved"
  else
    echo "unknown"
  fi
}

main() {
  local manifest="" config=""

  while getopts "m:c:h" opt; do
    case "$opt" in
      m) manifest="$OPTARG" ;;
      c) config="$OPTARG" ;;
      h) usage ;;
      *) usage ;;
    esac
  done

  if [[ -z "$manifest" ]]; then
    echo "Error: Manifest file is required (-m)" >&2
    return 1
  fi
  if [[ -z "$config" ]]; then
    echo "Error: Config file is required (-c)" >&2
    return 1
  fi
  if [[ ! -f "$manifest" ]]; then
    echo "Error: Manifest file not found: $manifest" >&2
    return 1
  fi
  if [[ ! -f "$config" ]]; then
    echo "Error: Config file not found: $config" >&2
    return 1
  fi

  read_config "$config"

  local deps has_denied=false
  local approved_count=0 denied_count=0 unknown_count=0
  local report_lines=()

  deps=$(parse_manifest "$manifest")

  if [[ -z "$deps" ]]; then
    echo "No dependencies found in $manifest"
    return 0
  fi

  while IFS=' ' read -r name version; do
    [[ -z "$name" ]] && continue
    local license status
    license=$(lookup_license "$name")
    status=$(check_license_status "$license")
    report_lines+=("${name}|${version}|${license}|${status}")
    case "$status" in
      approved) approved_count=$((approved_count + 1)) ;;
      denied)   denied_count=$((denied_count + 1)); has_denied=true ;;
      unknown)  unknown_count=$((unknown_count + 1)) ;;
    esac
  done <<< "$deps"

  local total=$((approved_count + denied_count + unknown_count))

  echo "=== Dependency License Compliance Report ==="
  echo "Manifest: $manifest"
  echo "Config: $config"
  echo ""
  printf "%-30s %-15s %-20s %-10s\n" "DEPENDENCY" "VERSION" "LICENSE" "STATUS"
  printf "%-30s %-15s %-20s %-10s\n" "----------" "-------" "-------" "------"

  for line in "${report_lines[@]}"; do
    IFS='|' read -r name version license status <<< "$line"
    printf "%-30s %-15s %-20s %-10s\n" "$name" "$version" "$license" "$status"
  done

  echo ""
  echo "=== Summary ==="
  echo "Total: $total"
  echo "Approved: $approved_count"
  echo "Denied: $denied_count"
  echo "Unknown: $unknown_count"

  if [[ "$has_denied" == true ]]; then
    echo ""
    echo "RESULT: FAIL - Denied licenses found"
    return 2
  elif [[ "$unknown_count" -gt 0 ]]; then
    echo ""
    echo "RESULT: WARNING - Unknown licenses found"
    return 0
  else
    echo ""
    echo "RESULT: PASS - All dependencies approved"
    return 0
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
