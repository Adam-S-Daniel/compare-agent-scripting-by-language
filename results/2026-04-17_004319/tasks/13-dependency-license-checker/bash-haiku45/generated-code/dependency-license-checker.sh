#!/usr/bin/env bash

# Dependency License Checker - Checks licenses of project dependencies against allow/deny lists
# Usage: dependency-license-checker.sh --manifest <file> [--config <file>]

set -euo pipefail

# Initialize variables
MANIFEST_FILE=""
CONFIG_FILE=""
ALLOWLIST=()
DENYLIST=()

# Mock license database: maps package names to their licenses
declare -A LICENSE_DB=(
    [lodash]="MIT"
    [express]="MIT"
    [jest]="MIT"
    [requests]="Apache-2.0"
    [django]="BSD-3-Clause"
    [viral-license-lib]="GPL-3.0"
    [mystery-lib]="Unlicense"
    [test-lib]="MIT"
)

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --manifest)
                MANIFEST_FILE="$2"
                shift 2
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            *)
                echo "Error: Unknown argument: $1" >&2
                return 1
                ;;
        esac
    done
    return 0
}

# Validate manifest file exists
validate_manifest() {
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        echo "error: Manifest file not found: $MANIFEST_FILE" >&2
        return 1
    fi
}

# Load configuration from JSON file
load_config() {
    if [[ -z "$CONFIG_FILE" ]]; then
        return 0
    fi

    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "error: Config file not found: $CONFIG_FILE" >&2
        return 1
    fi

    # Parse allowlist from config JSON
    ALLOWLIST=()
    while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        ALLOWLIST+=("$item")
    done < <(jq -r '.allowlist[]?' "$CONFIG_FILE" 2>/dev/null || echo "")

    # Parse denylist from config JSON
    DENYLIST=()
    while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        DENYLIST+=("$item")
    done < <(jq -r '.denylist[]?' "$CONFIG_FILE" 2>/dev/null || echo "")
}

# Get license for a package from the mock database
get_license() {
    local package_name="$1"
    echo "${LICENSE_DB[$package_name]:-UNKNOWN}"
}

# Check if license is approved
check_license_status() {
    local license="$1"

    # If denylist has this license, it's denied
    if [[ ${#DENYLIST[@]} -gt 0 ]]; then
        for denied in "${DENYLIST[@]}"; do
            if [[ "$license" == "$denied" ]]; then
                echo "DENIED"
                return 0
            fi
        done
    fi

    # If allowlist is specified, check if license is in it
    if [[ ${#ALLOWLIST[@]} -gt 0 ]]; then
        for allowed in "${ALLOWLIST[@]}"; do
            if [[ "$license" == "$allowed" ]]; then
                echo "APPROVED"
                return 0
            fi
        done
        # License not in allowlist
        echo "UNKNOWN"
        return 0
    fi

    # If no allowlist or denylist, report as unknown
    echo "UNKNOWN"
    return 0
}

# Parse package.json format
parse_package_json() {
    local file="$1"
    local -a deps

    # Extract dependencies and devDependencies
    while IFS='|' read -r name version; do
        [[ -z "$name" ]] && continue
        deps+=("$name|$version")
    done < <(jq -r '(.dependencies, .devDependencies) | to_entries[] | "\(.key)|\(.value)"' "$file" 2>/dev/null || echo "")

    printf '%s\n' "${deps[@]}"
}

# Parse requirements.txt format (Python)
parse_requirements_txt() {
    local file="$1"
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ -z "$line" || "$line" =~ ^# ]] && continue

        # Extract package name and version
        # Handle formats: package==1.0.0, package>=1.0, package[extra]==1.0, etc.
        if [[ $line =~ ^([a-zA-Z0-9_-]+).*==(.+)$ ]]; then
            local name="${BASH_REMATCH[1]}"
            local version="${BASH_REMATCH[2]}"
            echo "$name|$version"
        elif [[ $line =~ ^([a-zA-Z0-9_-]+) ]]; then
            echo "${BASH_REMATCH[1]}|unknown"
        fi
    done < "$file"
}

# Determine manifest type and parse accordingly
parse_manifest() {
    local file="$1"
    local manifest_type

    # Determine file type based on extension
    if [[ "$file" =~ \.json$ ]]; then
        manifest_type="json"
    elif [[ "$file" =~ \.txt$ ]]; then
        manifest_type="txt"
    else
        echo "error: Unknown manifest format: $file" >&2
        return 1
    fi

    case "$manifest_type" in
        json)
            parse_package_json "$file"
            ;;
        txt)
            parse_requirements_txt "$file"
            ;;
    esac
}

# Generate compliance report
generate_report() {
    local -a dependencies
    local status

    # Parse dependencies from manifest
    while IFS='|' read -r name version; do
        [[ -z "$name" ]] && continue

        # Get license for this dependency
        local license
        license=$(get_license "$name")

        # Check license status
        status=$(check_license_status "$license")

        # Output in table format
        printf "%-25s %-15s %-15s %s\n" "$name" "$version" "$license" "$status"
    done < <(parse_manifest "$MANIFEST_FILE")
}

# Main function
main() {
    parse_args "$@" || return 1
    validate_manifest || return 1
    load_config || return 1

    # Print header
    printf "%-25s %-15s %-15s %s\n" "DEPENDENCY" "VERSION" "LICENSE" "STATUS"
    printf "%s\n" "==============================================================================="

    # Generate and display report
    generate_report
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
