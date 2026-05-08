#!/usr/bin/env bash
# artifact-cleanup.sh
#
# Apply retention policies to GitHub Actions artifacts and produce a
# deletion plan. Supports three independent policies applied in order:
#
#   1. max_age      — delete artifacts older than max_age_days
#   2. keep_latest_n — per run_id, keep only the N most-recent artifacts
#   3. max_total_size — delete oldest remaining until total <= max_total_size_bytes
#
# Usage:
#   artifact-cleanup.sh --artifacts <file> --policy <file> [--dry-run]
#
# Environment:
#   REFERENCE_DATE  ISO-8601 date (YYYY-MM-DD) used as "today" for age
#                   calculations. Defaults to the actual current date.
#                   Set this in tests for deterministic output.

set -euo pipefail

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
ARTIFACTS_FILE=""
POLICY_FILE=""
DRY_RUN=false

usage() {
    echo "Usage: $0 --artifacts <file> --policy <file> [--dry-run]" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --artifacts) ARTIFACTS_FILE="$2"; shift 2 ;;
        --policy)    POLICY_FILE="$2";    shift 2 ;;
        --dry-run)   DRY_RUN=true;        shift   ;;
        -h|--help)   usage ;;
        *) echo "ERROR: unknown argument: $1" >&2; usage ;;
    esac
done

[[ -n "$ARTIFACTS_FILE" ]] || { echo "ERROR: --artifacts is required" >&2; usage; }
[[ -n "$POLICY_FILE"    ]] || { echo "ERROR: --policy is required"    >&2; usage; }
[[ -f "$ARTIFACTS_FILE" ]] || { echo "ERROR: artifacts file not found: $ARTIFACTS_FILE" >&2; exit 1; }
[[ -f "$POLICY_FILE"    ]] || { echo "ERROR: policy file not found: $POLICY_FILE"        >&2; exit 1; }

# ---------------------------------------------------------------------------
# Read policy (with safe defaults for omitted fields)
# ---------------------------------------------------------------------------
max_age_days=$(jq -r '.max_age_days    // 365'           "$POLICY_FILE")
max_total_size=$(jq -r '.max_total_size_bytes // 1099511627776' "$POLICY_FILE")
keep_latest_n=$(jq -r '.keep_latest_n  // 100'           "$POLICY_FILE")

# ---------------------------------------------------------------------------
# Reference date → Unix timestamp
# ---------------------------------------------------------------------------
ref_date="${REFERENCE_DATE:-$(date +%Y-%m-%d)}"
reference_ts=$(date -d "${ref_date}T00:00:00Z" +%s)

# ---------------------------------------------------------------------------
# Temp file management
# ---------------------------------------------------------------------------
tmp_augmented=$(mktemp)
tmp_stage=$(mktemp)

cleanup_temps() {
    rm -f "$tmp_augmented" "$tmp_stage"
}
trap cleanup_temps EXIT

# ---------------------------------------------------------------------------
# Step 1 — Augment artifacts with age_days, to_delete, delete_reason
# ---------------------------------------------------------------------------
{
    echo "["
    first=true
    while IFS= read -r artifact; do
        created_at=$(jq -r '.created_at' <<< "$artifact")
        # GNU date parses ISO-8601 with T/Z correctly
        created_ts=$(date -d "$created_at" +%s)
        age_days=$(( (reference_ts - created_ts) / 86400 ))

        [[ "$first" == "false" ]] && echo ","
        first=false

        jq --argjson age "$age_days" \
            '. + {"age_days": $age, "to_delete": false, "delete_reason": ""}' \
            <<< "$artifact"
    done < <(jq -c '.[]' "$ARTIFACTS_FILE")
    echo "]"
} > "$tmp_augmented"

# ---------------------------------------------------------------------------
# Step 2 — Policy 1: max_age
# Mark artifacts whose age exceeds max_age_days for deletion.
# ---------------------------------------------------------------------------
jq --argjson max_age "$max_age_days" '
  map(
    if .age_days > $max_age then
      . + {"to_delete": true, "delete_reason": "max_age"}
    else .
    end
  )
