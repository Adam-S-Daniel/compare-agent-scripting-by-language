#!/usr/bin/env bash
# check-licenses.sh - Dependency license compliance checker
#
# Parses dependency manifests (package.json, requirements.txt),
# extracts dependency names and versions, checks each against
# allow-list and deny-list of licenses from a config file,
# and generates a compliance report.
#
# Usage: check-licenses.sh <manifest-file> <config-file> [license-lookup-script]
#
# The optional license-lookup-script is a script/function that,
# given a package name and version, returns the license string.
# If not provided, a built-in mock is used.

set -euo pipefail

# --- Default mock license lookup ---
# Maps package names to licenses for testing purposes.
# In production, this would query a package registry (npm, PyPI, etc.).
builtin_license_lookup() {
    local name="$1"
    # Mock license database - returns known licenses for test packages
    case "$name" in
        express)     echo "MIT" ;;
        lodash)      echo "MIT" ;;
        react)       echo "MIT" ;;
        leftpad)     echo "WTFPL" ;;
        evilpkg)     echo "GPL-3.0" ;;
        requests)    echo "Apache-2.0" ;;
        flask)       echo "BSD-3-Clause" ;;
        numpy)       echo "BSD-3-Clause" ;;
        django)      echo "BSD-3-Clause" ;;
        pylint)      echo "GPL-2.0" ;;
        unknown-pkg) echo "UNKNOWN" ;;
        *)           echo "UNKNOWN" ;;
    esac
}

# --- Manifest parsers ---

# Parse package.json and output "name version" lines for dependencies
parse_package_json() {
    local manifest="$1"
    # Extract both dependencies and devDependencies
    jq -r '
        ((.dependencies // {}) + (.devDependencies // {}))
        | to_entries[]
        | "\(.key) \(.value)"
    ' "$manifest"
}

# Parse requirements.txt and output "name version" lines
parse_requirements_txt() {
    local manifest="$1"
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        # Handle ==, >=, <=, ~=, != version specifiers
        # Use a variable for the regex to avoid shellcheck parse issues with < >
        local version_re='^([a-zA-Z0-9._-]+)[=><!~]+(.+)$'
        local bare_re='^([a-zA-Z0-9._-]+)$'
        if [[ "$line" =~ $version_re ]]; then
            echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
        elif [[ "$line" =~ $bare_re ]]; then
            # No version specified
            echo "${BASH_REMATCH[1]} *"
        fi
    done < "$manifest"
}

# --- Config reader ---
# Config is JSON with "allowed_licenses" and "denied_licenses" arrays

get_allowed_licenses() {
    local config="$1"
    jq -r '.allowed_licenses[]' "$config"
}

get_denied_licenses() {
    local config="$1"
    jq -r '.denied_licenses[]' "$config"
}

# --- License classification ---
# Returns: approved, denied, or unknown

classify_license() {
    local license="$1"
    local config="$2"

    # Check if license is UNKNOWN from lookup
    if [[ "$license" == "UNKNOWN" ]]; then
        echo "unknown"
        return
    fi

    # Check denied list first (deny takes precedence)
    while IFS= read -r denied; do
        if [[ "$license" == "$denied" ]]; then
            echo "denied"
            return
        fi
    done < <(get_denied_licenses "$config")

    # Check allowed list
    while IFS= read -r allowed; do
        if [[ "$license" == "$allowed" ]]; then
            echo "approved"
            return
        fi
    done < <(get_allowed_licenses "$config")

    # Not in either list
    echo "unknown"
}

# --- Report generation ---

generate_report() {
    local manifest="$1"
    local config="$2"
    local lookup_cmd="${3:-}"

    # Detect manifest type
    local basename
    basename="$(basename "$manifest")"

    local parse_func
    case "$basename" in
        *.json)
            parse_func="parse_package_json"
            ;;
        *.txt)
            parse_func="parse_requirements_txt"
            ;;
        *)
            echo "ERROR: Unsupported manifest format: $basename" >&2
            echo "Supported formats: *.json (package.json), *.txt (requirements.txt)" >&2
            return 1
            ;;
    esac

    # Counters for summary
    local total=0
    local approved_count=0
    local denied_count=0
    local unknown_count=0

    echo "========================================="
    echo "  Dependency License Compliance Report"
    echo "========================================="
    echo ""
    echo "Manifest: $manifest"
    echo "Config:   $config"
    echo ""
    echo "-----------------------------------------"
    printf "%-20s %-12s %-15s %s\n" "PACKAGE" "VERSION" "LICENSE" "STATUS"
    echo "-----------------------------------------"

    # Parse manifest and check each dependency
    while IFS=' ' read -r name version; do
        [[ -z "$name" ]] && continue

        # Look up license
        local license
        if [[ -n "$lookup_cmd" ]]; then
            license="$("$lookup_cmd" "$name" "$version")"
        else
            license="$(builtin_license_lookup "$name")"
        fi

        # Classify
        local status
        status="$(classify_license "$license" "$config")"

        # Format status with markers
        local status_display
        case "$status" in
            approved) status_display="APPROVED" ;;
            denied)   status_display="DENIED" ;;
            unknown)  status_display="UNKNOWN" ;;
        esac

        printf "%-20s %-12s %-15s %s\n" "$name" "$version" "$license" "$status_display"

        # Update counters
        total=$((total + 1))
        case "$status" in
            approved) approved_count=$((approved_count + 1)) ;;
            denied)   denied_count=$((denied_count + 1)) ;;
            unknown)  unknown_count=$((unknown_count + 1)) ;;
        esac
    done < <("$parse_func" "$manifest")

    echo ""
    echo "========================================="
    echo "  Summary"
    echo "========================================="
    echo "Total dependencies: $total"
    echo "Approved: $approved_count"
    echo "Denied: $denied_count"
    echo "Unknown: $unknown_count"
    echo ""

    # Exit with error if any denied dependencies found
    if [[ "$denied_count" -gt 0 ]]; then
        echo "RESULT: FAIL - $denied_count denied license(s) found"
        return 1
    elif [[ "$unknown_count" -gt 0 ]]; then
        echo "RESULT: WARNING - $unknown_count unknown license(s) found"
        return 0
    else
        echo "RESULT: PASS - All dependencies have approved licenses"
        return 0
    fi
}

# --- Main entry point ---

main() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <manifest-file> <config-file> [license-lookup-script]" >&2
        return 1
    fi

    local manifest="$1"
    local config="$2"
    local lookup="${3:-}"

    # Validate inputs
    if [[ ! -f "$manifest" ]]; then
        echo "ERROR: Manifest file not found: $manifest" >&2
        return 1
    fi

    if [[ ! -f "$config" ]]; then
        echo "ERROR: Config file not found: $config" >&2
        return 1
    fi

    if [[ -n "$lookup" && ! -x "$lookup" ]]; then
        echo "ERROR: License lookup script not found or not executable: $lookup" >&2
        return 1
    fi

    generate_report "$manifest" "$config" "$lookup"
}

# Only run main if not being sourced (allows testing individual functions)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
