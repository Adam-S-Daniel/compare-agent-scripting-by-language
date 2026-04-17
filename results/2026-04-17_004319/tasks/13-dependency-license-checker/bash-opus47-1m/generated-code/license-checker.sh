#!/usr/bin/env bash
#
# license-checker.sh
# ------------------
# Parse a dependency manifest (package.json or requirements.txt), look up
# each dependency's license in a mock license database, and report the
# compliance status against allow-list and deny-list config files.
#
# Usage:
#   license-checker.sh <manifest> <allow-list> <deny-list> <license-db>
#
# Exit codes:
#   0  -> no denied licenses found (may include APPROVED/UNKNOWN)
#   1  -> at least one DENIED license found
#   2  -> usage / IO error
#
# The license lookup is deliberately mockable: the DB is a plain TSV file
# (name@version<TAB>license). Real deployments swap it for a call to
# npm/pypi/GitHub licenses. Tests provide a controlled fixture file.

set -euo pipefail

die() {
    printf 'Error: %s\n' "$1" >&2
    exit 2
}

usage() {
    cat >&2 <<'USAGE'
Usage: license-checker.sh <manifest> <allow-list> <deny-list> <license-db>
  manifest    package.json or requirements.txt
  allow-list  newline-delimited approved license identifiers
  deny-list   newline-delimited forbidden license identifiers
  license-db  TSV of "name@version<TAB>license" lines (mock lookup)
USAGE
    exit 2
}

[[ $# -eq 4 ]] || usage

MANIFEST=$1
ALLOW=$2
DENY=$3
DB=$4

for f in "$MANIFEST" "$ALLOW" "$DENY" "$DB"; do
    [[ -r "$f" ]] || die "cannot read file: $f"
done

# -- manifest parsing ---------------------------------------------------------
# Emit "name@version" one per line on stdout. Supports two manifest formats:
#   * package.json   -> reads the top-level "dependencies" object
#   * requirements.txt -> reads "name==version" pinned entries

parse_package_json() {
    local file=$1
    local line name ver
    local in_deps=0
    while IFS= read -r line || [[ -n $line ]]; do
        if [[ $in_deps -eq 0 && $line =~ \"dependencies\"[[:space:]]*:[[:space:]]*\{ ]]; then
            in_deps=1
            continue
        fi
        if [[ $in_deps -eq 1 ]]; then
            if [[ $line =~ ^[[:space:]]*\} ]]; then
                in_deps=0
                continue
            fi
            if [[ $line =~ \"([^\"]+)\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
                name=${BASH_REMATCH[1]}
                ver=${BASH_REMATCH[2]}
                # strip common semver prefixes so lookups use exact versions
                ver=${ver#[\^~]}
                printf '%s@%s\n' "$name" "$ver"
            fi
        fi
    done < "$file"
}

parse_requirements_txt() {
    local file=$1
    local line name ver
    while IFS= read -r line || [[ -n $line ]]; do
        # trim leading/trailing whitespace
        line=${line#"${line%%[![:space:]]*}"}
        line=${line%"${line##*[![:space:]]}"}
        [[ -z $line || $line == \#* ]] && continue
        if [[ $line == *==* ]]; then
            name=${line%%==*}
            ver=${line#*==}
            # strip any post-version extras (e.g. "; python_version...")
            ver=${ver%%[[:space:];]*}
            printf '%s@%s\n' "$name" "$ver"
        fi
    done < "$file"
}

parse_manifest() {
    case $1 in
        *package.json)      parse_package_json "$1" ;;
        *requirements.txt)  parse_requirements_txt "$1" ;;
        *)                  die "unsupported manifest type: $1" ;;
    esac
}

# -- license lookup / membership ---------------------------------------------

lookup_license() {
    # Prints the license identifier for the given "name@version" key, or
    # empty string when no mapping exists. Uses literal (-F) tab-anchored
    # grep so names containing regex metacharacters are safe.
    local key=$1
    local line
    line=$(grep -F -- "$(printf '%s\t' "$key")" "$DB" || true)
    [[ -z $line ]] && { printf ''; return; }
    printf '%s' "${line#*$'\t'}"
}

# membership predicates read allow/deny files line by line; files are tiny
is_in_list() {
    local needle=$1 file=$2 item
    while IFS= read -r item || [[ -n $item ]]; do
        item=${item#"${item%%[![:space:]]*}"}
        item=${item%"${item##*[![:space:]]}"}
        [[ -z $item || $item == \#* ]] && continue
        [[ $item == "$needle" ]] && return 0
    done < "$file"
    return 1
}

# -- main --------------------------------------------------------------------

main() {
    local deps dep license status any_denied=0

    deps=$(parse_manifest "$MANIFEST")
    if [[ -z $deps ]]; then
        die "no dependencies found in manifest: $MANIFEST"
    fi

    printf 'License Compliance Report\n'
    printf '=========================\n'
    printf '%-30s %-20s %s\n' "DEPENDENCY" "LICENSE" "STATUS"
    printf -- '-------------------------------------------------------------------\n'

    while IFS= read -r dep; do
        [[ -z $dep ]] && continue
        license=$(lookup_license "$dep")
        if [[ -z $license ]]; then
            status="UNKNOWN"
            license="(not found)"
        elif is_in_list "$license" "$DENY"; then
            status="DENIED"
            any_denied=1
        elif is_in_list "$license" "$ALLOW"; then
            status="APPROVED"
        else
            status="UNKNOWN"
        fi
        printf '%-30s %-20s %s\n' "$dep" "$license" "$status"
    done <<< "$deps"

    printf -- '-------------------------------------------------------------------\n'
    if [[ $any_denied -eq 1 ]]; then
        printf 'Result: FAIL (denied licenses found)\n'
        exit 1
    fi
    printf 'Result: PASS\n'
}

main "$@"
