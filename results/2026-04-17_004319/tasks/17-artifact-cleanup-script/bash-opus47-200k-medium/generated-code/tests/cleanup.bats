#!/usr/bin/env bats
# TDD-style tests for cleanup.sh. Each test produces a small TSV fixture inline,
# invokes the script with a deterministic --now, and asserts on the plan output.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../cleanup.sh"
  TMP="$(mktemp -d)"
  NOW=1_700_000_000  # 2023-11-14, fixed for determinism
  NOW=${NOW//_/}
}

teardown() {
  rm -rf "$TMP"
}

make_input() {
  printf '%s\n' "$@" > "$TMP/in.tsv"
}

@test "errors when --input is missing" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"--input is required"* ]]
}

@test "errors when input file does not exist" {
  run bash "$SCRIPT" --input /no/such/file
  [ "$status" -eq 2 ]
  [[ "$output" == *"input file not found"* ]]
}

@test "empty input yields empty plan and zero summary" {
  : > "$TMP/in.tsv"
  run bash "$SCRIPT" --input "$TMP/in.tsv" --now "$NOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"total_artifacts=0"* ]]
  [[ "$output" == *"deleted=0"* ]]
  [[ "$output" == *"retained=0"* ]]
  [[ "$output" == *"mode=execute"* ]]
}

@test "retains all artifacts when no policy given" {
  # 2 artifacts, no policies applied -> everything retained.
  local older=$((NOW - 10 * 86400))
  local newer=$((NOW - 1 * 86400))
  make_input \
    "a.zip	100	$older	w1" \
    "b.zip	200	$newer	w1"
  run bash "$SCRIPT" --input "$TMP/in.tsv" --now "$NOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"retained=2"* ]]
  [[ "$output" == *"deleted=0"* ]]
  [[ "$output" == *"retained_bytes=300"* ]]
}

@test "max-age-days deletes artifacts older than cutoff" {
  local old=$((NOW - 40 * 86400))
  local new=$((NOW - 5 * 86400))
  make_input \
    "old.zip	1000	$old	w1" \
    "new.zip	500	$new	w1"
  run bash "$SCRIPT" --input "$TMP/in.tsv" --now "$NOW" --max-age-days 30
  [ "$status" -eq 0 ]
  [[ "$output" == *"DELETE	old.zip"* ]]
  [[ "$output" == *"reason=age>30d"* ]]
  [[ "$output" == *"KEEP	new.zip"* ]]
  [[ "$output" == *"reclaimed_bytes=1000"* ]]
  [[ "$output" == *"retained_bytes=500"* ]]
}

@test "keep-latest per workflow deletes older ones beyond N per workflow" {
  local t1=$((NOW - 4 * 86400))
  local t2=$((NOW - 3 * 86400))
  local t3=$((NOW - 2 * 86400))
  local t4=$((NOW - 1 * 86400))
  # 3 in w1, 1 in w2. keep-latest=2 => deletes oldest in w1 only.
  make_input \
    "w1-a	10	$t1	w1" \
    "w1-b	10	$t2	w1" \
    "w1-c	10	$t3	w1" \
    "w2-a	10	$t4	w2"
  run bash "$SCRIPT" --input "$TMP/in.tsv" --now "$NOW" --keep-latest 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"DELETE	w1-a"* ]]
  [[ "$output" == *"KEEP	w1-b"* ]]
  [[ "$output" == *"KEEP	w1-c"* ]]
  [[ "$output" == *"KEEP	w2-a"* ]]
  [[ "$output" == *"deleted=1"* ]]
  [[ "$output" == *"retained=3"* ]]
}

@test "max-total-size evicts oldest retained until under budget" {
  local t1=$((NOW - 4 * 86400))
  local t2=$((NOW - 3 * 86400))
  local t3=$((NOW - 1 * 86400))
  # total 300, budget 150 => delete the two oldest (a=100, b=100) leaving c=100.
  make_input \
    "a	100	$t1	w1" \
    "b	100	$t2	w1" \
    "c	100	$t3	w1"
  run bash "$SCRIPT" --input "$TMP/in.tsv" --now "$NOW" --max-total-size 150
  [ "$status" -eq 0 ]
  [[ "$output" == *"DELETE	a"* ]]
  [[ "$output" == *"DELETE	b"* ]]
  [[ "$output" == *"KEEP	c"* ]]
  [[ "$output" == *"retained_bytes=100"* ]]
  [[ "$output" == *"reclaimed_bytes=200"* ]]
}

@test "dry-run flag flips mode label without changing the plan" {
  local old=$((NOW - 60 * 86400))
  make_input "old.zip	50	$old	w1"
  run bash "$SCRIPT" --input "$TMP/in.tsv" --now "$NOW" --max-age-days 30 --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"mode=dry-run"* ]]
  [[ "$output" == *"DELETE	old.zip"* ]]
}

@test "combined policies: age + keep-latest + size budget" {
  local very_old=$((NOW - 100 * 86400))
  local old=$((NOW - 40 * 86400))
  local mid=$((NOW - 10 * 86400))
  local recent=$((NOW - 1 * 86400))
  make_input \
    "vold	1000	$very_old	w1" \
    "old	100	$old	w1" \
    "mid	100	$mid	w1" \
    "rec	100	$recent	w1" \
    "w2	100	$recent	w2"
  # age>30 deletes vold+old, keep-latest=1 in w1 deletes mid (rec newest kept),
  # then budget 150 is already satisfied by rec+w2=200? => delete one more (rec is older than w2 only by seconds, same day; tie-break: rec created earlier).
  # To make it deterministic let's use budget 250 so no size eviction kicks in.
  run bash "$SCRIPT" --input "$TMP/in.tsv" --now "$NOW" --max-age-days 30 --keep-latest 1 --max-total-size 250
  [ "$status" -eq 0 ]
  [[ "$output" == *"DELETE	vold"* ]]
  [[ "$output" == *"DELETE	old"* ]]
  [[ "$output" == *"DELETE	mid"* ]]
  [[ "$output" == *"KEEP	rec"* ]]
  [[ "$output" == *"KEEP	w2"* ]]
  [[ "$output" == *"deleted=3"* ]]
  [[ "$output" == *"retained=2"* ]]
  [[ "$output" == *"reclaimed_bytes=1200"* ]]
}

@test "rejects malformed input line" {
  printf 'only-one-column\n' > "$TMP/in.tsv"
  run bash "$SCRIPT" --input "$TMP/in.tsv"
  [ "$status" -eq 2 ]
  [[ "$output" == *"malformed record"* ]]
}

@test "rejects non-numeric size" {
  printf 'x\tNaN\t1000\tw1\n' > "$TMP/in.tsv"
  run bash "$SCRIPT" --input "$TMP/in.tsv"
  [ "$status" -eq 2 ]
  [[ "$output" == *"non-numeric"* ]]
}
