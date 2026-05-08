#!/usr/bin/env bash
# check-licenses.sh — Parse a dependency manifest, resolve each dependency's
# license via a mock license DB, and classify it against an allow/deny policy.
#
# Usage: check-licenses.sh <manifest> <config>
#   <manifest>  package.json or requirements.txt
#   <config>    file with ALLOW=… and DENY=… lines (comma-separated SPDX IDs)
#
# Env:
#   LICENSE_DB  path to a "name=spdx" file used as the license source. Defaults
#               to ./licenses.db. Keeping the lookup mockable here is what
#               makes the script unit-testable without a network registry.
#
# Exit status:
#   0  all dependencies APPROVED
#   2  any DENIED or UNKNOWN dependency (compliance failure)
#   1  usage / IO error

set -euo pipefail

usage() {
    cat >&2 <<'EOF'
Usage: check-licenses.sh <manifest> <config>
  <manifest>  package.json or requirements.txt
  <config>    file containing ALLOW=... and DENY=... lines
EOF
}

die() { echo "error: $*" >&2; exit 1; }

# --- Argument parsing --------------------------------------------------------

if [ "$#" -ne 2 ]; then
    usage
    exit 1
fi

manifest=$1
config=$2

[ -f "$manifest" ] || die "manifest not found: $manifest"
[ -f "$config" ]   || die "config not found: $config"

LICENSE_DB=${LICENSE_DB:-./licenses.db}
[ -f "$LICENSE_DB" ] || die "license DB not found: $LICENSE_DB (set LICENSE_DB)"

# --- Load policy -------------------------------------------------------------
# The config file is intentionally a tiny KEY=VALUE format so we don't need to
# `source` arbitrary shell. Parse it line by line instead.

allow=""
deny=""
while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
        ''|\#*) continue ;;
        ALLOW=*) allow=${line#ALLOW=} ;;
        DENY=*)  deny=${line#DENY=} ;;
    esac
done < "$config"

# Returns 0 if $1 (license) appears in the comma list $2.
in_list() {
    local needle=$1 haystack=$2 IFS=','
    # shellcheck disable=SC2206  # intentional word splitting on commas
    local arr=($haystack)
    local item
    for item in "${arr[@]}"; do
        [ "$item" = "$needle" ] && return 0
    done
    return 1
}

# --- Manifest parsing --------------------------------------------------------
# parse_manifest emits one "name<TAB>version" line per dependency.
# We support package.json (deps + devDeps) and requirements.txt.

parse_package_json() {
    # Plain awk parser — avoids depending on jq inside CI containers. It
    # extracts both top-level "dependencies" and "devDependencies" blocks.
    awk '
        /"dependencies"[[:space:]]*:[[:space:]]*\{/   { in_block=1; next }
        /"devDependencies"[[:space:]]*:[[:space:]]*\{/{ in_block=1; next }
        in_block && /\}/                              { in_block=0; next }
        in_block && /"[^"]+"[[:space:]]*:[[:space:]]*"[^"]+"/ {
            # Strip the surrounding key/value quotes.
            line=$0
            # Capture name
            match(line, /"[^"]+"/); name=substr(line, RSTART+1, RLENGTH-2)
            rest=substr(line, RSTART+RLENGTH)
            # Capture version (next quoted string)
            match(rest, /"[^"]+"/); ver=substr(rest, RSTART+1, RLENGTH-2)
            # Strip leading semver operators.
            sub(/^[\^~><=!*[:space:]]+/, "", ver)
            printf "%s\t%s\n", name, ver
        }
    ' "$1"
}

parse_requirements_txt() {
    # Strip comments/blank lines, split on the first version operator.
    while IFS= read -r line || [ -n "$line" ]; do
        line=${line%%#*}
        line=${line//[[:space:]]/}
        [ -z "$line" ] && continue
        # Match name and the first version after ==, >=, <=, ~=, >, <, =
        local re='^([A-Za-z0-9_.-]+)[=~<>!]+([0-9][^,;]*)'
        if [[ "$line" =~ $re ]]; then
            printf '%s\t%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
        fi
    done < "$1"
}

parse_manifest() {
    case "$1" in
        *package.json|*.json)    parse_package_json "$1" ;;
        *requirements*.txt|*.txt) parse_requirements_txt "$1" ;;
        *) die "unsupported manifest type: $1" ;;
    esac
}

# --- License lookup (mockable) ----------------------------------------------

lookup_license() {
    local name=$1
    # Grep the mock DB. Return the value or "UNKNOWN".
    local hit
    hit=$(grep -E "^${name}=" "$LICENSE_DB" | head -n1 || true)
    if [ -n "$hit" ]; then
        printf '%s\n' "${hit#*=}"
    else
        printf 'UNKNOWN\n'
    fi
}

classify() {
    local lic=$1
    if [ "$lic" = "UNKNOWN" ]; then
        printf 'UNKNOWN\n'
    elif in_list "$lic" "$deny"; then
        printf 'DENIED\n'
    elif in_list "$lic" "$allow"; then
        printf 'APPROVED\n'
    else
        # Not on either list — treat as UNKNOWN for safety.
        printf 'UNKNOWN\n'
    fi
}

# --- Main loop ---------------------------------------------------------------

approved=0; denied=0; unknown=0

echo "Dependency License Compliance Report"
echo "manifest: $manifest"
echo "----------------------------------------"

while IFS=$'\t' read -r name version; do
    [ -z "$name" ] && continue
    lic=$(lookup_license "$name")
    status=$(classify "$lic")
    printf '%s@%s\t%s\t[%s]\n' "$name" "$version" "$lic" "$status"
    case "$status" in
        APPROVED) approved=$((approved+1)) ;;
        DENIED)   denied=$((denied+1)) ;;
        UNKNOWN)  unknown=$((unknown+1)) ;;
    esac
done < <(parse_manifest "$manifest")

echo "----------------------------------------"
echo "Summary: approved=$approved denied=$denied unknown=$unknown"

# Non-zero exit signals a CI compliance failure.
if [ "$denied" -gt 0 ] || [ "$unknown" -gt 0 ]; then
    exit 2
fi
exit 0
