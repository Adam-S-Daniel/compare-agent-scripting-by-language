#!/usr/bin/env bash
# license_checker.sh — Dependency License Compliance Checker
#
# Parses dependency manifests (package.json, requirements.txt), looks up
# each dependency's license from a mock database, checks against configured
# allow/deny lists, and generates a compliance report.
#
# Usage:
#   ./license_checker.sh --manifest <path> --config <path> --mock-db <path>
#
# Exit codes:
#   0  All licenses are approved (or unknown — no denied)
#   1  Error (missing files, unsupported format, parse failure)
#   2  One or more licenses are denied

set -euo pipefail

readonly SCRIPT_NAME="${0##*/}"

# ANSI color codes — only used when stdout is a terminal
if [ -t 1 ]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    NC=$'\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME --manifest <path> --config <path> --mock-db <path>

Parse a dependency manifest and check each license against allow/deny lists.

Options:
  --manifest <path>  Dependency manifest (package.json or requirements.txt)
  --config <path>    License config JSON with "allow" and "deny" arrays
  --mock-db <path>   Mock license database JSON (package name -> license)
  --help             Show this help message

Exit codes:
  0  All licenses approved (none denied)
  1  Error (missing files, parse failures)
  2  One or more licenses denied
EOF
    exit 0
}

