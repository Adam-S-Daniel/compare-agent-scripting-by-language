#!/usr/bin/env bash
#
# cleanup_artifacts.sh -- apply retention policies to a set of artifacts.
#
# Reads a TSV-formatted list of artifacts (name, size_bytes, created_epoch,
# workflow_run_id) and prints a deletion plan.  Three policies, applied in
# this order:
#
#   1. --max-age-days N            : delete artifacts older than N days.
#   2. --keep-latest-per-workflow N: per workflow_run_id, retain only the N
#                                    most recently created artifacts.
#   3. --max-total-size BYTES      : after the above, if the total size of the
#                                    surviving artifacts exceeds BYTES, delete
#                                    them oldest-first until under the limit.
#
# Output is a stable "plan" with one line per artifact, then a SUMMARY line.
# --dry-run only changes the prefix of the output ("DRY-RUN" header line):
# this script never deletes anything from the filesystem; callers are expected
# to feed the DELETE lines into a real deleter (e.g. `gh api ... DELETE`).
# This separation of concerns keeps the policy logic independently testable.

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: cleanup_artifacts.sh --input FILE [OPTIONS]

Apply retention policies to a list of artifacts and print a deletion plan.

Required:
  --input FILE                       TSV file: name<TAB>size<TAB>created_epoch<TAB>workflow_run_id

Policies (any combination, applied in declared order):
  --max-age-days N                   Delete artifacts older than N days.
  --keep-latest-per-workflow N       Per workflow_run_id, keep the N most recent.
  --max-total-size BYTES             After the above, prune oldest-first until total <= BYTES.

Modifiers:
  --dry-run                          Emit a DRY-RUN header. Does not change the plan.
  --now EPOCH                        Override "now" (for tests). Default: date +%s.
  --help                             Show this help.

Output:
  KEEP   <name> <size>
  DELETE <name> <size> <reason>
  SUMMARY retained=<N> deleted=<N> reclaimed_bytes=<N>
EOF
}

err() {
    printf 'error: %s\n' "$*" >&2
    exit 2
}

