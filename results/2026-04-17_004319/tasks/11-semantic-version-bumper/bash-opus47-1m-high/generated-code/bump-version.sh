#!/usr/bin/env bash
# Semantic version bumper driven by conventional commits.
#
# Subcommands (intended to be small enough to test in isolation):
#   --read FILE                 print the current version stored in FILE
#   --bump-type COMMITS_FILE    print "major" | "minor" | "patch" | "none"
#   --next VERSION TYPE         print the next version after applying TYPE
#   --write FILE VERSION        replace the version in FILE
#   --changelog VERSION COMMITS print a Markdown changelog entry to stdout
#   --run FILE COMMITS_FILE     do everything: bump FILE, update CHANGELOG.md,
#                               print the new version
#
# Conventional commit rules used here:
#   feat!: ... or "BREAKING CHANGE:" footer  -> major
#   feat:  ...                               -> minor
#   fix:   ...                               -> patch
#   anything else                            -> ignored for bump purposes

set -euo pipefail

VERSION_REGEX='^[0-9]+\.[0-9]+\.[0-9]+$'

die() {
  echo "error: $*" >&2
  exit 1
}

# Read a semver from either a plain file (one line: "X.Y.Z") or a package.json.
read_version() {
  local file="$1"
  [[ -f "$file" ]] || die "file not found: $file"

  local version
  if [[ "$file" == *package.json ]]; then
    # Minimal JSON extractor: looks for the first "version": "..." field.
    # Sufficient for the well-formed package.json files we expect to touch.
    version="$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$file" \
      | head -n1 \
      | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
  else
    version="$(tr -d '[:space:]' < "$file")"
  fi

  [[ -n "$version" ]] || die "no version found in $file"
  [[ "$version" =~ $VERSION_REGEX ]] || die "invalid version '$version' in $file"
  printf '%s\n' "$version"
}

# Examine a commits file (one commit message per logical block, blocks separated
# by blank lines or just newline-separated subjects) and decide the bump type.
determine_bump() {
  local file="$1"
  [[ -f "$file" ]] || die "commits file not found: $file"

  local has_major=0 has_minor=0 has_patch=0
  local line
  local subject_re='^([a-zA-Z]+)(\([^)]*\))?(!)?:'
  local breaking_re='^BREAKING[[:space:]]CHANGE:'
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Breaking change footer anywhere in the file -> major.
    if [[ "$line" =~ $breaking_re ]]; then
      has_major=1
      continue
    fi
    # Subject lines: "type(scope)?!?: description"
    if [[ "$line" =~ $subject_re ]]; then
      local type="${BASH_REMATCH[1]}"
      local bang="${BASH_REMATCH[3]}"
      if [[ -n "$bang" ]]; then
        has_major=1
      elif [[ "$type" == "feat" ]]; then
        has_minor=1
      elif [[ "$type" == "fix" ]]; then
        has_patch=1
      fi
    fi
  done < "$file"

  if (( has_major )); then echo "major"
  elif (( has_minor )); then echo "minor"
  elif (( has_patch )); then echo "patch"
  else echo "none"
  fi
}

# Compute the next semver. Resets lower components per semver spec.
next_version() {
  local current="$1" bump="$2"
  [[ "$current" =~ $VERSION_REGEX ]] || die "invalid current version: $current"

  local major minor patch
  IFS=. read -r major minor patch <<< "$current"

  case "$bump" in
    major) major=$((major + 1)); minor=0; patch=0 ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    patch) patch=$((patch + 1)) ;;
    none)  : ;;
    *)     die "unknown bump type: $bump" ;;
  esac
  printf '%s.%s.%s\n' "$major" "$minor" "$patch"
}

# Replace the version in a file, preserving surrounding content.
write_version() {
  local file="$1" new="$2"
  [[ -f "$file" ]] || die "file not found: $file"
  [[ "$new" =~ $VERSION_REGEX ]] || die "invalid version: $new"

  if [[ "$file" == *package.json ]]; then
    # Replace only the first version field. Use a temp file for atomicity.
    local tmp
    tmp="$(mktemp)"
    awk -v new="$new" '
      !done && /"version"[[:space:]]*:[[:space:]]*"[^"]+"/ {
        sub(/"version"[[:space:]]*:[[:space:]]*"[^"]+"/, "\"version\": \"" new "\"")
        done = 1
      }
      { print }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
  else
    printf '%s\n' "$new" > "$file"
  fi
}

