#!/usr/bin/env bash
# license-check.sh - Dependency license compliance checker.
#
# Parses a requirements.txt-style manifest, looks up each dependency's license
# in a mock CSV database, and classifies it as APPROVED / DENIED / UNKNOWN
# based on configured allow and deny lists. Emits a compliance report and
# exits nonzero if any dependency is DENIED or UNKNOWN.

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") --manifest <file> --licenses <csv> --allow <file> --deny <file>

Options:
  --manifest   Path to dependency manifest (name==version per line).
  --licenses   CSV database of licenses (name,version,license). Acts as the
               mock license lookup for testing.
  --allow      Allow-list of license identifiers (one per line).
  --deny       Deny-list of license identifiers (one per line).
  -h, --help   Show this help message.
EOF
}

die() {
  echo "error: $*" >&2
  exit 2
}

MANIFEST=""
LICENSES=""
ALLOW=""
DENY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest) MANIFEST="${2:-}"; shift 2 ;;
    --licenses) LICENSES="${2:-}"; shift 2 ;;
    --allow)    ALLOW="${2:-}"; shift 2 ;;
    --deny)     DENY="${2:-}"; shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

if [[ -z "$MANIFEST" || -z "$LICENSES" || -z "$ALLOW" || -z "$DENY" ]]; then
  usage >&2
  exit 2
fi

[[ -f "$MANIFEST" ]] || die "manifest file not found: $MANIFEST"
[[ -f "$LICENSES" ]] || die "licenses database not found: $LICENSES"
[[ -f "$ALLOW" ]]    || die "allow-list not found: $ALLOW"
[[ -f "$DENY" ]]     || die "deny-list not found: $DENY"

# Mock license lookup: read `name,version` from the CSV fixture. In a real
# implementation this would query a registry; the CSV indirection keeps the
# script testable without network access.
lookup_license() {
  local name="$1" version="$2"
  awk -F',' -v n="$name" -v v="$version" \
    'NR>1 && $1==n && $2==v { print $3; found=1; exit } END { if (!found) exit 1 }' \
    "$LICENSES"
}

# Check membership of a license in a newline-delimited list file.
in_list() {
  local license="$1" list="$2"
  grep -Fxq -- "$license" "$list"
}

total=0; approved=0; denied=0; unknown=0

echo "License Compliance Report"
echo "========================="

while IFS= read -r line || [[ -n "$line" ]]; do
  # Strip surrounding whitespace, skip blanks and comments.
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" || "$line" == \#* ]] && continue

  # Expect exactly `name==version`. Reject anything else.
  if [[ ! "$line" =~ ^([A-Za-z0-9._-]+)==([A-Za-z0-9._+-]+)$ ]]; then
    die "malformed manifest entry: $line"
  fi
  name="${BASH_REMATCH[1]}"
  version="${BASH_REMATCH[2]}"

  total=$((total + 1))

  if license="$(lookup_license "$name" "$version")" && [[ -n "$license" ]]; then
    if in_list "$license" "$DENY"; then
      status="DENIED"
      denied=$((denied + 1))
    elif in_list "$license" "$ALLOW"; then
      status="APPROVED"
      approved=$((approved + 1))
    else
      status="UNKNOWN"
      unknown=$((unknown + 1))
    fi
  else
    license="UNKNOWN"
    status="UNKNOWN"
    unknown=$((unknown + 1))
  fi

  printf '%s@%s: %s - %s\n' "$name" "$version" "$license" "$status"
done < "$MANIFEST"

echo "-------------------------"
echo "Total: $total"
echo "Approved: $approved"
echo "Denied: $denied"
echo "Unknown: $unknown"

if (( denied > 0 || unknown > 0 )); then
  exit 1
fi
exit 0