die() {
    # Print error to stderr and exit 1
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

parse_args() {
    # Initialise globals used by the rest of the script
    MANIFEST=''
    CONFIG=''
    MOCK_DB=''

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --manifest)
                [[ $# -ge 2 ]] || die "Option --manifest requires an argument"
                MANIFEST="$2"
                shift 2
                ;;
            --config)
                [[ $# -ge 2 ]] || die "Option --config requires an argument"
                CONFIG="$2"
                shift 2
                ;;
            --mock-db)
                [[ $# -ge 2 ]] || die "Option --mock-db requires an argument"
                MOCK_DB="$2"
                shift 2
                ;;
            --help | -h)
                usage
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    [[ -n "$MANIFEST" ]] || die "Missing required option: --manifest"
    [[ -n "$CONFIG"   ]] || die "Missing required option: --config"
    [[ -n "$MOCK_DB"  ]] || die "Missing required option: --mock-db"
}

validate_files() {
    [[ -f "$MANIFEST" ]] || die "Manifest file not found: $MANIFEST"
    [[ -f "$CONFIG"   ]] || die "Config file not found: $CONFIG"
    [[ -f "$MOCK_DB"  ]] || die "Mock database file not found: $MOCK_DB"
}

# ---------------------------------------------------------------------------
# Manifest parsers — each outputs "name version" pairs, one per line
# ---------------------------------------------------------------------------

parse_package_json() {
    # Merges dependencies + devDependencies and strips version prefix chars
    # (^, ~, >=, >, <=, <, =) using jq's ltrimstr chaining.
    local manifest="$1"
    jq -r '
        [(.dependencies // {}), (.devDependencies // {})] |
        add // {} |
        to_entries[] |
        .key + " " + (
            .value |
            ltrimstr("^") | ltrimstr("~") |
            ltrimstr(">=") | ltrimstr(">") |
            ltrimstr("<=") | ltrimstr("<") |
            ltrimstr("=")
        )
    ' "$manifest"
}

parse_requirements_txt() {
    # Parses lines of the form: name[operator]version
    # Handles ==, >=, <=, !=, ~=, >, < operators.
    # Skips comment lines and blank lines.
    local manifest="$1"
    local line name version

    while IFS= read -r line; do
        # Skip empty lines and comment lines
        [[ -z "$line" || "$line" == \#* ]] && continue

        # Strip inline comments, then trim trailing whitespace
        line="${line%%#*}"
        line="${line%"${line##*[! ]}"}"
        [[ -z "$line" ]] && continue

        # Match: name followed by a comparison operator and a version.
        # Store regex in a variable — bash parses < and > as operators when
        # they appear literally in [[ =~ ]], so a variable avoids that issue.
        local re_versioned='^([a-zA-Z0-9_.-]+)[[:space:]]*[><=~!]+=?[[:space:]]*([0-9][^[:space:]]*)$'
        local re_bare='^([a-zA-Z0-9_.-]+)$'
        if [[ "$line" =~ $re_versioned ]]; then
            name="${BASH_REMATCH[1]}"
            version="${BASH_REMATCH[2]}"
        elif [[ "$line" =~ $re_bare ]]; then
            # Package with no version constraint
            name="${BASH_REMATCH[1]}"
            version="unspecified"
        else
            # Skip lines that don't match known formats (URLs, extras, etc.)
            continue
        fi

        printf '%s %s\n' "$name" "$version"
    done < "$manifest"
}

parse_manifest() {
    # Auto-detect format by file extension and name.
    # Any *.json file is treated as a package.json-style manifest.
    # requirements.txt and requirements_*.txt are treated as pip manifests.
    local manifest="$1"
    local basename="${manifest##*/}"

    case "$basename" in
        requirements.txt | requirements_*.txt)
            parse_requirements_txt "$manifest"
            ;;
        *.json)
            parse_package_json "$manifest"
            ;;
        *)
            die "Unsupported manifest format: $basename (supported: *.json, requirements.txt)"
            ;;
    esac
}

# ---------------------------------------------------------------------------
# License lookup and classification
# ---------------------------------------------------------------------------

lookup_license() {
    # Query the mock database for a package's license.
    # Outputs the license string, or empty string if the package is unknown.
    local package="$1"
    local mock_db="$2"
    # jq --arg safely passes the package name; // empty suppresses "null" output
    jq -r --arg pkg "$package" '.[$pkg] // empty' "$mock_db"
}

check_license() {
    # Classify a license string against the allow/deny config.
    # Outputs: APPROVED, DENIED, or UNKNOWN
    local license="$1"
    local config="$2"

    if [[ -z "$license" ]]; then
        printf 'UNKNOWN\n'
        return
    fi

    local result
    result=$(jq -r --arg lic "$license" '
        if ((.deny  // []) | contains([$lic])) then "DENIED"
        elif ((.allow // []) | contains([$lic])) then "APPROVED"
        else "UNKNOWN"
        end
    ' "$config")
    printf '%s\n' "$result"
}

# ---------------------------------------------------------------------------
# Report generator
# ---------------------------------------------------------------------------

generate_report() {
    # Iterates over parsed dependencies, looks up each license, classifies it,
    # and prints a formatted compliance table plus a summary line.
    # Returns 0 if no licenses are denied, 2 if any are denied.
    local manifest="$1"
    local config="$2"
    local mock_db="$3"

    local total=0 approved=0 denied=0 unknown=0
    local has_denied=false

    # Parse manifest via command substitution BEFORE the loop so that any
    # error inside parse_manifest (e.g. die()) propagates to the caller with
    # set -e.  Using <<< (herestring) keeps the while loop in the current
    # shell so that counter and has_denied updates are visible after the loop.
    local deps
    # Explicit || die needed because set -e is suppressed inside functions
    # that are called as the left-hand side of a || expression (bash rule).
    deps=$(parse_manifest "$manifest") || die "Failed to parse manifest: $manifest"

    printf 'DEPENDENCY LICENSE COMPLIANCE REPORT\n'
    printf '=====================================\n'
    printf '%-35s %-20s %s\n' 'DEPENDENCY' 'LICENSE' 'STATUS'
    printf '%-35s %-20s %s\n' '---------' '-------' '------'

    while IFS=' ' read -r name version; do
        local license status colored_status dep_label display_license

        license=$(lookup_license "$name" "$mock_db")
        status=$(check_license "$license" "$config")

        display_license="${license:-UNKNOWN}"
        dep_label="${name}@${version}"

        case "$status" in
            APPROVED)
                colored_status="${GREEN}${status}${NC}"
                approved=$((approved + 1))
                ;;
            DENIED)
                colored_status="${RED}${status}${NC}"
                denied=$((denied + 1))
                has_denied=true
                ;;
            UNKNOWN)
                colored_status="${YELLOW}${status}${NC}"
                unknown=$((unknown + 1))
                ;;
            *)
                colored_status="$status"
                ;;
        esac

        printf '%-35s %-20s %s\n' "$dep_label" "$display_license" "$colored_status"
        total=$((total + 1))
    done <<< "$deps"

    printf '=====================================\n'
    printf 'Total: %d | Approved: %d | Denied: %d | Unknown: %d\n' \
        "$total" "$approved" "$denied" "$unknown"

    if $has_denied; then
        printf 'Status: FAIL (denied licenses found)\n'
        return 2
    else
        printf 'Status: PASS\n'
        return 0
    fi
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

main() {
    parse_args "$@"
    validate_files
    # Propagate generate_report's exit code (0 or 2) rather than letting
    # set -e treat a non-zero return as a fatal error.
    generate_report "$MANIFEST" "$CONFIG" "$MOCK_DB" || exit $?
}

main "$@"
