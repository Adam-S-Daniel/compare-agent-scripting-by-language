#!/usr/bin/env bash

# Artifact cleanup script: applies retention policies to artifact metadata
# and generates a deletion plan with summary

set -uo pipefail

DRY_RUN=false
MAX_AGE_DAYS=""
MAX_TOTAL_SIZE=""
KEEP_LATEST=""
INPUT_FILE=""
TODAY=$(date +%Y-%m-%d)

usage() {
  cat << 'EOF'
Usage: artifact-cleanup.sh [options]

Options:
  --input FILE              Path to artifact CSV file (required)
  --dry-run                 Show what would be deleted without deleting
  --max-age DAYS            Delete artifacts older than N days
  --max-total-size BYTES    Delete oldest artifacts if total size exceeds limit
  --keep-latest N           Keep only N latest artifacts per workflow
  --help                    Display this help message

Examples:
  artifact-cleanup.sh --input artifacts.csv --dry-run --max-age 30

CSV Format:
  name,size_bytes,creation_date,workflow_run_id
  artifact-1,1000,2026-05-01,run-1
EOF
}

parse_args() {
  while (( $# > 0 )); do
    case "$1" in
      --input)
        INPUT_FILE="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --max-age)
        MAX_AGE_DAYS="$2"
        shift 2
        ;;
      --max-total-size)
        MAX_TOTAL_SIZE="$2"
        shift 2
        ;;
      --keep-latest)
        KEEP_LATEST="$2"
        shift 2
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        echo "Error: Unknown option: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done
}

validate_input() {
  if [[ -z "$INPUT_FILE" ]]; then
    echo "Error: --input file is required" >&2
    exit 1
  fi

  if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file not found: $INPUT_FILE" >&2
    exit 1
  fi
}

days_since() {
  local date1="$1"
  local date2="$2"

  local epoch1 epoch2
  epoch1=$(date -d "$date1" +%s 2>/dev/null || echo "0")
  epoch2=$(date -d "$date2" +%s 2>/dev/null || echo "0")

  if [[ "$epoch1" == "0" ]] || [[ "$epoch2" == "0" ]]; then
    echo "999999"
    return
  fi

  echo $(( (epoch1 - epoch2) / 86400 ))
}

main() {
  parse_args "$@"
  validate_input

  # Read all artifacts into memory
  declare -A artifacts_size
  declare -A artifacts_date
  declare -A artifacts_run
  declare -a artifact_list=()

  # Load CSV (skip header)
  local line_num=0
  while IFS=',' read -r name size_bytes creation_date workflow_run_id; do
    (( line_num++ ))
    [[ $line_num -eq 1 ]] && continue
    [[ -z "$name" ]] && continue

    artifacts_size["$name"]="$size_bytes"
    artifacts_date["$name"]="$creation_date"
    artifacts_run["$name"]="$workflow_run_id"
    artifact_list+=("$name")
  done < "$INPUT_FILE"

  # Determine which artifacts to delete
  declare -A delete_decision  # maps artifact name to KEEP or DELETE
  for artifact in "${artifact_list[@]}"; do
    delete_decision["$artifact"]="KEEP"
  done

  # Apply max-age policy
  if [[ -n "$MAX_AGE_DAYS" ]]; then
    for artifact in "${artifact_list[@]}"; do
      local age_days
      age_days=$(days_since "$TODAY" "${artifacts_date[$artifact]}")
      if (( age_days > MAX_AGE_DAYS )); then
        delete_decision["$artifact"]="DELETE"
      fi
    done
  fi

  # Apply keep-latest-N policy
  if [[ -n "$KEEP_LATEST" ]]; then
    # Group by workflow
    declare -A workflow_artifacts
    for artifact in "${artifact_list[@]}"; do
      local run_id="${artifacts_run[$artifact]}"
      if [[ -z "${workflow_artifacts[$run_id]:-}" ]]; then
        workflow_artifacts["$run_id"]=""
      fi
      workflow_artifacts["$run_id"]+="$artifact "
    done

    # For each workflow, keep only latest N (by date)
    for run_id in "${!workflow_artifacts[@]}"; do
      local artifacts_str="${workflow_artifacts[$run_id]}"
      declare -a workflow_list=()
      declare -a sort_data=()

      for artifact in $artifacts_str; do
        workflow_list+=("$artifact")
        sort_data+=("${artifacts_date[$artifact]}|$artifact")
      done

      # Sort by date (newest first)
      local -a sorted=()
      while IFS= read -r line; do
        [[ -n "$line" ]] && sorted+=("$line")
      done < <(printf '%s\n' "${sort_data[@]}" | sort -r)

      local kept=0
      for entry in "${sorted[@]}"; do
        [[ -z "$entry" ]] && continue
        local artifact="${entry#*|}"
        if (( kept < KEEP_LATEST )); then
          (( kept++ ))
        else
          delete_decision["$artifact"]="DELETE"
        fi
      done
    done
  fi

  # Apply max-total-size policy
  if [[ -n "$MAX_TOTAL_SIZE" ]]; then
    # Calculate total size of artifacts kept so far
    local total_kept_size=0
    declare -a kept_artifacts=()

    for artifact in "${artifact_list[@]}"; do
      if [[ "${delete_decision[$artifact]}" == "KEEP" ]]; then
        total_kept_size=$((total_kept_size + artifacts_size[$artifact]))
        kept_artifacts+=("${artifacts_date[$artifact]}|$artifact")
      fi
    done

    # If over limit, mark oldest for deletion
    if (( total_kept_size > MAX_TOTAL_SIZE )); then
      local -a sorted=()
      while IFS= read -r line; do
        [[ -n "$line" ]] && sorted+=("$line")
      done < <(printf '%s\n' "${kept_artifacts[@]}" | sort)

      for entry in "${sorted[@]}"; do
        [[ -z "$entry" ]] && continue
        local artifact="${entry#*|}"
        if (( total_kept_size <= MAX_TOTAL_SIZE )); then
          break
        fi
        delete_decision["$artifact"]="DELETE"
        total_kept_size=$((total_kept_size - artifacts_size[$artifact]))
      done
    fi
  fi

  # Generate output
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "=== DRY RUN MODE ==="
    echo ""
  fi

  echo "=== ARTIFACT CLEANUP PLAN ==="
  echo ""

  local total_artifacts=0
  local deleted_count=0
  local retained_count=0
  local deleted_size=0

  for artifact in "${artifact_list[@]}"; do
    (( total_artifacts++ ))

    if [[ "${delete_decision[$artifact]}" == "DELETE" ]]; then
      (( deleted_count++ ))
      deleted_size=$((deleted_size + artifacts_size[$artifact]))
      echo "DELETE: $artifact (size: ${artifacts_size[$artifact]} bytes, date: ${artifacts_date[$artifact]})"
    else
      (( retained_count++ ))
      echo "RETAIN: $artifact (size: ${artifacts_size[$artifact]} bytes, date: ${artifacts_date[$artifact]})"
    fi
  done

  echo ""
  echo "=== SUMMARY ==="
  echo "Total artifacts: $total_artifacts"
  echo "Artifacts to retain: $retained_count"
  echo "Artifacts to delete: $deleted_count"
  echo "Total space reclaimed: $deleted_size bytes"
  echo ""

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "This is a dry-run. No artifacts were deleted."
  fi
}

main "$@"