# Build a markdown changelog entry from commits.
generate_changelog() {
  local version="$1" file="$2"
  [[ -f "$file" ]] || die "commits file not found: $file"

  local features=() fixes=() breaking=()
  local line
  local subject_re='^([a-zA-Z]+)(\([^)]*\))?(!)?:[[:space:]]*(.*)$'
  local breaking_re='^BREAKING[[:space:]]CHANGE:[[:space:]]*(.*)$'
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ $breaking_re ]]; then
      breaking+=("${BASH_REMATCH[1]}")
      continue
    fi
    if [[ "$line" =~ $subject_re ]]; then
      local type="${BASH_REMATCH[1]}"
      local bang="${BASH_REMATCH[3]}"
      local desc="${BASH_REMATCH[4]}"
      if [[ -n "$bang" ]]; then
        breaking+=("$desc")
      elif [[ "$type" == "feat" ]]; then
        features+=("$desc")
      elif [[ "$type" == "fix" ]]; then
        fixes+=("$desc")
      fi
    fi
  done < "$file"

  local today
  today="$(date -u +%Y-%m-%d)"
  printf '## %s - %s\n\n' "$version" "$today"

  if (( ${#breaking[@]} )); then
    printf '### Breaking Changes\n\n'
    local item
    for item in "${breaking[@]}"; do printf -- '- %s\n' "$item"; done
    printf '\n'
  fi
  if (( ${#features[@]} )); then
    printf '### Features\n\n'
    local item
    for item in "${features[@]}"; do printf -- '- %s\n' "$item"; done
    printf '\n'
  fi
  if (( ${#fixes[@]} )); then
    printf '### Fixes\n\n'
    local item
    for item in "${fixes[@]}"; do printf -- '- %s\n' "$item"; done
    printf '\n'
  fi
}

# Glue: read the version, decide the bump, write the version + changelog,
# print the new version on stdout (so callers can capture it).
run_all() {
  local version_file="$1" commits_file="$2"

  local current bump new
  current="$(read_version "$version_file")"
  bump="$(determine_bump "$commits_file")"
  new="$(next_version "$current" "$bump")"

  if [[ "$bump" == "none" ]]; then
    # Nothing to do — don't touch files, just echo the unchanged version.
    printf '%s\n' "$new"
    return 0
  fi

  write_version "$version_file" "$new"

  # Prepend the new entry to CHANGELOG.md so newest is on top.
  local entry existing
  entry="$(generate_changelog "$new" "$commits_file")"
  existing=""
  [[ -f CHANGELOG.md ]] && existing="$(cat CHANGELOG.md)"
  {
    printf '%s' "$entry"
    if [[ -n "$existing" ]]; then
      printf '\n%s\n' "$existing"
    fi
  } > CHANGELOG.md

  printf '%s\n' "$new"
}

usage() {
  cat <<'EOF'
Usage:
  bump-version.sh --read FILE
  bump-version.sh --bump-type COMMITS_FILE
  bump-version.sh --next VERSION TYPE
  bump-version.sh --write FILE VERSION
  bump-version.sh --changelog VERSION COMMITS
  bump-version.sh --run FILE COMMITS_FILE
EOF
}

main() {
  [[ $# -gt 0 ]] || { usage >&2; exit 2; }
  local cmd="$1"
  shift
  case "$cmd" in
    --read)      [[ $# -eq 1 ]] || die "--read needs FILE";              read_version "$1" ;;
    --bump-type) [[ $# -eq 1 ]] || die "--bump-type needs COMMITS_FILE"; determine_bump "$1" ;;
    --next)      [[ $# -eq 2 ]] || die "--next needs VERSION TYPE";      next_version "$1" "$2" ;;
    --write)     [[ $# -eq 2 ]] || die "--write needs FILE VERSION";     write_version "$1" "$2" ;;
    --changelog) [[ $# -eq 2 ]] || die "--changelog needs VERSION COMMITS"; generate_changelog "$1" "$2" ;;
    --run)       [[ $# -eq 2 ]] || die "--run needs FILE COMMITS_FILE";  run_all "$1" "$2" ;;
    -h|--help)   usage ;;
    *)           usage >&2; exit 2 ;;
  esac
}

main "$@"
