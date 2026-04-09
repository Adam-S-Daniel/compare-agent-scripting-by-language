#!/usr/bin/env bash
# artifact_cleanup.sh — Apply retention policies to a list of artifacts and
# generate a deletion plan with summary.
#
# INPUT FORMAT (TSV on stdin or via --input FILE):
#   name<TAB>size_bytes<TAB>creation_date(YYYY-MM-DD)<TAB>workflow_run_id
#
# RETENTION POLICIES (all optional, applied independently then merged):
#   --max-age DAYS        Delete artifacts older than DAYS days
#   --max-total-size BYTES  Keep total size under BYTES (removes oldest first)
#   --keep-latest-n N     Keep the N most recent artifacts per workflow run ID
#
# OPTIONS:
#   --dry-run             Print plan without marking deletions (default: true)
#   --execute             Actually print the deletion commands
#   --input FILE          Read artifacts from FILE instead of stdin
#   --reference-date DATE Use DATE (YYYY-MM-DD) as "today" for age calculations
#   --help                Show this help message
#
# OUTPUT: A human-readable deletion plan with summary statistics.

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
DRY_RUN=true
MAX_AGE=""
MAX_TOTAL_SIZE=""
KEEP_LATEST_N=""
INPUT_FILE=""
REFERENCE_DATE=""

# ── Helpers ───────────────────────────────────────────────────────────────────

usage() {
  sed -n '2,/^$/s/^# \?//p' "$0"
  exit 0
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# Convert YYYY-MM-DD to epoch seconds (portable: uses date -d or fallback).
date_to_epoch() {
  local d="$1"
  # Validate format
  if [[ ! "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    die "Invalid date format: '$d' (expected YYYY-MM-DD)"
  fi
  date -d "$d" +%s 2>/dev/null || die "Cannot parse date: $d"
}

# ── Parse arguments ──────────────────────────────────────────────────────────
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --max-age)
        [[ -n "${2:-}" ]] || die "--max-age requires a value"
        MAX_AGE="$2"; shift 2 ;;
      --max-total-size)
        [[ -n "${2:-}" ]] || die "--max-total-size requires a value"
        MAX_TOTAL_SIZE="$2"; shift 2 ;;
      --keep-latest-n)
        [[ -n "${2:-}" ]] || die "--keep-latest-n requires a value"
        KEEP_LATEST_N="$2"; shift 2 ;;
      --dry-run)
        DRY_RUN=true; shift ;;
      --execute)
        DRY_RUN=false; shift ;;
      --input)
        [[ -n "${2:-}" ]] || die "--input requires a file path"
        INPUT_FILE="$2"; shift 2 ;;
      --reference-date)
        [[ -n "${2:-}" ]] || die "--reference-date requires a value"
        REFERENCE_DATE="$2"; shift 2 ;;
      --help)
        usage ;;
      *)
        die "Unknown option: $1" ;;
    esac
  done
}

# ── Core logic ────────────────────────────────────────────────────────────────

# Globals populated by load_artifacts
declare -a ARTIFACT_NAMES=()
declare -a ARTIFACT_SIZES=()
declare -a ARTIFACT_DATES=()
declare -a ARTIFACT_WORKFLOWS=()
declare -a ARTIFACT_EPOCHS=()
declare -a DELETE_FLAGS=()   # "delete" or "keep"

