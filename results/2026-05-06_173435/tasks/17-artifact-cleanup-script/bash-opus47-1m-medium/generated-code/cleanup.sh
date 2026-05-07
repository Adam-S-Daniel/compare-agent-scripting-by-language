#!/usr/bin/env bash
# Artifact cleanup tool. Reads a TSV of artifacts and applies retention
# policies (max age, max total size, keep-latest-N per workflow run),
# emits a deletion plan and a summary. Supports --dry-run.
#
# Input TSV columns: name<TAB>size_bytes<TAB>iso_date<TAB>workflow_run_id
#
# An artifact is deleted if ANY enabled policy marks it for deletion.
# Policies are independent: max-age and keep-latest are evaluated per
# artifact; max-total-size deletes oldest-first until the kept set fits.

set -euo pipefail

INPUT=""
NOW=""
MAX_AGE_DAYS=""
MAX_TOTAL_SIZE=""
KEEP_LATEST=""
DRY_RUN=0

die() { echo "error: $*" >&2; exit 2; }

usage() {
    cat <<'EOF'
usage: cleanup.sh --input FILE [--now ISO_DATE] [--max-age-days N]
                  [--max-total-size BYTES] [--keep-latest N] [--dry-run]
EOF
}

# --- argument parsing ---
while [ $# -gt 0 ]; do
    case "$1" in
        --input)            INPUT="$2"; shift 2 ;;
        --now)              NOW="$2"; shift 2 ;;
        --max-age-days)     MAX_AGE_DAYS="$2"; shift 2 ;;
        --max-total-size)   MAX_TOTAL_SIZE="$2"; shift 2 ;;
        --keep-latest)      KEEP_LATEST="$2"; shift 2 ;;
        --dry-run)          DRY_RUN=1; shift ;;
        -h|--help)          usage; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
done

is_uint() { [[ "$1" =~ ^[0-9]+$ ]]; }

[ -n "$INPUT" ] || { usage >&2; die "missing --input"; }
[ -f "$INPUT" ] || die "input file not found: $INPUT"
[ -n "$NOW" ]   || NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [ -n "$MAX_AGE_DAYS" ]   && ! is_uint "$MAX_AGE_DAYS";   then die "invalid --max-age-days: $MAX_AGE_DAYS";   fi
if [ -n "$MAX_TOTAL_SIZE" ] && ! is_uint "$MAX_TOTAL_SIZE"; then die "invalid --max-total-size: $MAX_TOTAL_SIZE"; fi
if [ -n "$KEEP_LATEST" ]    && ! is_uint "$KEEP_LATEST";    then die "invalid --keep-latest: $KEEP_LATEST";    fi

NOW_EPOCH="$(date -u -d "$NOW" +%s 2>/dev/null)" || die "invalid --now: $NOW"

# --- load artifacts into parallel arrays ---
# We do all decisions in arrays rather than re-parsing, because policies
# need multiple passes over the same set (per-workflow grouping, total-size
# accumulation by age).
names=(); sizes=(); dates=(); epochs=(); runs=(); delete=(); reasons=()

while IFS=$'\t' read -r name size date run; do
    [ -z "${name:-}" ] && continue
    is_uint "$size" || die "invalid size for $name: $size"
    e="$(date -u -d "$date" +%s 2>/dev/null)" || die "invalid date for $name: $date"
    names+=("$name"); sizes+=("$size"); dates+=("$date"); epochs+=("$e"); runs+=("$run")
    delete+=(0); reasons+=("")
done < "$INPUT"

n="${#names[@]}"

mark() {
    # mark <index> <reason> — sets delete flag and accumulates reason text
    local i="$1" r="$2"
    delete[i]=1
    if [ -z "${reasons[i]}" ]; then reasons[i]="$r"; else reasons[i]="${reasons[i]},$r"; fi
}

# --- policy: max age ---
if [ -n "$MAX_AGE_DAYS" ]; then
    cutoff=$(( NOW_EPOCH - MAX_AGE_DAYS * 86400 ))
    for ((i=0; i<n; i++)); do
        if [ "${epochs[i]}" -lt "$cutoff" ]; then mark "$i" "max-age"; fi
    done
fi

# --- policy: keep-latest-N per workflow run id ---
# For each run id, sort indexes by epoch descending; mark all beyond the
# first KEEP_LATEST.
if [ -n "$KEEP_LATEST" ]; then
    # Get unique run ids
    declare -A seen=()
    unique_runs=()
    for r in "${runs[@]}"; do
        if [ -z "${seen[$r]:-}" ]; then seen[$r]=1; unique_runs+=("$r"); fi
    done
    for run in "${unique_runs[@]}"; do
        # Build "epoch idx" lines for this run, sort desc by epoch
        sorted_idxs=()
        while read -r idx; do sorted_idxs+=("$idx"); done < <(
            for ((i=0; i<n; i++)); do
                if [ "${runs[i]}" = "$run" ]; then printf '%s\t%s\n' "${epochs[i]}" "$i"; fi
            done | sort -k1,1nr | cut -f2
        )
        for ((k=0; k<${#sorted_idxs[@]}; k++)); do
            if [ "$k" -ge "$KEEP_LATEST" ]; then mark "${sorted_idxs[k]}" "keep-latest"; fi
        done
    done
fi

# --- policy: max total size ---
# Compute total of currently kept artifacts. If over limit, delete oldest
# kept artifacts until under the limit.
if [ -n "$MAX_TOTAL_SIZE" ]; then
    total=0
    for ((i=0; i<n; i++)); do
        if [ "${delete[i]}" -eq 0 ]; then total=$((total + sizes[i])); fi
    done
    if [ "$total" -gt "$MAX_TOTAL_SIZE" ]; then
        # Indexes of currently kept artifacts, oldest first
        kept_oldest_first=()
        while read -r idx; do kept_oldest_first+=("$idx"); done < <(
            for ((i=0; i<n; i++)); do
                if [ "${delete[i]}" -eq 0 ]; then printf '%s\t%s\n' "${epochs[i]}" "$i"; fi
            done | sort -k1,1n | cut -f2
        )
        for idx in "${kept_oldest_first[@]}"; do
            [ "$total" -le "$MAX_TOTAL_SIZE" ] && break
            mark "$idx" "max-size"
            total=$(( total - sizes[idx] ))
        done
    fi
fi

# --- output ---
mode_label="PLAN"
[ "$DRY_RUN" -eq 1 ] && mode_label="DRY-RUN PLAN"
echo "=== $mode_label ==="

retained=0
deleted=0
reclaimed=0
for ((i=0; i<n; i++)); do
    if [ "${delete[i]}" -eq 1 ]; then
        echo "DELETE ${names[i]}  size=${sizes[i]}  date=${dates[i]}  run=${runs[i]}  reason=${reasons[i]}"
        deleted=$((deleted + 1))
        reclaimed=$((reclaimed + sizes[i]))
    else
        echo "KEEP   ${names[i]}  size=${sizes[i]}  date=${dates[i]}  run=${runs[i]}"
        retained=$((retained + 1))
    fi
done

echo "=== SUMMARY ==="
echo "Retained: $retained"
echo "Deleted: $deleted"
echo "Reclaimed: $reclaimed bytes"
if [ "$DRY_RUN" -eq 1 ]; then
    echo "Mode: DRY-RUN (no artifacts actually removed)"
else
    echo "Mode: PLAN"
fi
