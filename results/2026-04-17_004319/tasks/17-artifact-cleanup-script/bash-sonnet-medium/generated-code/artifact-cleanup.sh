#!/usr/bin/env bash
# artifact-cleanup.sh
# Applies retention policies to GitHub Actions artifacts and generates a deletion plan.
# Policies supported: --max-age-days, --max-total-size, --keep-latest-n
# Supports --dry-run mode (prints plan without executing deletions).

set -euo pipefail

# ---------- defaults ----------
ARTIFACTS_FILE=""
MAX_AGE_DAYS=""
MAX_TOTAL_SIZE=""
KEEP_LATEST_N=""
DRY_RUN=false
# Override today's date for deterministic tests
REFERENCE_DATE=""

usage() {
    cat <<'EOF'
Usage: artifact-cleanup.sh [OPTIONS]

Options:
  --artifacts FILE        Path to CSV file with artifact metadata (required)
  --max-age-days N        Delete artifacts older than N days
  --max-total-size BYTES  Delete oldest artifacts until total size <= BYTES
  --keep-latest-n N       Keep only the N most recent artifacts per workflow run ID
  --dry-run               Print deletion plan without executing any deletions
  --reference-date DATE   Use DATE (YYYY-MM-DD) as today instead of system date
  --help                  Show this help message

CSV format (with header):
  name,size_bytes,created_date,workflow_run_id
EOF
}

die() {
    echo "Error: $*" >&2
    exit 1
}

# ---------- parse arguments ----------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --artifacts)       ARTIFACTS_FILE="$2"; shift 2 ;;
        --max-age-days)    MAX_AGE_DAYS="$2"; shift 2 ;;
        --max-total-size)  MAX_TOTAL_SIZE="$2"; shift 2 ;;
        --keep-latest-n)   KEEP_LATEST_N="$2"; shift 2 ;;
        --dry-run)         DRY_RUN=true; shift ;;
        --reference-date)  REFERENCE_DATE="$2"; shift 2 ;;
        --help)            usage; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
done

[[ -n "$ARTIFACTS_FILE" ]] || die "Missing required --artifacts FILE argument"
[[ -f "$ARTIFACTS_FILE" ]] || die "Artifacts file not found: $ARTIFACTS_FILE"

# ---------- date helpers ----------
# Returns epoch seconds for a YYYY-MM-DD string
date_to_epoch() {
    local d="$1"
    date -d "$d" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$d" +%s
}

today_epoch() {
    if [[ -n "$REFERENCE_DATE" ]]; then
        date_to_epoch "$REFERENCE_DATE"
    else
        date +%s
    fi
}

# ---------- load artifacts from CSV ----------
# Arrays parallel-indexed: name[i], size[i], created[i], workflow[i], action[i]
declare -a ART_NAME ART_SIZE ART_CREATED ART_WORKFLOW ART_EPOCH
declare -a DECISION  # RETAIN or DELETE
COUNT=0

{
    read -r _header  # skip header line
    while IFS=',' read -r name size_bytes created_date workflow_run_id; do
        # Skip blank lines
        [[ -z "$name" ]] && continue
        ART_NAME[COUNT]="$name"
        ART_SIZE[COUNT]="$size_bytes"
        ART_CREATED[COUNT]="$created_date"
        ART_WORKFLOW[COUNT]="$workflow_run_id"
        ART_EPOCH[COUNT]=$(date_to_epoch "$created_date")
        DECISION[COUNT]="RETAIN"
        (( COUNT++ )) || true
    done
} < "$ARTIFACTS_FILE"

# ---------- Policy 1: max-age-days ----------
if [[ -n "$MAX_AGE_DAYS" ]]; then
    today=$(today_epoch)
    cutoff=$(( today - MAX_AGE_DAYS * 86400 ))
    for (( i=0; i<COUNT; i++ )); do
        if [[ "${ART_EPOCH[$i]}" -lt "$cutoff" ]]; then
            DECISION[i]="DELETE:age"
        fi
    done
fi

