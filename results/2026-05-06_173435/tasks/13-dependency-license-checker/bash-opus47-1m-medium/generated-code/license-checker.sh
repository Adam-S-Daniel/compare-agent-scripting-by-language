#!/usr/bin/env bash
# license-checker.sh
#
# Parses a dependency manifest (package.json or requirements.txt),
# looks up each dependency's license, classifies it against an
# allow/deny config, and prints a compliance report.
#
# License lookup is mocked via a TSV file pointed at by the
# LICENSE_LOOKUP_FILE environment variable (one "name<TAB>license"
# per line). This keeps tests deterministic and side-effect-free.
#
# Exit codes:
#   0  all dependencies APPROVED or UNKNOWN, none DENIED
#   1  invalid usage / file not found / parse error
#   2  at least one dependency uses a DENIED license

set -uo pipefail

usage() {
    cat <<'EOF'
Usage: license-checker.sh --manifest <file> --config <file> [--output <file>]

  --manifest  Path to package.json or requirements.txt
  --config    Path to JSON config with "allow" and "deny" arrays of license IDs
  --output    Optional path to also write the report to

Environment:
  LICENSE_LOOKUP_FILE  Path to a TSV mock of name<TAB>license rows

Exit code 2 if any dependency uses a denied license.
EOF
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

# Parse CLI args.
manifest=""
config=""
output=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --manifest) manifest="${2:-}"; shift 2 ;;
        --config)   config="${2:-}";   shift 2 ;;
        --output)   output="${2:-}";   shift 2 ;;
        -h|--help)  usage; exit 0 ;;
        *) usage >&2; exit 1 ;;
    esac
done

if [[ -z "$manifest" || -z "$config" ]]; then
    usage >&2
    exit 1
fi

[[ -f "$manifest" ]] || die "manifest file not found: $manifest"
[[ -f "$config"   ]] || die "config file not found: $config"

# Extract dependency names from the manifest. We only need names —
# version strings are ignored for license lookup purposes.
extract_deps() {
    local file="$1"
    case "$file" in
        *package.json)
            # Pull keys from "dependencies" and "devDependencies".
            # Use a forgiving sed/awk pipeline so we don't require jq.
            awk '
                /"(dependencies|devDependencies)"[[:space:]]*:[[:space:]]*\{/ { in_block=1; next }
                in_block && /\}/ { in_block=0; next }
                in_block {
                    if (match($0, /"[^"]+"[[:space:]]*:/)) {
                        s = substr($0, RSTART+1, RLENGTH-3)
                        print s
                    }
                }
            ' "$file"
            ;;
        *requirements.txt)
            # Strip comments, blank lines, and version specifiers.
            sed -e 's/#.*//' "$file" \
                | awk 'NF' \
                | sed -E 's/[[:space:]]*([<>=!~]=?|===).*$//' \
                | awk 'NF'
            ;;
        *)
            die "unsupported manifest type: $file"
            ;;
    esac
}

# Parse allow/deny arrays from the config JSON. Forgiving parser.
read_array_from_config() {
    local key="$1" file="$2"
    awk -v key="$key" '
        BEGIN { found=0 }
        {
            if (match($0, "\"" key "\"[[:space:]]*:[[:space:]]*\\[")) {
                rest = substr($0, RSTART+RLENGTH-1)
                # Greedy capture until the closing bracket, possibly multi-line.
                buf = rest
                while (index(buf, "]") == 0) {
                    if ((getline line) <= 0) break
                    buf = buf line
                }
                end = index(buf, "]")
                inner = substr(buf, 2, end-2)
                n = split(inner, parts, ",")
                for (i=1; i<=n; i++) {
                    p = parts[i]
                    gsub(/[[:space:]"]/, "", p)
                    if (p != "") print p
                }
                found=1
                exit
            }
        }
    ' "$file"
}

lookup_license() {
    local name="$1"
    if [[ -n "${LICENSE_LOOKUP_FILE:-}" && -f "$LICENSE_LOOKUP_FILE" ]]; then
        awk -F'\t' -v n="$name" '$1==n { print $2; found=1; exit } END { if (!found) exit 1 }' "$LICENSE_LOOKUP_FILE"
        return $?
    fi
    return 1
}

classify() {
    # $1 license, $2 allow-list (newline), $3 deny-list (newline)
    local lic="$1" allow="$2" deny="$3"
    if [[ -z "$lic" ]]; then
        echo "UNKNOWN"; return
    fi
    if grep -qxF -- "$lic" <<<"$deny"; then
        echo "DENIED"; return
    fi
    if grep -qxF -- "$lic" <<<"$allow"; then
        echo "APPROVED"; return
    fi
    echo "UNKNOWN"
}

main() {
    local allow deny
    allow="$(read_array_from_config allow "$config")"
    deny="$(read_array_from_config deny  "$config")"

    local deps
    deps="$(extract_deps "$manifest")"
    if [[ -z "$deps" ]]; then
        die "no dependencies found in $manifest"
    fi

    local approved=0 denied=0 unknown=0
    local report=""
    report+=$'Dependency License Compliance Report\n'
    report+=$'====================================\n'
    report+="$(printf '%-30s %-20s %s\n' "PACKAGE" "LICENSE" "STATUS")"$'\n'

    while IFS= read -r dep; do
        [[ -z "$dep" ]] && continue
        local lic status
        if lic="$(lookup_license "$dep")"; then
            :
        else
            lic=""
        fi
        status="$(classify "$lic" "$allow" "$deny")"
        case "$status" in
            APPROVED) approved=$((approved+1)) ;;
            DENIED)   denied=$((denied+1)) ;;
            UNKNOWN)  unknown=$((unknown+1)) ;;
        esac
        report+="$(printf '%-30s %-20s %s\n' "$dep" "${lic:-?}" "$status")"$'\n'
    done <<< "$deps"

    report+=$'------------------------------------\n'
    report+="Summary: approved=${approved} denied=${denied} unknown=${unknown}"$'\n'

    printf '%s' "$report"
    if [[ -n "$output" ]]; then
        printf '%s' "$report" > "$output"
    fi

    if (( denied > 0 )); then
        return 2
    fi
    return 0
}

main
