#!/usr/bin/env bash
set -euo pipefail

# Semantic version bumper: parses a version file, determines the next version
# from conventional commit messages, updates the file, and generates a changelog.

usage() {
  cat <<EOF
Usage: $(basename "$0") --version-file <path> --commit-log <path> [--changelog <path>]

Options:
  --version-file  Path to VERSION file or package.json
  --commit-log    Path to file containing conventional commit messages
  --changelog     Path to changelog file to create/prepend (optional)
  -h, --help      Show this help message
EOF
}

parse_version() {
  local file="$1"
  local version

  if [[ "$file" == *.json ]]; then
    version=$(grep -oP '"version"\s*:\s*"\K[^"]+' "$file")
  else
    version=$(head -1 "$file" | tr -d '[:space:]')
  fi

  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: invalid version string '$version' in $file" >&2
    return 1
  fi

  echo "$version"
}

detect_bump_type() {
  local commit_log="$1"
  local bump="patch"

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    # Breaking change: bang notation (feat!:, fix!:, etc.) or BREAKING CHANGE footer
    if [[ "$line" =~ ^[a-z]+(\(.+\))?!: ]] || [[ "$line" =~ ^BREAKING[[:space:]]CHANGE ]]; then
      echo "major"
      return 0
    fi

    if [[ "$line" =~ ^feat(\(.+\))?: ]]; then
      bump="minor"
    fi
  done < "$commit_log"

  echo "$bump"
}

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
  esac

  echo "${major}.${minor}.${patch}"
}

update_version_file() {
  local file="$1"
  local old_version="$2"
  local new_version="$3"

  if [[ "$file" == *.json ]]; then
    sed -i "s/\"version\": *\"${old_version}\"/\"version\": \"${new_version}\"/" "$file"
  else
    echo "$new_version" > "$file"
  fi
}

generate_changelog() {
  local new_version="$1"
  local commit_log="$2"
  local changelog_file="$3"

  local features=()
  local fixes=()
  local others=()

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    if [[ "$line" =~ ^feat(\(.+\))?\!?:[[:space:]]*(.*) ]]; then
      features+=("${BASH_REMATCH[2]}")
    elif [[ "$line" =~ ^fix(\(.+\))?\!?:[[:space:]]*(.*) ]]; then
      fixes+=("${BASH_REMATCH[2]}")
    elif [[ "$line" =~ ^BREAKING[[:space:]]CHANGE ]]; then
      continue
    elif [[ "$line" =~ ^[a-z]+(\(.+\))?:[[:space:]]*(.*) ]]; then
      others+=("${BASH_REMATCH[2]}")
    fi
  done < "$commit_log"

  local entry=""
  entry+="## ${new_version} ($(date +%Y-%m-%d))"$'\n\n'

  if [[ ${#features[@]} -gt 0 ]]; then
    entry+="### Features"$'\n\n'
    for f in "${features[@]}"; do
      entry+="- ${f}"$'\n'
    done
    entry+=$'\n'
  fi

  if [[ ${#fixes[@]} -gt 0 ]]; then
    entry+="### Bug Fixes"$'\n\n'
    for f in "${fixes[@]}"; do
      entry+="- ${f}"$'\n'
    done
    entry+=$'\n'
  fi

  if [[ ${#others[@]} -gt 0 ]]; then
    entry+="### Other"$'\n\n'
    for o in "${others[@]}"; do
      entry+="- ${o}"$'\n'
    done
    entry+=$'\n'
  fi

  if [[ -f "$changelog_file" ]]; then
    local existing
    existing=$(cat "$changelog_file")
    echo -e "${entry}${existing}" > "$changelog_file"
  else
    echo -n "$entry" > "$changelog_file"
  fi
}

main() {
  local version_file=""
  local commit_log=""
  local changelog_file=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version-file) version_file="$2"; shift 2 ;;
      --commit-log) commit_log="$2"; shift 2 ;;
      --changelog) changelog_file="$2"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Error: unknown option '$1'" >&2; usage >&2; exit 1 ;;
    esac
  done

  if [[ -z "$version_file" ]]; then
    echo "Error: --version-file is required" >&2
    exit 1
  fi

  if [[ -z "$commit_log" ]]; then
    echo "Error: --commit-log is required" >&2
    exit 1
  fi

  if [[ ! -f "$version_file" ]]; then
    echo "Error: version file '$version_file' not found" >&2
    exit 1
  fi

  if [[ ! -f "$commit_log" ]]; then
    echo "Error: commit log '$commit_log' not found" >&2
    exit 1
  fi

  local current_version
  current_version=$(parse_version "$version_file")

  local bump_type
  bump_type=$(detect_bump_type "$commit_log")

  local new_version
  new_version=$(bump_version "$current_version" "$bump_type")

  update_version_file "$version_file" "$current_version" "$new_version"

  if [[ -n "$changelog_file" ]]; then
    generate_changelog "$new_version" "$commit_log" "$changelog_file"
  fi

  echo "$new_version"
}

main "$@"
