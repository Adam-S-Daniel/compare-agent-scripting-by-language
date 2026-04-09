#!/usr/bin/env bats
# test_artifact_cleanup.bats — All tests run through act (GitHub Actions).
#
# Each test case:
# 1. Creates a temp git repo with project files + fixtures
# 2. Runs `act push --rm` to execute the workflow
# 3. Captures output to act-result.txt (appended, clearly delimited)
# 4. Asserts exit code 0 and verifies exact expected values

# ── Globals ───────────────────────────────────────────────────────────────────
PROJ_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
ACT_RESULT="$PROJ_DIR/act-result.txt"
ACT_IMAGE="catthehacker/ubuntu:act-latest"

# ── Helpers ───────────────────────────────────────────────────────────────────

# Create a temp git repo with project files. Returns the path.
# IMPORTANT: caller must `cd` into the returned path.
make_act_repo() {
  local tmpdir
  tmpdir=$(mktemp -d)
  cp "$PROJ_DIR/artifact_cleanup.sh" "$tmpdir/"
  chmod +x "$tmpdir/artifact_cleanup.sh"
  cp -r "$PROJ_DIR/fixtures" "$tmpdir/"
  mkdir -p "$tmpdir/.github/workflows"
  git -C "$tmpdir" init -b main --quiet
  echo "$tmpdir"
}

# Run act in the given repo directory. Caller should already be cd'd there
# or pass the path.
run_act_in() {
  local dir="$1"
  cd "$dir"
  git add -A
  git commit -m "test" --quiet
  act push --rm -P ubuntu-latest="$ACT_IMAGE" 2>&1
}

# ── Setup / Teardown ─────────────────────────────────────────────────────────

setup() {
  # Truncate act-result.txt on first test only
  if [[ "$BATS_TEST_NUMBER" -eq 1 ]]; then
    : > "$ACT_RESULT"
  fi
}

# ── Workflow structure tests ─────────────────────────────────────────────────

@test "workflow YAML structure: has expected triggers" {
  local wf="$PROJ_DIR/.github/workflows/artifact-cleanup-script.yml"
  echo "=== TEST: workflow YAML structure — triggers ===" >> "$ACT_RESULT"

  [ -f "$wf" ]
  grep -q 'push:' "$wf"
  grep -q 'pull_request:' "$wf"
  grep -q 'workflow_dispatch:' "$wf"

  echo "PASS: triggers found (push, pull_request, workflow_dispatch)" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"
}

@test "workflow YAML structure: has expected jobs" {
  local wf="$PROJ_DIR/.github/workflows/artifact-cleanup-script.yml"
  echo "=== TEST: workflow YAML structure — jobs ===" >> "$ACT_RESULT"

  grep -q 'validate:' "$wf"
  grep -q 'test-max-age:' "$wf"
  grep -q 'test-keep-latest-n:' "$wf"
  grep -q 'test-max-total-size:' "$wf"
  grep -q 'test-combined-policies:' "$wf"
  grep -q 'test-dry-run-mode:' "$wf"
  grep -q 'test-error-handling:' "$wf"
  grep -q 'summary:' "$wf"

  echo "PASS: all expected jobs found" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"
}

@test "workflow YAML structure: references correct script files" {
  local wf="$PROJ_DIR/.github/workflows/artifact-cleanup-script.yml"
  echo "=== TEST: workflow YAML structure — script references ===" >> "$ACT_RESULT"

  grep -q 'artifact_cleanup.sh' "$wf"
  [ -f "$PROJ_DIR/artifact_cleanup.sh" ]

  # All fixture files referenced in workflow exist
  grep -oP 'fixtures/\S+\.tsv' "$wf" | sort -u | while read -r fpath; do
    [ -f "$PROJ_DIR/$fpath" ] || { echo "FAIL: $fpath not found"; return 1; }
  done

  echo "PASS: all referenced files exist" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"
}

@test "workflow YAML structure: uses actions/checkout@v4" {
  local wf="$PROJ_DIR/.github/workflows/artifact-cleanup-script.yml"
  echo "=== TEST: workflow YAML structure — checkout action ===" >> "$ACT_RESULT"

  grep -q 'actions/checkout@v4' "$wf"

  echo "PASS: uses actions/checkout@v4" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"
}

