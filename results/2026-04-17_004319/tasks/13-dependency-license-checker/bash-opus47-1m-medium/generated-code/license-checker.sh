#!/usr/bin/env bash
# Dependency license compliance checker.
# Parses a manifest (package.json or requirements.txt), looks up each dep's
# license from a mock DB, and classifies as approved/denied/unknown based on
# allow- and deny-lists.

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: license-checker.sh --manifest <file> [--allow <csv>] [--deny <csv>] [--db <file>]

Options:
  --manifest <file>   Path to package.json or requirements.txt
  --allow <csv>       Comma-separated allowed licenses (e.g. MIT,Apache-2.0)
  --deny <csv>        Comma-separated denied licenses (e.g. GPL-3.0)
  --db <file>         Path to license DB (CSV: name,version,license). Mock for tests.
  -h|--help           Show this help
EOF
}

manifest=""
allow_csv=""
deny_csv=""
db_file="${LICENSE_DB:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manifest) manifest="$2"; shift 2 ;;
        --allow)    allow_csv="$2"; shift 2 ;;
        --deny)     deny_csv="$2"; shift 2 ;;
        --db)       db_file="$2"; shift 2 ;;
        -h|--help)  usage; exit 0 ;;
        *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [[ -z "$manifest" ]]; then
    echo "ERROR: --manifest is required" >&2
    exit 2
fi
if [[ ! -f "$manifest" ]]; then
    echo "ERROR: manifest not found: $manifest" >&2
    exit 2
fi

# Parse the manifest into "name<TAB>version" lines on stdout.
parse_manifest() {
    local file="$1"
    local base kind
    base="$(basename "$file")"
    # Prefer filename-based detection; fall back to content sniff so that
    # alternately named JSON fixtures (e.g. all-approved.json) still parse.
    case "$base" in
        package.json|*.json) kind=package.json ;;
        requirements.txt|*.txt) kind=requirements.txt ;;
        *)
            if head -c1 "$file" | grep -q '{'; then
                kind=package.json
            else
                kind=requirements.txt
            fi
            ;;
    esac
    case "$kind" in
        package.json)
            # Extract dependencies + devDependencies as name/version pairs.
            # Avoid jq dependency: use a small awk-based parser sufficient for
            # well-formatted package.json files used in this checker.
            python3 - "$file" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
for key in ("dependencies", "devDependencies"):
    for name, ver in (data.get(key) or {}).items():
        print(f"{name}\t{ver}")
PY
            ;;
        requirements.txt)
            # Each non-empty, non-comment line: pkg==version (or pkg)
            while IFS= read -r line || [[ -n "$line" ]]; do
                line="${line%%#*}"                   # strip comments
                line="$(echo -n "$line" | tr -d '[:space:]')"
                [[ -z "$line" ]] && continue
                if [[ "$line" == *"=="* ]]; then
                    name="${line%%==*}"
                    ver="${line##*==}"
                else
                    name="$line"
                    ver=""
                fi
                printf '%s\t%s\n' "$name" "$ver"
            done < "$file"
            ;;
        *)
            echo "ERROR: unsupported manifest type: $base" >&2
            return 3
            ;;
    esac
}

# Look up license for "name version" using the mock DB CSV.
# Returns "UNKNOWN" if not present.
lookup_license() {
    local name="$1" version="$2"
    if [[ -z "$db_file" || ! -f "$db_file" ]]; then
        echo "UNKNOWN"
        return 0
    fi
    local found="UNKNOWN"
    while IFS=, read -r d_name d_ver d_lic; do
        [[ -z "$d_name" || "$d_name" == "name" ]] && continue
        if [[ "$d_name" == "$name" ]]; then
            if [[ "$d_ver" == "$version" || "$d_ver" == "*" ]]; then
                found="$d_lic"
                break
            fi
        fi
    done < "$db_file"
    echo "$found"
}

# Classify a license against allow/deny lists.
# Precedence: deny > allow > unknown.
classify() {
    local license="$1"
    local item
    if [[ "$license" == "UNKNOWN" ]]; then
        echo "unknown"
        return 0
    fi
    IFS=',' read -ra deny_arr <<< "$deny_csv"
    for item in "${deny_arr[@]}"; do
        [[ -z "$item" ]] && continue
        if [[ "$item" == "$license" ]]; then
            echo "denied"
            return 0
        fi
    done
    IFS=',' read -ra allow_arr <<< "$allow_csv"
    for item in "${allow_arr[@]}"; do
        [[ -z "$item" ]] && continue
        if [[ "$item" == "$license" ]]; then
            echo "approved"
            return 0
        fi
    done
    echo "unknown"
}

main() {
    local denied_count=0
    echo "Dependency License Compliance Report"
    echo "===================================="
    printf '%-30s %-15s %-15s %s\n' "NAME" "VERSION" "LICENSE" "STATUS"
    while IFS=$'\t' read -r name version; do
        [[ -z "$name" ]] && continue
        license="$(lookup_license "$name" "$version")"
        status="$(classify "$license")"
        printf '%-30s %-15s %-15s %s\n' "$name" "${version:--}" "$license" "$status"
        if [[ "$status" == "denied" ]]; then
            denied_count=$((denied_count + 1))
        fi
    done < <(parse_manifest "$manifest")
    echo "===================================="
    echo "Denied dependencies: $denied_count"
    # Exit non-zero if any denied license is present.
    if [[ "$denied_count" -gt 0 ]]; then
        return 1
    fi
    return 0
}

main
