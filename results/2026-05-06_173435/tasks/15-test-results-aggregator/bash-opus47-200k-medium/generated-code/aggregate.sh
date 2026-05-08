#!/usr/bin/env bash
# aggregate.sh — Aggregate test results from JUnit XML and JSON files into a
# markdown summary suitable for a GitHub Actions job summary.
#
# Usage: aggregate.sh <directory>
#
# Behaviour:
#   - Scans <directory> recursively for *.xml (JUnit) and *.json (custom).
#   - Computes totals: passed / failed / skipped / duration.
#   - Detects flaky tests: same test name observed with both passed and failed
#     statuses across the input files.
#   - Writes markdown to stdout, or to $GITHUB_STEP_SUMMARY if that env var
#     points to a writable file path.
#
# JSON fixture shape:
#   {"tests":[{"name": "<id>", "status": "passed|failed|skipped",
#              "duration": <seconds>}, ...]}
#
# Dependencies: standard POSIX tools + jq (for JSON parsing). XML parsing is
# done with awk/sed which is sufficient for the well-formed JUnit subset we
# care about here.

set -euo pipefail

usage() {
  echo "Usage: $0 <directory>" >&2
  exit 2
}

[[ $# -ge 1 ]] || usage
DIR="$1"
[[ -d "$DIR" ]] || { echo "Error: '$DIR' is not a directory" >&2; exit 2; }

command -v jq >/dev/null || { echo "Error: jq is required" >&2; exit 2; }

# Collect normalised records as TSV: status<TAB>name<TAB>duration
records_file="$(mktemp)"
trap 'rm -f "$records_file"' EXIT

# --- Parse JUnit XML files ---
# Strategy: flatten to one tag per line, then walk testcase elements and look
# at the next non-whitespace tag to decide pass/fail/skip.
parse_junit() {
  local file="$1"
  # Normalise: each tag on its own line, drop XML decl/comments.
  # We then iterate over <testcase ...> openings; if the next sibling is
  # <failure/error/skipped...> we mark it accordingly, otherwise passed.
  awk '
    BEGIN { RS=">"; ORS="" }
    {
      gsub(/\r/, "")
      tag = $0 "<"   # placeholder; we mostly want the original $0 with > re-added
      # we will re-emit each chunk as a line "<...>"
      # strip leading whitespace/newlines inside the chunk
      gsub(/^[ \t\n]+/, "")
      if (length($0) > 0) print $0 ">\n"
    }
  ' "$file" | awk -v out="$records_file" '
    function attr(line, key,    re, m) {
      # Require space (or tag-open) before the key so "name" does not match
      # inside "classname".
      re = "[ <]" key "=\"[^\"]*\""
      if (match(line, re)) {
        m = substr(line, RSTART, RLENGTH)
        sub(/^[ <]/, "", m)
        sub(key "=\"", "", m)
        sub(/"$/, "", m)
        return m
      }
      return ""
    }
    /<testcase[ >]/ {
      cls = attr($0, "classname")
      nm  = attr($0, "name")
      tm  = attr($0, "time")
      if (tm == "") tm = "0"
      full = (cls != "" ? cls "." nm : nm)
      # If this tag is self-closed, status is passed.
      if ($0 ~ /\/>[[:space:]]*$/) {
        print "passed\t" full "\t" tm >> out
        next
      }
      # Otherwise look ahead at subsequent tags until </testcase>.
      status = "passed"
      while ((getline next_line) > 0) {
        if (next_line ~ /<\/testcase>/) break
        if (next_line ~ /<failure[ \/>]/ || next_line ~ /<error[ \/>]/) {
          status = "failed"; break
        }
        if (next_line ~ /<skipped[ \/>]/) {
          status = "skipped"; break
        }
      }
      # Drain the rest until </testcase>
      while (next_line !~ /<\/testcase>/ && (getline next_line) > 0) { }
      print status "\t" full "\t" tm >> out
    }
  '
}

# --- Parse JSON files ---
parse_json() {
  local file="$1"
  jq -r '.tests[] | [.status, .name, (.duration // 0)] | @tsv' "$file" >> "$records_file"
}

shopt -s nullglob globstar
declare -A seen_paths=()
for f in "$DIR"/**/*.xml; do
  [[ -f "$f" ]] || continue
  [[ -n "${seen_paths[$f]:-}" ]] && continue
  seen_paths[$f]=1
  parse_junit "$f" || echo "Warning: failed to parse $f" >&2
done
for f in "$DIR"/**/*.json; do
  [[ -f "$f" ]] || continue
  [[ -n "${seen_paths[$f]:-}" ]] && continue
  seen_paths[$f]=1
  parse_json "$f" || echo "Warning: failed to parse $f (invalid JSON?)" >&2
done

# --- Aggregate totals & detect flaky tests ---
# Use awk so we don't fork per record.
summary="$(awk -F'\t' '
  {
    status=$1; name=$2; dur=$3+0
    total++
    if (status == "passed")  passed++
    else if (status == "failed")  failed++
    else if (status == "skipped") skipped++
    duration += dur
    seen[name "|" status]++
  }
  END {
    # Flaky = name observed with both passed and failed.
    for (k in seen) {
      split(k, a, "|")
      if (a[2] == "passed")  passed_set[a[1]] = 1
      if (a[2] == "failed")  failed_set[a[1]] = 1
    }
    for (n in passed_set) {
      if (n in failed_set) flaky_list = flaky_list n "\n"
    }
    printf "%d\t%d\t%d\t%d\t%.3f\n", total+0, passed+0, failed+0, skipped+0, duration+0
    printf "%s", flaky_list
  }
' "$records_file")"

totals_line="$(printf '%s\n' "$summary" | head -n1)"
flaky_lines="$(printf '%s\n' "$summary" | tail -n +2 | sort -u | sed '/^$/d')"

IFS=$'\t' read -r total passed failed skipped duration <<<"$totals_line"
total="${total:-0}"; passed="${passed:-0}"; failed="${failed:-0}"
skipped="${skipped:-0}"; duration="${duration:-0.000}"

# --- Render markdown ---
render() {
  echo "# Test Results"
  echo
  echo "| Metric | Count |"
  echo "| --- | --- |"
  echo "| Total | $total |"
  echo "| Passed | $passed |"
  echo "| Failed | $failed |"
  echo "| Skipped | $skipped |"
  echo "| Duration (s) | $duration |"
  echo
  if [[ -n "$flaky_lines" ]]; then
    echo "## Flaky Tests"
    echo
    while IFS= read -r name; do
      echo "- \`$name\`"
    done <<<"$flaky_lines"
    echo
  else
    echo "## Flaky Tests"
    echo
    echo "_None detected._"
    echo
  fi
  if [[ "$failed" -gt 0 ]]; then
    echo "Status: FAILED"
  else
    echo "Status: OK"
  fi
}

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  render | tee "$GITHUB_STEP_SUMMARY"
else
  render
fi
