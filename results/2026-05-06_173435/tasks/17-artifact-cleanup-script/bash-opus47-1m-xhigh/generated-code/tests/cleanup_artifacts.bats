#!/usr/bin/env bats

# TDD test suite for cleanup_artifacts.sh.
# Each test is independent and uses tmpdir-based fixtures to keep state isolated.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../cleanup_artifacts.sh"
    TMPDIR="$(mktemp -d)"
    # Fixed reference time for deterministic age math (2026-01-01 00:00:00 UTC).
    NOW_EPOCH=1767225600
}

teardown() {
    rm -rf "$TMPDIR"
}

# ---------- Step 1: skeleton ----------

@test "script file exists and is executable" {
    [ -x "$SCRIPT" ]
}

@test "script prints usage when given --help" {
    run "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"--input"* ]]
    [[ "$output" == *"--max-age-days"* ]]
    [[ "$output" == *"--max-total-size"* ]]
    [[ "$output" == *"--keep-latest-per-workflow"* ]]
    [[ "$output" == *"--dry-run"* ]]
}

@test "script errors with meaningful message when --input missing" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"--input"* ]]
}

@test "script errors when input file does not exist" {
    run "$SCRIPT" --input "$TMPDIR/missing.tsv"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* || "$output" == *"does not exist"* ]]
}

# ---------- Step 2: basic input parsing, no policies => everything KEPT ----------

@test "with no policies all artifacts are KEEP" {
    cat > "$TMPDIR/in.tsv" <<EOF
small.zip	100	1767100000	wf1
large.zip	1000	1767200000	wf2
EOF
    run "$SCRIPT" --input "$TMPDIR/in.tsv"
    [ "$status" -eq 0 ]
    [[ "$output" == *"KEEP"*"small.zip"* ]]
    [[ "$output" == *"KEEP"*"large.zip"* ]]
    [[ "$output" != *"DELETE"*"small.zip"* ]]
    [[ "$output" != *"DELETE"*"large.zip"* ]]
}

@test "summary reports counts and bytes for keep-only run" {
    cat > "$TMPDIR/in.tsv" <<EOF
a.zip	100	1767100000	wf1
b.zip	250	1767200000	wf2
EOF
    run "$SCRIPT" --input "$TMPDIR/in.tsv"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SUMMARY"* ]]
    [[ "$output" == *"retained=2"* ]]
    [[ "$output" == *"deleted=0"* ]]
    [[ "$output" == *"reclaimed_bytes=0"* ]]
}

# ---------- Step 3: max-age policy ----------

@test "max-age-days deletes artifacts older than threshold" {
    # Threshold: max-age-days=10 with NOW=1767225600 (2026-01-01).
    # 10 days = 864000 sec, so cutoff = 1766361600 (2025-12-22).
    # old.zip created 1765000000 (2025-12-06) => DELETE
    # fresh.zip created 1767100000 (2025-12-30) => KEEP
    cat > "$TMPDIR/in.tsv" <<EOF
old.zip	500	1765000000	wf1
fresh.zip	100	1767100000	wf2
EOF
    run "$SCRIPT" --input "$TMPDIR/in.tsv" --max-age-days 10 --now "$NOW_EPOCH"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE"*"old.zip"*"max-age"* ]]
    [[ "$output" == *"KEEP"*"fresh.zip"* ]]
    [[ "$output" == *"retained=1"* ]]
    [[ "$output" == *"deleted=1"* ]]
    [[ "$output" == *"reclaimed_bytes=500"* ]]
}

@test "max-age-days with no expired artifacts deletes nothing" {
    cat > "$TMPDIR/in.tsv" <<EOF
a.zip	100	1767100000	wf1
EOF
    run "$SCRIPT" --input "$TMPDIR/in.tsv" --max-age-days 365 --now "$NOW_EPOCH"
    [ "$status" -eq 0 ]
    [[ "$output" == *"KEEP"*"a.zip"* ]]
    [[ "$output" == *"deleted=0"* ]]
}

# ---------- Step 4: keep-latest-N per workflow ----------

@test "keep-latest-per-workflow keeps N most recent per workflow_run_id" {
    # wf1 has 4 artifacts; keep latest 2; oldest 2 deleted.
    # wf2 has 1 artifact; should be kept.
    cat > "$TMPDIR/in.tsv" <<EOF
wf1-old1.zip	10	1700000000	wf1
wf1-old2.zip	20	1700000100	wf1
wf1-new1.zip	30	1700000200	wf1
wf1-new2.zip	40	1700000300	wf1
wf2-only.zip	50	1700000400	wf2
EOF
    run "$SCRIPT" --input "$TMPDIR/in.tsv" --keep-latest-per-workflow 2
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE"*"wf1-old1.zip"* ]]
    [[ "$output" == *"DELETE"*"wf1-old2.zip"* ]]
    [[ "$output" == *"KEEP"*"wf1-new1.zip"* ]]
    [[ "$output" == *"KEEP"*"wf1-new2.zip"* ]]
    [[ "$output" == *"KEEP"*"wf2-only.zip"* ]]
    [[ "$output" == *"retained=3"* ]]
    [[ "$output" == *"deleted=2"* ]]
    [[ "$output" == *"reclaimed_bytes=30"* ]]
}

# ---------- Step 5: max-total-size ----------

