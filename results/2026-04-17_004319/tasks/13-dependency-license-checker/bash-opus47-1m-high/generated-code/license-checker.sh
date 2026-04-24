#!/usr/bin/env bash
# license-checker.sh
#
# Parses a dependency manifest (package.json or requirements.txt), resolves
# each dependency's SPDX license via a pluggable lookup command, classifies
# the license against allow/deny lists, and prints a compliance report.
#
# Usage:
#   license-checker.sh MANIFEST CONFIG [LOOKUP_CMD]
#
# Arguments:
#   MANIFEST    Path to package.json or requirements.txt.
#   CONFIG      Path to a JSON config with "allow" and "deny" arrays of
#               SPDX license identifiers.
#   LOOKUP_CMD  Optional. A command that, given a dep name on stdin or as
#               its first argument, prints an SPDX id on stdout. Defaults
#               to ./mock-license-lookup.sh. If the command prints an
#               empty string or exits non-zero the license is treated as
#               UNKNOWN.
#
# Exit codes:
#   0  all dependencies classified as APPROVED
#   1  at least one DENIED (or UNKNOWN) license encountered
#   2  usage / parse error

set -u

die() {
    printf 'license-checker: error: %s\n' "$1" >&2
    exit 2
}

# extract_deps_from_package_json FILE
# Prints one "name" per line for every key in the top-level "dependencies"
# object. Uses jq if available; falls back to a minimal sed/grep parser
# adequate for the flat, well-formed fixtures used here.
extract_deps_from_package_json() {
    local file="$1"
    if command -v jq >/dev/null 2>&1; then
        jq -r '.dependencies // {} | keys[]' "$file"
        return
    fi
    # Minimal fallback: grab the "dependencies": { ... } block and pull keys.
    awk '
        /"dependencies"[[:space:]]*:[[:space:]]*\{/ { in_deps=1; next }
        in_deps && /^[[:space:]]*\}/ { in_deps=0 }
        in_deps {
            match($0, /"[^"]+"/)
            if (RSTART > 0) {
                name = substr($0, RSTART+1, RLENGTH-2)
                print name
            }
        }
    ' "$file"
}

# extract_deps_from_requirements_txt FILE
# Prints dep names, stripping version specifiers, comments, and blank lines.
extract_deps_from_requirements_txt() {
    local file="$1"
    # Strip comments; split on common version operators; trim whitespace.
    sed -E 's/#.*$//' "$file" \
        | sed -E 's/[[:space:]]*(==|>=|<=|~=|!=|>|<).*$//' \
        | awk 'NF { gsub(/[[:space:]]/, ""); if ($0 != "") print }'
}

# extract_deps MANIFEST
# Dispatches on filename to the correct parser.
extract_deps() {
    local file="$1"
    case "$file" in
        *package.json) extract_deps_from_package_json "$file" ;;
        *requirements.txt) extract_deps_from_requirements_txt "$file" ;;
        *) die "unsupported manifest: $file" ;;
    esac
}

# classify_license LICENSE ALLOW_CSV DENY_CSV
# Echoes APPROVED, DENIED, or UNKNOWN based on membership.
# UNKNOWN licenses take precedence over allow-list presence (the license
# is literally unknown, so it can't be approved).
classify_license() {
    local license="$1" allow="$2" deny="$3"
    if [[ -z "$license" || "$license" == "UNKNOWN" ]]; then
        echo "UNKNOWN"
        return
    fi
    # Comma-delimited exact membership checks.
    if [[ ",$deny," == *",$license,"* ]]; then
        echo "DENIED"
        return
    fi
    if [[ ",$allow," == *",$license,"* ]]; then
        echo "APPROVED"
        return
    fi
    echo "UNKNOWN"
}

# load_config CONFIG_PATH -> sets CONFIG_ALLOW and CONFIG_DENY as CSVs.
load_config() {
    local path="$1"
    [[ -f "$path" ]] || die "config not found: $path"
    if command -v jq >/dev/null 2>&1; then
        CONFIG_ALLOW="$(jq -r '.allow // [] | join(",")' "$path")"
        CONFIG_DENY="$(jq -r '.deny  // [] | join(",")' "$path")"
    else
        # Minimal fallback: parse flat "allow"/"deny" arrays of strings.
        CONFIG_ALLOW="$(awk '/"allow"/,/\]/' "$path" | grep -oE '"[^"]+"' | tail -n +2 | tr -d '"' | paste -sd, -)"
        CONFIG_DENY="$(awk '/"deny"/,/\]/' "$path" | grep -oE '"[^"]+"' | tail -n +2 | tr -d '"' | paste -sd, -)"
    fi
}

# lookup_license NAME
# Calls the configured lookup command; empty/missing output becomes UNKNOWN.
lookup_license() {
    local name="$1"
    local out
    if ! out="$("$LOOKUP_CMD" "$name" 2>/dev/null)"; then
        echo "UNKNOWN"
        return
    fi
    out="${out//[[:space:]]/}"
    if [[ -z "$out" ]]; then
        echo "UNKNOWN"
    else
        echo "$out"
    fi
}

main() {
    if [[ $# -lt 2 || $# -gt 3 ]]; then
        die "usage: license-checker.sh MANIFEST CONFIG [LOOKUP_CMD]"
    fi
    local manifest="$1" config="$2"
    LOOKUP_CMD="${3:-./mock-license-lookup.sh}"
    [[ -f "$manifest" ]] || die "manifest not found: $manifest"
    [[ -x "$LOOKUP_CMD" ]] || die "lookup command not executable: $LOOKUP_CMD"

    load_config "$config"

    local approved=0 denied=0 unknown=0
    local name license status

    echo "Dependency License Compliance Report"
    echo "------------------------------------"
    echo "NAME | LICENSE | STATUS"

    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        license="$(lookup_license "$name")"
        status="$(classify_license "$license" "$CONFIG_ALLOW" "$CONFIG_DENY")"
        printf '%s | %s | %s\n' "$name" "$license" "$status"
        case "$status" in
            APPROVED) approved=$((approved + 1)) ;;
            DENIED)   denied=$((denied + 1)) ;;
            UNKNOWN)  unknown=$((unknown + 1)) ;;
        esac
    done < <(extract_deps "$manifest")

    echo "------------------------------------"
    printf 'TOTALS: approved=%d denied=%d unknown=%d\n' \
        "$approved" "$denied" "$unknown"

    # Any denied or unknown license is a non-approval; exit non-zero so
    # CI can gate on it.
    if (( denied > 0 || unknown > 0 )); then
        return 1
    fi
    return 0
}

main "$@"
