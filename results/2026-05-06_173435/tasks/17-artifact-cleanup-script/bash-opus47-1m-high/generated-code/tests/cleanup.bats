#!/usr/bin/env bats
# Tests for cleanup.sh - artifact retention policy engine.
#
# Input format (TSV, one artifact per line):
#   name<TAB>size_bytes<TAB>created_epoch<TAB>workflow_run_id
#
# The script is deterministic: --now lets tests freeze "current time".

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$ROOT/cleanup.sh"
  FIXTURES="$ROOT/fixtures"
  TMP="$(mktemp -d)"
  # 2026-05-07 00:00:00 UTC = 1778457600
  NOW=1778457600
}

teardown() {
  rm -rf "$TMP"
}

# ---------- basic plumbing ----------

@test "script exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "script passes bash -n syntax check" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "--help prints usage and exits 0" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--max-age-days"* ]]
  [[ "$output" == *"--max-total-size"* ]]
  [[ "$output" == *"--keep-latest"* ]]
  [[ "$output" == *"--dry-run"* ]]
}

@test "missing input file exits non-zero with clear error" {
  run "$SCRIPT" --input "$TMP/does-not-exist.tsv" --now "$NOW"
  [ "$status" -ne 0 ]
  [[ "$output" == *"input file not found"* ]] || [[ "$output" == *"does-not-exist"* ]]
}

@test "unknown option exits non-zero" {
  run "$SCRIPT" --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown"* ]] || [[ "$output" == *"Unknown"* ]]
}

# ---------- empty / minimal input ----------

@test "empty input produces zero-everything summary" {
  : > "$TMP/empty.tsv"
  run "$SCRIPT" --input "$TMP/empty.tsv" --now "$NOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Total artifacts: 0"* ]]
  [[ "$output" == *"Kept: 0"* ]]
  [[ "$output" == *"Deleted: 0"* ]]
  [[ "$output" == *"Space reclaimed: 0"* ]]
}

@test "input with only comments and blank lines is treated as empty" {
  printf '# comment line\n\n   \n' > "$TMP/comments.tsv"
  run "$SCRIPT" --input "$TMP/comments.tsv" --now "$NOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Total artifacts: 0"* ]]
}

# ---------- max-age policy ----------

@test "no policies: every artifact is kept" {
  # 3 artifacts, all from "yesterday"
  printf 'a\t1000\t%d\t1\nb\t2000\t%d\t1\nc\t3000\t%d\t2\n' \
    $((NOW-86400)) $((NOW-86400)) $((NOW-86400)) > "$TMP/all.tsv"
  run "$SCRIPT" --input "$TMP/all.tsv" --now "$NOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Kept: 3"* ]]
  [[ "$output" == *"Deleted: 0"* ]]
  [[ "$output" == *"Space reclaimed: 0"* ]]
}

@test "max-age-days deletes only artifacts older than the cutoff" {
  # one 5-day-old, one 30-day-old, one 100-day-old; cutoff 90 days
  printf 'recent\t100\t%d\t1\nmid\t200\t%d\t1\nancient\t500\t%d\t2\n' \
    $((NOW - 5*86400)) $((NOW - 30*86400)) $((NOW - 100*86400)) > "$TMP/age.tsv"
  run "$SCRIPT" --input "$TMP/age.tsv" --max-age-days 90 --now "$NOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Kept: 2"* ]]
  [[ "$output" == *"Deleted: 1"* ]]
  [[ "$output" == *"Space reclaimed: 500"* ]]
  [[ "$output" == *"DELETE"*"ancient"* ]]
  [[ "$output" == *"max-age"* ]]
}

# ---------- keep-latest-N per workflow ----------

@test "keep-latest 2 keeps the two newest per workflow_run_id" {
  # Workflow 1: four runs, oldest two should be deleted
  # Workflow 2: one run, kept
  printf 'w1-old\t100\t%d\t1\n'    $((NOW - 4*86400))  > "$TMP/keep.tsv"
  printf 'w1-mid\t100\t%d\t1\n'    $((NOW - 3*86400)) >> "$TMP/keep.tsv"
  printf 'w1-new\t100\t%d\t1\n'    $((NOW - 2*86400)) >> "$TMP/keep.tsv"
  printf 'w1-newest\t100\t%d\t1\n' $((NOW - 1*86400)) >> "$TMP/keep.tsv"
  printf 'w2-only\t999\t%d\t2\n'   $((NOW - 1*86400)) >> "$TMP/keep.tsv"

  run "$SCRIPT" --input "$TMP/keep.tsv" --keep-latest 2 --now "$NOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Kept: 3"* ]]
  [[ "$output" == *"Deleted: 2"* ]]
  [[ "$output" == *"Space reclaimed: 200"* ]]
  [[ "$output" == *"DELETE"*"w1-old"* ]]
  [[ "$output" == *"DELETE"*"w1-mid"* ]]
  [[ "$output" == *"keep-latest"* ]]
}