' "$tmp_augmented" > "$tmp_stage"
mv "$tmp_stage" "$tmp_augmented"

# ---------------------------------------------------------------------------
# Step 3 — Policy 2: keep_latest_n per run_id
# Among non-deleted artifacts, group by run_id and mark the oldest as
# deleted until each group has at most keep_latest_n entries.
# ---------------------------------------------------------------------------
jq --argjson n "$keep_latest_n" '
  . as $all |
  # Unique run_ids from still-retained artifacts
  [.[] | select(.to_delete == false) | .run_id] | unique as $run_ids |
  # For each run_id: sort by created_at asc, take the (len-n) oldest to delete
  [
    $run_ids[] as $rid |
    [ $all[] | select(.to_delete == false and .run_id == $rid) ] |
    sort_by(.created_at) |
    if length > $n then .[0:(length - $n)][].name else empty end
  ] as $excess_names |
  # Mark them
  $all | map(
    if .to_delete == false and (.name | IN($excess_names[]))
    then . + {"to_delete": true, "delete_reason": "keep_latest_n"}
    else .
    end
  )
' "$tmp_augmented" > "$tmp_stage"
mv "$tmp_stage" "$tmp_augmented"

# ---------------------------------------------------------------------------
# Step 4 — Policy 3: max_total_size
# While the total size of retained artifacts exceeds the limit, delete the
# oldest remaining artifact (by created_at).
# ---------------------------------------------------------------------------
while true; do
    total_size=$(jq '[.[] | select(.to_delete == false) | .size] | add // 0' "$tmp_augmented")

    if (( total_size <= max_total_size )); then
        break
    fi

    # Pick the oldest retained artifact
    oldest_name=$(jq -r '
      [ .[] | select(.to_delete == false) ] |
      sort_by(.created_at) | .[0].name // ""
    ' "$tmp_augmented")

    if [[ -z "$oldest_name" || "$oldest_name" == "null" ]]; then
        break
    fi

    jq --arg name "$oldest_name" '
      map(
        if .to_delete == false and .name == $name then
          . + {"to_delete": true, "delete_reason": "max_total_size"}
        else .
        end
      )
    ' "$tmp_augmented" > "$tmp_stage"
    mv "$tmp_stage" "$tmp_augmented"
done

# ---------------------------------------------------------------------------
# Output — Deletion plan
# ---------------------------------------------------------------------------
echo "=== ARTIFACT CLEANUP PLAN ==="
jq -r '.[] |
  if .to_delete then
    "[DELETE] \(.name) (run_id=\(.run_id), size=\(.size) bytes, age=\(.age_days) days, reason=\(.delete_reason))"
  else
    "[RETAIN] \(.name) (run_id=\(.run_id), size=\(.size) bytes, age=\(.age_days) days)"
  end
' "$tmp_augmented"

echo ""
echo "=== SUMMARY ==="

total=$(jq 'length' "$tmp_augmented")
to_delete=$(jq '[.[] | select(.to_delete)]       | length' "$tmp_augmented")
to_retain=$(jq '[.[] | select(.to_delete == false)] | length' "$tmp_augmented")
space_reclaimed=$(jq '[.[] | select(.to_delete) | .size] | add // 0' "$tmp_augmented")
space_mb=$(awk -v b="$space_reclaimed" 'BEGIN { printf "%.2f", b / 1048576 }')

echo "Total artifacts: $total"
echo "To delete: $to_delete"
echo "To retain: $to_retain"
echo "Space reclaimed: $space_reclaimed bytes ($space_mb MB)"

if [[ "$DRY_RUN" == "true" ]]; then
    echo "Mode: DRY-RUN (no artifacts were deleted)"
else
    echo "Mode: EXECUTE"
fi
