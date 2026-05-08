#!/usr/bin/env bash

# Dependency License Compliance Checker
# Parses manifest files, extracts dependencies, and checks licenses against allow/deny lists

set -uo pipefail

# Script globals
MANIFEST=""
ALLOW_LIST=""
DENY_LIST=""
LICENSE_DB=""
FORMAT="text"
EXIT_CODE=0

# Helper: print error message and exit
error() {
  echo "Error: $*" >&2
  exit 1
}

# Helper: print usage
usage() {
  cat << 'EOF'
Usage: dependency-checker.sh [options]

Options:
  --manifest FILE       Path to manifest file (package.json or requirements.txt)
  --allow FILE          Path to allow-list file (one license per line)
  --deny FILE           Path to deny-list file (one license per line)
  --license-db FILE     Path to license database file (format: package|license)
  --format FORMAT       Output format: text or json (default: text)
  --help               Show this help message

EOF
  exit 1
}

# Parse command-line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --manifest)
        MANIFEST="$2"
        shift 2
        ;;
      --allow)
        ALLOW_LIST="$2"
        shift 2
        ;;
      --deny)
        DENY_LIST="$2"
        shift 2
        ;;
      --license-db)
        LICENSE_DB="$2"
        shift 2
        ;;
      --format)
        FORMAT="$2"
        shift 2
        ;;
      --help)
        usage
        ;;
      *)
        error "Unknown option: $1"
        ;;
    esac
  done

  # Validate required arguments
  [[ -n "$MANIFEST" ]] || error "Missing required argument: --manifest"
  [[ -n "$ALLOW_LIST" ]] || error "Missing required argument: --allow"
  [[ -n "$DENY_LIST" ]] || error "Missing required argument: --deny"
  [[ -n "$LICENSE_DB" ]] || error "Missing required argument: --license-db"

  # Validate files exist
  [[ -f "$MANIFEST" ]] || error "Manifest file not found: $MANIFEST"
  [[ -f "$ALLOW_LIST" ]] || error "Allow-list file not found: $ALLOW_LIST"
  [[ -f "$DENY_LIST" ]] || error "Deny-list file not found: $DENY_LIST"
  [[ -f "$LICENSE_DB" ]] || error "License database file not found: $LICENSE_DB"
}

# Load allow-list into associative array
declare -A ALLOW_LICENSES
load_allow_list() {
  local old_ifs="$IFS"
  while IFS= read -r license || [[ -n "$license" ]]; do
    [[ -z "$license" ]] && continue
    license="${license// /}"
    ALLOW_LICENSES["${license,,}"]="yes"
  done < "$ALLOW_LIST"
  IFS="$old_ifs"
}

# Load deny-list into associative array
declare -A DENY_LICENSES
load_deny_list() {
  local old_ifs="$IFS"
  while IFS= read -r license || [[ -n "$license" ]]; do
    [[ -z "$license" ]] && continue
    license="${license// /}"
    DENY_LICENSES["${license,,}"]="yes"
  done < "$DENY_LIST"
  IFS="$old_ifs"
}

# Load license database into associative array
declare -A LICENSE_DB_ARRAY
load_license_db() {
  local old_ifs="$IFS"
  while IFS='|' read -r package license || [[ -n "$package" ]]; do
    [[ -z "$package" ]] && continue
    package="${package// /}"
    license="${license// /}"
    LICENSE_DB_ARRAY["${package,,}"]="${license,,}"
  done < "$LICENSE_DB"
  IFS="$old_ifs"
}

# Detect manifest file type and parse
declare -a DEPENDENCIES

parse_manifest() {
  if [[ "$MANIFEST" == *.json ]]; then
    parse_package_json
  elif [[ "$MANIFEST" == *.txt ]]; then
    parse_requirements_txt
  else
    error "Unsupported manifest format: $MANIFEST"
  fi
}

