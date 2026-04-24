#!/usr/bin/env bash
# license-checker.sh
# Dependency License Checker
#
# Parses package.json or requirements.txt, looks up each dependency's license
# in a mock database, and generates a compliance report against allow/deny lists.

set -euo pipefail

usage() {
    cat >&2 <<'EOF'
Usage: license-checker.sh --manifest <file> --config <config.json> \
                           [--mock-db <db.json>] [--strict]

Options:
  --manifest  Path to dependency manifest (package.json or requirements.txt)
  --config    Path to license config JSON with "allow" and "deny" arrays
  --mock-db   Path to mock license database JSON  (name -> license string)
  --strict    Exit 1 if any denied packages are found (default: always exit 0)
EOF
    exit 1
}

# ── Argument parsing ─────────────────────────────────────────────────────────
MANIFEST=""
CONFIG=""
MOCK_DB=""
STRICT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manifest) MANIFEST="$2"; shift 2 ;;
        --config)   CONFIG="$2";   shift 2 ;;
        --mock-db)  MOCK_DB="$2";  shift 2 ;;
        --strict)   STRICT=true;   shift   ;;
        -h|--help)  usage ;;
        *)  echo "Error: unknown option: $1" >&2; usage ;;
    esac
done

# ── Validation ───────────────────────────────────────────────────────────────
if [[ -z "$MANIFEST" || -z "$CONFIG" ]]; then
    echo "Error: --manifest and --config are required" >&2
    usage
fi

if [[ ! -f "$MANIFEST" ]]; then
    echo "Error: manifest file not found: $MANIFEST" >&2
    exit 1
fi

if [[ ! -f "$CONFIG" ]]; then
    echo "Error: config file not found: $CONFIG" >&2
    exit 1
fi

# ── Manifest parsers ─────────────────────────────────────────────────────────

# Emit lines of "name\tversion" from package.json
# Merges dependencies, devDependencies, and peerDependencies.
parse_package_json() {
    local manifest="$1"
    jq -r '
      [
        (.dependencies       // {}),
        (.devDependencies    // {}),
        (.peerDependencies   // {})
      ]
      | add
      | to_entries[]
      | [
          .key,
          # strip leading semver range operators (^, ~, >=, >, <=, <, =)
          (.value | ltrimstr("^") | ltrimstr("~")
                  | ltrimstr(">=") | ltrimstr(">")
                  | ltrimstr("<=") | ltrimstr("<")
                  | ltrimstr("=")
                  | split(" ")[0])
        ]
      | @tsv
    ' "$manifest"
}

# Emit lines of "name\tversion" from requirements.txt (pip format)
parse_requirements_txt() {
    local manifest="$1"
    while IFS= read -r line; do
        # Skip comments and blank lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]]           && continue

        # pkg==ver, pkg>=ver, pkg~=ver, pkg!=ver, just pkg
        # Regex must be in a variable to avoid bash parser issues with special chars
        local req_re='^([A-Za-z0-9_.-]+)[=><~!]+([^[:space:]]+)'
        if [[ "$line" =~ $req_re ]]; then
            printf '%s\t%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
        else
            printf '%s\tunknown\n' "${line%% *}"
        fi
    done < "$manifest"
}

# ── License lookup (mock database) ───────────────────────────────────────────

# Return the license string for a package, or "" if not found.
lookup_license() {
    local pkg="$1"
    if [[ -z "$MOCK_DB" || ! -f "$MOCK_DB" ]]; then
        echo ""
        return
    fi
    jq -r --arg pkg "$pkg" '.[$pkg] // ""' "$MOCK_DB"
}

# ── Compliance check ─────────────────────────────────────────────────────────

# Return "approved", "denied", or "unknown" for a given license string.
check_license_status() {
    local license="$1"
    if [[ -z "$license" ]]; then
        echo "unknown"
        return
    fi

    # Check allow list first
    if jq -e --arg lic "$license" '.allow | index($lic) != null' "$CONFIG" > /dev/null 2>&1; then
        echo "approved"
        return
    fi

    # Check deny list
    if jq -e --arg lic "$license" '.deny | index($lic) != null' "$CONFIG" > /dev/null 2>&1; then
        echo "denied"
        return
    fi

    echo "unknown"
}

# ── Parse manifest ────────────────────────────────────────────────────────────
DEPS_FILE=$(mktemp)
# shellcheck disable=SC2064
trap "rm -f '$DEPS_FILE'" EXIT

MANIFEST_BASE="$(basename "$MANIFEST")"
case "$MANIFEST_BASE" in
    *.json)
        parse_package_json "$MANIFEST" > "$DEPS_FILE"
        ;;
    requirements.txt|*.txt)
        parse_requirements_txt "$MANIFEST" > "$DEPS_FILE"
        ;;
    *)
        echo "Error: unsupported manifest format: $MANIFEST_BASE" >&2
        exit 1
        ;;
esac

# ── Build report ─────────────────────────────────────────────────────────────
APPROVED=()
DENIED=()
UNKNOWN=()

while IFS=$'\t' read -r pkg ver; do
    [[ -z "$pkg" ]] && continue
    license=$(lookup_license "$pkg")
    status=$(check_license_status "$license")

    case "$status" in
        approved) APPROVED+=("  $pkg $ver - $license") ;;
        denied)   DENIED+=(  "  $pkg $ver - $license") ;;
        unknown)  UNKNOWN+=(  "  $pkg $ver - (no license data)") ;;
    esac
done < "$DEPS_FILE"

# ── Print report ─────────────────────────────────────────────────────────────
echo "=== Dependency License Compliance Report ==="
echo "Manifest: $MANIFEST"
echo "Config:   $CONFIG"
echo ""

if [[ ${#APPROVED[@]} -gt 0 ]]; then
    echo "APPROVED:"
    printf '%s\n' "${APPROVED[@]}"
    echo ""
fi

if [[ ${#DENIED[@]} -gt 0 ]]; then
    echo "DENIED:"
    printf '%s\n' "${DENIED[@]}"
    echo ""
fi

if [[ ${#UNKNOWN[@]} -gt 0 ]]; then
    echo "UNKNOWN:"
    printf '%s\n' "${UNKNOWN[@]}"
    echo ""
fi

echo "Summary: ${#APPROVED[@]} approved, ${#DENIED[@]} denied, ${#UNKNOWN[@]} unknown"

# Strict mode: exit 1 when denied packages are present
if $STRICT && [[ ${#DENIED[@]} -gt 0 ]]; then
    exit 1
fi