main() {
    local input="" max_age_days="" max_total_size="" keep_latest=""
    local dry_run=0 now_epoch=""

    # ---- argument parsing --------------------------------------------------
    while (( $# > 0 )); do
        case $1 in
            --help)
                usage
                exit 0
                ;;
            --dry-run)
                dry_run=1
                shift
                ;;
            --input|--max-age-days|--max-total-size|--keep-latest-per-workflow|--now)
                local flag=$1
                if (( $# < 2 )); then err "$flag requires a value"; fi
                local val=$2
                case $flag in
                    --input)                     input=$val ;;
                    --max-age-days)              max_age_days=$val ;;
                    --max-total-size)            max_total_size=$val ;;
                    --keep-latest-per-workflow)  keep_latest=$val ;;
                    --now)                       now_epoch=$val ;;
                esac
                shift 2
                ;;
            *)
                err "unknown argument: $1"
                ;;
        esac
    done

    [[ -n $input ]] || err "--input is required"
    [[ -f $input ]] || err "input file not found: $input"

    if [[ -n $max_age_days ]] && ! [[ $max_age_days =~ ^[0-9]+$ ]]; then
        err "--max-age-days must be a non-negative integer"
    fi
    if [[ -n $max_total_size ]] && ! [[ $max_total_size =~ ^[0-9]+$ ]]; then
        err "--max-total-size must be a non-negative integer"
    fi
    if [[ -n $keep_latest ]] && ! [[ $keep_latest =~ ^[0-9]+$ ]]; then
        err "--keep-latest-per-workflow must be a non-negative integer"
    fi
    if [[ -n $now_epoch ]] && ! [[ $now_epoch =~ ^[0-9]+$ ]]; then
        err "--now must be a non-negative integer"
    fi
    [[ -n $now_epoch ]] || now_epoch=$(date +%s)

    # ---- input parsing -----------------------------------------------------
    # Parallel arrays: index i corresponds to one artifact across all four.
    # `reasons[i]` is "" if the artifact is currently retained, or a short
    # tag identifying the policy that marked it for deletion.
    local -a names=() sizes=() created=() wfids=() reasons=()
    local lineno=0 line name size t wfid extra
    while IFS= read -r line || [[ -n $line ]]; do
        lineno=$((lineno + 1))
        # Skip blank and comment lines.
        if [[ -z ${line//[[:space:]]/} ]]; then continue; fi
        if [[ ${line:0:1} == "#" ]]; then continue; fi
        # Parse exactly 4 tab-separated fields. `extra` catches >4-field rows
        # because bash `read` packs trailing fields into the last variable.
        IFS=$'\t' read -r name size t wfid extra <<<"$line"
        if [[ -z $name || -z $size || -z $t || -z $wfid || -n $extra ]]; then
            err "malformed line $lineno (expected 4 tab-separated fields): $line"
        fi
        if ! [[ $size =~ ^[0-9]+$ ]]; then
            err "invalid size at line $lineno: $size"
        fi
        if ! [[ $t =~ ^[0-9]+$ ]]; then
            err "invalid created_epoch at line $lineno: $t"
        fi
        names+=("$name")
        sizes+=("$size")
        created+=("$t")
        wfids+=("$wfid")
        reasons+=("")
    done < "$input"

    local n=${#names[@]}

    # ---- policy 1: max-age-days -------------------------------------------
    if [[ -n $max_age_days ]] && (( n > 0 )); then
        local cutoff=$(( now_epoch - max_age_days * 86400 ))
        local i
        for ((i = 0; i < n; i++)); do
            if (( created[i] < cutoff )); then
                if [[ -z ${reasons[i]} ]]; then
                    reasons[i]="max-age"
                fi
            fi
        done
    fi

    # ---- policy 2: keep-latest-per-workflow -------------------------------
    if [[ -n $keep_latest ]] && (( n > 0 )); then
        # Build a list of unique workflow ids (preserving first-seen order is
        # not strictly necessary but keeps debugging output friendly).
        local -A seen=()
        local -a wfid_list=()
        local i
        for ((i = 0; i < n; i++)); do
            if [[ -z ${seen[${wfids[i]}]+x} ]]; then
                seen[${wfids[i]}]=1
                wfid_list+=("${wfids[i]}")
            fi
        done
        local g
        for g in "${wfid_list[@]}"; do
            # Sort indices in this group by created_epoch descending. Newest
            # come first, so the first $keep_latest survive the policy.
            local -a group_sorted=()
            mapfile -t group_sorted < <(
                for ((i = 0; i < n; i++)); do
                    if [[ ${wfids[i]} == "$g" ]]; then
                        printf '%s\t%s\n' "${created[i]}" "$i"
                    fi
                done | sort -t$'\t' -k1,1nr | awk -F'\t' '{print $2}'
            )
            local count=0 idx
            for idx in "${group_sorted[@]}"; do
                count=$((count + 1))
                if (( count > keep_latest )); then
                    if [[ -z ${reasons[idx]} ]]; then
                        reasons[idx]="keep-latest-per-workflow"
                    fi
                fi
            done
        done
    fi

    # ---- policy 3: max-total-size -----------------------------------------
    if [[ -n $max_total_size ]] && (( n > 0 )); then
        local kept_total=0 i
        for ((i = 0; i < n; i++)); do
            if [[ -z ${reasons[i]} ]]; then
                kept_total=$((kept_total + sizes[i]))
            fi
        done
        if (( kept_total > max_total_size )); then
            # Delete oldest-first among the still-retained artifacts.
            local -a sorted_kept=()
            mapfile -t sorted_kept < <(
                for ((i = 0; i < n; i++)); do
                    if [[ -z ${reasons[i]} ]]; then
                        printf '%s\t%s\n' "${created[i]}" "$i"
                    fi
                done | sort -t$'\t' -k1,1n | awk -F'\t' '{print $2}'
            )
            local idx
            for idx in "${sorted_kept[@]}"; do
                if (( kept_total <= max_total_size )); then
                    break
                fi
                reasons[idx]="max-total-size"
                kept_total=$((kept_total - sizes[idx]))
            done
        fi
    fi

    # ---- emit plan ---------------------------------------------------------
    if (( dry_run )); then
        echo "DRY-RUN (no artifacts will actually be deleted; reporting only)"
    fi

    local retained=0 deleted=0 reclaimed=0 i
    for ((i = 0; i < n; i++)); do
        if [[ -n ${reasons[i]} ]]; then
            printf 'DELETE\t%s\t%s\t%s\n' "${names[i]}" "${sizes[i]}" "${reasons[i]}"
            deleted=$((deleted + 1))
            reclaimed=$((reclaimed + sizes[i]))
        else
            printf 'KEEP\t%s\t%s\n' "${names[i]}" "${sizes[i]}"
            retained=$((retained + 1))
        fi
    done

    printf 'SUMMARY retained=%d deleted=%d reclaimed_bytes=%d\n' \
        "$retained" "$deleted" "$reclaimed"
}

main "$@"
