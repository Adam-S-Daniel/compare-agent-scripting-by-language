#!/usr/bin/env bash
#
# semver-bump.sh — Semantic version bumper using conventional commits
#
# Parses a VERSION file (or package.json) for a semantic version string,
# determines the next version based on conventional commit messages
# (feat -> minor, fix -> patch, breaking -> major), updates the version
# file, optionally generates a changelog entry, and outputs the new version.
#
# Usage:
#   semver-bump.sh --version-file <FILE> [--commit-log <FILE>] [--changelog <FILE>]
#
# If --commit-log is omitted, commits are read from git log (since last tag).
# If --changelog is provided, a changelog entry is written to that file.

set -euo pipefail

# --- Argument parsing ---
VERSION_FILE=""
COMMIT_LOG=""
CHANGELOG_FILE=""

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version-file)
        VERSION_FILE="$2"
        shift 2
        ;;
      --commit-log)
        COMMIT_LOG="$2"
        shift 2
        ;;
      --changelog)
        CHANGELOG_FILE="$2"
        shift 2
        ;;
      *)
        echo "ERROR: Unknown argument: $1" >&2
        exit 1
        ;;
    esac
  done

  if [[ -z "$VERSION_FILE" ]]; then
    echo "ERROR: --version-file is required" >&2
    exit 1
  fi
}

# --- Version parsing ---
# Extracts a semver string from either a plain VERSION file or package.json.
# Returns the version via stdout.
parse_version() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    echo "ERROR: Version file does not exist: $file" >&2
    return 1
  fi

  local version=""

  if [[ "$file" == *.json ]]; then
    # Extract version from package.json using grep + sed (no jq dependency)
    version=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$file" \
      | head -1 \
      | sed 's/.*"\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)".*/\1/')
  else
    # Plain text VERSION file — read first line, strip whitespace
    version=$(head -1 "$file" | tr -d '[:space:]')
  fi

  # Validate semver format (MAJOR.MINOR.PATCH)
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: Invalid semantic version: '$version'" >&2
    return 1
  fi

  echo "$version"
}

# --- Commit reading ---
# Reads commit messages either from a file or from git log.
# Returns one commit message per line via stdout.
read_commits() {
  if [[ -n "$COMMIT_LOG" ]]; then
    if [[ ! -f "$COMMIT_LOG" ]]; then
      echo "ERROR: Commit log file not found: $COMMIT_LOG" >&2
      return 1
    fi
    cat "$COMMIT_LOG"
  else
    # Read from git log since the last version tag
    local last_tag
    last_tag=$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)

    if [[ -n "$last_tag" ]]; then
      git log "${last_tag}..HEAD" --pretty=format:"%s%n%b" 2>/dev/null
    else
      git log --pretty=format:"%s%n%b" 2>/dev/null
    fi
  fi
}

# --- Bump type determination ---
# Analyzes commit messages and determines the bump type.
# Priority: major > minor > patch
# Returns: "major", "minor", "patch", or "none"
determine_bump() {
  local commits="$1"
  local bump="none"

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    # Check for breaking changes: "feat!:", "fix!:", or "BREAKING CHANGE" in body
    if [[ "$line" =~ ^[a-z]+!: ]] || [[ "$line" =~ ^BREAKING\ CHANGE ]]; then
      bump="major"
      break  # Major is the highest priority, no need to continue
    fi

    # Check for feat: -> minor bump
    if [[ "$line" =~ ^feat(\(.+\))?:  ]]; then
      # Only upgrade if not already major
      if [[ "$bump" != "major" ]]; then
        bump="minor"
      fi
    fi

    # Check for fix: -> patch bump
    if [[ "$line" =~ ^fix(\(.+\))?:  ]]; then
      if [[ "$bump" == "none" ]]; then
        bump="patch"
      fi
    fi
  done <<< "$commits"

  echo "$bump"
}

# --- Version bumping ---
# Given a current version and bump type, compute the new version.
bump_version() {
  local version="$1"
  local bump_type="$2"

  local major minor patch
  IFS='.' read -r major minor patch <<< "$version"

  case "$bump_type" in
    major)
      major=$((major + 1))
      minor=0
      patch=0
      ;;
    minor)
      minor=$((minor + 1))
      patch=0
      ;;
    patch)
      patch=$((patch + 1))
      ;;
    *)
      echo "$version"
      return
      ;;
  esac

  echo "${major}.${minor}.${patch}"
}

# --- Version file update ---
# Writes the new version back to the version file.
update_version_file() {
  local file="$1"
  local new_version="$2"

  if [[ "$file" == *.json ]]; then
    # Update version in package.json using sed
    sed -i "s/\"version\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"version\": \"${new_version}\"/" "$file"
  else
    # Plain VERSION file — just write the version
    echo "$new_version" > "$file"
  fi
}

# --- Changelog generation ---
# Groups commits by type and writes a changelog entry.
generate_changelog() {
  local commits="$1"
  local new_version="$2"
  local changelog_file="$3"

  local features="" fixes="" others=""
  local today
  today=$(date +%Y-%m-%d)

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    # Categorize by conventional commit type
    if [[ "$line" =~ ^feat(!?\(.+\))?!?:[[:space:]]*(.+) ]] || [[ "$line" =~ ^feat:[[:space:]]*(.+) ]]; then
      local desc="${BASH_REMATCH[2]:-${BASH_REMATCH[1]}}"
      features="${features}- ${desc}"$'\n'
    elif [[ "$line" =~ ^fix(!?\(.+\))?!?:[[:space:]]*(.+) ]] || [[ "$line" =~ ^fix:[[:space:]]*(.+) ]]; then
      local desc="${BASH_REMATCH[2]:-${BASH_REMATCH[1]}}"
      fixes="${fixes}- ${desc}"$'\n'
    elif [[ "$line" =~ ^[a-z]+(\(.+\))?:[[:space:]]*(.+) ]]; then
      others="${others}- ${BASH_REMATCH[2]}"$'\n'
    fi
  done <<< "$commits"

  {
    echo "## [${new_version}] - ${today}"
    echo ""
    if [[ -n "$features" ]]; then
      echo "### Features"
      echo ""
      echo -n "$features"
      echo ""
    fi
    if [[ -n "$fixes" ]]; then
      echo "### Bug Fixes"
      echo ""
      echo -n "$fixes"
      echo ""
    fi
    if [[ -n "$others" ]]; then
      echo "### Other"
      echo ""
      echo -n "$others"
      echo ""
    fi
  } > "$changelog_file"
}

# --- Main ---
main() {
  parse_args "$@"

  # Parse current version
  local current_version
  current_version=$(parse_version "$VERSION_FILE")

  # Read commits
  local commits
  commits=$(read_commits)

  # Determine bump type
  local bump_type
  bump_type=$(determine_bump "$commits")

  if [[ "$bump_type" == "none" ]]; then
    echo "No bump required — no feat or fix commits found."
    exit 0
  fi

  # Calculate new version
  local new_version
  new_version=$(bump_version "$current_version" "$bump_type")

  # Update version file
  update_version_file "$VERSION_FILE" "$new_version"

  # Generate changelog if requested
  if [[ -n "$CHANGELOG_FILE" ]]; then
    generate_changelog "$commits" "$new_version" "$CHANGELOG_FILE"
  fi

  echo "Bumped version: ${current_version} -> ${new_version} (${bump_type})"
}

main "$@"
