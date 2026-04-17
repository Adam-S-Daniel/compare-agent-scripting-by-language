#!/usr/bin/env bats
# Unit tests for cleanup.sh — red/green TDD.
#
# Input format (TSV, one artifact per line):
#   name<TAB>size_bytes<TAB>creation_date(YYYY-MM-DD)<TAB>workflow_run_id
#
# Output: a deletion plan followed by a summary block.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../cleanup.sh"
  FIXTURES="${BATS_TEST_DIRNAME}/fixtures"
  TMPDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "${TMPDIR}"
}

# ---------- CLI plumbing ----------

@test "script exists and is executable" {
  [ -x "${SCRIPT}" ]
}

@test "--help prints usage and exits 0" {
  run "${SCRIPT}" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--max-age-days"* ]]
  [[ "$output" == *"--keep-latest"* ]]
  [[ "$output" == *"--max-total-size"* ]]
  [[ "$output" == *"--dry-run"* ]]
}

@test "unknown option exits non-zero with error message" {
  run "${SCRIPT}" --bogus-flag
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown option"* ]] || [[ "$output" == *"Unknown option"* ]]
}

@test "missing input file is a graceful error" {
  run "${SCRIPT}" --input "${TMPDIR}/does-not-exist.tsv"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]] || [[ "$output" == *"No such"* ]]
}

@test "malformed TSV row produces a helpful error" {
  printf 'onlyonefield\n' > "${TMPDIR}/bad.tsv"
  run "${SCRIPT}" --input "${TMPDIR}/bad.tsv"
  [ "$status" -ne 0 ]
  [[ "$output" == *"malformed"* ]] || [[ "$output" == *"invalid"* ]]
}

# ---------- Baseline: no policies ----------

@test "with no retention policy every artifact is KEPT" {
  cp "${FIXTURES}/simple.tsv" "${TMPDIR}/in.tsv"
  run "${SCRIPT}" --input "${TMPDIR}/in.tsv" --current-date 2026-04-17
  [ "$status" -eq 0 ]
  # All three fixture rows should show KEEP
  [[ "$output" == *"KEEP"*"build-logs-1"* ]]
  [[ "$output" == *"KEEP"*"test-results-1"* ]]
  [[ "$output" == *"KEEP"*"coverage-1"* ]]
  [[ "$output" != *"DELETE"* ]]
}

@test "summary reports totals" {
  cp "${FIXTURES}/simple.tsv" "${TMPDIR}/in.tsv"
  run "${SCRIPT}" --input "${TMPDIR}/in.tsv" --current-date 2026-04-17
  [ "$status" -eq 0 ]
  [[ "$output" == *"Summary"* ]]
  [[ "$output" == *"Artifacts retained: 3"* ]]
  [[ "$output" == *"Artifacts deleted: 0"* ]]
  [[ "$output" == *"Space reclaimed: 0 bytes"* ]]
}

# ---------- --max-age-days ----------

@test "--max-age-days marks older artifacts for deletion" {
  cp "${FIXTURES}/aged.tsv" "${TMPDIR}/in.tsv"
  # aged.tsv: one artifact at 2026-04-16 (1 day old), one at 2026-04-01 (16 days),
  # one at 2026-02-01 (75 days). With --max-age-days 30, only the 75-day one deletes.
  run "${SCRIPT}" --input "${TMPDIR}/in.tsv" --current-date 2026-04-17 --max-age-days 30
  [ "$status" -eq 0 ]
  [[ "$output" == *"KEEP"*"fresh-1"* ]]
  [[ "$output" == *"KEEP"*"medium-1"* ]]
  [[ "$output" == *"DELETE"*"ancient-1"* ]]
  [[ "$output" == *"max-age"* ]]
  [[ "$output" == *"Artifacts retained: 2"* ]]
  [[ "$output" == *"Artifacts deleted: 1"* ]]
}

@test "--max-age-days=0 deletes everything not created today" {
  cp "${FIXTURES}/aged.tsv" "${TMPDIR}/in.tsv"
  run "${SCRIPT}" --input "${TMPDIR}/in.tsv" --current-date 2026-04-17 --max-age-days 0
  [ "$status" -eq 0 ]
  [[ "$output" == *"Artifacts retained: 0"* ]]
  [[ "$output" == *"Artifacts deleted: 3"* ]]
}

# ---------- --keep-latest ----------

