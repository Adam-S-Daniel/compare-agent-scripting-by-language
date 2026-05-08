#!/usr/bin/env bash
# cleanup-artifacts.sh
#
# Apply retention policies to a list of CI artifacts and emit a deletion plan.
#
# Input: TSV file (--input) with columns:
#   name<TAB>size_bytes<TAB>created_epoch<TAB>workflow_run_id
#
# Policies (any combination, all optional; if none given, nothing is deleted):
#   --max-age DAYS         delete artifacts older than DAYS days
#   --keep-latest N        keep the N newest artifacts per workflow_run_id
#   --max-total-size BYTES delete oldest remaining artifacts until total size <= BYTES
#
# Modes:
#   --dry-run              report only (default is "live"; this is mock data so
#                          neither mode actually deletes anything, but the report
#                          marks which mode was selected)
#
# Determinism:
#   --now EPOCH            override "now" for testing; defaults to date +%s
#
# Output: a per-artifact line ("DELETE: name (reason)" or "KEEP: name") followed
# by a SUMMARY block with totals.

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: cleanup-artifacts.sh --input FILE [options]

Options:
  --input FILE             TSV input: name<TAB>size<TAB>created_epoch<TAB>workflow_run_id
  --max-age DAYS           Delete artifacts older than DAYS days
  --keep-latest N          Keep N newest per workflow_run_id
  --max-total-size BYTES   Delete oldest until total size <= BYTES
  --dry-run                Report only (do not perform deletions)
  --now EPOCH              Override current time (for tests)
  -h, --help               Show this help
EOF
}

# --- Argument parsing -------------------------------------------------------

input=""
max_age=""
keep_latest=""
max_total_size=""
dry_run=0
now="$(date +%s)"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input)          input="$2"; shift 2 ;;
        --max-age)        max_age="$2"; shift 2 ;;
        --keep-latest)    keep_latest="$2"; shift 2 ;;
        --max-total-size) max_total_size="$2"; shift 2 ;;
        --dry-run)        dry_run=1; shift ;;
        --now)            now="$2"; shift 2 ;;
        -h|--help)        usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [[ -z "$input" ]]; then
    echo "Error: --input is required" >&2
    usage >&2
    exit 2
fi

if [[ ! -f "$input" ]]; then
    echo "Error: input file not found: $input" >&2
    exit 2
fi

# --- Load and validate input ------------------------------------------------
# We hold artifacts in parallel arrays indexed 0..N-1.
# Each index has: name, size, created, workflow.
# A "decision" array tracks the deletion reason (empty string == keep).

names=()
sizes=()
createds=()
workflows=()

line_no=0
while IFS=$'\t' read -r name size created workflow || [[ -n "${name:-}" ]]; do
    line_no=$((line_no + 1))
    # Skip blank lines (trailing newline at EOF).
    if [[ -z "${name:-}" && -z "${size:-}" && -z "${created:-}" && -z "${workflow:-}" ]]; then
        continue
    fi
    if [[ -z "${size:-}" || -z "${created:-}" || -z "${workflow:-}" ]]; then
        echo "Error: malformed input on line $line_no (expected 4 tab-separated fields)" >&2
        exit 3
    fi
    if ! [[ "$size" =~ ^[0-9]+$ ]] || ! [[ "$created" =~ ^[0-9]+$ ]]; then
        echo "Error: invalid numeric field on line $line_no" >&2
        exit 3
    fi
    names+=("$name")
    sizes+=("$size")
    createds+=("$created")
    workflows+=("$workflow")
done < "$input"

n=${#names[@]}

# Initialize all decisions to "keep" (empty reason).
reasons=()
for ((i = 0; i < n; i++)); do
    reasons+=("")
done

# --- Policy: max-age --------------------------------------------------------
# Anything created before (now - max_age*86400) is marked for deletion.
if [[ -n "$max_age" ]]; then
    cutoff=$(( now - max_age * 86400 ))
    for ((i = 0; i < n; i++)); do
        if (( createds[i] < cutoff )); then
            reasons[i]="max_age"
        fi
    done
fi

# --- Policy: keep-latest-N per workflow ------------------------------------
# For each workflow group, sort survivors by created desc and mark anything
# beyond rank N as "keep_latest" (unless already marked).
if [[ -n "$keep_latest" ]]; then
    # Get unique workflow ids of currently-surviving artifacts.
    declare -A seen_wf=()
    for ((i = 0; i < n; i++)); do
        [[ -n "${reasons[i]}" ]] && continue
        seen_wf["${workflows[i]}"]=1
    done
    for wf in "${!seen_wf[@]}"; do
        # Build "created<TAB>index" lines for this workflow's survivors,
        # sort numerically descending, and mark indexes past position N.
        rank=0
        while IFS=$'\t' read -r _ idx; do
            rank=$((rank + 1))
            if (( rank > keep_latest )); then
                reasons[idx]="keep_latest"
            fi
        done < <(
            for ((i = 0; i < n; i++)); do
                [[ -n "${reasons[i]}" ]] && continue
                [[ "${workflows[i]}" != "$wf" ]] && continue
                printf '%s\t%s\n' "${createds[i]}" "$i"
            done | sort -k1,1nr
        )
    done
fi

# --- Policy: max-total-size -------------------------------------------------
# Sum surviving sizes; if over cap, delete oldest first until we're at/under.
if [[ -n "$max_total_size" ]]; then
    total=0
    for ((i = 0; i < n; i++)); do
        [[ -n "${reasons[i]}" ]] && continue
        total=$(( total + sizes[i] ))
    done
    if (( total > max_total_size )); then
        # Walk survivors oldest-first, marking until total drops to cap.
        while IFS=$'\t' read -r _ idx; do
            (( total <= max_total_size )) && break
            reasons[idx]="max_total_size"
            total=$(( total - sizes[idx] ))
        done < <(
            for ((i = 0; i < n; i++)); do
                [[ -n "${reasons[i]}" ]] && continue
                printf '%s\t%s\n' "${createds[i]}" "$i"
            done | sort -k1,1n
        )
    fi
fi

# --- Emit plan + summary ----------------------------------------------------
deleted=0
retained=0
reclaimed=0

for ((i = 0; i < n; i++)); do
    if [[ -n "${reasons[i]}" ]]; then
        printf 'DELETE: %s (reason: %s, size: %s)\n' \
            "${names[i]}" "${reasons[i]}" "${sizes[i]}"
        deleted=$(( deleted + 1 ))
        reclaimed=$(( reclaimed + sizes[i] ))
    else
        printf 'KEEP: %s (size: %s)\n' "${names[i]}" "${sizes[i]}"
        retained=$(( retained + 1 ))
    fi
done

if (( dry_run == 1 )); then
    mode="dry-run"
else
    mode="live"
fi

cat <<EOF
SUMMARY:
  Total artifacts: $n
  Retained: $retained
  Deleted: $deleted
  Space reclaimed: $reclaimed
  Mode: $mode
EOF