load_artifacts() {
  local src="${1:--}"  # default stdin
  local line_num=0

  while IFS=$'\t' read -r name size cdate wfid; do
    line_num=$((line_num + 1))

    # Skip blank lines and comments
    [[ -z "$name" || "$name" == \#* ]] && continue

    # Validate fields
    [[ -n "$size" ]]  || die "Line $line_num: missing size field"
    [[ -n "$cdate" ]] || die "Line $line_num: missing creation_date field"
    [[ -n "$wfid" ]]  || die "Line $line_num: missing workflow_run_id field"
    [[ "$size" =~ ^[0-9]+$ ]] || die "Line $line_num: size must be numeric, got '$size'"

    local epoch
    epoch=$(date_to_epoch "$cdate")

    ARTIFACT_NAMES+=("$name")
    ARTIFACT_SIZES+=("$size")
    ARTIFACT_DATES+=("$cdate")
    ARTIFACT_WORKFLOWS+=("$wfid")
    ARTIFACT_EPOCHS+=("$epoch")
    DELETE_FLAGS+=("keep")
  done < <(if [[ "$src" == "-" ]]; then cat; else cat "$src"; fi)

  [[ ${#ARTIFACT_NAMES[@]} -gt 0 ]] || die "No artifacts loaded"
}

# Policy 1: max-age — mark artifacts older than MAX_AGE days for deletion
apply_max_age() {
  [[ -n "$MAX_AGE" ]] || return 0
  local ref_epoch
  if [[ -n "$REFERENCE_DATE" ]]; then
    ref_epoch=$(date_to_epoch "$REFERENCE_DATE")
  else
    ref_epoch=$(date +%s)
  fi
  local cutoff_epoch=$(( ref_epoch - MAX_AGE * 86400 ))

  for i in "${!ARTIFACT_NAMES[@]}"; do
    if (( ARTIFACT_EPOCHS[i] < cutoff_epoch )); then
      DELETE_FLAGS[i]="delete"
    fi
  done
}

# Policy 2: keep-latest-n — per workflow, keep only the N most recent artifacts
apply_keep_latest_n() {
  [[ -n "$KEEP_LATEST_N" ]] || return 0

  # Collect unique workflow IDs
  declare -A wf_indices
  for i in "${!ARTIFACT_NAMES[@]}"; do
    local wf="${ARTIFACT_WORKFLOWS[$i]}"
    wf_indices["$wf"]+="$i "
  done

  for wf in "${!wf_indices[@]}"; do
    # Sort indices by epoch descending
    local sorted
    sorted=$(
      for idx in ${wf_indices[$wf]}; do
        echo "${ARTIFACT_EPOCHS[$idx]} $idx"
      done | sort -rn | awk '{print $2}'
    )

    local count=0
    for idx in $sorted; do
      count=$((count + 1))
      if (( count > KEEP_LATEST_N )); then
        DELETE_FLAGS[idx]="delete"
      fi
    done
  done
}

# Policy 3: max-total-size — enforce total size budget (remove oldest first)
apply_max_total_size() {
  [[ -n "$MAX_TOTAL_SIZE" ]] || return 0

  # Calculate current total of kept artifacts
  local total=0
  for i in "${!ARTIFACT_NAMES[@]}"; do
    if [[ "${DELETE_FLAGS[$i]}" == "keep" ]]; then
      total=$((total + ARTIFACT_SIZES[i]))
    fi
  done

  if (( total <= MAX_TOTAL_SIZE )); then
    return 0
  fi

  # Sort kept artifacts by epoch ascending (oldest first) for removal
  local sorted
  sorted=$(
    for i in "${!ARTIFACT_NAMES[@]}"; do
      if [[ "${DELETE_FLAGS[$i]}" == "keep" ]]; then
        echo "${ARTIFACT_EPOCHS[$i]} $i"
      fi
    done | sort -n | awk '{print $2}'
  )

  for idx in $sorted; do
    if (( total <= MAX_TOTAL_SIZE )); then
      break
    fi
    DELETE_FLAGS[idx]="delete"
    total=$((total - ARTIFACT_SIZES[idx]))
  done
}

# ── Output ────────────────────────────────────────────────────────────────────

print_plan() {
  local delete_count=0 keep_count=0
  local delete_size=0 keep_size=0

  echo "========================================"
  echo "  ARTIFACT CLEANUP PLAN"
  if [[ "$DRY_RUN" == true ]]; then
    echo "  Mode: DRY-RUN (no deletions)"
  else
    echo "  Mode: EXECUTE"
  fi
  echo "========================================"
  echo ""

  # Artifacts to DELETE
  echo "--- Artifacts to DELETE ---"
  for i in "${!ARTIFACT_NAMES[@]}"; do
    if [[ "${DELETE_FLAGS[$i]}" == "delete" ]]; then
      delete_count=$((delete_count + 1))
      delete_size=$((delete_size + ARTIFACT_SIZES[i]))
      echo "  [DELETE] ${ARTIFACT_NAMES[$i]}  size=${ARTIFACT_SIZES[$i]}  date=${ARTIFACT_DATES[$i]}  workflow=${ARTIFACT_WORKFLOWS[$i]}"
    fi
  done
  if (( delete_count == 0 )); then
    echo "  (none)"
  fi
  echo ""

  # Artifacts to KEEP
  echo "--- Artifacts to KEEP ---"
  for i in "${!ARTIFACT_NAMES[@]}"; do
    if [[ "${DELETE_FLAGS[$i]}" == "keep" ]]; then
      keep_count=$((keep_count + 1))
      keep_size=$((keep_size + ARTIFACT_SIZES[i]))
      echo "  [KEEP]   ${ARTIFACT_NAMES[$i]}  size=${ARTIFACT_SIZES[$i]}  date=${ARTIFACT_DATES[$i]}  workflow=${ARTIFACT_WORKFLOWS[$i]}"
    fi
  done
  if (( keep_count == 0 )); then
    echo "  (none)"
  fi
  echo ""

  # Summary
  echo "--- Summary ---"
  echo "  Total artifacts: $(( delete_count + keep_count ))"
  echo "  Artifacts to delete: ${delete_count}"
  echo "  Artifacts to keep: ${keep_count}"
  echo "  Space reclaimed: ${delete_size} bytes"
  echo "  Space retained: ${keep_size} bytes"
  echo "========================================"

  # If in execute mode, print deletion commands
  if [[ "$DRY_RUN" == false ]]; then
    echo ""
    echo "--- Deletion Commands ---"
    for i in "${!ARTIFACT_NAMES[@]}"; do
      if [[ "${DELETE_FLAGS[$i]}" == "delete" ]]; then
        echo "  gh api -X DELETE /repos/{owner}/{repo}/actions/artifacts/${ARTIFACT_NAMES[$i]}"
      fi
    done
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
  parse_args "$@"

  if [[ -n "$INPUT_FILE" ]]; then
    [[ -f "$INPUT_FILE" ]] || die "Input file not found: $INPUT_FILE"
    load_artifacts "$INPUT_FILE"
  else
    load_artifacts "-"
  fi

  # Apply policies in order: age, keep-latest-n, then size budget
  apply_max_age
  apply_keep_latest_n
  apply_max_total_size

  print_plan
}

# Only run main if not being sourced (allows testing internal functions)
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