@test "workflow passes actionlint" {
  local wf="$PROJ_DIR/.github/workflows/artifact-cleanup-script.yml"
  echo "=== TEST: actionlint validation ===" >> "$ACT_RESULT"

  run actionlint "$wf"
  echo "actionlint exit code: $status" >> "$ACT_RESULT"
  [ "$status" -eq 0 ]

  echo "PASS: actionlint clean" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"
}

# ── Act integration tests ────────────────────────────────────────────────────

@test "act: max-age policy deletes old artifacts" {
  echo "=== TEST: act — max-age policy ===" >> "$ACT_RESULT"

  local tmpdir
  tmpdir=$(make_act_repo)

  cat > "$tmpdir/.github/workflows/artifact-cleanup-script.yml" <<'WORKFLOW'
name: Test max-age
on: push
env:
  REFERENCE_DATE: "2026-04-09"
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: chmod +x artifact_cleanup.sh
      - name: Run max-age test
        run: |
          ./artifact_cleanup.sh \
            --input fixtures/age_test.tsv \
            --reference-date "$REFERENCE_DATE" \
            --max-age 30
WORKFLOW

  local output
  output=$(run_act_in "$tmpdir")
  local rc=$?

  echo "$output" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"

  [ "$rc" -eq 0 ]
  echo "$output" | grep -q 'Job succeeded'
  echo "$output" | grep -q '\[DELETE\] month-old-build'
  echo "$output" | grep -q '\[DELETE\] ancient-build'
  echo "$output" | grep -q '\[KEEP\]   recent-build'
  echo "$output" | grep -q '\[KEEP\]   week-old-build'
  echo "$output" | grep -q 'Artifacts to delete: 2'
  echo "$output" | grep -q 'Artifacts to keep: 2'
  echo "$output" | grep -q 'Space reclaimed: 7000 bytes'

  echo "PASS: max-age policy correct" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"

  rm -rf "$tmpdir"
}

@test "act: keep-latest-n retains only N most recent per workflow" {
  echo "=== TEST: act — keep-latest-n policy ===" >> "$ACT_RESULT"

  local tmpdir
  tmpdir=$(make_act_repo)

  cat > "$tmpdir/.github/workflows/artifact-cleanup-script.yml" <<'WORKFLOW'
name: Test keep-latest-n
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: chmod +x artifact_cleanup.sh
      - name: Run keep-latest-n test
        run: |
          ./artifact_cleanup.sh \
            --input fixtures/keep_latest_test.tsv \
            --keep-latest-n 2
WORKFLOW

  local output
  output=$(run_act_in "$tmpdir")
  local rc=$?

  echo "$output" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"

  [ "$rc" -eq 0 ]
  echo "$output" | grep -q 'Job succeeded'
  echo "$output" | grep -q '\[DELETE\] build-v1'
  echo "$output" | grep -q '\[DELETE\] build-v2'
  echo "$output" | grep -q '\[KEEP\]   build-v3'
  echo "$output" | grep -q '\[KEEP\]   build-v4'
  echo "$output" | grep -q '\[DELETE\] test-v1'
  echo "$output" | grep -q '\[KEEP\]   test-v2'
  echo "$output" | grep -q '\[KEEP\]   test-v3'
  echo "$output" | grep -q 'Artifacts to delete: 3'
  echo "$output" | grep -q 'Artifacts to keep: 4'
  echo "$output" | grep -q 'Space reclaimed: 2500 bytes'

  echo "PASS: keep-latest-n policy correct" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"

  rm -rf "$tmpdir"
}

@test "act: max-total-size removes oldest to fit budget" {
  echo "=== TEST: act — max-total-size policy ===" >> "$ACT_RESULT"

  local tmpdir
  tmpdir=$(make_act_repo)

  cat > "$tmpdir/.github/workflows/artifact-cleanup-script.yml" <<'WORKFLOW'
name: Test max-total-size
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: chmod +x artifact_cleanup.sh
      - name: Run max-total-size test
        run: |
          ./artifact_cleanup.sh \
            --input fixtures/size_test.tsv \
            --max-total-size 5000
WORKFLOW

  local output
  output=$(run_act_in "$tmpdir")
  local rc=$?

  echo "$output" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"

  [ "$rc" -eq 0 ]
  echo "$output" | grep -q 'Job succeeded'
  echo "$output" | grep -q '\[DELETE\] big-artifact'
  echo "$output" | grep -q '\[DELETE\] medium-artifact'
  echo "$output" | grep -q '\[KEEP\]   small-artifact'
  echo "$output" | grep -q '\[KEEP\]   tiny-artifact'
  echo "$output" | grep -q 'Artifacts to delete: 2'
  echo "$output" | grep -q 'Artifacts to keep: 2'
  echo "$output" | grep -q 'Space reclaimed: 7000 bytes'
  echo "$output" | grep -q 'Space retained: 3000 bytes'

  echo "PASS: max-total-size policy correct" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"

  rm -rf "$tmpdir"
}

