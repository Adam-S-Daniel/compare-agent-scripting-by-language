#!/usr/bin/env bash
# Artifact cleanup script
# Applies retention policies to mock artifact data and generates a deletion plan.
#
# Policies (all optional, all combined when specified):
#   max_age_days         – delete artifacts older than N days
#   max_total_size_bytes – delete oldest artifacts until total size is under limit
#   keep_latest_n        – per workflow_run_id, keep only the N newest artifacts
#
# Supports --dry-run mode (plan only, no actual deletions).
# Uses --reference-date for deterministic testing.

set -euo pipefail

# --- Argument parsing ---
ARTIFACTS_FILE=""
POLICY_FILE=""
DRY_RUN=false
REFERENCE_DATE=""

usage() {
  echo "Usage: $0 --artifacts <file> --policy <file> [--dry-run] [--reference-date YYYY-MM-DD]" >&2
  echo "  --artifacts       JSON file with artifact list" >&2
  echo "  --policy          JSON file with retention policy" >&2
  echo "  --dry-run         Show deletion plan without making changes" >&2
  echo "  --reference-date  Override today's date for testing (YYYY-MM-DD)" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifacts)      ARTIFACTS_FILE="$2"; shift 2 ;;
    --policy)         POLICY_FILE="$2"; shift 2 ;;
    --dry-run)        DRY_RUN=true; shift ;;
    --reference-date) REFERENCE_DATE="$2"; shift 2 ;;
    *)                echo "Error: Unknown argument: $1" >&2; usage ;;
  esac
done

if [[ -z "$ARTIFACTS_FILE" ]]; then
  echo "Error: --artifacts is required" >&2
  usage
fi
if [[ -z "$POLICY_FILE" ]]; then
  echo "Error: --policy is required" >&2
  usage
fi
if [[ ! -f "$ARTIFACTS_FILE" ]]; then
  echo "Error: Artifacts file not found: $ARTIFACTS_FILE" >&2
  exit 1
fi
if [[ ! -f "$POLICY_FILE" ]]; then
  echo "Error: Policy file not found: $POLICY_FILE" >&2
  exit 1
fi

# --- Reference date (ISO8601 with time for fromdateiso8601) ---
if [[ -z "$REFERENCE_DATE" ]]; then
  REF_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
else
  REF_ISO="${REFERENCE_DATE}T00:00:00Z"
fi

REF_EPOCH=$(echo "\"${REF_ISO}\"" | jq 'fromdateiso8601')

# --- Load policy fields (null when absent) ---
MAX_AGE_DAYS=$(jq 'if has("max_age_days") then .max_age_days else null end' "$POLICY_FILE")
MAX_TOTAL_SIZE=$(jq 'if has("max_total_size_bytes") then .max_total_size_bytes else null end' "$POLICY_FILE")
KEEP_LATEST_N=$(jq 'if has("keep_latest_n") then .keep_latest_n else null end' "$POLICY_FILE")

