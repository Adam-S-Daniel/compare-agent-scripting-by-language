#!/usr/bin/env bash
# Semantic version bumper.
# Reads a version from VERSION or package.json, scans conventional-commit
# messages from a commits file, decides patch/minor/major, writes the new
# version back, appends a changelog entry, and prints the new version.

set -euo pipefail

usage() {
    cat >&2 <<'EOF'
Usage: bump-version.sh <version-file> <commits-file> [changelog-file]

  version-file   Path to VERSION file (plain text) or package.json
  commits-file   Path to file containing one commit subject per line
  changelog-file Path to changelog (defaults to CHANGELOG.md alongside version-file)
EOF
    exit 2
}

[[ $# -ge 2 && $# -le 3 ]] || usage

version_file=$1
commits_file=$2
changelog_file=${3:-"$(dirname "$version_file")/CHANGELOG.md"}

[[ -f $version_file ]] || { echo "error: version file not found: $version_file" >&2; exit 1; }
[[ -f $commits_file ]] || { echo "error: commits file not found: $commits_file" >&2; exit 1; }

# Extract current version from VERSION or package.json.
read_version() {
    local f=$1
    if [[ $f == *package.json ]]; then
        # Minimal JSON-aware extraction: find the "version": "x.y.z" pair.
        local v
        v=$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+"' "$f" \
            | head -n1 \
            | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        [[ -n $v ]] || { echo "error: no version field in $f" >&2; exit 1; }
        echo "$v"
    else
        local v
        v=$(tr -d '[:space:]' < "$f")
        [[ $v =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
            echo "error: invalid semver in $f: '$v'" >&2; exit 1;
        }
        echo "$v"
    fi
}

write_version() {
    local f=$1 new=$2
    if [[ $f == *package.json ]]; then
        # Replace only the first version line.
        local tmp
        tmp=$(mktemp)
        sed -E "0,/\"version\"[[:space:]]*:[[:space:]]*\"[0-9]+\.[0-9]+\.[0-9]+\"/ \
            s//\"version\": \"${new}\"/" "$f" > "$tmp"
        mv "$tmp" "$f"
    else
        printf '%s\n' "$new" > "$f"
    fi
}

# Decide bump kind by scanning conventional commit subjects.
# Precedence: breaking > feat > fix > none.
classify_commits() {
    local f=$1
    local kind="none"
    local re_break='^[a-zA-Z]+(\([^)]*\))?!:'
    local re_feat='^feat(\([^)]*\))?:'
    local re_fix='^fix(\([^)]*\))?:'
    while IFS= read -r line; do
        [[ -z $line ]] && continue
        # Breaking change: "type!:" prefix or BREAKING CHANGE marker.
        if [[ $line =~ $re_break ]] || [[ $line == *"BREAKING CHANGE"* ]]; then
            echo "major"; return
        fi
        if [[ $line =~ $re_feat ]]; then
            kind="minor"
        elif [[ $line =~ $re_fix ]] && [[ $kind != "minor" ]]; then
            kind="patch"
        fi
    done < "$f"
    echo "$kind"
}

bump() {
    local cur=$1 kind=$2
    IFS=. read -r maj min pat <<< "$cur"
    case $kind in
        major) echo "$((maj+1)).0.0" ;;
        minor) echo "${maj}.$((min+1)).0" ;;
        patch) echo "${maj}.${min}.$((pat+1))" ;;
        none)  echo "$cur" ;;
        *) echo "error: unknown bump kind: $kind" >&2; exit 1 ;;
    esac
}

write_changelog() {
    local f=$1 new=$2 commits=$3 kind=$4
    local date_iso
    date_iso=$(date -u +%Y-%m-%d)
    {
        echo "## ${new} - ${date_iso} (${kind})"
        echo
        while IFS= read -r line; do
            [[ -z $line ]] && continue
            echo "- ${line}"
        done < "$commits"
        echo
        if [[ -f $f ]]; then
            cat "$f"
        fi
    } > "${f}.tmp"
    mv "${f}.tmp" "$f"
}

current=$(read_version "$version_file")
kind=$(classify_commits "$commits_file")

if [[ $kind == "none" ]]; then
    echo "no version-impacting commits; keeping ${current}" >&2
    echo "$current"
    exit 0
fi

new=$(bump "$current" "$kind")
write_version "$version_file" "$new"
write_changelog "$changelog_file" "$new" "$commits_file" "$kind"
echo "$new"
