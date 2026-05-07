#!/usr/bin/env bash
#
# cleanup.sh — apply retention policies to a list of artifacts and emit a
# deletion plan. The script is pure-text in/out: it does not contact any real
# artifact API. That keeps it deterministic and testable; a caller integrating
# with GitHub's REST API can pipe the plan into another tool.
#
# Input: TSV with one artifact per line:
#   name<TAB>size_bytes<TAB>created_epoch<TAB>workflow_run_id
# Lines starting with "#" and blank lines are ignored.
#
# Policies (any combination, applied as a union):
#   --max-age-days N       drop artifacts older than N days
#   --max-total-size B     drop oldest until total kept-size <= B bytes
#   --keep-latest N        keep only the N newest per workflow_run_id
#
# --dry-run only changes the "Mode:" line in the summary (no real deletes
# happen in either mode here — the plan is the deliverable).
# --now EPOCH lets tests freeze the clock.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: cleanup.sh --input FILE [policies] [--dry-run] [--now EPOCH]

Reads artifacts (TSV: name<TAB>size<TAB>created_epoch<TAB>workflow_run_id),
applies retention policies, and prints a deletion plan + summary.

Policies (any combination):
  --max-age-days N       Delete artifacts older than N days
  --max-total-size B     Delete oldest first until total kept size <= B bytes
  --keep-latest N        Keep only the N newest artifacts per workflow_run_id

Other:
  --dry-run              Mark the plan as a dry run (no side effects either way)
  --now EPOCH            Override "current time" for deterministic tests
  -h, --help             Show this help
EOF
}

err() { printf 'cleanup.sh: %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# argument parsing
# ---------------------------------------------------------------------------
input=""
max_age_days=""
max_total_size=""
keep_latest=""
dry_run=0
now=""

while [ $# -gt 0 ]; do
  case "$1" in
    --input)           input="${2:?--input requires a path}"; shift 2 ;;
    --max-age-days)    max_age_days="${2:?--max-age-days requires a value}"; shift 2 ;;
    --max-total-size)  max_total_size="${2:?--max-total-size requires a value}"; shift 2 ;;
    --keep-latest)     keep_latest="${2:?--keep-latest requires a value}"; shift 2 ;;
    --now)             now="${2:?--now requires an epoch value}"; shift 2 ;;
    --dry-run)         dry_run=1; shift ;;
    -h|--help)         usage; exit 0 ;;
    *)                 err "unknown option: $1"; usage >&2; exit 2 ;;
  esac
done

if [ -z "$input" ]; then
  err "missing required --input"
  usage >&2
  exit 2
fi
if [ ! -f "$input" ]; then
  err "input file not found: $input"
  exit 2
fi
if [ -z "$now" ]; then
  now="$(date +%s)"
fi

# Numeric validation for the policy values that are set.
is_nonneg_int() { [[ "$1" =~ ^[0-9]+$ ]]; }
for var_name in max_age_days max_total_size keep_latest now; do
  v="${!var_name}"
  if [ -n "$v" ] && ! is_nonneg_int "$v"; then
    err "invalid --${var_name//_/-} value: $v"
    exit 2
  fi
done

# ---------------------------------------------------------------------------
# load + validate artifacts
# ---------------------------------------------------------------------------
# We hold artifacts in four parallel arrays indexed by load order. Bash 3
# doesn't have hash maps with array values, so parallel arrays are the
# simplest portable structure. The keep[] array is the working set: 1 = kept,
# 0 = marked-for-delete. Reasons accumulate in del_reason[] for auditing.
names=()
sizes=()
created=()
workflows=()
keep=()
del_reason=()

line_no=0
while IFS= read -r line || [ -n "$line" ]; do
  line_no=$((line_no + 1))
  # Strip trailing CR (Windows line endings) and skip comments / blanks.
  line="${line%$'\r'}"
  trimmed="${line#"${line%%[![:space:]]*}"}"
  case "$trimmed" in
    ''|'#'*) continue ;;
  esac

  IFS=$'\t' read -r f_name f_size f_created f_workflow <<<"$line"
  if [ -z "${f_name:-}" ] || [ -z "${f_size:-}" ] || [ -z "${f_created:-}" ] || [ -z "${f_workflow:-}" ]; then
    err "line $line_no: malformed row (need 4 tab-separated fields)"
    exit 2
  fi
  if ! is_nonneg_int "$f_size";    then err "line $line_no: invalid size: $f_size"; exit 2; fi
  if ! is_nonneg_int "$f_created"; then err "line $line_no: invalid created_epoch: $f_created"; exit 2; fi

  names+=("$f_name")
  sizes+=("$f_size")
  created+=("$f_created")
  workflows+=("$f_workflow")
  keep+=("1")
  del_reason+=("")
done < "$input"

n="${#names[@]}"