# ---------- Policy 2: keep-latest-n (per workflow_run_id) ----------
# For each workflow, sort its artifacts newest-first and mark older ones for deletion.
if [[ -n "$KEEP_LATEST_N" ]]; then
    # Collect unique workflow IDs
    declare -A seen_workflows
    for (( i=0; i<COUNT; i++ )); do
        seen_workflows["${ART_WORKFLOW[$i]}"]=1
    done

    for wf in "${!seen_workflows[@]}"; do
        # Collect indices for this workflow, sort by epoch descending
        mapfile -t wf_indices < <(
            for (( i=0; i<COUNT; i++ )); do
                if [[ "${ART_WORKFLOW[$i]}" == "$wf" ]]; then
                    echo "${ART_EPOCH[$i]} $i"
                fi
            done | sort -rn | awk '{print $2}'
        )

        # Keep the first KEEP_LATEST_N; mark the rest
        for (( j=KEEP_LATEST_N; j<${#wf_indices[@]}; j++ )); do
            idx="${wf_indices[$j]}"
            if [[ "${DECISION[idx]}" == "RETAIN" ]]; then
                DECISION[idx]="DELETE:keep-latest"
            fi
        done
    done
fi

# ---------- Policy 3: max-total-size ----------
# After applying previous policies, if the total retained size still exceeds the
# limit, delete the oldest retained artifacts one by one until under the limit.
if [[ -n "$MAX_TOTAL_SIZE" ]]; then
    # Calculate total size of currently-retained artifacts
    total=0
    for (( i=0; i<COUNT; i++ )); do
        if [[ "${DECISION[i]}" == "RETAIN" ]]; then
            total=$(( total + ART_SIZE[i] ))
        fi
    done

    if (( total > MAX_TOTAL_SIZE )); then
        # Build list of retained indices sorted oldest-first
        mapfile -t retained_sorted < <(
            for (( i=0; i<COUNT; i++ )); do
                if [[ "${DECISION[i]}" == "RETAIN" ]]; then
                    echo "${ART_EPOCH[$i]} $i"
                fi
            done | sort -n | awk '{print $2}'
        )

        for idx in "${retained_sorted[@]}"; do
            (( total <= MAX_TOTAL_SIZE )) && break
            DECISION[idx]="DELETE:size"
            total=$(( total - ART_SIZE[idx] ))
        done
    fi
fi

# ---------- build summary ----------
delete_count=0
retain_count=0
reclaimed=0

for (( i=0; i<COUNT; i++ )); do
    if [[ "${DECISION[i]}" == RETAIN ]]; then
        (( retain_count++ )) || true
    else
        (( delete_count++ )) || true
        (( reclaimed += ART_SIZE[i] )) || true
    fi
done

# ---------- output deletion plan ----------
echo "=== Artifact Cleanup Plan ==="
echo ""

if (( COUNT == 0 )); then
    echo "No artifacts found. 0 to delete, 0 to retain."
    echo "Space reclaimed: 0 bytes"
    exit 0
fi

for (( i=0; i<COUNT; i++ )); do
    reason="${DECISION[i]}"
    if [[ "$reason" == "RETAIN" ]]; then
        echo "  RETAIN  ${ART_NAME[$i]}  (${ART_SIZE[i]} bytes, ${ART_CREATED[$i]}, ${ART_WORKFLOW[$i]})"
    else
        echo "  DELETE  ${ART_NAME[$i]}  (${ART_SIZE[i]} bytes, ${ART_CREATED[$i]}, ${ART_WORKFLOW[$i]})  reason: ${reason#DELETE:}"
    fi
done

echo ""
echo "=== Summary ==="
echo "  Deleted: $delete_count artifact(s)"
echo "  Retained: $retain_count artifact(s)"

# Human-readable size
if (( reclaimed >= 1048576 )); then
    mb=$(( reclaimed / 1048576 ))
    echo "  Space reclaimed: $reclaimed bytes (${mb} MB)"
else
    echo "  Space reclaimed: $reclaimed bytes"
fi

# ---------- execute deletions in non-dry-run mode ----------
if [[ "$DRY_RUN" == "false" ]]; then
    echo ""
    echo "=== Executing Deletions ==="
    for (( i=0; i<COUNT; i++ )); do
        if [[ "${DECISION[i]}" != "RETAIN" ]]; then
            echo "  gh artifact delete \"${ART_NAME[$i]}\""
            # In a real pipeline: gh api -X DELETE "repos/{owner}/{repo}/actions/artifacts/{id}"
            # Here we emit the command; actual deletion is caller's responsibility.
        fi
    done
fi