# Parse package.json file
parse_package_json() {
  local in_deps=0
  local old_ifs="$IFS"
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Check if we're starting the dependencies section
    if [[ "$line" == *"dependencies"* ]] && [[ "$line" == *"{"* ]]; then
      in_deps=1
      continue
    fi

    # Exit if we hit the closing brace of dependencies section
    if [[ "$in_deps" == "1" && "$line" =~ ^[[:space:]]*} ]]; then
      break
    fi

    # Parse dependency lines: "name": "version"
    if [[ "$in_deps" == "1" && "$line" =~ \"([^\"]+)\":[[:space:]]*\"([^\"]+)\" ]]; then
      local name="${BASH_REMATCH[1]}"
      local version="${BASH_REMATCH[2]}"
      # Remove version prefixes (^, ~, =, >=, etc.) but keep numbers and dots
      version="${version//[^0-9.]/}"
      [[ -n "$version" ]] || version="unknown"
      DEPENDENCIES+=("$name|$version")
    fi
  done < "$MANIFEST"
  IFS="$old_ifs"
}

# Parse requirements.txt file (pip format)
parse_requirements_txt() {
  local old_ifs="$IFS"
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and empty lines
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    # Extract package name and version (format: package==version or package>=version, etc.)
    if [[ "$line" =~ ^([a-zA-Z0-9_-]+)([=<>!~]+)([0-9.]+) ]]; then
      local name="${BASH_REMATCH[1]}"
      local version="${BASH_REMATCH[3]}"
      DEPENDENCIES+=("$name|$version")
    elif [[ "$line" =~ ^([a-zA-Z0-9_-]+)$ ]]; then
      # Package without version
      local name="$line"
      DEPENDENCIES+=("$name|unknown")
    fi
  done < "$MANIFEST"
  IFS="$old_ifs"
}

# Lookup license for a package
lookup_license() {
  local package="$1"
  local package_lower="${package,,}"

  if [[ -n "${LICENSE_DB_ARRAY[$package_lower]:-}" ]]; then
    echo "${LICENSE_DB_ARRAY[$package_lower]}"
  else
    echo "unknown"
  fi
}

# Check if license is in allow-list
is_allowed() {
  local license="$1"
  local license_lower="${license,,}"
  [[ -n "${ALLOW_LICENSES[$license_lower]:-}" ]]
}

# Check if license is in deny-list
is_denied() {
  local license="$1"
  local license_lower="${license,,}"
  [[ -n "${DENY_LICENSES[$license_lower]:-}" ]]
}

# Get status for a license
get_status() {
  local license="$1"

  if is_denied "$license"; then
    echo "DENIED"
  elif is_allowed "$license"; then
    echo "APPROVED"
  else
    echo "UNKNOWN"
  fi
}

# Generate text report
generate_text_report() {
  echo "=== Dependency License Compliance Report ==="
  echo ""

  local approved_count=0
  local denied_count=0
  local unknown_count=0
  local idx=0
  local total=${#DEPENDENCIES[@]}

  while [[ $idx -lt $total ]]; do
    local dep="${DEPENDENCIES[$idx]}"
    local package="${dep%|*}"
    local version="${dep#*|}"
    local license
    license=$(lookup_license "$package")
    local status
    status=$(get_status "$license")

    case "$status" in
      APPROVED)
        echo "[✓ APPROVED] $package ($version) - License: $license"
        ((approved_count++))
        ;;
      DENIED)
        echo "[✗ DENIED]   $package ($version) - License: $license"
        ((denied_count++))
        EXIT_CODE=1
        ;;
      UNKNOWN)
        echo "[? UNKNOWN]  $package ($version) - License: not found in database"
        ((unknown_count++))
        ;;
    esac

    idx=$((idx + 1))
  done

  echo ""
  echo "=== Summary ==="
  echo "Approved:  $approved_count"
  echo "Denied:    $denied_count"
  echo "Unknown:   $unknown_count"
  echo "Total:     $((approved_count + denied_count + unknown_count))"
}

# Generate JSON report
generate_json_report() {
  local json_output="{"
  json_output+=$'\"dependencies\": ['
  local first=1
  local idx=0
  local total=${#DEPENDENCIES[@]}

  while [[ $idx -lt $total ]]; do
    local dep="${DEPENDENCIES[$idx]}"
    local package="${dep%|*}"
    local version="${dep#*|}"
    local license
    license=$(lookup_license "$package")
    local status
    status=$(get_status "$license")

    if [[ "$first" == "0" ]]; then
      json_output+=","
    fi
    first=0

    json_output+=$'{\n'
    json_output+="\"name\": \"$package\", "
    json_output+="\"version\": \"$version\", "
    json_output+="\"license\": \"$license\", "
    json_output+="\"status\": \"$status\""
    json_output+=$'\n}'

    if [[ "$status" == "DENIED" ]]; then
      EXIT_CODE=1
    fi

    idx=$((idx + 1))
  done

  json_output+=$'\n]'
  json_output+="}"

  echo "$json_output"
}

# Main execution
main() {
  parse_args "$@"
  load_allow_list
  load_deny_list
  load_license_db
  parse_manifest

  case "$FORMAT" in
    text)
      generate_text_report
      ;;
    json)
      generate_json_report
      ;;
    *)
      error "Unknown format: $FORMAT"
      ;;
  esac

  exit "$EXIT_CODE"
}

main "$@"
