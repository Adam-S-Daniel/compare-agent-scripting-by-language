#!/usr/bin/env bash
# Semantic version bumper based on Conventional Commits.
#
# Reads a SemVer string from a version file (plain VERSION or package.json),
# inspects a commits log, decides on major/minor/patch bump, writes the new
# version back, optionally appends a changelog entry, and prints the version.
#
# Bump rules (Conventional Commits):
#   - any commit with "!" before the colon, or a "BREAKING CHANGE:" footer => major
#   - any "feat" commit                                                    => minor
#   - any "fix"  commit                                                    => patch
#   - otherwise                                                            => patch (default safety)

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bump-version.sh --version-file <path> --commits <path> [--changelog <path>]

Reads commits from a file (one commit message per record, blank-line separated),
determines the conventional-commit bump type, updates the version file, and
prints the new version.
EOF
}

err() { echo "ERROR: $*" >&2; }

VERSION_FILE=""
COMMITS_FILE=""
CHANGELOG_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version-file) VERSION_FILE="$2"; shift 2 ;;
    --commits)      COMMITS_FILE="$2"; shift 2 ;;
    --changelog)    CHANGELOG_FILE="$2"; shift 2 ;;
    -h|--help)      usage; exit 0 ;;
    *) err "Unknown argument: $1"; usage >&2; exit 2 ;;
  esac
done

# Auto-detect default version file.
if [[ -z "$VERSION_FILE" ]]; then
  if [[ -f VERSION ]]; then
    VERSION_FILE="VERSION"
  elif [[ -f package.json ]]; then
    VERSION_FILE="package.json"
  else
    err "No VERSION file or package.json found (and --version-file not given)."
    exit 1
  fi
fi

[[ -f "$VERSION_FILE" ]] || { err "Version file '$VERSION_FILE' does not exist."; exit 1; }
[[ -n "$COMMITS_FILE" && -f "$COMMITS_FILE" ]] || { err "Commits file is required (--commits)."; exit 1; }

# Extract current version.
read_version() {
  local file="$1"
  if [[ "$file" == *.json ]]; then
    # Grab "version": "x.y.z" — keeps the script dependency-free (no jq required).
    grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$file" \
      | head -n1 \
      | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
  else
    head -n1 "$file" | tr -d '[:space:]'
  fi
}

CURRENT="$(read_version "$VERSION_FILE")"

# Validate SemVer (major.minor.patch, digits only — no pre-release for simplicity).
if ! [[ "$CURRENT" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  err "Invalid version '$CURRENT' in $VERSION_FILE (expected MAJOR.MINOR.PATCH)."
  exit 1
fi
MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
PATCH="${BASH_REMATCH[3]}"

# Decide bump type by scanning commits.
bump="patch"
has_feat=0
has_fix=0
has_breaking=0

while IFS= read -r line || [[ -n "$line" ]]; do
  # Header forms like "feat:", "feat(scope):", "feat!:", "fix(api)!:" etc.
  if [[ "$line" =~ ^[a-zA-Z]+(\([^\)]+\))?!: ]]; then
    has_breaking=1
  elif [[ "$line" == "BREAKING CHANGE:"* || "$line" == "BREAKING-CHANGE:"* ]]; then
    has_breaking=1
  elif [[ "$line" =~ ^feat(\([^\)]+\))?: ]]; then
    has_feat=1
  elif [[ "$line" =~ ^fix(\([^\)]+\))?: ]]; then
    has_fix=1
  fi
done < "$COMMITS_FILE"

if (( has_breaking )); then
  bump="major"
elif (( has_feat )); then
  bump="minor"
elif (( has_fix )); then
  bump="patch"
fi

case "$bump" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
esac

NEW="${MAJOR}.${MINOR}.${PATCH}"

# Write version back to the file.
write_version() {
  local file="$1" new="$2"
  if [[ "$file" == *.json ]]; then
    # In-place sed of the first "version": "..." line.
    local tmp
    tmp="$(mktemp)"
    awk -v v="$new" '
      !done && /"version"[[:space:]]*:[[:space:]]*"[^"]+"/ {
        sub(/"version"[[:space:]]*:[[:space:]]*"[^"]+"/, "\"version\": \"" v "\"")
        done = 1
      }
      { print }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
  else
    echo "$new" > "$file"
  fi
}

write_version "$VERSION_FILE" "$NEW"

# Optional changelog generation.
if [[ -n "$CHANGELOG_FILE" ]]; then
  {
    echo "## ${NEW} - $(date -u +%Y-%m-%d)"
    echo
    # Group entries by type for readability.
    feats=$(grep -E '^feat(\([^)]+\))?!?:' "$COMMITS_FILE" || true)
    fixes=$(grep -E '^fix(\([^)]+\))?!?:'  "$COMMITS_FILE" || true)
    breaks=$(grep -E '^[a-zA-Z]+(\([^)]+\))?!:|^BREAKING CHANGE:' "$COMMITS_FILE" || true)
    if [[ -n "$breaks" ]]; then
      echo "### BREAKING CHANGES"
      echo "$breaks" | awk '{print "- " $0}'
      echo
    fi
    if [[ -n "$feats" ]]; then
      echo "### Features"
      echo "$feats" | awk '{print "- " $0}'
      echo
    fi
    if [[ -n "$fixes" ]]; then
      echo "### Fixes"
      echo "$fixes" | awk '{print "- " $0}'
      echo
    fi
  } >> "$CHANGELOG_FILE"
fi

echo "$NEW"
