#!/usr/bin/env bash
#
# artifact-cleanup.sh
#
# Read a JSON list of artifacts (name, size_bytes, created_at, workflow_run_id),
# apply retention policies, and emit a deletion plan.
#
# Policies (all optional, combined with logical OR for "delete"):
#   --max-age-days N       Delete artifacts older than N days.
#   --max-total-size SZ    After applying other policies, if the total size of
#                          retained artifacts exceeds SZ, delete the oldest
#                          retained artifacts until under budget. Accepts
#                          suffixes B/KB/MB/GB (decimal).
#   --keep-latest N        Retain only the N newest artifacts per workflow;
#                          delete older ones.
#
# Mode flags:
#   --dry-run              Do not emulate deletion; only report.
#   --json                 Emit JSON plan + summary instead of human output.
#   --now YYYY-MM-DD       Override "today" for deterministic tests.
#   --input FILE           Path to input JSON. Defaults to stdin if absent.

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: artifact-cleanup.sh [OPTIONS]

Apply retention policies to a set of CI artifacts and emit a deletion plan.

Options:
  --input FILE           Input JSON file (array of artifact objects).
  --max-age-days N       Delete artifacts older than N days.
  --max-total-size SIZE  Cap total retained size. Accepts B, KB, MB, GB.
  --keep-latest N        Keep only N newest artifacts per workflow.
  --dry-run              Report what would be deleted; do not simulate deletion.
  --json                 Emit machine-readable JSON instead of text.
  --now YYYY-MM-DD       Override current date (for deterministic tests).
  -h, --help             Show this help and exit.

Exit codes:
  0  success
  1  usage or input error
  2  runtime error

Example:
  artifact-cleanup.sh --input artifacts.json --max-age-days 30 \
                      --keep-latest 5 --max-total-size 2GB --dry-run
EOF
}

err() {
    printf 'Error: %s\n' "$*" >&2
}

# Parse a size string like "800MB", "2GB", "1048576" into bytes.
parse_size() {
    local raw="$1"
    local num unit
    if [[ "$raw" =~ ^([0-9]+)([A-Za-z]*)$ ]]; then
        num="${BASH_REMATCH[1]}"
        unit="${BASH_REMATCH[2]^^}"
    else
        err "invalid size: $raw"
        return 1
    fi
    case "$unit" in
        ""|B)  echo "$num" ;;
        KB)    echo "$(( num * 1000 ))" ;;
        MB)    echo "$(( num * 1000 * 1000 ))" ;;
        GB)    echo "$(( num * 1000 * 1000 * 1000 ))" ;;
        *)     err "unknown size unit: $unit"; return 1 ;;
    esac
}

# Convert YYYY-MM-DD or ISO-8601 timestamp to epoch seconds.
to_epoch() {
    date -u -d "$1" +%s
}

