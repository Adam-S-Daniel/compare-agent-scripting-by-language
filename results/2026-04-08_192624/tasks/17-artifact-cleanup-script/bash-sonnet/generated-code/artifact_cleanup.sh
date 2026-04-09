#!/usr/bin/env bash
# artifact_cleanup.sh - Apply retention policies to CI/CD artifacts
#
# Given a CSV list of artifacts with metadata, applies one or more retention
# policies and generates a deletion plan with a summary report.
#
# Usage:
#   artifact_cleanup.sh --artifacts FILE [OPTIONS]
#
# Policies (applied in order):
#   1. --max-age DAYS        Delete artifacts older than DAYS days
#   2. --keep-latest N       Keep only N newest per workflow_run_id group
#   3. --max-total-size BYTES  Delete oldest first until total <= limit
#
# CSV format (with header):
#   name,size_bytes,created_epoch,workflow_run_id
#
# Output format:
#   DELETE <name> <reason> <size_bytes>
#   RETAIN <name>
#   SUMMARY:total=N retained=M deleted=P space_reclaimed=Q

set -euo pipefail

# -----------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------
error() {
    echo "ERROR: $*" >&2
    exit 1
}

usage() {
    cat >&2 <<'EOF'
Usage: artifact_cleanup.sh --artifacts FILE [OPTIONS]

Options:
  --artifacts FILE       CSV file (header: name,size_bytes,created_epoch,workflow_run_id)
  --max-age DAYS         Delete artifacts older than DAYS days
  --keep-latest N        Keep only N latest artifacts per workflow run ID
  --max-total-size BYTES Delete oldest until total retained size <= BYTES
  --dry-run              Print deletion plan without marking as executed
  --reference-date EPOCH Override "now" for age calculations (default: current epoch)

EOF
    exit 1
}

# -----------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------
ARTIFACTS_FILE=""
MAX_AGE_DAYS=""
KEEP_LATEST=""
MAX_TOTAL_SIZE=""
DRY_RUN=false
REFERENCE_DATE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --artifacts)       ARTIFACTS_FILE="$2";  shift 2 ;;
        --max-age)         MAX_AGE_DAYS="$2";    shift 2 ;;
        --keep-latest)     KEEP_LATEST="$2";     shift 2 ;;
        --max-total-size)  MAX_TOTAL_SIZE="$2";  shift 2 ;;
        --dry-run)         DRY_RUN=true;         shift   ;;
        --reference-date)  REFERENCE_DATE="$2";  shift 2 ;;
        -h|--help)         usage ;;
        *)                 error "Unknown option: $1" ;;
    esac
done

# Validate required arguments
[[ -z "$ARTIFACTS_FILE" ]] && error "--artifacts FILE is required"
[[ ! -f "$ARTIFACTS_FILE" ]] && error "Artifact file not found: $ARTIFACTS_FILE"

# Default reference date to current Unix epoch
[[ -z "$REFERENCE_DATE" ]] && REFERENCE_DATE=$(date +%s)

# -----------------------------------------------------------------------
# Read CSV into parallel arrays (skip header row)
# -----------------------------------------------------------------------
declare -a NAMES=() SIZES=() EPOCHS=() RUN_IDS=()
# DELETE_FLAGS: 0=retain, 1=delete; DELETE_REASONS: policy that triggered deletion
declare -a DELETE_FLAGS=() DELETE_REASONS=()

while IFS=',' read -r name size epoch run_id; do
    NAMES+=("$name")
    SIZES+=("$size")
    EPOCHS+=("$epoch")
    RUN_IDS+=("$run_id")
    DELETE_FLAGS+=(0)
    DELETE_REASONS+=("")
done < <(tail -n +2 "$ARTIFACTS_FILE")

COUNT="${#NAMES[@]}"

# -----------------------------------------------------------------------
# Policy 1: max-age
# Mark artifacts for deletion if their age in days exceeds MAX_AGE_DAYS.
# -----------------------------------------------------------------------
if [[ -n "$MAX_AGE_DAYS" ]]; then
    max_age_seconds=$(( MAX_AGE_DAYS * 86400 ))
    for i in "${!NAMES[@]}"; do
        age_seconds=$(( REFERENCE_DATE - EPOCHS[i] ))
        if [[ "$age_seconds" -gt "$max_age_seconds" ]]; then
            DELETE_FLAGS[i]=1
            DELETE_REASONS[i]="max_age"
        fi
    done