# ---------- max-total-size policy ----------

@test "max-total-size deletes oldest until under cap" {
  # Four 1000-byte artifacts; cap 2500 → must delete the two oldest (2 x 1000 = 2000 left)
  printf 'a\t1000\t%d\t1\n' $((NOW - 4*86400))  > "$TMP/size.tsv"
  printf 'b\t1000\t%d\t1\n' $((NOW - 3*86400)) >> "$TMP/size.tsv"
  printf 'c\t1000\t%d\t2\n' $((NOW - 2*86400)) >> "$TMP/size.tsv"
  printf 'd\t1000\t%d\t2\n' $((NOW - 1*86400)) >> "$TMP/size.tsv"

  run "$SCRIPT" --input "$TMP/size.tsv" --max-total-size 2500 --now "$NOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Kept: 2"* ]]
  [[ "$output" == *"Deleted: 2"* ]]
  [[ "$output" == *"Space reclaimed: 2000"* ]]
  [[ "$output" == *"DELETE"*"a"* ]]
  [[ "$output" == *"DELETE"*"b"* ]]
  [[ "$output" == *"max-total-size"* ]]
}

@test "max-total-size already under cap: nothing deleted" {
  printf 'a\t100\t%d\t1\n' $((NOW - 1*86400))  > "$TMP/under.tsv"
  printf 'b\t200\t%d\t1\n' $((NOW - 2*86400)) >> "$TMP/under.tsv"
  run "$SCRIPT" --input "$TMP/under.tsv" --max-total-size 1000 --now "$NOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Kept: 2"* ]]
  [[ "$output" == *"Deleted: 0"* ]]
}

# ---------- combined policies ----------

@test "policies stack: union of deletions, no double-counting" {
  # a: ancient (max-age delete)
  # b: old enough that keep-latest=1 evicts it under workflow 1
  # c: newest in workflow 1 (kept)
  # d: workflow 2 single (kept unless size kicks in)
  # Set max-total-size cap so it does NOT trigger here.
  printf 'a\t500\t%d\t1\n' $((NOW - 100*86400)) > "$TMP/combo.tsv"
  printf 'b\t300\t%d\t1\n' $((NOW - 10*86400)) >> "$TMP/combo.tsv"
  printf 'c\t100\t%d\t1\n' $((NOW - 1*86400))  >> "$TMP/combo.tsv"
  printf 'd\t100\t%d\t2\n' $((NOW - 1*86400))  >> "$TMP/combo.tsv"

  run "$SCRIPT" --input "$TMP/combo.tsv" \
    --max-age-days 90 --keep-latest 1 --max-total-size 100000 --now "$NOW"
  [ "$status" -eq 0 ]
  # a gets dropped by both age and keep-latest, but only counted once
  [[ "$output" == *"Kept: 2"* ]]
  [[ "$output" == *"Deleted: 2"* ]]
  [[ "$output" == *"Space reclaimed: 800"* ]]
}

# ---------- dry-run ----------

@test "dry-run mode is reported in the summary" {
  printf 'old\t100\t%d\t1\n' $((NOW - 100*86400)) > "$TMP/dry.tsv"
  run "$SCRIPT" --input "$TMP/dry.tsv" --max-age-days 30 --dry-run --now "$NOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]] || [[ "$output" == *"dry-run"* ]] || [[ "$output" == *"Mode: dry-run"* ]]
  [[ "$output" == *"Deleted: 1"* ]]
}

@test "non-dry-run mode reports execute" {
  printf 'old\t100\t%d\t1\n' $((NOW - 100*86400)) > "$TMP/exe.tsv"
  run "$SCRIPT" --input "$TMP/exe.tsv" --max-age-days 30 --now "$NOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Mode: execute"* ]]
}

# ---------- malformed input ----------

@test "row with non-numeric size is rejected" {
  printf 'bad\tnotanumber\t%d\t1\n' "$NOW" > "$TMP/bad.tsv"
  run "$SCRIPT" --input "$TMP/bad.tsv" --now "$NOW"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid"* ]] || [[ "$output" == *"malformed"* ]]
}

@test "row with too few columns is rejected" {
  printf 'bad\t100\n' > "$TMP/short.tsv"
  run "$SCRIPT" --input "$TMP/short.tsv" --now "$NOW"
  [ "$status" -ne 0 ]
}

# ---------- shellcheck ----------

@test "script passes shellcheck" {
  if ! command -v shellcheck >/dev/null; then
    skip "shellcheck not installed"
  fi
  run shellcheck "$SCRIPT"
  [ "$status" -eq 0 ]
}
