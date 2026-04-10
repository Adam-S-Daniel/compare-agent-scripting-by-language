#!/usr/bin/env bash
# artifact-cleanup.sh — Apply retention policies to CI artifacts and generate a deletion plan.
#
# Input: A CSV file with artifact metadata (name,size_bytes,created_date,workflow_run_id)
# Policies: --max-age-days N, --max-total-size-bytes N, --keep-latest-n N
# Modes: --dry-run (default) shows plan without deleting; --execute would delete
#
# Output: Deletion plan with summary (space reclaimed, retained vs deleted counts)

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
MAX_AGE_DAYS=""
MAX_TOTAL_SIZE=""
KEEP_LATEST_N=""
DRY_RUN="true"
INPUT_FILE=""
NOW_EPOCH=""  # Allow injecting "now" for testability

usage() {
    cat <<'EOF'
Usage: artifact-cleanup.sh [OPTIONS] --input <file>

Options:
  --input <file>            CSV file with artifact metadata
                            (name,size_bytes,created_date,workflow_run_id)
  --max-age-days <N>        Delete artifacts older than N days
  --max-total-size-bytes <N> Keep total size under N bytes (deletes oldest first)
  --keep-latest-n <N>       Keep only the N most recent artifacts per workflow
  --dry-run                 Show deletion plan without acting (default)
  --execute                 Actually perform deletions
  --now <epoch>             Override current time (epoch seconds) for testing
  -h, --help                Show this help message
EOF
}