@test "act: combined policies applied together" {
  echo "=== TEST: act — combined policies ===" >> "$ACT_RESULT"

  local tmpdir
  tmpdir=$(make_act_repo)

  cat > "$tmpdir/.github/workflows/artifact-cleanup-script.yml" <<'WORKFLOW'
name: Test combined
on: push
env:
  REFERENCE_DATE: "2026-04-09"
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: chmod +x artifact_cleanup.sh
      - name: Run combined test
        run: |
          ./artifact_cleanup.sh \
            --input fixtures/combined_test.tsv \
            --reference-date "$REFERENCE_DATE" \
            --max-age 60 \
            --keep-latest-n 2 \
            --max-total-size 5000
WORKFLOW

  local output
  output=$(run_act_in "$tmpdir")
  local rc=$?

  echo "$output" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"

  [ "$rc" -eq 0 ]
  echo "$output" | grep -q 'Job succeeded'
  echo "$output" | grep -q '\[DELETE\] alpha'
  echo "$output" | grep -q '\[DELETE\] beta'
  echo "$output" | grep -q '\[DELETE\] epsilon'
  echo "$output" | grep -q '\[KEEP\]   gamma'
  echo "$output" | grep -q '\[KEEP\]   delta'
  echo "$output" | grep -q '\[KEEP\]   zeta'
  echo "$output" | grep -q '\[KEEP\]   eta'
  echo "$output" | grep -q 'Artifacts to delete: 3'
  echo "$output" | grep -q 'Artifacts to keep: 4'
  echo "$output" | grep -q 'Space reclaimed: 5500 bytes'
  echo "$output" | grep -q 'Space retained: 3000 bytes'

  echo "PASS: combined policies correct" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"

  rm -rf "$tmpdir"
}

@test "act: dry-run mode does not show deletion commands" {
  echo "=== TEST: act — dry-run mode ===" >> "$ACT_RESULT"

  local tmpdir
  tmpdir=$(make_act_repo)

  cat > "$tmpdir/.github/workflows/artifact-cleanup-script.yml" <<'WORKFLOW'
name: Test dry-run
on: push
env:
  REFERENCE_DATE: "2026-04-09"
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: chmod +x artifact_cleanup.sh
      - name: Run dry-run test
        run: |
          OUTPUT=$(./artifact_cleanup.sh \
            --input fixtures/basic_artifacts.tsv \
            --reference-date "$REFERENCE_DATE" \
            --max-age 60 \
            --dry-run)
          echo "$OUTPUT"
          echo "$OUTPUT" | grep -q 'Mode: DRY-RUN'
          if echo "$OUTPUT" | grep -q 'Deletion Commands'; then
            echo "FAIL: dry-run should not show deletion commands"
            exit 1
          fi
          echo "dry-run verified"
WORKFLOW

  local output
  output=$(run_act_in "$tmpdir")
  local rc=$?

  echo "$output" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"

  [ "$rc" -eq 0 ]
  echo "$output" | grep -q 'Job succeeded'
  echo "$output" | grep -q 'Mode: DRY-RUN'
  echo "$output" | grep -q 'dry-run verified'

  echo "PASS: dry-run mode correct" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"

  rm -rf "$tmpdir"
}

