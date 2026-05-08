#!/usr/bin/env bash
# Dependency License Checker
# Parses dependency manifests, checks licenses against allow/deny lists, generates compliance reports.
# Usage: ./license-checker.sh --manifest <file> --config <config.json> [--mock-db <db.json>] [--fail-on-denied]

set -euo pipefail

MANIFEST=""
CONFIG=""
MOCK_DB=""
FAIL_ON_DENIED=false

usage() {
  echo "Usage: $0 --manifest <file> --config <config.json> [--mock-db <db.json>] [--fail-on-denied]" >&2
  exit 1
}

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest)    MANIFEST="$2"; shift 2 ;;
    --config)      CONFIG="$2";   shift 2 ;;
    --mock-db)     MOCK_DB="$2";  shift 2 ;;
    --fail-on-denied) FAIL_ON_DENIED=true; shift ;;
    *) echo "Error: unknown option: $1" >&2; usage ;;
  esac
done

# Validate required arguments
if [[ -z "$MANIFEST" ]]; then
  echo "Error: --manifest is required" >&2
  exit 1
fi
if [[ -z "$CONFIG" ]]; then
  echo "Error: --config is required" >&2
  exit 1
fi
if [[ ! -f "$MANIFEST" ]]; then
  echo "Error: manifest file not found: $MANIFEST" >&2
  exit 1
fi
if [[ ! -f "$CONFIG" ]]; then
  echo "Error: config file not found: $CONFIG" >&2
  exit 1
fi

# Load allow and deny license lists from config JSON
ALLOW_LIST=$(jq -r '.allow // [] | .[]' "$CONFIG" 2>/dev/null)
DENY_LIST=$(jq  -r '.deny  // [] | .[]' "$CONFIG" 2>/dev/null)

# Detect manifest type: prefer content-based detection over exact filename matching
# so that fixture files like all-approved-package.json are handled correctly.
detect_manifest_type() {
  local file="$1"
  local base
  base="$(basename "$file")"

  case "$base" in
    # Any .json file that looks like a Node manifest
    *.json)
      if jq -e 'has("dependencies") or has("devDependencies") or has("name")' "$file" &>/dev/null 2>&1; then
        echo "npm"
      else
        echo "unknown"
      fi
      ;;
    # requirements*.txt or *.txt treated as pip
    requirements*.txt | *.txt)
      echo "pip"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

# Parse dependencies, emitting lines of: <name> <version>
parse_dependencies() {
  local manifest="$1"
  local type
  type=$(detect_manifest_type "$manifest")

  case "$type" in
    npm)
      # Merge dependencies and devDependencies, strip leading ^ ~ = < > operators from version
      jq -r '((.dependencies // {}) + (.devDependencies // {})) | to_entries[] | "\(.key) \(.value)"' \
        "$manifest" | sed 's/ [^0-9]/ /; s/ [^0-9 ].*//'
      ;;
    pip)
      # Strip comments, blank lines, and version specifiers (==, >=, <=, ~=, !=, <>)
      grep -v '^\s*#' "$manifest" \
        | grep -v '^\s*$' \
        | sed 's/[>=<!~].*//' \
        | sed 's/\s.*//' \
        | awk '{print $1, "any"}'
      ;;
    *)
      echo "Error: unsupported manifest type for file: $manifest" >&2
      exit 1
      ;;
  esac
}

# Look up the license for a given package name using the mock database (or return UNKNOWN)
lookup_license() {
  local package="$1"

  if [[ -n "$MOCK_DB" && -f "$MOCK_DB" ]]; then
    local license
    license=$(jq -r --arg pkg "$package" '.[$pkg] // empty' "$MOCK_DB" 2>/dev/null)
    if [[ -z "$license" ]]; then
      echo "UNKNOWN"
    else
      echo "$license"
    fi
  else
    # No mock DB: real lookup would go here; for now, return UNKNOWN
    echo "UNKNOWN"
  fi
}

# Determine approval status: approved | denied | unknown
check_license_status() {
  local license="$1"

  if [[ "$license" == "UNKNOWN" || -z "$license" ]]; then
    echo "unknown"
    return
  fi

  # Deny list takes priority over allow list
  while IFS= read -r denied_license; do
    [[ -z "$denied_license" ]] && continue
    if [[ "$license" == "$denied_license" ]]; then
      echo "denied"
      return
    fi
  done <<< "$DENY_LIST"

  while IFS= read -r allowed_license; do
    [[ -z "$allowed_license" ]] && continue
    if [[ "$license" == "$allowed_license" ]]; then
      echo "approved"
      return
    fi
  done <<< "$ALLOW_LIST"

  # License is known but not in either list
  echo "unknown"
}

# Generate the compliance report
generate_report() {
  local manifest="$1"
  local approved_count=0
  local denied_count=0
  local unknown_count=0
  declare -a report_lines=()

  # Build report data
  while IFS=' ' read -r name version; do
    [[ -z "$name" ]] && continue
    local license
    license=$(lookup_license "$name")
    local status
    status=$(check_license_status "$license")

    # Use += 1 to avoid (( n++ )) returning exit 1 when n==0 under set -e
    case "$status" in
      approved) approved_count=$(( approved_count + 1 )) ;;
      denied)   denied_count=$(( denied_count + 1 ))   ;;
      unknown)  unknown_count=$(( unknown_count + 1 ))  ;;
    esac

    report_lines+=("${name}|${version}|${license}|${status}")
  done < <(parse_dependencies "$manifest")

  # Print report header
  echo "=== Dependency License Compliance Report ==="
  echo "Manifest: ${manifest}"
  echo "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo ""

  # Table header
  printf "%-35s %-15s %-20s %-10s\n" "PACKAGE" "VERSION" "LICENSE" "STATUS"
  printf "%-35s %-15s %-20s %-10s\n" "-------" "-------" "-------" "------"

  # Table rows
  for line in "${report_lines[@]}"; do
    IFS='|' read -r name version license status <<< "$line"
    printf "%-35s %-15s %-20s %-10s\n" "$name" "$version" "$license" "$status"
  done

  # Summary
  local total=$(( approved_count + denied_count + unknown_count ))
  echo ""
  echo "=== Summary ==="
  printf "Approved: %d\n" "$approved_count"
  printf "Denied:   %d\n" "$denied_count"
  printf "Unknown:  %d\n" "$unknown_count"
  printf "Total:    %d\n" "$total"

  # In strict mode, exit 1 if any denied licenses were found
  if [[ "$FAIL_ON_DENIED" == "true" && "$denied_count" -gt 0 ]]; then
    echo ""
    echo "ERROR: ${denied_count} dependency(ies) with denied license(s) found." >&2
    exit 1
  fi
}

generate_report "$MANIFEST"
