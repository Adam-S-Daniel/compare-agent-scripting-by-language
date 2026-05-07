#!/usr/bin/env bash
# Artifact cleanup script: applies retention policies to a list of artifacts
# and generates a deletion plan.
#
# Input format (one artifact per line, pipe-delimited):
#   name|size_bytes|creation_epoch|workflow_run_id
#
# Usage:
#   artifact-cleanup.sh [OPTIONS] <artifacts_file>
#
# Options:
#   --max-age DAYS         Delete artifacts older than N days
#   --max-total-size BYTES Keep total size under limit (oldest first)
#   --keep-latest N        Keep N most recent artifacts per workflow run ID
#   --dry-run              Show plan without executing deletions
#   --reference-time EPOCH Use this as "now" instead of current time
#   --help                 Show this help message

set -euo pipefail

usage() {
    sed -n '2,/^$/s/^# \?//p' "$0"
    exit 0
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

MAX_AGE_DAYS=""
MAX_TOTAL_SIZE=""
KEEP_LATEST=""
DRY_RUN=false
REFERENCE_TIME=""
ARTIFACTS_FILE=""

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --max-age)
                [[ -n "${2:-}" ]] || die "--max-age requires a value"
                MAX_AGE_DAYS="$2"
                shift 2
                ;;
            --max-total-size)
                [[ -n "${2:-}" ]] || die "--max-total-size requires a value"
                MAX_TOTAL_SIZE="$2"
                shift 2
                ;;
            --keep-latest)
                [[ -n "${2:-}" ]] || die "--keep-latest requires a value"
                KEEP_LATEST="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --reference-time)
                [[ -n "${2:-}" ]] || die "--reference-time requires a value"
                REFERENCE_TIME="$2"
                shift 2
                ;;
            --help)
                usage
                ;;
            -*)
                die "Unknown option: $1"
                ;;
            *)
                [[ -z "$ARTIFACTS_FILE" ]] || die "Multiple artifact files specified"
                ARTIFACTS_FILE="$1"
                shift
                ;;
        esac
    done
}

validate_inputs() {
    [[ -n "$ARTIFACTS_FILE" ]] || die "No artifacts file specified"
    [[ -f "$ARTIFACTS_FILE" ]] || die "Artifacts file not found: $ARTIFACTS_FILE"

    if [[ -n "$MAX_AGE_DAYS" ]]; then
        [[ "$MAX_AGE_DAYS" =~ ^[0-9]+$ ]] || die "--max-age must be a positive integer"
    fi
    if [[ -n "$MAX_TOTAL_SIZE" ]]; then
        [[ "$MAX_TOTAL_SIZE" =~ ^[0-9]+$ ]] || die "--max-total-size must be a positive integer"
    fi
    if [[ -n "$KEEP_LATEST" ]]; then
        [[ "$KEEP_LATEST" =~ ^[0-9]+$ ]] || die "--keep-latest must be a positive integer"
    fi

    if [[ -z "$MAX_AGE_DAYS" && -z "$MAX_TOTAL_SIZE" && -z "$KEEP_LATEST" ]]; then
        die "At least one retention policy must be specified"
    fi
}

now_epoch() {
    if [[ -n "$REFERENCE_TIME" ]]; then
        echo "$REFERENCE_TIME"
    else
        date +%s
    fi
}

# Read artifacts into parallel arrays for processing
declare -a ART_NAMES=()
declare -a ART_SIZES=()
declare -a ART_EPOCHS=()
declare -a ART_WORKFLOWS=()
declare -a ART_DELETE=()