mark_delete() {
  # mark_delete <index> <reason>
  # Idempotent: first reason wins, so a single artifact never double-counts
  # against the summary even if multiple policies would drop it.
  local i="$1" reason="$2"
  if [ "${keep[$i]}" = "1" ]; then
    keep[i]=0
    del_reason[i]="$reason"
  fi
}

# ---------------------------------------------------------------------------
# policy: max-age-days
# ---------------------------------------------------------------------------
if [ -n "$max_age_days" ]; then
  cutoff=$(( now - max_age_days * 86400 ))
  for ((i=0; i<n; i++)); do
    if [ "${created[$i]}" -lt "$cutoff" ]; then
      mark_delete "$i" "max-age (>${max_age_days}d)"
    fi
  done
fi

# ---------------------------------------------------------------------------
# policy: keep-latest N per workflow_run_id
# ---------------------------------------------------------------------------
# For each workflow group, sort its currently-kept members by created DESC
# (newest first). Keep the first N indices, mark the rest for deletion.
if [ -n "$keep_latest" ]; then
  # Collect distinct workflow ids among still-kept rows.
  declare -A seen_wf=()
  for ((i=0; i<n; i++)); do
    [ "${keep[$i]}" = "1" ] || continue
    seen_wf["${workflows[$i]}"]=1
  done
  for wf in "${!seen_wf[@]}"; do
    # indices in this workflow, kept only
    group=()
    for ((i=0; i<n; i++)); do
      if [ "${keep[$i]}" = "1" ] && [ "${workflows[$i]}" = "$wf" ]; then
        group+=("$i")
      fi
    done
    # Sort by created DESC. Pipe "epoch idx" lines to sort.
    sorted=()
    while IFS= read -r idx; do
      sorted+=("$idx")
    done < <(
      for idx in "${group[@]}"; do
        printf '%s %s\n' "${created[$idx]}" "$idx"
      done | sort -k1,1nr -k2,2n | awk '{print $2}'
    )
    # Keep first N, drop the rest.
    for ((j=0; j<${#sorted[@]}; j++)); do
      if [ "$j" -ge "$keep_latest" ]; then
        mark_delete "${sorted[$j]}" "keep-latest (workflow=$wf, rank>$keep_latest)"
      fi
    done
  done
fi

# ---------------------------------------------------------------------------
# policy: max-total-size
# ---------------------------------------------------------------------------
# Of the still-kept artifacts, sum sizes. If over cap, delete oldest first
# until under. We only consider rows that are *currently* kept, so this layers
# correctly on top of the other two policies.
if [ -n "$max_total_size" ]; then
  total=0
  for ((i=0; i<n; i++)); do
    [ "${keep[$i]}" = "1" ] || continue
    total=$(( total + sizes[i] ))
  done
  if [ "$total" -gt "$max_total_size" ]; then
    # Sort kept indices by created ASC (oldest first).
    oldest_first=()
    while IFS= read -r idx; do
      oldest_first+=("$idx")
    done < <(
      for ((i=0; i<n; i++)); do
        [ "${keep[$i]}" = "1" ] || continue
        printf '%s %s\n' "${created[$i]}" "$i"
      done | sort -k1,1n -k2,2n | awk '{print $2}'
    )
    for idx in "${oldest_first[@]}"; do
      [ "$total" -gt "$max_total_size" ] || break
      mark_delete "$idx" "max-total-size (cap=${max_total_size}B)"
      total=$(( total - sizes[idx] ))
    done
  fi
fi

# ---------------------------------------------------------------------------
# emit plan + summary
# ---------------------------------------------------------------------------
mode="execute"
[ "$dry_run" -eq 1 ] && mode="dry-run"

printf 'Artifact Cleanup Plan\n'
printf '=====================\n'
printf 'Mode: %s\n' "$mode"
printf '\n'

kept_count=0
del_count=0
reclaimed=0

# Print KEEP rows first (stable, in load order), then DELETE rows.
for ((i=0; i<n; i++)); do
  if [ "${keep[$i]}" = "1" ]; then
    kept_count=$(( kept_count + 1 ))
    printf 'KEEP    name=%s size=%s workflow=%s\n' \
      "${names[$i]}" "${sizes[$i]}" "${workflows[$i]}"
  fi
done
for ((i=0; i<n; i++)); do
  if [ "${keep[$i]}" = "0" ]; then
    del_count=$(( del_count + 1 ))
    reclaimed=$(( reclaimed + sizes[i] ))
    printf 'DELETE  name=%s size=%s workflow=%s reason=%s\n' \
      "${names[$i]}" "${sizes[$i]}" "${workflows[$i]}" "${del_reason[$i]}"
  fi
done

printf '\n'
printf 'Summary:\n'
printf '  Total artifacts: %d\n' "$n"
printf '  Kept: %d\n'             "$kept_count"
printf '  Deleted: %d\n'          "$del_count"
printf '  Space reclaimed: %d bytes\n' "$reclaimed"
