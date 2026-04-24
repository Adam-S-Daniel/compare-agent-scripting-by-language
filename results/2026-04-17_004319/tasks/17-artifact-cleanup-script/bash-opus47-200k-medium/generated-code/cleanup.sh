#!/usr/bin/env bash
# Artifact cleanup script.
# Reads a TSV of artifacts (name\tsize_bytes\tcreated_epoch\tworkflow_run_id),
# applies retention policies, and emits a deletion plan plus a summary.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: cleanup.sh --input FILE [options]

Options:
  --input FILE              TSV: name<TAB>size<TAB>created_epoch<TAB>workflow_run_id
  --max-age-days N          Delete artifacts older than N days
  --max-total-size BYTES    Keep retained total size at or below BYTES (delete oldest first)
  --keep-latest N           Per workflow, keep only the N newest artifacts
  --now EPOCH               Override current time (seconds since epoch) — for tests
  --dry-run                 Mark plan as dry-run (no side effects performed either way)
  -h|--help                 Show this help
EOF
}

die() { echo "Error: $*" >&2; exit 2; }

INPUT=""
MAX_AGE_DAYS=""
MAX_TOTAL_SIZE=""
KEEP_LATEST=""
DRY_RUN=0
NOW=$(date +%s)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INPUT="${2:-}"; shift 2 ;;
    --max-age-days) MAX_AGE_DAYS="${2:-}"; shift 2 ;;
    --max-total-size) MAX_TOTAL_SIZE="${2:-}"; shift 2 ;;
    --keep-latest) KEEP_LATEST="${2:-}"; shift 2 ;;
    --now) NOW="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

[[ -z "$INPUT" ]] && die "--input is required"
[[ ! -f "$INPUT" ]] && die "input file not found: $INPUT"

# Validate numeric options.
for pair in "MAX_AGE_DAYS:$MAX_AGE_DAYS" "MAX_TOTAL_SIZE:$MAX_TOTAL_SIZE" "KEEP_LATEST:$KEEP_LATEST" "NOW:$NOW"; do
  name="${pair%%:*}"
  val="${pair#*:}"
  if [[ -n "$val" && ! "$val" =~ ^[0-9]+$ ]]; then
    die "$name must be a non-negative integer, got: $val"
  fi
done

# Parse artifacts. Skip blank and comment lines.
declare -a NAMES=() SIZES=() CREATED=() WORKFLOWS=() DELETE=() REASON=()
N=0
lineno=0
while IFS=$'\t' read -r name size created workflow || [[ -n "${name:-}" ]]; do
  lineno=$((lineno + 1))
  [[ -z "${name:-}" ]] && continue
  [[ "$name" == \#* ]] && continue
  if [[ -z "${size:-}" || -z "${created:-}" || -z "${workflow:-}" ]]; then
    die "malformed record at line $lineno of $INPUT"
  fi
  if [[ ! "$size" =~ ^[0-9]+$ ]] || [[ ! "$created" =~ ^[0-9]+$ ]]; then
    die "non-numeric size/created at line $lineno of $INPUT"
  fi
  NAMES[N]="$name"
  SIZES[N]="$size"
  CREATED[N]="$created"
  WORKFLOWS[N]="$workflow"
  DELETE[N]=0
  REASON[N]=""
  N=$((N + 1))
done < "$INPUT"

mark_delete() {
  local idx=$1 reason=$2
  if [[ "${DELETE[idx]}" -eq 0 ]]; then
    DELETE[idx]=1
    REASON[idx]="$reason"
  fi
}

# Policy 1: max age.
if [[ -n "$MAX_AGE_DAYS" ]]; then
  cutoff=$((NOW - MAX_AGE_DAYS * 86400))
  for ((j = 0; j < N; j++)); do
    if (( CREATED[j] < cutoff )); then
      mark_delete "$j" "age>${MAX_AGE_DAYS}d"
    fi
  done
fi

# Policy 2: keep-latest-N per workflow. Sort per-workflow indices by created desc;
# anything beyond rank N is deletable.
if [[ -n "$KEEP_LATEST" ]]; then
  declare -A _seen=()
  for ((j = 0; j < N; j++)); do _seen["${WORKFLOWS[j]}"]=1; done
  for wf in "${!_seen[@]}"; do
    idxs=()
    for ((j = 0; j < N; j++)); do
      [[ "${WORKFLOWS[j]}" == "$wf" ]] && idxs+=("$j")
    done
    # Sort indices by CREATED descending (newest first).
    sorted=$(for k in "${idxs[@]}"; do printf '%s\t%s\n' "${CREATED[k]}" "$k"; done | sort -k1,1rn -k2,2n | cut -f2)
    rank=0
    for k in $sorted; do
      if (( rank >= KEEP_LATEST )); then
        mark_delete "$k" "beyond-keep-latest-${KEEP_LATEST}"
      fi
      rank=$((rank + 1))
    done
  done
fi

# Policy 3: max-total-size. While retained total exceeds budget, delete oldest retained.
if [[ -n "$MAX_TOTAL_SIZE" ]]; then
  while :; do
    total=0
    for ((j = 0; j < N; j++)); do
      (( DELETE[j] == 0 )) && total=$((total + SIZES[j]))
    done
    (( total <= MAX_TOTAL_SIZE )) && break
    # Pick oldest retained to evict.
    oldest=-1
    oldest_time=-1
    for ((j = 0; j < N; j++)); do
      if (( DELETE[j] == 0 )); then
        if (( oldest < 0 )) || (( CREATED[j] < oldest_time )); then
          oldest=$j
          oldest_time=${CREATED[j]}
        fi
      fi
    done
    (( oldest < 0 )) && break
    mark_delete "$oldest" "over-budget>${MAX_TOTAL_SIZE}B"
  done
fi

# Emit plan.
deleted=0
retained=0
reclaimed=0
retained_bytes=0
for ((j = 0; j < N; j++)); do
  if (( DELETE[j] == 1 )); then
    printf 'DELETE\t%s\tsize=%s\tworkflow=%s\treason=%s\n' \
      "${NAMES[j]}" "${SIZES[j]}" "${WORKFLOWS[j]}" "${REASON[j]}"
    deleted=$((deleted + 1))
    reclaimed=$((reclaimed + SIZES[j]))
  else
    printf 'KEEP\t%s\tsize=%s\tworkflow=%s\n' \
      "${NAMES[j]}" "${SIZES[j]}" "${WORKFLOWS[j]}"
    retained=$((retained + 1))
    retained_bytes=$((retained_bytes + SIZES[j]))
  fi
done

mode="execute"
(( DRY_RUN == 1 )) && mode="dry-run"

cat <<EOF
SUMMARY
total_artifacts=$N
deleted=$deleted
retained=$retained
reclaimed_bytes=$reclaimed
retained_bytes=$retained_bytes
mode=$mode
EOF