load_artifacts() {
    local line name size epoch workflow lineno=0
    while IFS= read -r line; do
        lineno=$((lineno + 1))
        # Skip empty lines and comments
        [[ -z "$line" || "$line" == \#* ]] && continue

        IFS='|' read -r name size epoch workflow <<< "$line"

        [[ -n "$name" ]] || die "Line $lineno: missing artifact name"
        [[ "$size" =~ ^[0-9]+$ ]] || die "Line $lineno: invalid size '$size'"
        [[ "$epoch" =~ ^[0-9]+$ ]] || die "Line $lineno: invalid epoch '$epoch'"
        [[ -n "$workflow" ]] || die "Line $lineno: missing workflow run ID"

        ART_NAMES+=("$name")
        ART_SIZES+=("$size")
        ART_EPOCHS+=("$epoch")
        ART_WORKFLOWS+=("$workflow")
        ART_DELETE+=(false)
    done < "$ARTIFACTS_FILE"

    [[ ${#ART_NAMES[@]} -gt 0 ]] || die "No artifacts found in $ARTIFACTS_FILE"
}

apply_max_age() {
    [[ -n "$MAX_AGE_DAYS" ]] || return 0
    local now cutoff_epoch age_seconds
    now=$(now_epoch)
    age_seconds=$((MAX_AGE_DAYS * 86400))
    cutoff_epoch=$((now - age_seconds))

    for i in "${!ART_NAMES[@]}"; do
        if [[ "${ART_EPOCHS[i]}" -lt "$cutoff_epoch" ]]; then
            ART_DELETE[i]=true
        fi
    done
}

apply_keep_latest() {
    [[ -n "$KEEP_LATEST" ]] || return 0

    # Collect unique workflow IDs
    declare -A workflows
    for i in "${!ART_NAMES[@]}"; do
        workflows["${ART_WORKFLOWS[$i]}"]=1
    done

    for wf in "${!workflows[@]}"; do
        # Get indices for this workflow, sorted by epoch descending
        local indices=()
        for i in "${!ART_NAMES[@]}"; do
            [[ "${ART_WORKFLOWS[$i]}" == "$wf" ]] && indices+=("$i")
        done

        # Sort indices by epoch descending (newest first)
        local sorted
        mapfile -t sorted < <(for idx in "${indices[@]}"; do
            echo "${ART_EPOCHS[idx]} $idx"
        done | sort -rn | awk '{print $2}')

        # Mark artifacts beyond keep-latest for deletion
        local count=0
        for idx in "${sorted[@]}"; do
            count=$((count + 1))
            if [[ $count -gt $KEEP_LATEST ]]; then
                ART_DELETE[idx]=true
            fi
        done
    done
}

apply_max_total_size() {
    [[ -n "$MAX_TOTAL_SIZE" ]] || return 0

    # Calculate total size of non-deleted artifacts
    local total=0
    for i in "${!ART_NAMES[@]}"; do
        [[ "${ART_DELETE[i]}" == "true" ]] && continue
        total=$((total + ART_SIZES[i]))
    done

    # If already under limit, nothing to do
    [[ $total -gt $MAX_TOTAL_SIZE ]] || return 0

    # Get non-deleted indices sorted by epoch ascending (oldest first)
    local indices=()
    for i in "${!ART_NAMES[@]}"; do
        [[ "${ART_DELETE[i]}" == "true" ]] && continue
        indices+=("$i")
    done

    local sorted
    mapfile -t sorted < <(for idx in "${indices[@]}"; do
        echo "${ART_EPOCHS[idx]} $idx"
    done | sort -n | awk '{print $2}')

    # Delete oldest artifacts until under limit
    for idx in "${sorted[@]}"; do
        [[ $total -le $MAX_TOTAL_SIZE ]] && break
        ART_DELETE[idx]=true
        total=$((total - ART_SIZES[idx]))
    done
}

format_size() {
    local bytes=$1
    if [[ $bytes -ge 1073741824 ]]; then
        echo "$(awk "BEGIN{printf \"%.2f\", $bytes/1073741824}")GB"
    elif [[ $bytes -ge 1048576 ]]; then
        echo "$(awk "BEGIN{printf \"%.2f\", $bytes/1048576}")MB"
    elif [[ $bytes -ge 1024 ]]; then
        echo "$(awk "BEGIN{printf \"%.2f\", $bytes/1024}")KB"
    else
        echo "${bytes}B"
    fi
}

generate_plan() {
    local delete_count=0 retain_count=0 delete_size=0 retain_size=0

    echo "=== Artifact Cleanup Plan ==="
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "Mode: DRY RUN (no artifacts will be deleted)"
    else
        echo "Mode: EXECUTE"
    fi
    echo ""

    echo "--- Artifacts to DELETE ---"
    for i in "${!ART_NAMES[@]}"; do
        if [[ "${ART_DELETE[$i]}" == "true" ]]; then
            delete_count=$((delete_count + 1))
            delete_size=$((delete_size + ART_SIZES[i]))
            echo "  DELETE: ${ART_NAMES[$i]} ($(format_size "${ART_SIZES[$i]}"), workflow=${ART_WORKFLOWS[$i]})"
        fi
    done
    [[ $delete_count -gt 0 ]] || echo "  (none)"
    echo ""

    echo "--- Artifacts to RETAIN ---"
    for i in "${!ART_NAMES[@]}"; do
        if [[ "${ART_DELETE[$i]}" == "false" ]]; then
            retain_count=$((retain_count + 1))
            retain_size=$((retain_size + ART_SIZES[i]))
            echo "  RETAIN: ${ART_NAMES[$i]} ($(format_size "${ART_SIZES[$i]}"), workflow=${ART_WORKFLOWS[$i]})"
        fi
    done
    [[ $retain_count -gt 0 ]] || echo "  (none)"
    echo ""

    echo "--- Summary ---"
    echo "Total artifacts: $((delete_count + retain_count))"
    echo "Artifacts to delete: $delete_count"
    echo "Artifacts to retain: $retain_count"
    echo "Space reclaimed: $(format_size "$delete_size")"
    echo "Space retained: $(format_size "$retain_size")"
}

main() {
    parse_args "$@"
    validate_inputs
    load_artifacts
    apply_max_age
    apply_keep_latest
    apply_max_total_size
    generate_plan
}

# Only run main if not being sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
