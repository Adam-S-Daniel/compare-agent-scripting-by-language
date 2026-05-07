#!/usr/bin/env bash

# Artifact Cleanup Script
# Reads a JSON list of artifacts with metadata, applies retention policies,
# and generates a deletion plan with a summary.
#
# Policies (any combination may be used together):
#   --max-age-days N          Delete artifacts older than N days
#   --max-total-size-bytes N  Delete oldest artifacts until total size is under N bytes
#   --keep-latest-n N         Keep only N most recent artifacts per workflow_run_id
#
# Artifacts JSON format:
#   [{"name":"...","size":<bytes>,"created_at":"<ISO8601>","workflow_run_id":"..."}]

set -euo pipefail

MAX_AGE_DAYS=""
MAX_TOTAL_SIZE_BYTES=""
KEEP_LATEST_N=""
DRY_RUN=false
ARTIFACTS_FILE=""

usage() {
    cat >&2 <<'EOF'
Usage: artifact-cleanup.sh [OPTIONS] <artifacts-file.json>

Options:
  --max-age-days N          Delete artifacts older than N days
  --max-total-size-bytes N  Delete oldest artifacts until total size is under N bytes
  --keep-latest-n N         Keep only N most recent artifacts per workflow run ID
  --dry-run                 Show deletion plan without executing
  -h, --help                Show this help

The artifacts JSON file must be an array of objects with keys:
  name, size (bytes integer), created_at (ISO8601 string), workflow_run_id
EOF
    exit 1
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --max-age-days)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --max-age-days requires a value" >&2; exit 1
            fi
            MAX_AGE_DAYS="$2"; shift 2 ;;
        --max-total-size-bytes)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --max-total-size-bytes requires a value" >&2; exit 1
            fi
            MAX_TOTAL_SIZE_BYTES="$2"; shift 2 ;;
        --keep-latest-n)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --keep-latest-n requires a value" >&2; exit 1
            fi
            KEEP_LATEST_N="$2"; shift 2 ;;
        --dry-run)
            DRY_RUN=true; shift ;;
        -h|--help)
            usage ;;
        -*)
            echo "Error: Unknown option: $1" >&2; usage ;;
        *)
            ARTIFACTS_FILE="$1"; shift ;;
    esac
done

if [[ -z "$ARTIFACTS_FILE" ]]; then
    echo "Error: artifacts file is required" >&2
    usage
fi

if [[ ! -f "$ARTIFACTS_FILE" ]]; then
    echo "Error: artifacts file not found: $ARTIFACTS_FILE" >&2
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed" >&2
    exit 1
fi

ARTIFACTS=$(jq '.' "$ARTIFACTS_FILE" 2>/dev/null) || {
    echo "Error: invalid JSON in artifacts file: $ARTIFACTS_FILE" >&2
    exit 1
}

TOTAL_COUNT=$(echo "$ARTIFACTS" | jq 'length')

if [[ "$TOTAL_COUNT" -eq 0 ]]; then
    echo "=== Artifact Cleanup Plan ==="
    echo ""
    echo "Artifacts to delete: 0"
    echo "Artifacts to retain: 0"
    echo ""
    echo "--- Summary ---"
    echo "Total artifacts: 0"
    echo "Artifacts deleted: 0"
    echo "Artifacts retained: 0"
    echo "Space reclaimed: 0 bytes"
    exit 0
fi

# DELETE_REASONS[i] is empty → retain; non-empty → delete with that reason
declare -a DELETE_REASONS
for ((i=0; i<TOTAL_COUNT; i++)); do
    DELETE_REASONS[i]=""
done

# ── Policy 1: Max age ─────────────────────────────────────────────────────────
if [[ -n "$MAX_AGE_DAYS" ]]; then
    NOW=$(date +%s)
    MAX_AGE_SECONDS=$((MAX_AGE_DAYS * 86400))
    while IFS=$'\t' read -r idx created_at; do
        created_ts=$(date -d "$created_at" +%s 2>/dev/null) || continue
        age_seconds=$((NOW - created_ts))
        if [[ $age_seconds -gt $MAX_AGE_SECONDS ]]; then
            DELETE_REASONS[idx]="age exceeds ${MAX_AGE_DAYS} days"
        fi
    done < <(echo "$ARTIFACTS" | jq -r 'to_entries[] | [(.key | tostring), .value.created_at] | @tsv')
fi