fi

# -----------------------------------------------------------------------
# Policy 2: keep-latest-N
# For each workflow_run_id group, keep only the N most-recent artifacts
# (by created_epoch). Only considers artifacts not already marked deleted.
# -----------------------------------------------------------------------
if [[ -n "$KEEP_LATEST" ]]; then
    # Collect unique run IDs among retained artifacts
    declare -A seen_runs=()
    for i in "${!NAMES[@]}"; do
        [[ "${DELETE_FLAGS[i]}" -eq 1 ]] && continue
        seen_runs["${RUN_IDS[i]}"]=1
    done

    for run_id in "${!seen_runs[@]}"; do
        # Build "epoch<TAB>index" lines for sorting, then extract indices sorted newest-first
        sorted_indices=()
        while IFS=$'\t' read -r _epoch idx; do
            sorted_indices+=("$idx")
        done < <(
            for i in "${!NAMES[@]}"; do
                [[ "${DELETE_FLAGS[i]}" -eq 1 ]] && continue
                [[ "${RUN_IDS[i]}" != "$run_id" ]] && continue
                printf '%s\t%s\n' "${EPOCHS[i]}" "$i"
            done | sort -k1 -rn   # descending epoch → newest first
        )

        # Indices beyond position KEEP_LATEST are the oldest; mark them deleted
        for j in "${!sorted_indices[@]}"; do
            if [[ "$j" -ge "$KEEP_LATEST" ]]; then
                idx="${sorted_indices[$j]}"
                DELETE_FLAGS[idx]=1
                DELETE_REASONS[idx]="keep_latest"
            fi
        done
    done
fi

# -----------------------------------------------------------------------
# Policy 3: max-total-size
# If the total size of retained artifacts exceeds the limit, delete the
# oldest ones first until the total is at or below the limit.
# -----------------------------------------------------------------------
if [[ -n "$MAX_TOTAL_SIZE" ]]; then
    # Sum size of currently-retained artifacts
    total_size=0
    for i in "${!NAMES[@]}"; do
        [[ "${DELETE_FLAGS[i]}" -eq 1 ]] && continue
        total_size=$(( total_size + SIZES[i] ))
    done

    if [[ "$total_size" -gt "$MAX_TOTAL_SIZE" ]]; then
        # Sort retained artifacts oldest-first for greedy deletion
        while IFS=$'\t' read -r _epoch idx; do
            [[ "$total_size" -le "$MAX_TOTAL_SIZE" ]] && break
            DELETE_FLAGS[idx]=1
            DELETE_REASONS[idx]="max_total_size"
            total_size=$(( total_size - SIZES[idx] ))
        done < <(
            for i in "${!NAMES[@]}"; do
                [[ "${DELETE_FLAGS[i]}" -eq 1 ]] && continue
                printf '%s\t%s\n' "${EPOCHS[i]}" "$i"
            done | sort -k1 -n    # ascending epoch → oldest first
        )
    fi
fi

# -----------------------------------------------------------------------
# Generate output
# -----------------------------------------------------------------------
if [[ "$DRY_RUN" == true ]]; then
    echo "DRY-RUN MODE: the following plan will NOT be executed"
fi

deleted_count=0
retained_count=0
space_reclaimed=0

for i in "${!NAMES[@]}"; do
    if [[ "${DELETE_FLAGS[i]}" -eq 1 ]]; then
        echo "DELETE ${NAMES[i]} ${DELETE_REASONS[i]} ${SIZES[i]}"
        deleted_count=$(( deleted_count + 1 ))
        space_reclaimed=$(( space_reclaimed + SIZES[i] ))
    else
        echo "RETAIN ${NAMES[i]}"
        retained_count=$(( retained_count + 1 ))
    fi
done

echo "SUMMARY:total=${COUNT} retained=${retained_count} deleted=${deleted_count} space_reclaimed=${space_reclaimed}"