main() {
    local input=""
    local max_age_days=""
    local max_total_size=""
    local keep_latest=""
    local dry_run=0
    local json_output=0
    local now_override=""

    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help) usage; exit 0 ;;
            --input) input="$2"; shift 2 ;;
            --max-age-days) max_age_days="$2"; shift 2 ;;
            --max-total-size) max_total_size="$2"; shift 2 ;;
            --keep-latest) keep_latest="$2"; shift 2 ;;
            --dry-run) dry_run=1; shift ;;
            --json) json_output=1; shift ;;
            --now) now_override="$2"; shift 2 ;;
            *) err "unknown option: $1"; usage >&2; exit 1 ;;
        esac
    done

    # Resolve input source
    local input_json
    if [ -n "$input" ]; then
        if [ ! -f "$input" ]; then
            err "input file not found: $input"
            exit 1
        fi
        input_json="$(cat "$input")"
    else
        input_json="$(cat)"
    fi

    # Validate JSON
    if ! echo "$input_json" | jq -e 'type == "array"' >/dev/null 2>&1; then
        err "input is not valid JSON array"
        exit 1
    fi

    # Determine "now"
    local now_epoch
    if [ -n "$now_override" ]; then
        now_epoch="$(to_epoch "$now_override")"
    else
        now_epoch="$(date -u +%s)"
    fi

    # Build a normalized TSV of artifacts sorted by created_at ASC:
    #   idx  name  size_bytes  created_epoch  workflow_run_id  reasons(|-joined)
    # "reasons" starts empty; we fill it as each policy fires.
    local tsv
    tsv="$(echo "$input_json" | jq -r '
        sort_by(.created_at) |
        to_entries[] |
        "\(.key)\t\(.value.name)\t\(.value.size_bytes)\t\(.value.created_at)\t\(.value.workflow_run_id)"
    ')"

    # Convert created_at ISO to epoch in a second pass (bash side so jq stays portable).
    local work=""
    while IFS=$'\t' read -r idx name size created wf; do
        [ -z "$idx" ] && continue
        local ep
        ep="$(to_epoch "$created")"
        work+="${idx}"$'\t'"${name}"$'\t'"${size}"$'\t'"${ep}"$'\t'"${wf}"$'\t'$'\n'
    done <<< "$tsv"

    # Apply policies: mark reasons for deletion.
    # We keep `work` immutable in structure; just mutate the "reasons" column.
    local new_work=""

    # --- max-age-days ---
    if [ -n "$max_age_days" ]; then
        local cutoff=$(( now_epoch - max_age_days * 86400 ))
        while IFS=$'\t' read -r idx name size ep wf reasons; do
            [ -z "$idx" ] && continue
            if [ "$ep" -lt "$cutoff" ]; then
                reasons="${reasons:+$reasons|}max-age"
            fi
            new_work+="${idx}"$'\t'"${name}"$'\t'"${size}"$'\t'"${ep}"$'\t'"${wf}"$'\t'"${reasons}"$'\n'
        done <<< "$work"
        work="$new_work"
        new_work=""
    fi

    # --- keep-latest-N per workflow ---
    if [ -n "$keep_latest" ]; then
        # Sort DESC by created time per workflow, mark everything past position N.
        # First collect per-workflow positions.
        declare -A wf_rank
        # Process lines in DESC order of ep.
        local sorted_desc
        sorted_desc="$(printf '%s' "$work" | sort -t $'\t' -k4,4nr)"
        local -A seen_count
        while IFS=$'\t' read -r idx name size ep wf reasons; do
            [ -z "$idx" ] && continue
            seen_count["$wf"]=$(( ${seen_count["$wf"]:-0} + 1 ))
            if [ "${seen_count["$wf"]}" -gt "$keep_latest" ]; then
                wf_rank["$idx"]=1
            fi
        done <<< "$sorted_desc"

        while IFS=$'\t' read -r idx name size ep wf reasons; do
            [ -z "$idx" ] && continue
            if [ "${wf_rank["$idx"]:-0}" -eq 1 ]; then
                reasons="${reasons:+$reasons|}keep-latest"
            fi
            new_work+="${idx}"$'\t'"${name}"$'\t'"${size}"$'\t'"${ep}"$'\t'"${wf}"$'\t'"${reasons}"$'\n'
        done <<< "$work"
        work="$new_work"
        new_work=""
    fi

    # --- max-total-size (budget) ---
    # Among artifacts NOT yet marked, if total retained size > budget,
    # delete oldest first until under.
    if [ -n "$max_total_size" ]; then
        local budget
        budget="$(parse_size "$max_total_size")"
        local total=0
        while IFS=$'\t' read -r idx name size ep wf reasons; do
            [ -z "$idx" ] && continue
            if [ -z "$reasons" ]; then
                total=$(( total + size ))
            fi
        done <<< "$work"

        if [ "$total" -gt "$budget" ]; then
            # Sort oldest first to find eviction candidates.
            local sorted_asc
            sorted_asc="$(printf '%s' "$work" | sort -t $'\t' -k4,4n)"
            declare -A evict
            while IFS=$'\t' read -r idx name size ep wf reasons; do
                [ -z "$idx" ] && continue
                [ "$total" -le "$budget" ] && break
                if [ -z "$reasons" ]; then
                    evict["$idx"]=1
                    total=$(( total - size ))
                fi
            done <<< "$sorted_asc"

            while IFS=$'\t' read -r idx name size ep wf reasons; do
                [ -z "$idx" ] && continue
                if [ "${evict["$idx"]:-0}" -eq 1 ]; then
                    reasons="${reasons:+$reasons|}max-total-size"
                fi
                new_work+="${idx}"$'\t'"${name}"$'\t'"${size}"$'\t'"${ep}"$'\t'"${wf}"$'\t'"${reasons}"$'\n'
            done <<< "$work"
            work="$new_work"
            new_work=""
        fi
    fi

    # --- tally + emit ---
    local deleted_count=0
    local retained_count=0
    local reclaimed=0

    # Build per-entry plan lines in original order (idx ASC).
    local ordered
    ordered="$(printf '%s' "$work" | sort -t $'\t' -k1,1n)"

    if [ "$json_output" -eq 1 ]; then
        # Assemble JSON by piping a TSV-like stream into jq.
        local plan_json
        plan_json="$(printf '%s' "$ordered" | awk -F'\t' '
            BEGIN { printf "[" }
            NF >= 5 {
                if (NR > 1) printf ","
                action = ($6 == "" ? "KEEP" : "DELETE")
                # escape quotes in name
                gsub(/\\/, "\\\\", $2); gsub(/"/, "\\\"", $2)
                gsub(/\\/, "\\\\", $5); gsub(/"/, "\\\"", $5)
                gsub(/\\/, "\\\\", $6); gsub(/"/, "\\\"", $6)
                printf "{\"name\":\"%s\",\"size_bytes\":%s,\"created_epoch\":%s,\"workflow_run_id\":\"%s\",\"action\":\"%s\",\"reasons\":\"%s\"}",
                    $2, $3, $4, $5, action, $6
            }
            END { printf "]" }
        ')"

        while IFS=$'\t' read -r idx name size ep wf reasons; do
            [ -z "$idx" ] && continue
            if [ -n "$reasons" ]; then
                deleted_count=$(( deleted_count + 1 ))
                reclaimed=$(( reclaimed + size ))
            else
                retained_count=$(( retained_count + 1 ))
            fi
        done <<< "$ordered"

        jq -n \
            --argjson plan "$plan_json" \
            --argjson deleted "$deleted_count" \
            --argjson retained "$retained_count" \
            --argjson reclaimed "$reclaimed" \
            --argjson dry "$dry_run" \
            '{
                summary: {
                    deleted_count: $deleted,
                    retained_count: $retained,
                    space_reclaimed_bytes: $reclaimed,
                    dry_run: ($dry == 1)
                },
                plan: $plan
            }'
        exit 0
    fi

    # Human-readable output
    if [ "$dry_run" -eq 1 ]; then
        echo "=== DRY-RUN: no artifacts will actually be removed ==="
    fi

    printf '%-8s %-30s %12s %-22s %s\n' "ACTION" "NAME" "SIZE(B)" "WORKFLOW" "REASON"
    printf '%-8s %-30s %12s %-22s %s\n' "------" "----" "-------" "--------" "------"

    while IFS=$'\t' read -r idx name size ep wf reasons; do
        [ -z "$idx" ] && continue
        local action
        if [ -n "$reasons" ]; then
            action="DELETE"
            deleted_count=$(( deleted_count + 1 ))
            reclaimed=$(( reclaimed + size ))
        else
            action="KEEP"
            retained_count=$(( retained_count + 1 ))
        fi
        printf '%-8s %-30s %12s %-22s %s\n' "$action" "$name" "$size" "$wf" "${reasons:--}"
    done <<< "$ordered"

    echo
    echo "Summary:"
    echo "  Deleted: $deleted_count"
    echo "  Retained: $retained_count"
    echo "  Space reclaimed: $reclaimed bytes"

    if [ "$dry_run" -eq 0 ] && [ "$deleted_count" -gt 0 ]; then
        # There's nothing to actually delete (artifacts are metadata only),
        # but we surface that the plan was committed.
        echo "  Status:          DELETED (simulated; no real storage touched)"
    fi
}

main "$@"