# ── Argument parsing ──────────────────────────────────────────────────────────
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --input)
                [[ $# -lt 2 ]] && { echo "ERROR: --input requires a value" >&2; exit 1; }
                INPUT_FILE="$2"; shift 2 ;;
            --max-age-days)
                [[ $# -lt 2 ]] && { echo "ERROR: --max-age-days requires a value" >&2; exit 1; }
                MAX_AGE_DAYS="$2"; shift 2 ;;
            --max-total-size-bytes)
                [[ $# -lt 2 ]] && { echo "ERROR: --max-total-size-bytes requires a value" >&2; exit 1; }
                MAX_TOTAL_SIZE="$2"; shift 2 ;;
            --keep-latest-n)
                [[ $# -lt 2 ]] && { echo "ERROR: --keep-latest-n requires a value" >&2; exit 1; }
                KEEP_LATEST_N="$2"; shift 2 ;;
            --dry-run)
                DRY_RUN="true"; shift ;;
            --execute)
                DRY_RUN="false"; shift ;;
            --now)
                [[ $# -lt 2 ]] && { echo "ERROR: --now requires a value" >&2; exit 1; }
                NOW_EPOCH="$2"; shift 2 ;;
            -h|--help)
                usage; exit 0 ;;
            *)
                echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
        esac
    done
}

# ── Validation ────────────────────────────────────────────────────────────────
validate_args() {
    if [[ -z "$INPUT_FILE" ]]; then
        echo "ERROR: --input is required" >&2
        exit 1
    fi
    if [[ ! -f "$INPUT_FILE" ]]; then
        echo "ERROR: Input file not found: $INPUT_FILE" >&2
        exit 1
    fi
    if [[ -z "$MAX_AGE_DAYS" && -z "$MAX_TOTAL_SIZE" && -z "$KEEP_LATEST_N" ]]; then
        echo "ERROR: At least one retention policy is required (--max-age-days, --max-total-size-bytes, --keep-latest-n)" >&2
        exit 1
    fi
    # Validate numeric values
    if [[ -n "$MAX_AGE_DAYS" ]] && ! [[ "$MAX_AGE_DAYS" =~ ^[0-9]+$ ]]; then
        echo "ERROR: --max-age-days must be a positive integer" >&2; exit 1
    fi
    if [[ -n "$MAX_TOTAL_SIZE" ]] && ! [[ "$MAX_TOTAL_SIZE" =~ ^[0-9]+$ ]]; then
        echo "ERROR: --max-total-size-bytes must be a positive integer" >&2; exit 1
    fi
    if [[ -n "$KEEP_LATEST_N" ]] && ! [[ "$KEEP_LATEST_N" =~ ^[0-9]+$ ]]; then
        echo "ERROR: --keep-latest-n must be a positive integer" >&2; exit 1
    fi
}

# ── Date helpers ──────────────────────────────────────────────────────────────
# Convert ISO date (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS) to epoch seconds
date_to_epoch() {
    local datestr="$1"
    # Use date -d for GNU date
    date -d "$datestr" +%s 2>/dev/null
}

get_now_epoch() {
    if [[ -n "$NOW_EPOCH" ]]; then
        echo "$NOW_EPOCH"
    else
        date +%s
    fi
}

# ── Core logic ────────────────────────────────────────────────────────────────

# Read artifacts from CSV into parallel arrays
# Globals set: NAMES, SIZES, DATES, EPOCHS, WORKFLOWS, ARTIFACT_COUNT
declare -a NAMES=() SIZES=() DATES=() EPOCHS=() WORKFLOWS=()
ARTIFACT_COUNT=0

read_artifacts() {
    local file="$1"
    local line_num=0

    while IFS=',' read -r name size created workflow_id; do
        line_num=$((line_num + 1))
        # Skip header line
        if [[ "$line_num" -eq 1 && "$name" == "name" ]]; then
            continue
        fi
        # Skip empty lines
        [[ -z "$name" ]] && continue

        local epoch
        epoch=$(date_to_epoch "$created")
        if [[ -z "$epoch" ]]; then
            echo "WARNING: Could not parse date '$created' for artifact '$name', skipping" >&2
            continue
        fi

        NAMES+=("$name")
        SIZES+=("$size")
        DATES+=("$created")
        EPOCHS+=("$epoch")
        WORKFLOWS+=("$workflow_id")
    done < "$file"

    ARTIFACT_COUNT=${#NAMES[@]}
}

# Apply retention policies and determine which artifacts to delete.
# Sets DELETE_FLAGS array: "delete" or "keep" for each artifact index.
declare -a DELETE_FLAGS=()
declare -a DELETE_REASONS=()

apply_policies() {
    local now_epoch
    now_epoch=$(get_now_epoch)

    # Initialize all as "keep"
    for ((i = 0; i < ARTIFACT_COUNT; i++)); do
        DELETE_FLAGS+=("keep")
        DELETE_REASONS+=("")
    done

    # Policy 1: Max age — delete artifacts older than N days
    if [[ -n "$MAX_AGE_DAYS" ]]; then
        local max_age_seconds=$((MAX_AGE_DAYS * 86400))
        for ((i = 0; i < ARTIFACT_COUNT; i++)); do
            local age=$((now_epoch - EPOCHS[i]))
            if [[ $age -gt $max_age_seconds ]]; then
                DELETE_FLAGS[i]="delete"
                DELETE_REASONS[i]="older than ${MAX_AGE_DAYS} days"
            fi
        done
    fi

    # Policy 2: Keep-latest-N per workflow — for each workflow, sort by date
    # descending, keep only the N newest, mark the rest for deletion
    if [[ -n "$KEEP_LATEST_N" ]]; then
        # Collect unique workflow IDs
        declare -A seen_workflows=()
        for ((i = 0; i < ARTIFACT_COUNT; i++)); do
            seen_workflows["${WORKFLOWS[$i]}"]=1
        done

        for wf_id in "${!seen_workflows[@]}"; do
            # Collect indices for this workflow, sorted by epoch descending
            local indices=()
            for ((i = 0; i < ARTIFACT_COUNT; i++)); do
                if [[ "${WORKFLOWS[$i]}" == "$wf_id" ]]; then
                    indices+=("$i")
                fi
            done

            # Sort indices by epoch descending (bubble sort — fine for small lists)
            local n=${#indices[@]}
            for ((a = 0; a < n; a++)); do
                for ((b = a + 1; b < n; b++)); do
                    if [[ ${EPOCHS[${indices[$a]}]} -lt ${EPOCHS[${indices[$b]}]} ]]; then
                        local tmp="${indices[$a]}"
                        indices[a]="${indices[$b]}"
                        indices[b]="$tmp"
                    fi
                done
            done

            # Mark artifacts beyond keep-latest-N for deletion
            local count=0
            for idx in "${indices[@]}"; do
                count=$((count + 1))
                if [[ $count -gt $KEEP_LATEST_N ]]; then
                    DELETE_FLAGS[idx]="delete"
                    if [[ -n "${DELETE_REASONS[$idx]}" ]]; then
                        DELETE_REASONS[idx]="${DELETE_REASONS[$idx]}; exceeds keep-latest-${KEEP_LATEST_N} for workflow ${wf_id}"
                    else
                        DELETE_REASONS[idx]="exceeds keep-latest-${KEEP_LATEST_N} for workflow ${wf_id}"
                    fi
                fi
            done
        done
    fi

    # Policy 3: Max total size — after other policies, if retained artifacts
    # exceed the budget, delete oldest-first until within budget
    if [[ -n "$MAX_TOTAL_SIZE" ]]; then
        # Collect retained artifact indices sorted by epoch ascending (oldest first)
        local retained_indices=()
        for ((i = 0; i < ARTIFACT_COUNT; i++)); do
            if [[ "${DELETE_FLAGS[$i]}" == "keep" ]]; then
                retained_indices+=("$i")
            fi
        done

        # Sort retained by epoch ascending
        local n=${#retained_indices[@]}
        for ((a = 0; a < n; a++)); do
            for ((b = a + 1; b < n; b++)); do
                if [[ ${EPOCHS[${retained_indices[$a]}]} -gt ${EPOCHS[${retained_indices[$b]}]} ]]; then
                    local tmp="${retained_indices[$a]}"
                    retained_indices[a]="${retained_indices[$b]}"
                    retained_indices[b]="$tmp"
                fi
            done
        done

        # Calculate total retained size
        local total_retained=0
        for idx in "${retained_indices[@]}"; do
            total_retained=$((total_retained + SIZES[idx]))
        done

        # Remove oldest retained artifacts until within budget
        for idx in "${retained_indices[@]}"; do
            if [[ $total_retained -le $MAX_TOTAL_SIZE ]]; then
                break
            fi
            DELETE_FLAGS[idx]="delete"
            if [[ -n "${DELETE_REASONS[$idx]}" ]]; then
                DELETE_REASONS[idx]="${DELETE_REASONS[$idx]}; total size exceeds ${MAX_TOTAL_SIZE} bytes"
            else
                DELETE_REASONS[idx]="total size exceeds ${MAX_TOTAL_SIZE} bytes"
            fi
            total_retained=$((total_retained - SIZES[idx]))
        done
    fi
}

# ── Output ────────────────────────────────────────────────────────────────────
generate_report() {
    local delete_count=0
    local retain_count=0
    local space_reclaimed=0
    local space_retained=0

    echo "============================================"
    echo "  ARTIFACT CLEANUP PLAN"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  Mode: DRY RUN (no deletions performed)"
    else
        echo "  Mode: EXECUTE"
    fi
    echo "============================================"
    echo ""

    # Policies applied
    echo "Policies applied:"
    [[ -n "$MAX_AGE_DAYS" ]] && echo "  - Max age: ${MAX_AGE_DAYS} days"
    [[ -n "$KEEP_LATEST_N" ]] && echo "  - Keep latest: ${KEEP_LATEST_N} per workflow"
    [[ -n "$MAX_TOTAL_SIZE" ]] && echo "  - Max total size: ${MAX_TOTAL_SIZE} bytes"
    echo ""

    # Deletion list
    echo "--- ARTIFACTS TO DELETE ---"
    for ((i = 0; i < ARTIFACT_COUNT; i++)); do
        if [[ "${DELETE_FLAGS[$i]}" == "delete" ]]; then
            delete_count=$((delete_count + 1))
            space_reclaimed=$((space_reclaimed + SIZES[i]))
            echo "  DELETE: ${NAMES[$i]} | size=${SIZES[$i]} | created=${DATES[$i]} | workflow=${WORKFLOWS[$i]} | reason: ${DELETE_REASONS[$i]}"
        fi
    done
    if [[ $delete_count -eq 0 ]]; then
        echo "  (none)"
    fi
    echo ""

    # Retention list
    echo "--- ARTIFACTS TO RETAIN ---"
    for ((i = 0; i < ARTIFACT_COUNT; i++)); do
        if [[ "${DELETE_FLAGS[$i]}" == "keep" ]]; then
            retain_count=$((retain_count + 1))
            space_retained=$((space_retained + SIZES[i]))
            echo "  KEEP:   ${NAMES[$i]} | size=${SIZES[$i]} | created=${DATES[$i]} | workflow=${WORKFLOWS[$i]}"
        fi
    done
    if [[ $retain_count -eq 0 ]]; then
        echo "  (none)"
    fi
    echo ""

    # Summary
    echo "============================================"
    echo "  SUMMARY"
    echo "============================================"
    echo "  Total artifacts:    ${ARTIFACT_COUNT}"
    echo "  Artifacts to delete: ${delete_count}"
    echo "  Artifacts to retain: ${retain_count}"
    echo "  Space reclaimed:    ${space_reclaimed} bytes"
    echo "  Space retained:     ${space_retained} bytes"
    echo "============================================"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"
    validate_args
    read_artifacts "$INPUT_FILE"

    if [[ $ARTIFACT_COUNT -eq 0 ]]; then
        echo "No artifacts found in input file." >&2
        exit 0
    fi

    apply_policies
    generate_report
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