@test "--keep-latest keeps N newest artifacts per workflow run" {
  cp "${FIXTURES}/per-workflow.tsv" "${TMPDIR}/in.tsv"
  # per-workflow.tsv has:
  #   workflow 100: four artifacts dated 2026-04-10..13
  #   workflow 200: two artifacts dated 2026-04-14..15
  # --keep-latest 2 => workflow 100 keeps 2 newest, deletes 2 oldest; workflow 200 keeps both.
  run "${SCRIPT}" --input "${TMPDIR}/in.tsv" --current-date 2026-04-17 --keep-latest 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"DELETE"*"wf100-a"* ]]
  [[ "$output" == *"DELETE"*"wf100-b"* ]]
  [[ "$output" == *"KEEP"*"wf100-c"* ]]
  [[ "$output" == *"KEEP"*"wf100-d"* ]]
  [[ "$output" == *"KEEP"*"wf200-a"* ]]
  [[ "$output" == *"KEEP"*"wf200-b"* ]]
  [[ "$output" == *"keep-latest"* ]]
  [[ "$output" == *"Artifacts retained: 4"* ]]
  [[ "$output" == *"Artifacts deleted: 2"* ]]
}

# ---------- --max-total-size ----------

@test "--max-total-size deletes oldest until total fits under cap" {
  cp "${FIXTURES}/sized.tsv" "${TMPDIR}/in.tsv"
  # sized.tsv: five 1000-byte artifacts on 2026-04-10..14. Cap at 3000 bytes =>
  # should keep 3 newest (3000 bytes) and delete 2 oldest.
  run "${SCRIPT}" --input "${TMPDIR}/in.tsv" --current-date 2026-04-17 --max-total-size 3000
  [ "$status" -eq 0 ]
  [[ "$output" == *"DELETE"*"big-1"* ]]
  [[ "$output" == *"DELETE"*"big-2"* ]]
  [[ "$output" == *"KEEP"*"big-3"* ]]
  [[ "$output" == *"KEEP"*"big-4"* ]]
  [[ "$output" == *"KEEP"*"big-5"* ]]
  [[ "$output" == *"max-total-size"* ]]
  [[ "$output" == *"Artifacts retained: 3"* ]]
  [[ "$output" == *"Artifacts deleted: 2"* ]]
  [[ "$output" == *"Space reclaimed: 2000 bytes"* ]]
}

# ---------- Combined policies ----------

@test "multiple policies compose — each artifact can be deleted for multiple reasons" {
  cp "${FIXTURES}/combined.tsv" "${TMPDIR}/in.tsv"
  # combined.tsv has 5 artifacts split across 2 workflows, mix of old and new.
  run "${SCRIPT}" --input "${TMPDIR}/in.tsv" --current-date 2026-04-17 \
      --max-age-days 30 --keep-latest 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Artifacts retained: 2"* ]]
  [[ "$output" == *"Artifacts deleted: 3"* ]]
}

# ---------- Dry run ----------

@test "--dry-run adds DRY RUN banner and changes exit semantics" {
  cp "${FIXTURES}/aged.tsv" "${TMPDIR}/in.tsv"
  run "${SCRIPT}" --input "${TMPDIR}/in.tsv" --current-date 2026-04-17 \
      --max-age-days 30 --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
  # Dry run still reports the plan
  [[ "$output" == *"DELETE"*"ancient-1"* ]]
}

# ---------- Space reclaimed calculation ----------

@test "space reclaimed is sum of deleted artifact sizes" {
  cp "${FIXTURES}/sized.tsv" "${TMPDIR}/in.tsv"
  run "${SCRIPT}" --input "${TMPDIR}/in.tsv" --current-date 2026-04-17 --max-age-days 5
  [ "$status" -eq 0 ]
  # max-age-days=5 with current 2026-04-17: anything older than 2026-04-12 deletes.
  # Dates 2026-04-10 (big-1) and 2026-04-11 (big-2) are > 5 days old => DELETE.
  # 2 * 1000 = 2000 bytes reclaimed.
  [[ "$output" == *"Space reclaimed: 2000 bytes"* ]]
}

# ---------- Stdin input ----------

@test "reads from stdin when --input is '-'" {
  run bash -c "cat '${FIXTURES}/simple.tsv' | '${SCRIPT}' --input - --current-date 2026-04-17"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Artifacts retained: 3"* ]]
}
