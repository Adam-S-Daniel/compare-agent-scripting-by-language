#!/usr/bin/env bash
# Dependency License Checker
#
# Parses a dependency manifest (package.json or requirements.txt), looks up
# each package's license from a mock database, checks it against allow/deny
# lists in a config file, and prints a compliance report.
#
# Usage:
#   license_checker.sh --manifest <file> --config <file> --license-db <file>
#
# Output lines:
#   [LICENSE-CHECK] <pkg>@<ver>: <license> -> <APPROVED|DENIED|UNKNOWN>
#   [SUMMARY] approved=N denied=N unknown=N
#   [RESULT] PASSED|FAILED: ...
#
# Exit code: 0 = all packages approved/unknown, 1 = at least one DENIED

set -euo pipefail

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

MANIFEST=""
CONFIG=""
LICENSE_DB=""

usage() {
    echo "Usage: $0 --manifest <file> --config <file> --license-db <file>" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manifest)   MANIFEST="${2}";   shift 2 ;;
        --config)     CONFIG="${2}";     shift 2 ;;
        --license-db) LICENSE_DB="${2}"; shift 2 ;;
        -h|--help)    usage ;;
        *)
            echo "Error: Unknown argument: ${1}" >&2
            usage
            ;;
    esac
done

# Validate all required flags are present
if [[ -z "${MANIFEST}" ]]; then
    echo "Error: --manifest is required" >&2
    usage
fi
if [[ -z "${CONFIG}" ]]; then
    echo "Error: --config is required" >&2
    usage
fi
if [[ -z "${LICENSE_DB}" ]]; then
    echo "Error: --license-db is required" >&2
    usage
fi

# Validate files exist
if [[ ! -f "${MANIFEST}" ]]; then
    echo "Error: Manifest not found: ${MANIFEST}" >&2
    exit 1
fi
if [[ ! -f "${CONFIG}" ]]; then
    echo "Error: Config not found: ${CONFIG}" >&2
    exit 1
fi
if [[ ! -f "${LICENSE_DB}" ]]; then
    echo "Error: License DB not found: ${LICENSE_DB}" >&2
    exit 1
fi

# Verify jq is available (required for JSON parsing)
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is required but not installed" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Dependency extraction
# ---------------------------------------------------------------------------

# Extract "name version" pairs from a package.json file.
# Merges dependencies and devDependencies; strips common version prefixes.
extract_package_json() {
    local manifest="${1}"
    jq -r '
        [(.dependencies // {}), (.devDependencies // {})] |
        add // {} |
        to_entries[] |
        "\(.key) \(
            .value |
            ltrimstr("^") | ltrimstr("~") |
            ltrimstr(">=") | ltrimstr(">") |
            ltrimstr("<=") | ltrimstr("<")
        )"
    ' "${manifest}"
}

# Extract "name version" pairs from a requirements.txt file.
# Supports name==version format; comments and blank lines are skipped.
extract_requirements_txt() {
    local manifest="${1}"
    while IFS= read -r line || [[ -n "${line}" ]]; do
        # Skip comment lines and blank lines
        [[ "${line}" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line//[[:space:]]/}" ]] && continue

        # Extract package name (everything before any version specifier)
        local name
        name="$(echo "${line}" | sed -E 's/[><=!~].*//' | tr -d '[:space:]' | cut -d'[' -f1)"
        [[ -z "${name}" ]] && continue

        # Extract exact version from == specifier, fall back to "unknown"
        local version
        if [[ "${line}" =~ ==([^,[:space:]]+) ]]; then
            version="${BASH_REMATCH[1]}"
        else
            version="unknown"
        fi

        echo "${name} ${version}"
    done < "${manifest}"
}

# Dispatch to the correct extractor based on the manifest filename.
extract_deps() {
    local manifest="${1}"
    local basename
    basename="$(basename "${manifest}")"

    case "${basename}" in
        package.json)
            extract_package_json "${manifest}"
            ;;
        requirements.txt)
            extract_requirements_txt "${manifest}"
            ;;
        *)
            echo "Error: Unsupported manifest type: ${basename}" >&2
            echo "Supported types: package.json, requirements.txt" >&2
            exit 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# License lookup and status classification
# ---------------------------------------------------------------------------

# Look up a package's license from the mock license database.
# Returns "UNKNOWN" if the package is not in the database.
lookup_license() {
    local pkg="${1}"
    jq -r --arg pkg "${pkg}" '.[$pkg] // "UNKNOWN"' "${LICENSE_DB}"
}

# Classify a license string as APPROVED, DENIED, or UNKNOWN based on the
# allow/deny lists in the config file.
check_status() {
    local license="${1}"

    if [[ "${license}" == "UNKNOWN" ]]; then
        echo "UNKNOWN"
        return
    fi

    # Check allow list first
    if jq -e --arg lic "${license}" '.allow | any(. == $lic)' "${CONFIG}" > /dev/null 2>&1; then
        echo "APPROVED"
        return
    fi

    # Check deny list
    if jq -e --arg lic "${license}" '.deny | any(. == $lic)' "${CONFIG}" > /dev/null 2>&1; then
        echo "DENIED"
        return
    fi

    # Not in either list — treat as unknown
    echo "UNKNOWN"
}

# ---------------------------------------------------------------------------
# Main report generation
# ---------------------------------------------------------------------------

main() {
    local approved=0 denied=0 unknown=0

    echo "DEPENDENCY LICENSE COMPLIANCE REPORT"
    echo "====================================="
    echo "Manifest:   ${MANIFEST}"
    echo "Config:     ${CONFIG}"
    echo "License DB: ${LICENSE_DB}"
    echo ""

    # Process each dependency extracted from the manifest
    while IFS=' ' read -r pkg version; do
        [[ -z "${pkg}" ]] && continue

        local license status
        license="$(lookup_license "${pkg}")"
        status="$(check_status "${license}")"

        echo "[LICENSE-CHECK] ${pkg}@${version}: ${license} -> ${status}"

        case "${status}" in
            APPROVED) approved=$(( approved + 1 )) ;;
            DENIED)   denied=$(( denied + 1 ))     ;;
            UNKNOWN)  unknown=$(( unknown + 1 ))   ;;
        esac
    done < <(extract_deps "${MANIFEST}")

    echo ""
    echo "[SUMMARY] approved=${approved} denied=${denied} unknown=${unknown}"

    if [[ "${denied}" -gt 0 ]]; then
        echo "[RESULT] FAILED: ${denied} denied license(s) found"
        return 1
    else
        echo "[RESULT] PASSED: No denied licenses found"
        return 0
    fi
}

main
