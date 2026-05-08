#!/usr/bin/env bash
# Dependency License Checker
# Usage: license-checker.sh <manifest-file> <config-file> [mock-db-file]
#
# Parses package.json or requirements.txt, looks up each dependency's license
# from a mock database, checks against allow/deny lists, and prints a report.
# Exit code: 0 = all approved/unknown, 1 = any denied packages found.

set -euo pipefail

MANIFEST_FILE="${1:-}"
CONFIG_FILE="${2:-}"
# Default mock DB lives next to this script
MOCK_DB_FILE="${3:-$(dirname "$0")/mock-licenses.db}"

# --- Argument validation ---
if [[ -z "$MANIFEST_FILE" ]] || [[ -z "$CONFIG_FILE" ]]; then
  echo "Error: Usage: $0 <manifest-file> <config-file> [mock-db-file]" >&2
  exit 1
fi

if [[ ! -f "$MANIFEST_FILE" ]]; then
  echo "Error: Manifest file not found: $MANIFEST_FILE" >&2
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

# --- Load allow/deny lists (newline-separated strings from jq) ---
ALLOW_LIST=$(jq -r '.allow[]' "$CONFIG_FILE")
DENY_LIST=$(jq -r '.deny[]' "$CONFIG_FILE")

# --- Mock license lookup ---
# Reads from a simple "package=LICENSE" flat file.
# Returns "UNKNOWN" when the package is not in the database.
lookup_license() {
  local pkg="$1"
  local found=""
  if [[ -f "$MOCK_DB_FILE" ]]; then
    found=$(grep "^${pkg}=" "$MOCK_DB_FILE" 2>/dev/null | head -1 | cut -d'=' -f2-)
  fi
  echo "${found:-UNKNOWN}"
}

# --- License classification ---
# Checks deny list first, then allow list, then marks as UNKNOWN.
classify_license() {
  local license="$1"

  if [[ "$license" == "UNKNOWN" ]]; then
    echo "UNKNOWN"
    return
  fi

  local entry
  while IFS= read -r entry; do
    if [[ "$license" == "$entry" ]]; then
      echo "DENIED"
      return
    fi
  done <<< "$DENY_LIST"

  while IFS= read -r entry; do
    if [[ "$license" == "$entry" ]]; then
      echo "APPROVED"
      return
    fi
  done <<< "$ALLOW_LIST"

  # License exists but is not in either list
  echo "UNKNOWN"
}

# --- Manifest parsing ---
# Populates parallel arrays DEP_NAMES and DEP_VERS, sorted for determinism.
declare -a DEP_NAMES=()
declare -a DEP_VERS=()

MANIFEST_BASENAME=$(basename "$MANIFEST_FILE")

# Detect manifest type by extension (.json = npm, .txt = pip requirements)
if [[ "$MANIFEST_BASENAME" == *.json ]]; then
  # Merge dependencies and devDependencies, then sort by name
  while IFS=$'\t' read -r pkg ver; do
    DEP_NAMES+=("$pkg")
    DEP_VERS+=("$ver")
  done < <(jq -r '((.dependencies // {}) + (.devDependencies // {})) | to_entries | sort_by(.key)[] | "\(.key)\t\(.value)"' "$MANIFEST_FILE")

elif [[ "$MANIFEST_BASENAME" == *.txt ]]; then
  # Parse "package==version" lines; skip comments and blank lines.
  declare -a raw_names=()
  declare -a raw_vers=()
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    # Strip trailing comments and whitespace
    line="${line%%#*}"
    line="${line%"${line##*[! ]}"}"
    # Match: package-name followed by a version specifier
    # (regex stored in variable to avoid bash misinterpreting > inside [[ ]])
    ver_re='^([A-Za-z0-9_.-]+)[[:space:]]*[><=~!]+[[:space:]]*([0-9][^[:space:],;]*)'
    bare_re='^([A-Za-z0-9_.-]+)$'
    if [[ "$line" =~ $ver_re ]]; then
      raw_names+=("${BASH_REMATCH[1]}")
      raw_vers+=("${BASH_REMATCH[2]}")
    elif [[ "$line" =~ $bare_re ]]; then  # bare package name, no version
      raw_names+=("${BASH_REMATCH[1]}")
      raw_vers+=("unspecified")
    fi
  done < "$MANIFEST_FILE"

  # Sort by package name for deterministic output
  if [[ "${#raw_names[@]}" -gt 0 ]]; then
    mapfile -t sorted_indices < <(
      for i in "${!raw_names[@]}"; do printf '%s\t%d\n' "${raw_names[$i]}" "$i"; done | sort | cut -f2
    )
    for i in "${sorted_indices[@]}"; do
      DEP_NAMES+=("${raw_names[$i]}")
      DEP_VERS+=("${raw_vers[$i]}")
    done
  fi

else
  echo "Error: Unsupported manifest format: $MANIFEST_BASENAME" >&2
  echo "Supported formats: package.json, requirements.txt" >&2
  exit 1
fi

# --- Generate compliance report ---
echo "=== DEPENDENCY LICENSE COMPLIANCE REPORT ==="
echo "Manifest: $MANIFEST_FILE"
echo ""

approved_count=0
denied_count=0
unknown_count=0
has_denied=false

# Collect output lines into per-status arrays (already sorted by name)
declare -a approved_lines=()
declare -a denied_lines=()
declare -a unknown_lines=()

for i in "${!DEP_NAMES[@]}"; do
  pkg="${DEP_NAMES[$i]}"
  ver="${DEP_VERS[$i]}"
  license=$(lookup_license "$pkg")
  status=$(classify_license "$license")

  case "$status" in
    APPROVED)
      approved_count=$((approved_count + 1))
      approved_lines+=("APPROVED: $pkg $ver $license")
      ;;
    DENIED)
      denied_count=$((denied_count + 1))
      denied_lines+=("DENIED:   $pkg $ver $license")
      has_denied=true
      ;;
    UNKNOWN)
      unknown_count=$((unknown_count + 1))
      unknown_lines+=("UNKNOWN:  $pkg $ver $license")
      ;;
  esac
done

# Print status groups in order: approved, denied, unknown
for line in "${approved_lines[@]+"${approved_lines[@]}"}"; do echo "$line"; done
for line in "${denied_lines[@]+"${denied_lines[@]}"}"; do echo "$line"; done
for line in "${unknown_lines[@]+"${unknown_lines[@]}"}"; do echo "$line"; done

echo ""
echo "Summary: $approved_count approved, $denied_count denied, $unknown_count unknown"

if $has_denied; then
  echo "Status: FAIL"
  exit 1
else
  echo "Status: PASS"
  exit 0
fi