@test "act: execute mode shows deletion commands" {
  echo "=== TEST: act — execute mode ===" >> "$ACT_RESULT"

  local tmpdir
  tmpdir=$(make_act_repo)

  cat > "$tmpdir/.github/workflows/artifact-cleanup-script.yml" <<'WORKFLOW'
name: Test execute
on: push
env:
  REFERENCE_DATE: "2026-04-09"
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: chmod +x artifact_cleanup.sh
      - name: Run execute test
        run: |
          ./artifact_cleanup.sh \
            --input fixtures/basic_artifacts.tsv \
            --reference-date "$REFERENCE_DATE" \
            --max-age 60 \
            --execute
WORKFLOW

  local output
  output=$(run_act_in "$tmpdir")
  local rc=$?

  echo "$output" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"

  [ "$rc" -eq 0 ]
  echo "$output" | grep -q 'Job succeeded'
  echo "$output" | grep -q 'Mode: EXECUTE'
  echo "$output" | grep -q 'Deletion Commands'
  echo "$output" | grep -q 'gh api -X DELETE'

  echo "PASS: execute mode correct" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"

  rm -rf "$tmpdir"
}

@test "act: error handling — missing input file" {
  echo "=== TEST: act — error: missing input file ===" >> "$ACT_RESULT"

  local tmpdir
  tmpdir=$(make_act_repo)

  cat > "$tmpdir/.github/workflows/artifact-cleanup-script.yml" <<'WORKFLOW'
name: Test error handling
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: chmod +x artifact_cleanup.sh
      - name: Test missing file error
        run: |
          if ./artifact_cleanup.sh --input nonexistent.tsv 2>err.txt; then
            echo "FAIL: should have exited with error"
            exit 1
          fi
          cat err.txt
          grep -q 'Input file not found' err.txt
          echo "error-handling verified"
WORKFLOW

  local output
  output=$(run_act_in "$tmpdir")
  local rc=$?

  echo "$output" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"

  [ "$rc" -eq 0 ]
  echo "$output" | grep -q 'Job succeeded'
  echo "$output" | grep -q 'error-handling verified'

  echo "PASS: error handling correct" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"

  rm -rf "$tmpdir"
}

@test "act: error handling — empty input" {
  echo "=== TEST: act — error: empty input ===" >> "$ACT_RESULT"

  local tmpdir
  tmpdir=$(make_act_repo)

  cat > "$tmpdir/.github/workflows/artifact-cleanup-script.yml" <<'WORKFLOW'
name: Test empty input
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: chmod +x artifact_cleanup.sh
      - name: Test empty input error
        run: |
          if echo "" | ./artifact_cleanup.sh 2>err.txt; then
            echo "FAIL: should have exited with error"
            exit 1
          fi
          cat err.txt
          grep -q 'No artifacts loaded' err.txt
          echo "empty-input-error verified"
WORKFLOW

  local output
  output=$(run_act_in "$tmpdir")
  local rc=$?

  echo "$output" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"

  [ "$rc" -eq 0 ]
  echo "$output" | grep -q 'Job succeeded'
  echo "$output" | grep -q 'empty-input-error verified'

  echo "PASS: empty input error handling correct" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"

  rm -rf "$tmpdir"
}

@test "act: full workflow with all jobs succeeds" {
  echo "=== TEST: act — full workflow (all jobs) ===" >> "$ACT_RESULT"

  local tmpdir
  tmpdir=$(make_act_repo)

  # Copy the actual production workflow
  cp "$PROJ_DIR/.github/workflows/artifact-cleanup-script.yml" "$tmpdir/.github/workflows/"

  local output
  output=$(run_act_in "$tmpdir")
  local rc=$?

  echo "$output" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"

  [ "$rc" -eq 0 ]

  # Every job should succeed
  echo "$output" | grep -q 'Job succeeded'

  # Check that specific test outputs appear
  echo "$output" | grep -q 'max-age test PASSED'
  echo "$output" | grep -q 'keep-latest-n test PASSED'
  echo "$output" | grep -q 'max-total-size test PASSED'
  echo "$output" | grep -q 'combined policy test PASSED'
  echo "$output" | grep -q 'dry-run mode test PASSED'
  echo "$output" | grep -q 'execute mode test PASSED'
  echo "$output" | grep -q 'missing file error test PASSED'
  echo "$output" | grep -q 'unknown option error test PASSED'
  echo "$output" | grep -q 'empty input error test PASSED'

  echo "PASS: full workflow — all jobs succeeded" >> "$ACT_RESULT"
  echo "" >> "$ACT_RESULT"

  rm -rf "$tmpdir"
}

@test "act-result.txt exists and is non-empty" {
  [ -f "$ACT_RESULT" ]
  [ -s "$ACT_RESULT" ]
}
