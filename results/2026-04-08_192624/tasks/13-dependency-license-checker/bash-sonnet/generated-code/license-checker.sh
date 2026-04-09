#!/usr/bin/env bash
# Dependency License Checker
#
# Parses dependency manifests (package.json, requirements.txt), looks up
# each dependency's license via a mock lookup table, and generates a
# compliance report comparing against allow/deny lists.
#
# Usage:
#   license-checker.sh --manifest <file> --licenses <config.json> [--report|--list-deps]
#
# Options:
#   --manifest <file>   Path to package.json or requirements.txt
#   --licenses <file>   Path to license configuration JSON
#   --report            Generate full compliance report (default)
#   --list-deps         Only list extracted dependency names and versions
#
# Exit codes:
#   0 = all licenses approved (or only listing deps)
#   1 = one or more denied licenses found
#   2 = usage error or missing files

set -euo pipefail

# ── Globals ────────────────────────────────────────────────────────────────
MANIFEST=""
LICENSE_CONFIG=""
MODE="report"

# ── Helpers ────────────────────────────────────────────────────────────────

# Print an error message to stderr and exit
error() {
    echo "Error: $*" >&2
    exit 2
}

# Require jq for JSON parsing
require_jq() {
    if ! command -v jq &>/dev/null; then
        error "jq is required but not installed. Install with: apt-get install jq"
    fi
}

# ── Argument Parsing ───────────────────────────────────────────────────────
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --manifest)
                MANIFEST="$2"
                shift 2
                ;;
            --licenses)
                LICENSE_CONFIG="$2"
                shift 2
                ;;
            --report)
                MODE="report"
                shift
                ;;
            --list-deps)
                MODE="list-deps"
                shift
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done

    [[ -n "$MANIFEST" ]]      || error "Missing --manifest argument"
    [[ -n "$LICENSE_CONFIG" ]] || error "Missing --licenses argument"
    [[ -f "$MANIFEST" ]]      || error "Manifest file not found: $MANIFEST"
    [[ -f "$LICENSE_CONFIG" ]] || error "License config file not found: $LICENSE_CONFIG"
}

# ── Manifest Parsing ───────────────────────────────────────────────────────

# Parse package.json — outputs "name version" pairs, one per line
parse_package_json() {
    local file="$1"
    # Extract dependencies (name + version) using jq
    jq -r '
        (.dependencies // {}) + (.devDependencies // {}) |
        to_entries[] |
        "\(.key) \(.value)"
    ' "$file" | sed 's/[\^~>=<]//g'
}

# Parse requirements.txt — handles ==, >=, <=, ~=, bare names, and comments
parse_requirements_txt() {
    local file="$1"
    # Skip comments and blank lines; extract name and optional version
    while IFS= read -r line; do
        # Strip inline comments
        line="${line%%#*}"
        # Trim whitespace
        line="${line//[[:space:]]/}"
        [[ -z "$line" ]] && continue

        # Handle ==, >=, <=, ~=, !=  — take the first version specifier
        # Use sed to split on version specifier operators (avoids <> ambiguity in [[ ]])
        local name version
        local sep_pos
        sep_pos="$(echo "$line" | sed -n 's/^\([A-Za-z0-9_.-]\+\)[=!<>~].*/\1/p')"
        if [[ -n "$sep_pos" ]]; then
            name="$sep_pos"
            version="$(echo "$line" | sed 's/^[A-Za-z0-9_.-]*[=!<>~]*//; s/[=!<>~].*$//')"
            [[ -z "$version" ]] && version="unknown"
        elif [[ "$line" =~ ^([A-Za-z0-9_.-]+) ]]; then
            name="${BASH_REMATCH[1]}"
            version="unknown"
        else
            continue
        fi
        echo "${name} ${version}"
    done < "$file"
}

# Dispatch to the right parser based on file extension
# Any .json file is treated as package.json format; any .txt as requirements.txt format
parse_manifest() {
    local file="$1"
    local basename ext
    basename="$(basename "$file")"
    ext="${basename##*.}"

    case "$ext" in
        json)
            parse_package_json "$file"
            ;;
        txt)
            parse_requirements_txt "$file"
            ;;
        *)
            error "Unsupported manifest type: $basename (supported: *.json, *.txt)"
            ;;
    esac
}

# ── License Lookup (Mock) ──────────────────────────────────────────────────

# Look up a dependency's license from the mock_licenses table in the config.
# Falls back to "UNKNOWN-LICENSE" if not found.
lookup_license() {
    local dep="$1"
    local config="$2"
    jq -r --arg dep "$dep" '.mock_licenses[$dep] // "UNKNOWN-LICENSE"' "$config"
}

# ── License Classification ─────────────────────────────────────────────────

# Returns "APPROVED", "DENIED", or "UNKNOWN" for a given SPDX license string.
classify_license() {
    local license="$1"
    local config="$2"

    # Check allow-list
    local allowed
    allowed="$(jq -r --arg lic "$license" '.allow | map(. == $lic) | any' "$config")"
    if [[ "$allowed" == "true" ]]; then
        echo "APPROVED"
        return
    fi

    # Check deny-list
    local denied
    denied="$(jq -r --arg lic "$license" '.deny | map(. == $lic) | any' "$config")"
    if [[ "$denied" == "true" ]]; then
        echo "DENIED"
        return
    fi

    echo "UNKNOWN"
}

# ── Report Generation ──────────────────────────────────────────────────────

generate_report() {
    local manifest="$1"
    local config="$2"

    local approved=0 denied=0 unknown=0 total=0

    echo "Dependency License Compliance Report"
    echo "====================================="
    echo "Manifest: $(basename "$manifest")"
    echo ""
    printf "%-30s %-20s %-10s %s\n" "Package" "Version" "License" "Status"
    printf "%-30s %-20s %-10s %s\n" "-------" "-------" "-------" "------"

    # Collect results for the summary
    local has_denied=0

    while IFS=" " read -r name version; do
        [[ -z "$name" ]] && continue
        total=$((total + 1))

        local license status
        license="$(lookup_license "$name" "$config")"
        status="$(classify_license "$license" "$config")"

        printf "%-30s %-20s %-10s %s\n" "$name" "$version" "$license" "$status"

        case "$status" in
            APPROVED) approved=$((approved + 1)) ;;
            DENIED)   denied=$((denied + 1));  has_denied=1 ;;
            UNKNOWN)  unknown=$((unknown + 1)) ;;
        esac
    done < <(parse_manifest "$manifest")

    echo ""
    echo "Summary"
    echo "-------"
    echo "Total:    $total"
    echo "Approved: $approved"
    echo "Denied:   $denied"
    echo "Unknown:  $unknown"

    if [[ $has_denied -eq 1 ]]; then
        echo ""
        echo "COMPLIANCE FAILED: Denied licenses found."
        # Exit 1 signals denied licenses — set flag, don't exit inside subshell
        return 1
    else
        echo ""
        echo "COMPLIANCE PASSED: No denied licenses found."
        return 0
    fi
}

list_deps() {
    local manifest="$1"
    echo "Dependencies in $(basename "$manifest"):"
    while IFS=" " read -r name version; do
        [[ -z "$name" ]] && continue
        printf "  %-30s %s\n" "$name" "$version"
    done < <(parse_manifest "$manifest")
}

# ── Main ───────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"
    require_jq

    case "$MODE" in
        report)
            if ! generate_report "$MANIFEST" "$LICENSE_CONFIG"; then
                exit 1
            fi
            ;;
        list-deps)
            list_deps "$MANIFEST"
            ;;
    esac
}

main "$@"