@test "max-total-size deletes oldest first until under limit" {
    # Sizes: 100 + 200 + 300 + 400 = 1000 total. Limit 500.
    # Sorted by age ascending (oldest first to delete):
    # a.zip(100, t=1000), b.zip(200, t=2000), c.zip(300, t=3000), d.zip(400, t=4000)
    # Need to free at least 500. Delete a (100), b (200) => freed 300, still 700>500.
    # Delete c (300) => freed 600, remaining = 400 <= 500. Stop. d kept.
    cat > "$TMPDIR/in.tsv" <<EOF
a.zip	100	1000	wf1
b.zip	200	2000	wf1
c.zip	300	3000	wf1
d.zip	400	4000	wf1
EOF
    run "$SCRIPT" --input "$TMPDIR/in.tsv" --max-total-size 500
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE"*"a.zip"*"max-total-size"* ]]
    [[ "$output" == *"DELETE"*"b.zip"*"max-total-size"* ]]
    [[ "$output" == *"DELETE"*"c.zip"*"max-total-size"* ]]
    [[ "$output" == *"KEEP"*"d.zip"* ]]
    [[ "$output" == *"reclaimed_bytes=600"* ]]
}

@test "max-total-size below limit keeps everything" {
    cat > "$TMPDIR/in.tsv" <<EOF
a.zip	100	1000	wf1
b.zip	200	2000	wf1
EOF
    run "$SCRIPT" --input "$TMPDIR/in.tsv" --max-total-size 1000
    [ "$status" -eq 0 ]
    [[ "$output" == *"KEEP"*"a.zip"* ]]
    [[ "$output" == *"KEEP"*"b.zip"* ]]
    [[ "$output" == *"deleted=0"* ]]
}

# ---------- Step 6: dry-run mode ----------

@test "dry-run prefixes output with DRY-RUN marker" {
    cat > "$TMPDIR/in.tsv" <<EOF
old.zip	500	1765000000	wf1
EOF
    run "$SCRIPT" --input "$TMPDIR/in.tsv" --max-age-days 1 --now "$NOW_EPOCH" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN"* ]]
    [[ "$output" == *"DELETE"*"old.zip"* ]]
}

# ---------- Step 7: combined policies ----------

@test "combined policies apply max-age, then keep-latest, then max-size" {
    # 4 artifacts. max-age-days=400 keeps everything. keep-latest=2 per wf1.
    # wf1: e=1700000000(oldest), f=1700000100, g=1700000200, h=1700000300(newest)
    # After keep-latest=2: e and f deleted, g and h kept.
    # Sizes: e=10, f=20, g=30, h=40. Remaining total=70. max-total-size=50 trims older first.
    # Delete g (30) => total = 40. Done. h kept.
    cat > "$TMPDIR/in.tsv" <<EOF
e.zip	10	1700000000	wf1
f.zip	20	1700000100	wf1
g.zip	30	1700000200	wf1
h.zip	40	1700000300	wf1
EOF
    run "$SCRIPT" --input "$TMPDIR/in.tsv" \
        --max-age-days 4000 --now "$NOW_EPOCH" \
        --keep-latest-per-workflow 2 \
        --max-total-size 50
    [ "$status" -eq 0 ]
    [[ "$output" == *"DELETE"*"e.zip"* ]]
    [[ "$output" == *"DELETE"*"f.zip"* ]]
    [[ "$output" == *"DELETE"*"g.zip"* ]]
    [[ "$output" == *"KEEP"*"h.zip"* ]]
    [[ "$output" == *"retained=1"* ]]
    [[ "$output" == *"deleted=3"* ]]
    [[ "$output" == *"reclaimed_bytes=60"* ]]
}

# ---------- Edge cases ----------

@test "empty input file produces empty plan and zeroed summary" {
    : > "$TMPDIR/in.tsv"
    run "$SCRIPT" --input "$TMPDIR/in.tsv"
    [ "$status" -eq 0 ]
    [[ "$output" == *"retained=0"* ]]
    [[ "$output" == *"deleted=0"* ]]
    [[ "$output" == *"reclaimed_bytes=0"* ]]
}

@test "comment lines and blank lines in input are ignored" {
    cat > "$TMPDIR/in.tsv" <<EOF
# this is a comment
a.zip	100	1767100000	wf1

# another comment
b.zip	200	1767200000	wf2
EOF
    run "$SCRIPT" --input "$TMPDIR/in.tsv"
    [ "$status" -eq 0 ]
    [[ "$output" == *"KEEP"*"a.zip"* ]]
    [[ "$output" == *"KEEP"*"b.zip"* ]]
    [[ "$output" == *"retained=2"* ]]
}

@test "malformed line (too few columns) yields a clear error" {
    cat > "$TMPDIR/in.tsv" <<EOF
a.zip	100	1767100000
EOF
    run "$SCRIPT" --input "$TMPDIR/in.tsv"
    [ "$status" -ne 0 ]
    [[ "$output" == *"malformed"* || "$output" == *"invalid"* ]]
}

@test "non-numeric size is rejected" {
    cat > "$TMPDIR/in.tsv" <<EOF
a.zip	notanumber	1767100000	wf1
EOF
    run "$SCRIPT" --input "$TMPDIR/in.tsv"
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid size"* || "$output" == *"size"* ]]
}
