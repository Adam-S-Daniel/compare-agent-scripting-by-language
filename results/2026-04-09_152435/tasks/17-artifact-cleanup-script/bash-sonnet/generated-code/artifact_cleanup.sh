#!/usr/bin/env bash
# artifact_cleanup.sh — Apply retention policies to a list of artifacts and
# generate a deletion plan with a summary.
#
# USAGE:
#   artifact_cleanup.sh <artifacts.csv>
#
# ARTIFACT FILE FORMAT (CSV, one artifact per line, no header):
#   name,size_bytes,created_epoch,workflow_run_id
#
# RETENTION POLICIES (environment variables):
#   MAX_AGE_DAYS       Delete artifacts older than N days (default: unset = no limit)
#   MAX_TOTAL_SIZE_B   Delete oldest artifacts when cumulative size exceeds N bytes
#                      (default: unset = no limit)
#   KEEP_LATEST_N      Keep only the N most-recent artifacts per workflow_run_id
#                      (default: unset = keep all)
#   DRY_RUN            If "true", print the plan but do not perform deletions
#                      (default: false)
#   NOW                Unix epoch for "current time" — override for testing
#                      (default: current system time)

set -euo pipefail

# ─── Helpers ─────────────────────────────────────────────────────────────────

err() { echo "ERROR: $*" >&2; }

usage() {
  echo "Usage: $(basename "$0") <artifacts.csv>" >&2
  echo "  CSV format: name,size_bytes,created_epoch,workflow_run_id" >&2
  exit 1
}

# Format bytes as a human-readable string (still emit the raw number too).
# We keep this simple — just bytes for exactness; callers can pretty-print.
human_bytes() {
  local bytes=$1
  if (( bytes >= 1073741824 )); then
    printf '%s (%.2f GiB)' "$bytes" "$(echo "scale=2; $bytes/1073741824" | bc)"
  elif (( bytes >= 1048576 )); then
    printf '%s (%.2f MiB)' "$bytes" "$(echo "scale=2; $bytes/1048576" | bc)"
  elif (( bytes >= 1024 )); then
    printf '%s (%.2f KiB)' "$bytes" "$(echo "scale=2; $bytes/1024" | bc)"
  else
    printf '%s bytes' "$bytes"
  fi
}

# ─── Argument / environment parsing ──────────────────────────────────────────

