#!/usr/bin/env bash
# Artifact cleanup planner.
#
# Reads artifact metadata (TSV: name, size_bytes, creation_date, workflow_run_id)
# and applies retention policies to produce a deletion plan + summary.
#
# Policies (any combination):
#   --max-age-days N       delete artifacts older than N days
#   --keep-latest N        keep only N newest per workflow_run_id
#   --max-total-size B     cap total kept size at B bytes; delete oldest first
#
# Modes:
#   --dry-run              print DRY RUN banner; semantically a no-op since this
#                          planner never performs deletions itself (the caller
#                          in CI applies the plan), but the banner lets callers
#                          mark output as non-actionable.
#
# All decisions are deterministic given --current-date.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: cleanup.sh [OPTIONS]

Reads artifact metadata from --input (or stdin with '-') as TSV:
    name<TAB>size_bytes<TAB>creation_date(YYYY-MM-DD)<TAB>workflow_run_id

Options:
  --input PATH              TSV file path, or '-' for stdin (required)
  --current-date YYYY-MM-DD Override "today" for deterministic runs
  --max-age-days N          Delete artifacts older than N days
  --keep-latest N           Keep only N newest artifacts per workflow_run_id
  --max-total-size BYTES    Cap total kept size at BYTES; delete oldest first
  --dry-run                 Emit DRY RUN banner (plan is always a plan)
  -h, --help                Show this help
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

# Convert YYYY-MM-DD to days-since-epoch. Falls back to a pure-bash calculation
# if `date -d` isn't available (unlikely on Linux but keeps this portable).
date_to_days() {
  local d="$1"
  if [[ ! "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    die "invalid date: $d"
  fi
  local epoch_seconds
  if ! epoch_seconds="$(date -d "$d" +%s 2>/dev/null)"; then
    die "invalid date: $d"
  fi
  # 86400 seconds per day
  printf '%d\n' "$(( epoch_seconds / 86400 ))"
}

# -------- argument parsing --------
INPUT=""
CURRENT_DATE=""
MAX_AGE_DAYS=""
KEEP_LATEST=""
MAX_TOTAL_SIZE=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)           INPUT="$2"; shift 2 ;;
    --current-date)    CURRENT_DATE="$2"; shift 2 ;;
    --max-age-days)    MAX_AGE_DAYS="$2"; shift 2 ;;
    --keep-latest)     KEEP_LATEST="$2"; shift 2 ;;
    --max-total-size)  MAX_TOTAL_SIZE="$2"; shift 2 ;;
    --dry-run)         DRY_RUN=1; shift ;;
    -h|--help)         usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

[[ -n "$INPUT" ]] || die "--input is required (use '-' for stdin)"

# Validate numeric policy arguments up front so downstream arithmetic is safe.
for pair in "MAX_AGE_DAYS:$MAX_AGE_DAYS" "KEEP_LATEST:$KEEP_LATEST" "MAX_TOTAL_SIZE:$MAX_TOTAL_SIZE"; do
  name="${pair%%:*}"
  val="${pair#*:}"
  if [[ -n "$val" ]] && [[ ! "$val" =~ ^[0-9]+$ ]]; then
    die "--${name,,} must be a non-negative integer (got: $val)"
  fi
done

# -------- load input --------
if [[ "$INPUT" == "-" ]]; then
  INPUT_CONTENT="$(cat)"
else
  [[ -f "$INPUT" ]] || die "input file not found: $INPUT"
  INPUT_CONTENT="$(cat "$INPUT")"
fi

# Parse TSV rows into parallel arrays. We validate each row's shape as we go.
# We also compute the days-since-epoch for each artifact for deterministic
# age comparisons.
declare -a NAMES=() SIZES=() DATES=() WORKFLOWS=() DAYS=()
row=0
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  row=$(( row + 1 ))
  # shellcheck disable=SC2206
  IFS=$'\t' read -r -a fields <<< "$line"
  if [[ "${#fields[@]}" -ne 4 ]]; then
    die "malformed row $row: expected 4 tab-separated fields, got ${#fields[@]}"
  fi
  name="${fields[0]}"
  size="${fields[1]}"
  date_val="${fields[2]}"
  wf="${fields[3]}"
  if [[ ! "$size" =~ ^[0-9]+$ ]]; then
    die "malformed row $row: size must be a non-negative integer (got: $size)"
  fi
  NAMES+=("$name")
  SIZES+=("$size")
  DATES+=("$date_val")
  WORKFLOWS+=("$wf")
  DAYS+=("$(date_to_days "$date_val")")
done <<< "$INPUT_CONTENT"

N="${#NAMES[@]}"

# Resolve "today" in days.
if [[ -n "$CURRENT_DATE" ]]; then
  TODAY_DAYS="$(date_to_days "$CURRENT_DATE")"
else
  TODAY_DAYS="$(( $(date +%s) / 86400 ))"
fi

