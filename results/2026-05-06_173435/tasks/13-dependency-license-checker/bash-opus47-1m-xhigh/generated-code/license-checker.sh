#!/usr/bin/env bash
# Dependency license compliance checker.
#
# Reads a dependency manifest, looks up each dependency's license against a
# mock license database, and reports whether each license is on the allow-list,
# deny-list, or unknown.
#
# Usage:
#   license-checker.sh --manifest <file> --config <file> --mock <file> [--output <file>]
#
# Manifest formats supported (auto-detected by file extension):
#   *.json            -> package.json with dependencies / devDependencies (jq required)
#   anything else     -> requirements.txt-style (one "name==version" per line;
#                        bare "name" lines accepted with version="*"; comments
#                        starting with '#' and blank lines ignored)
#
# Config file format (shell-style key=value):
#   ALLOW=MIT,Apache-2.0,BSD-3-Clause,ISC
#   DENY=GPL-3.0,GPL-2.0,AGPL-3.0
#
# Mock license database: one "name=license" line per dependency.
# Comments (#) and blank lines are ignored. Names not present are reported
# with license "UNKNOWN".
#
# Output: a plain-text compliance report on stdout (or --output).
# Exit codes:
#   0 - all dependencies approved
#   1 - at least one denied license present
#   2 - at least one unknown license, but no denied licenses
#   3 - usage / IO error

set -euo pipefail

# --- error helper -----------------------------------------------------------
# Prints message to stderr with the program name prefix.
err() {
    printf 'license-checker: %s\n' "$*" >&2
}

usage() {
    cat <<'EOF' >&2
Usage: license-checker.sh --manifest <file> --config <file> --mock <file> [--output <file>]
EOF
}

# --- argument parsing -------------------------------------------------------
manifest=""
config=""
mock=""
output=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manifest) manifest="${2:-}"; shift 2 ;;
        --config)   config="${2:-}";   shift 2 ;;
        --mock)     mock="${2:-}";     shift 2 ;;
        --output)   output="${2:-}";   shift 2 ;;
        -h|--help)  usage; exit 0 ;;
        *)
            err "unknown argument: $1"
            usage
            exit 3
            ;;
    esac
done

if [[ -z "$manifest" || -z "$config" || -z "$mock" ]]; then
    err "missing required argument(s)"
    usage
    exit 3
fi

for f in "$manifest" "$config" "$mock"; do
    if [[ ! -f "$f" ]]; then
        err "file not found: $f"
        exit 3
    fi
done

# --- load config ------------------------------------------------------------
# Read ALLOW=... and DENY=... lines, ignoring blanks and # comments.
ALLOW_LIST=""
DENY_LIST=""
while IFS= read -r line || [[ -n "$line" ]]; do
    # Strip leading/trailing whitespace and skip blanks/comments.
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    case "$line" in
        ALLOW=*) ALLOW_LIST="${line#ALLOW=}" ;;
        DENY=*)  DENY_LIST="${line#DENY=}"   ;;
        *) err "ignoring unrecognised config line: $line" ;;
    esac
done < "$config"

# Helper: returns 0 if $1 (license) is in comma-list $2.
license_in_list() {
    local license="$1" list="$2" item
    [[ -z "$list" ]] && return 1
    IFS=',' read -ra parts <<< "$list"
    for item in "${parts[@]}"; do
        # Trim whitespace.
        item="${item#"${item%%[![:space:]]*}"}"
        item="${item%"${item##*[![:space:]]}"}"
        [[ "$item" == "$license" ]] && return 0
    done
    return 1
}

# --- load mock license database into associative array ---------------------
declare -A LICENSES
while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$line" != *=* ]]; then
        err "ignoring malformed mock line: $line"
        continue
    fi
    name="${line%%=*}"
    license="${line#*=}"
    LICENSES["$name"]="$license"
done < "$mock"

# Mock license lookup: prints license string for a dep name, or "UNKNOWN".
lookup_license() {
    local name="$1"
    if [[ -n "${LICENSES[$name]+x}" ]]; then
        printf '%s\n' "${LICENSES[$name]}"
    else
        printf 'UNKNOWN\n'
    fi
}

# --- parse manifest ---------------------------------------------------------
# Emits "name<TAB>version" lines on stdout.
parse_manifest() {
    local path="$1"
    case "$path" in
        *.json)
            command -v jq >/dev/null 2>&1 || {
                err "jq is required to parse JSON manifests"
                exit 3
            }
            # Combine dependencies and devDependencies; strip ^/~ prefixes from versions.
            jq -r '
                ((.dependencies // {}) + (.devDependencies // {}))
                | to_entries[]
                | "\(.key)\t\(.value | sub("^[\\^~]"; ""))"
            ' "$path"
            ;;
        *)
            # requirements.txt-style: name==version, or just name.
            while IFS= read -r line || [[ -n "$line" ]]; do
                line="${line#"${line%%[![:space:]]*}"}"
                line="${line%"${line##*[![:space:]]}"}"
                [[ -z "$line" || "$line" == \#* ]] && continue
                if [[ "$line" == *==* ]]; then
                    name="${line%%==*}"
                    version="${line#*==}"
                else
                    name="$line"
                    version="*"
                fi
                printf '%s\t%s\n' "$name" "$version"
            done < "$path"
            ;;
    esac
}

# --- generate report --------------------------------------------------------
# Build the report into a temporary buffer first so we can compute the summary
# before printing.
total=0
approved=0
denied=0
unknown=0
report_lines=()

while IFS=$'\t' read -r name version; do
    [[ -z "$name" ]] && continue
    total=$((total + 1))
    license="$(lookup_license "$name")"
    if [[ "$license" == "UNKNOWN" ]]; then
        status="UNKNOWN"
        unknown=$((unknown + 1))
    elif license_in_list "$license" "$DENY_LIST"; then
        status="DENIED"
        denied=$((denied + 1))
    elif license_in_list "$license" "$ALLOW_LIST"; then
        status="APPROVED"
        approved=$((approved + 1))
    else
        # Not on either list: treat as unknown for compliance purposes.
        status="UNKNOWN"
        unknown=$((unknown + 1))
    fi
    report_lines+=("${name}@${version} | ${license} | ${status}")
done < <(parse_manifest "$manifest")

if (( denied > 0 )); then
    overall="FAIL"
elif (( unknown > 0 )); then
    overall="WARN"
else
    overall="PASS"
fi

emit_report() {
    echo "DEPENDENCY LICENSE COMPLIANCE REPORT"
    echo "===================================="
    local line
    for line in "${report_lines[@]}"; do
        echo "$line"
    done
    echo "===================================="
    echo "SUMMARY: total=${total} approved=${approved} denied=${denied} unknown=${unknown}"
    echo "STATUS: ${overall}"
}

if [[ -n "$output" ]]; then
    emit_report > "$output"
else
    emit_report
fi

# Exit code reflects compliance status.
case "$overall" in
    PASS) exit 0 ;;
    FAIL) exit 1 ;;
    WARN) exit 2 ;;
esac