# --- Step 1: Annotate artifacts with age_days, delete=false, delete_reason="" ---
ANNOTATED=$(jq --argjson ref_epoch "$REF_EPOCH" '
  map(
    . + {
      age_days: (($ref_epoch - (.created_at | fromdateiso8601)) / 86400 | floor),
      delete: false,
      delete_reason: ""
    }
  )
' "$ARTIFACTS_FILE")

# --- Step 2: Apply max_age_days ---
if [[ "$MAX_AGE_DAYS" != "null" ]]; then
  ANNOTATED=$(jq --argjson max_age "$MAX_AGE_DAYS" '
    map(
      if (.delete == false and .age_days > $max_age) then
        . + {delete: true, delete_reason: "max_age"}
      else .
      end
    )
  ' <<< "$ANNOTATED")
fi

# --- Step 3: Apply keep_latest_n (per workflow_run_id, among non-deleted artifacts) ---
# For each workflow: sort non-deleted artifacts newest-first; mark those beyond position N for deletion.
if [[ "$KEEP_LATEST_N" != "null" ]]; then
  ANNOTATED=$(jq --argjson keep_n "$KEEP_LATEST_N" '
    . as $initial |
    ([.[] | .workflow_run_id] | unique) as $workflows |
    reduce $workflows[] as $wf (
      $initial;
      . as $arr |
      (
        [range($arr | length)] |
        map(select(
          $arr[.].workflow_run_id == $wf and
          $arr[.].delete == false
        )) |
        sort_by($arr[.].created_at) | reverse
      ) as $wf_idx |
      reduce range($arr | length) as $i (
        .;
        if (($wf_idx | index($i)) != null) and (($wf_idx | index($i)) >= $keep_n) then
          .[$i] += {delete: true, delete_reason: "keep_latest_n"}
        else .
        end
      )
    )
  ' <<< "$ANNOTATED")
fi

# --- Step 4: Apply max_total_size_bytes (delete oldest non-deleted until under limit) ---
if [[ "$MAX_TOTAL_SIZE" != "null" ]]; then
  CURRENT_SIZE=$(jq '[.[] | select(.delete == false) | .size] | add // 0' <<< "$ANNOTATED")

  if [[ "$CURRENT_SIZE" -gt "$MAX_TOTAL_SIZE" ]]; then
    # Read non-deleted artifacts sorted oldest-first (highest age_days first)
    while IFS=$'\t' read -r _age name; do
      if [[ "$CURRENT_SIZE" -le "$MAX_TOTAL_SIZE" ]]; then
        break
      fi
      ART_SIZE=$(jq --arg n "$name" '.[] | select(.name == $n) | .size' <<< "$ANNOTATED")
      ANNOTATED=$(jq --arg n "$name" '
        map(if (.name == $n and .delete == false) then
          . + {delete: true, delete_reason: "max_total_size"}
        else . end)
      ' <<< "$ANNOTATED")
      CURRENT_SIZE=$((CURRENT_SIZE - ART_SIZE))
    done < <(jq -r '.[] | select(.delete == false) | [.age_days, .name] | @tsv' <<< "$ANNOTATED" \
              | sort -t$'\t' -k1 -rn)
  fi
fi

# --- Output: deletion plan header ---
echo ""
if [[ "$DRY_RUN" == "true" ]]; then
  echo "=== ARTIFACT DELETION PLAN (DRY RUN) ==="
else
  echo "=== ARTIFACT DELETION PLAN (LIVE RUN) ==="
fi
echo ""

# Per-artifact decisions
jq -r '.[] |
  if .delete then
    "DELETE: \(.name) (\(.size) bytes, \(.age_days) days old, workflow=\(.workflow_run_id)) [reason: \(.delete_reason)]"
  else
    "KEEP:   \(.name) (\(.size) bytes, \(.age_days) days old, workflow=\(.workflow_run_id))"
  end
' <<< "$ANNOTATED"

echo ""

# --- Summary ---
DELETE_COUNT=$(jq '[.[] | select(.delete == true)]  | length' <<< "$ANNOTATED")
RETAIN_COUNT=$(jq '[.[] | select(.delete == false)] | length' <<< "$ANNOTATED")
TOTAL_COUNT=$(jq  'length' <<< "$ANNOTATED")
SPACE_RECLAIMED=$(jq '[.[] | select(.delete == true)  | .size] | add // 0' <<< "$ANNOTATED")
SPACE_RETAINED=$(jq  '[.[] | select(.delete == false) | .size] | add // 0' <<< "$ANNOTATED")

echo "=== SUMMARY ==="
echo "total_artifacts=${TOTAL_COUNT}"
echo "delete_count=${DELETE_COUNT}"
echo "retain_count=${RETAIN_COUNT}"
echo "space_reclaimed_bytes=${SPACE_RECLAIMED}"
echo "space_retained_bytes=${SPACE_RETAINED}"
