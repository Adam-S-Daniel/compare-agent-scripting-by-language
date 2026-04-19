#!/usr/bin/env bash
# Artifact Cleanup Script
# Applies retention policies to GitHub Actions artifacts and generates deletion plans
# Usage: artifact-cleanup.sh <artifacts-json> [--max-age DAYS] [--max-size MB] [--keep-latest N] [--dry-run]

set -euo pipefail

# Global variables
DRY_RUN=false
MAX_AGE_DAYS=30
MAX_SIZE_MB=10240
KEEP_LATEST=10
TODAY="${TODAY:-$(date +%Y-%m-%d)}"

# Parse command-line arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --max-age)
        MAX_AGE_DAYS="$2"
        shift 2
        ;;
      --max-size)
        MAX_SIZE_MB="$2"
        shift 2
        ;;
      --keep-latest)
        KEEP_LATEST="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      *)
        shift
        ;;
    esac
  done
}

# Count artifacts in JSON array
parse_artifacts() {
  local json_file="$1"
  jq '. | length' "$json_file"
}

# Calculate age in days between two dates (YYYY-MM-DD format)
calculate_age() {
  local created_date="$1"
  local reference_date="${2:-$(date +%Y-%m-%d)}"

  # Extract just the date part if timestamp is provided
  created_date="${created_date%T*}"

  # Convert to seconds since epoch and calculate difference
  local created_epoch reference_epoch
  created_epoch=$(date -d "$created_date" +%s 2>/dev/null || echo 0)
  reference_epoch=$(date -d "$reference_date" +%s 2>/dev/null || echo 0)

  echo $(( (reference_epoch - created_epoch) / 86400 ))
}

# Filter artifacts by age, returning those exceeding max age
filter_by_age() {
  local json_file="$1"
  local max_age_days="$2"
  local reference_date="${3:-$(date +%Y-%m-%d)}"

  # Use a bash loop to filter artifacts by age
  local result="[]"
  local i=0
  local count
  count=$(jq '. | length' "$json_file")

  for ((i = 0; i < count; i++)); do
    local artifact
    artifact=$(jq ".[$i]" "$json_file")
    local created
    created=$(jq -r '.created' <<< "$artifact" | cut -d'T' -f1)

    # Calculate age
    local age
    age=$(calculate_age "$created" "$reference_date")

    # If age exceeds max_age_days, add to result
    if [[ $age -ge $max_age_days ]]; then
      result=$(jq --argjson item "$artifact" '. += [$item]' <<< "$result")
    fi
  done

  echo "$result"
}

# Filter artifacts by total size, returning those where total exceeds limit
filter_by_size() {
  local json_file="$1"
  local max_size_bytes="$2"

  # Sort by creation date (newest first) and accumulate sizes
  local result="[]"
  local total_size=0
  local count
  count=$(jq '. | length' "$json_file")

  # Sort artifacts by creation date descending
  local sorted
  sorted=$(jq 'sort_by(.created) | reverse' "$json_file")

  # Iterate and include those that would exceed limit
  for ((i = 0; i < count; i++)); do
    local artifact size
    artifact=$(jq ".[$i]" <<< "$sorted")
    size=$(jq '.size' <<< "$artifact")

    # If adding this artifact exceeds limit, mark for deletion
    if (( total_size + size > max_size_bytes )); then
      result=$(jq --argjson item "$artifact" '. += [$item]' <<< "$result")
    else
      total_size=$((total_size + size))
    fi
  done

  echo "$result"
}

# Filter to keep only latest N artifacts per workflow
filter_by_latest() {
  local json_file="$1"
  local keep_latest="$2"

  # Group by workflow_run_id, sort by date within group, keep only latest N
  jq --arg keep "$keep_latest" '
    group_by(.workflow_run_id) |
    map(sort_by(.created) | reverse | .[($keep | tonumber):]) |
    flatten
  ' "$json_file"
}

# Apply all retention policies and generate deletion plan
apply_all_policies() {
  local json_file="$1"
  local max_age_days="$2"
  local max_size_bytes="$3"
  local keep_latest="$4"
  local reference_date="${5:-$(date +%Y-%m-%d)}"

  # Start with all artifacts
  local all_artifacts
  all_artifacts=$(jq '.' "$json_file")

  # Apply each filter and collect candidates for deletion
  local by_age by_size by_latest
  by_age=$(filter_by_age <(echo "$all_artifacts") "$max_age_days" "$reference_date")
  by_size=$(filter_by_size <(echo "$all_artifacts") "$max_size_bytes")
  by_latest=$(filter_by_latest <(echo "$all_artifacts") "$keep_latest")

  # Merge results (union of all deletion candidates)
  local to_delete_names
  to_delete_names=$(
    jq -s '.[0] + .[1] + .[2] | unique_by(.name)' \
      <(echo "$by_age") <(echo "$by_size") <(echo "$by_latest")
  )

  # Find artifacts to keep (those not in to_delete)
  local to_keep
  to_keep=$(
    jq --argjson to_delete "$to_delete_names" '
      [.[] | select(. as $item |
        ($to_delete | map(.name) | index($item.name) | . == null))]
    ' "$json_file"
  )

  # Generate plan
  jq -n \
    --argjson artifacts_to_delete "$to_delete_names" \
    --argjson artifacts_to_keep "$to_keep" \
    '{artifacts_to_delete: $artifacts_to_delete, artifacts_to_keep: $artifacts_to_keep}'
}

# Main cleanup function
cleanup_artifacts() {
  local artifacts_json="$1"
  shift

  parse_arguments "$@"

  # Validate input file
  if [[ ! -f "$artifacts_json" ]]; then
    echo "Error: Artifacts JSON file not found: $artifacts_json" >&2
    return 1
  fi

  # Announce dry-run mode
  if [[ "$DRY_RUN" == true ]]; then
    echo "DRY_RUN: No artifacts will be deleted" >&2
  fi

  # Apply all retention policies
  local plan_json
  plan_json=$(apply_all_policies "$artifacts_json" "$MAX_AGE_DAYS" \
    "$((MAX_SIZE_MB * 1048576))" "$KEEP_LATEST" "$TODAY")

  echo "$plan_json"
}

# Generate summary of deletion plan
generate_summary() {
  local plan_json="$1"

  # Extract deleted artifacts and calculate total size
  local total_size
  total_size=$(jq '[.artifacts_to_delete[] | .size] | add // 0' "$plan_json")

  # Count artifacts
  local delete_count keep_count
  delete_count=$(jq '.artifacts_to_delete | length' "$plan_json")
  keep_count=$(jq '.artifacts_to_keep | length' "$plan_json")

  # Format output
  echo "=== Artifact Cleanup Summary ==="
  echo "Artifacts to delete: $delete_count"
  echo "Artifacts to keep: $keep_count"
  echo "Total space to reclaim: $total_size bytes"

  # Convert to human-readable format
  if (( total_size > 1048576 )); then
    printf "                       (%.2f MB)\n" "$(awk "BEGIN {printf \"%.2f\", $total_size / 1048576}")"
  elif (( total_size > 1024 )); then
    printf "                       (%.2f 'KB)\n" "$(awk "BEGIN {printf \"%.2f\", $total_size / 1024}")"
  fi
}

# Main execution (only if sourced for testing or run directly)
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  : # Being sourced for testing
else
  # Direct execution
  if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <artifacts-json> [--max-age DAYS] [--max-size MB] [--keep-latest N] [--dry-run]" >&2
    exit 1
  fi

  artifacts_file="$1"
  shift

  result=$(cleanup_artifacts "$artifacts_file" "$@")
  echo "$result"
fi