# ── Policy 2: Keep latest N per workflow_run_id ───────────────────────────────
# Sort each workflow's artifacts newest-first; mark rank > N for deletion.
if [[ -n "$KEEP_LATEST_N" ]]; then
    while IFS= read -r workflow_id; do
        rank=0
        while IFS= read -r idx; do
            rank=$((rank + 1))
            if [[ $rank -gt $KEEP_LATEST_N ]]; then
                reason="exceeds keep-latest-${KEEP_LATEST_N} for workflow ${workflow_id}"
                if [[ -n "${DELETE_REASONS[idx]:-}" ]]; then
                    DELETE_REASONS[idx]="${DELETE_REASONS[idx]}; ${reason}"
                else
                    DELETE_REASONS[idx]="$reason"
                fi
            fi
        done < <(echo "$ARTIFACTS" | jq -r --arg wid "$workflow_id" \
            'to_entries
             | map(select(.value.workflow_run_id == $wid))
             | sort_by(.value.created_at)
             | reverse
             | .[].key
             | tostring')
    done < <(echo "$ARTIFACTS" | jq -r '[.[].workflow_run_id] | unique[]')
fi

# ── Policy 3: Max total size (delete oldest first until under limit) ──────────
if [[ -n "$MAX_TOTAL_SIZE_BYTES" ]]; then
    # Sum sizes of artifacts not already marked for deletion
    current_total=0
    while IFS=$'\t' read -r idx size; do
        if [[ -z "${DELETE_REASONS[idx]:-}" ]]; then
            current_total=$((current_total + size))
        fi
    done < <(echo "$ARTIFACTS" | jq -r 'to_entries[] | [(.key | tostring), (.value.size | tostring)] | @tsv')

    if [[ $current_total -gt $MAX_TOTAL_SIZE_BYTES ]]; then
        # Walk artifacts oldest-first, deleting until under the limit
        while IFS=$'\t' read -r idx size; do
            if [[ $current_total -le $MAX_TOTAL_SIZE_BYTES ]]; then
                break
            fi
            if [[ -z "${DELETE_REASONS[idx]:-}" ]]; then
                DELETE_REASONS[idx]="total size exceeds ${MAX_TOTAL_SIZE_BYTES} bytes"
                current_total=$((current_total - size))
            fi
        done < <(echo "$ARTIFACTS" \
            | jq -r 'to_entries
                     | sort_by(.value.created_at)
                     | .[]
                     | [(.key | tostring), (.value.size | tostring)]
                     | @tsv')
    fi
fi

# ── Build summary ─────────────────────────────────────────────────────────────
DELETE_COUNT=0
SPACE_RECLAIMED=0
for ((i=0; i<TOTAL_COUNT; i++)); do
    if [[ -n "${DELETE_REASONS[$i]:-}" ]]; then
        DELETE_COUNT=$((DELETE_COUNT + 1))
        size=$(echo "$ARTIFACTS" | jq --argjson idx "$i" '.[$idx].size')
        SPACE_RECLAIMED=$((SPACE_RECLAIMED + size))
    fi
done
RETAIN_COUNT=$((TOTAL_COUNT - DELETE_COUNT))

# ── Output ────────────────────────────────────────────────────────────────────
echo "=== Artifact Cleanup Plan ==="
if [[ "$DRY_RUN" == "true" ]]; then
    echo "(DRY RUN - no artifacts will be deleted)"
fi
echo ""
echo "Artifacts to delete: ${DELETE_COUNT}"
echo "Artifacts to retain: ${RETAIN_COUNT}"
echo ""

if [[ $DELETE_COUNT -gt 0 ]]; then
    echo "--- Deletion List ---"
    for ((i=0; i<TOTAL_COUNT; i++)); do
        if [[ -n "${DELETE_REASONS[$i]:-}" ]]; then
            name=$(echo "$ARTIFACTS" | jq -r --argjson idx "$i" '.[$idx].name')
            size=$(echo "$ARTIFACTS" | jq -r --argjson idx "$i" '.[$idx].size')
            created_at=$(echo "$ARTIFACTS" | jq -r --argjson idx "$i" '.[$idx].created_at')
            reason="${DELETE_REASONS[$i]}"
            echo "  DELETE: ${name} (size: ${size} bytes, created: ${created_at}, reason: ${reason})"
        fi
    done
    echo ""
fi

echo "--- Summary ---"
echo "Total artifacts: ${TOTAL_COUNT}"
echo "Artifacts deleted: ${DELETE_COUNT}"
echo "Artifacts retained: ${RETAIN_COUNT}"
echo "Space reclaimed: ${SPACE_RECLAIMED} bytes"