# -------- policy evaluation --------
# Each artifact gets a list of deletion reasons. An empty list => KEEP.
declare -a REASONS=()
for ((i = 0; i < N; i++)); do
  REASONS+=("")
done

add_reason() {
  local idx="$1" reason="$2"
  if [[ -z "${REASONS[$idx]}" ]]; then
    REASONS[idx]="$reason"
  else
    REASONS[idx]="${REASONS[$idx]},$reason"
  fi
}

# Policy 1: max-age-days
if [[ -n "$MAX_AGE_DAYS" ]]; then
  for ((i = 0; i < N; i++)); do
    age=$(( TODAY_DAYS - DAYS[i] ))
    if (( age > MAX_AGE_DAYS )); then
      add_reason "$i" "max-age"
    fi
  done
fi

# Policy 2: keep-latest per workflow.
# Group indices by workflow, sort each group by (day DESC, name DESC for ties),
# keep the first N, mark the rest.
if [[ -n "$KEEP_LATEST" ]]; then
  # Build unique workflow list.
  declare -A seen_wf=()
  wf_list=()
  for wf in "${WORKFLOWS[@]}"; do
    if [[ -z "${seen_wf[$wf]:-}" ]]; then
      seen_wf["$wf"]=1
      wf_list+=("$wf")
    fi
  done

  for wf in "${wf_list[@]}"; do
    # Collect indices for this workflow with sort keys.
    # Format: DAYS<TAB>NAME<TAB>INDEX, then sort numerically descending on days,
    # tiebreak by name descending.
    lines=""
    for ((i = 0; i < N; i++)); do
      if [[ "${WORKFLOWS[$i]}" == "$wf" ]]; then
        lines+="${DAYS[$i]}"$'\t'"${NAMES[$i]}"$'\t'"$i"$'\n'
      fi
    done
    # Sort: primary key days desc (numeric), secondary key name desc.
    sorted="$(printf '%s' "$lines" | sort -t$'\t' -k1,1nr -k2,2r)"
    kept=0
    while IFS=$'\t' read -r _ _ idx; do
      [[ -z "$idx" ]] && continue
      if (( kept < KEEP_LATEST )); then
        kept=$(( kept + 1 ))
      else
        add_reason "$idx" "keep-latest"
      fi
    done <<< "$sorted"
  done
fi

# Policy 3: max-total-size.
# After the above policies, compute total size of currently-kept artifacts.
# If over the cap, delete oldest kept artifacts until under the cap.
if [[ -n "$MAX_TOTAL_SIZE" ]]; then
  # List currently-kept indices sorted oldest-first (days asc, name asc).
  kept_lines=""
  for ((i = 0; i < N; i++)); do
    if [[ -z "${REASONS[$i]}" ]]; then
      kept_lines+="${DAYS[$i]}"$'\t'"${NAMES[$i]}"$'\t'"$i"$'\n'
    fi
  done
  sorted_oldest="$(printf '%s' "$kept_lines" | sort -t$'\t' -k1,1n -k2,2)"

  # Compute total currently-kept size.
  total=0
  while IFS=$'\t' read -r _ _ idx; do
    [[ -z "$idx" ]] && continue
    total=$(( total + SIZES[idx] ))
  done <<< "$sorted_oldest"

  # Evict oldest until under cap.
  while (( total > MAX_TOTAL_SIZE )); do
    # Take first line (oldest).
    first_line="$(printf '%s' "$sorted_oldest" | head -n1)"
    [[ -z "$first_line" ]] && break
    idx="$(printf '%s' "$first_line" | cut -f3)"
    add_reason "$idx" "max-total-size"
    total=$(( total - SIZES[idx] ))
    # Drop first line from remaining.
    sorted_oldest="$(printf '%s' "$sorted_oldest" | tail -n +2)"
  done
fi

# -------- render plan --------
if (( DRY_RUN == 1 )); then
  echo "=== DRY RUN ==="
fi
echo "=== Deletion Plan ==="
printf '%-8s %-20s %10s  %-10s  %-12s %s\n' \
  "ACTION" "NAME" "SIZE" "DATE" "WORKFLOW" "REASON"

retained=0
deleted=0
reclaimed=0
for ((i = 0; i < N; i++)); do
  if [[ -z "${REASONS[$i]}" ]]; then
    action="KEEP"
    reason="-"
    retained=$(( retained + 1 ))
  else
    action="DELETE"
    reason="${REASONS[$i]}"
    deleted=$(( deleted + 1 ))
    reclaimed=$(( reclaimed + SIZES[i] ))
  fi
  printf '%-8s %-20s %10s  %-10s  %-12s %s\n' \
    "$action" "${NAMES[$i]}" "${SIZES[$i]}" "${DATES[$i]}" "${WORKFLOWS[$i]}" "$reason"
done

echo ""
echo "=== Summary ==="
echo "Artifacts retained: ${retained}"
echo "Artifacts deleted: ${deleted}"
echo "Space reclaimed: ${reclaimed} bytes"