if [[ $# -eq 0 ]]; then
  err "No artifact file specified."
  usage
fi

ARTIFACT_FILE="$1"

if [[ ! -f "$ARTIFACT_FILE" ]]; then
  err "Artifact file not found: $ARTIFACT_FILE"
  exit 1
fi

# Current time (overridable for deterministic tests)
NOW="${NOW:-$(date +%s)}"

# Policy defaults (empty = policy disabled)
MAX_AGE_DAYS="${MAX_AGE_DAYS:-}"
MAX_TOTAL_SIZE_B="${MAX_TOTAL_SIZE_B:-}"
KEEP_LATEST_N="${KEEP_LATEST_N:-}"
DRY_RUN="${DRY_RUN:-false}"

# ─── Data structures ─────────────────────────────────────────────────────────
# We store artifact data in parallel arrays indexed by line number (0-based).

declare -a ART_NAME=()
declare -a ART_SIZE=()
declare -a ART_EPOCH=()
declare -a ART_WORKFLOW=()
# Decision per artifact: "KEEP" or "DELETE:<reason>"
declare -a ART_DECISION=()

# ─── Parse artifact file ─────────────────────────────────────────────────────

line_num=0
while IFS=',' read -r name size epoch workflow || [[ -n "$name" ]]; do
  # Skip blank lines
  [[ -z "$name" ]] && continue

  # Validate numeric fields
  if ! [[ "$size" =~ ^[0-9]+$ ]]; then
    err "Line $((line_num+1)): invalid size_bytes '$size' for artifact '$name'"
    exit 1
  fi
  if ! [[ "$epoch" =~ ^[0-9]+$ ]]; then
    err "Line $((line_num+1)): invalid created_epoch '$epoch' for artifact '$name'"
    exit 1
  fi

  ART_NAME+=("$name")
  ART_SIZE+=("$size")
  ART_EPOCH+=("$epoch")
  ART_WORKFLOW+=("$workflow")
  ART_DECISION+=("KEEP")
  (( line_num++ )) || true
done < "$ARTIFACT_FILE"

total_artifacts=${#ART_NAME[@]}

# Nothing to do if file is empty
if [[ $total_artifacts -eq 0 ]]; then
  echo "=== Artifact Cleanup Plan ==="
  echo "No artifacts found."
  echo "=== Summary ==="
  echo "  Retained: 0  |  Deleted: 0  |  Reclaimed: 0 bytes"
  exit 0
fi

# ─── Policy 1: Max age ────────────────────────────────────────────────────────
# Mark artifacts older than MAX_AGE_DAYS as DELETE.

if [[ -n "$MAX_AGE_DAYS" ]]; then
  cutoff_epoch=$(( NOW - MAX_AGE_DAYS * 86400 ))
  for i in "${!ART_NAME[@]}"; do
    if [[ "${ART_DECISION[$i]}" == "KEEP" ]]; then
      if (( ART_EPOCH[i] < cutoff_epoch )); then
        ART_DECISION[i]="DELETE:max-age"
      fi
    fi
  done
fi

# ─── Policy 2: Keep-latest-N per workflow ────────────────────────────────────
# For each workflow_run_id, sort artifacts by epoch descending and mark those
# beyond position N as DELETE (regardless of current decision — age may have
# already marked some; keep-N can only add more deletions, not resurrect).

if [[ -n "$KEEP_LATEST_N" ]]; then
  # Collect unique workflow IDs
  declare -A seen_workflows=()
  for wf in "${ART_WORKFLOW[@]}"; do
    seen_workflows["$wf"]=1
  done

  for wf in "${!seen_workflows[@]}"; do
    # Collect indices belonging to this workflow, sorted newest-first by epoch.
    # Build a sortable list: "epoch:index"
    sorted_indices=()
    for i in "${!ART_NAME[@]}"; do
      if [[ "${ART_WORKFLOW[$i]}" == "$wf" ]]; then
        sorted_indices+=("${ART_EPOCH[$i]}:$i")
      fi
    done

    # Sort descending by epoch
    mapfile -t sorted_indices < <(printf '%s\n' "${sorted_indices[@]}" | sort -t: -k1 -rn)

    rank=0
    for entry in "${sorted_indices[@]}"; do
      idx="${entry##*:}"
      (( rank++ )) || true
      if (( rank > KEEP_LATEST_N )); then
        ART_DECISION[idx]="DELETE:keep-latest-N"
      fi
    done
  done
fi

# ─── Policy 3: Max total size ─────────────────────────────────────────────────
# Sum up the sizes of KEEP artifacts (oldest-first) and delete the oldest once
# cumulative size exceeds the limit.

if [[ -n "$MAX_TOTAL_SIZE_B" ]]; then
  # Build sorted list of KEEP artifacts by epoch ascending (oldest first to delete first)
  sort_candidates=()
  for i in "${!ART_NAME[@]}"; do
    if [[ "${ART_DECISION[$i]}" == "KEEP" ]]; then
      sort_candidates+=("${ART_EPOCH[$i]}:$i")
    fi
  done

  mapfile -t sort_candidates < <(printf '%s\n' "${sort_candidates[@]}" | sort -t: -k1 -n)

  # Sum total kept size
  total_kept=0
  for entry in "${sort_candidates[@]}"; do
    idx="${entry##*:}"
    (( total_kept += ART_SIZE[idx] )) || true
  done

  # Delete from oldest until we're under the limit
  for entry in "${sort_candidates[@]}"; do
    if (( total_kept <= MAX_TOTAL_SIZE_B )); then
      break
    fi
    idx="${entry##*:}"
    (( total_kept -= ART_SIZE[idx] )) || true
    ART_DECISION[idx]="DELETE:max-total-size"
  done
fi

# ─── Generate deletion plan ───────────────────────────────────────────────────

echo "=== Artifact Cleanup Plan ==="
if [[ "$DRY_RUN" == "true" ]]; then
  echo "*** DRY RUN — no artifacts will actually be deleted ***"
fi
echo ""

count_keep=0
count_delete=0
bytes_reclaimed=0

for i in "${!ART_NAME[@]}"; do
  decision="${ART_DECISION[$i]}"
  # Extract action part (before colon)
  action="${decision%%:*}"
  reason="${decision#*:}"
  if [[ "$reason" == "$action" ]]; then reason=""; fi

  if [[ "$action" == "KEEP" ]]; then
    printf "  KEEP   %s  (%s bytes, workflow: %s)\n" \
      "${ART_NAME[$i]}" "${ART_SIZE[$i]}" "${ART_WORKFLOW[$i]}"
    (( count_keep++ )) || true
  else
    printf "  DELETE %s  (%s bytes, workflow: %s) [reason: %s]\n" \
      "${ART_NAME[$i]}" "${ART_SIZE[$i]}" "${ART_WORKFLOW[$i]}" "$reason"
    (( count_delete++ )) || true
    (( bytes_reclaimed += ART_SIZE[i] )) || true
  fi
done

echo ""
echo "=== Summary ==="
echo "  Retained: ${count_keep}  |  Deleted: ${count_delete}  |  Reclaimed: $(human_bytes "$bytes_reclaimed")"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "  (dry-run: no changes made)"
fi
