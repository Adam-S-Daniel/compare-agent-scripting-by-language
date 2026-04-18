#!/usr/bin/env bash
# Artifact cleanup script.
# Applies retention policies (max age, max total size, keep-latest-N per workflow)
# to a list of artifacts supplied as TSV (name, size_bytes, iso8601_date, workflow_run_id)
# and prints a deletion plan plus summary. Supports --dry-run.

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: cleanup.sh --input FILE [options]

Options:
  --input FILE              TSV file: name<TAB>size<TAB>iso_date<TAB>workflow_id
  --now ISO8601             Reference "now" (default: current UTC time)
  --max-age-days N          Delete artifacts older than N days
  --max-total-size BYTES    Enforce total size cap (delete oldest first)
  --keep-latest N           Keep only N most recent artifacts per workflow_id
  --dry-run                 Do not mark execution; just preview
  -h, --help                Show this help
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

# Convert ISO8601 (UTC, ending with Z) to epoch seconds.
iso_to_epoch() {
    date -u -d "$1" +%s 2>/dev/null || die "invalid date: $1"
}

main() {
    local input="" now="" max_age="" max_size="" keep_latest=""
    local dry_run=0

    if [[ $# -eq 0 ]]; then
        usage >&2
        exit 2
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --input) input="$2"; shift 2 ;;
            --now) now="$2"; shift 2 ;;
            --max-age-days) max_age="$2"; shift 2 ;;
            --max-total-size) max_size="$2"; shift 2 ;;
            --keep-latest) keep_latest="$2"; shift 2 ;;
            --dry-run) dry_run=1; shift ;;
            -h|--help) usage; exit 0 ;;
            *) die "unknown arg: $1" ;;
        esac
    done

    [[ -n "$input" ]] || die "--input required"
    [[ -f "$input" ]] || die "input file not found: $input"

    if [[ -n "$max_age" && ! "$max_age" =~ ^[0-9]+$ ]]; then
        die "invalid --max-age-days: must be non-negative integer"
    fi
    if [[ -n "$max_size" && ! "$max_size" =~ ^[0-9]+$ ]]; then
        die "invalid --max-total-size: must be non-negative integer"
    fi
    if [[ -n "$keep_latest" && ! "$keep_latest" =~ ^[0-9]+$ ]]; then
        die "invalid --keep-latest: must be non-negative integer"
    fi

    local now_epoch
    if [[ -n "$now" ]]; then
        now_epoch=$(iso_to_epoch "$now")
    else
        now_epoch=$(date -u +%s)
    fi

    # Load artifacts into parallel arrays.
    local -a names sizes epochs workflows deletes reasons
    local name size iso wf epoch
    while IFS=$'\t' read -r name size iso wf || [[ -n "$name" ]]; do
        [[ -z "$name" ]] && continue
        epoch=$(iso_to_epoch "$iso")
        names+=("$name")
        sizes+=("$size")
        epochs+=("$epoch")
        workflows+=("$wf")
        deletes+=("0")
        reasons+=("")
    done < "$input"

    local n=${#names[@]}

    # Policy 1: max age.
    if [[ -n "$max_age" ]]; then
        local cutoff=$(( now_epoch - max_age * 86400 ))
        for ((i=0; i<n; i++)); do
            if (( epochs[i] < cutoff )); then
                deletes[i]=1
                reasons[i]="age"
            fi
        done
    fi

    # Policy 2: keep-latest-N per workflow.
    # For each workflow, sort indices by epoch desc; mark all past first N for deletion.
    if [[ -n "$keep_latest" ]]; then
        # Collect unique workflow IDs.
        local -A seen=()
        local -a uniq_wfs=()
        for ((i=0; i<n; i++)); do
            if [[ -z "${seen[${workflows[i]}]:-}" ]]; then
                seen[${workflows[i]}]=1
                uniq_wfs+=("${workflows[i]}")
            fi
        done
        local wf_id idx_sorted
        for wf_id in "${uniq_wfs[@]}"; do
            # Build "epoch idx" lines for this workflow, sort desc.
            idx_sorted=$(
                for ((i=0; i<n; i++)); do
                    if [[ "${workflows[i]}" == "$wf_id" ]]; then
                        echo "${epochs[i]} $i"
                    fi
                done | sort -rn
            )
            local kept=0
            while IFS=' ' read -r _ idx; do
                [[ -z "${idx:-}" ]] && continue
                if (( kept < keep_latest )); then
                    kept=$((kept+1))
                else
                    deletes[idx]=1
                    if [[ -z "${reasons[idx]}" ]]; then
                        reasons[idx]="keep-latest"
                    else
                        reasons[idx]="${reasons[idx]},keep-latest"
                    fi
                fi
            done <<< "$idx_sorted"
        done
    fi

    # Policy 3: max total size. Evaluate current retained total; delete oldest first until within cap.
    if [[ -n "$max_size" ]]; then
        local total=0
        for ((i=0; i<n; i++)); do
            if [[ "${deletes[i]}" == "0" ]]; then
                total=$(( total + sizes[i] ))
            fi
        done
        if (( total > max_size )); then
            # Order retained indices by epoch ascending (oldest first).
            local sorted
            sorted=$(
                for ((i=0; i<n; i++)); do
                    if [[ "${deletes[i]}" == "0" ]]; then
                        echo "${epochs[i]} $i"
                    fi
                done | sort -n
            )
            while IFS=' ' read -r _ idx; do
                [[ -z "${idx:-}" ]] && continue
                (( total <= max_size )) && break
                deletes[idx]=1
                if [[ -z "${reasons[idx]}" ]]; then
                    reasons[idx]="max-size"
                else
                    reasons[idx]="${reasons[idx]},max-size"
                fi
                total=$(( total - sizes[idx] ))
            done <<< "$sorted"
        fi
    fi

    # Emit plan.
    local del_count=0 ret_count=0 reclaimed=0
    for ((i=0; i<n; i++)); do
        if [[ "${deletes[i]}" == "1" ]]; then
            echo "DELETE: ${names[i]} (${reasons[i]}) size=${sizes[i]}"
            del_count=$((del_count+1))
            reclaimed=$(( reclaimed + sizes[i] ))
        else
            echo "KEEP: ${names[i]} size=${sizes[i]}"
            ret_count=$((ret_count+1))
        fi
    done

    echo "---"
    if (( dry_run )); then
        echo "Mode: dry-run"
    else
        echo "Mode: execute"
    fi
    echo "Total artifacts: $n"
    echo "Retained: $ret_count"
    echo "Deleted: $del_count"
    echo "Space reclaimed: $reclaimed"
}

main "$@"
