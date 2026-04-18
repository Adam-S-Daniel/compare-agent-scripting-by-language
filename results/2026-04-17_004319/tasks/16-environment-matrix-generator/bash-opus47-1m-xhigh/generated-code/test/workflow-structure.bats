#!/usr/bin/env bats
# Structural tests for the GitHub Actions workflow that wraps matrix-gen.sh.
# These validate shape, file references, and actionlint conformance.

setup() {
  BATS_TEST_DIRNAME="${BATS_TEST_DIRNAME:-$(dirname "$BATS_TEST_FILENAME")}"
  PROJECT_DIR="$BATS_TEST_DIRNAME/.."
  WORKFLOW="$PROJECT_DIR/.github/workflows/environment-matrix-generator.yml"
}

# We avoid pulling in a YAML parser by using grep/awk on the well-known
# simple subset of YAML the workflow uses. This is sufficient because the
# workflow is authored by us and has a stable shape.

@test "workflow file exists" {
  [ -f "$WORKFLOW" ]
}

@test "workflow has a name" {
  grep -q "^name: environment-matrix-generator" "$WORKFLOW"
}

@test "workflow triggers include push, pull_request and workflow_dispatch" {
  grep -q "^  push:" "$WORKFLOW"
  grep -q "^  pull_request:" "$WORKFLOW"
  grep -q "^  workflow_dispatch:" "$WORKFLOW"
}

@test "workflow declares read-only contents permission" {
  grep -q "^permissions:" "$WORKFLOW"
  grep -qE "^  contents: read" "$WORKFLOW"
}

@test "workflow defines a matrix-gen job" {
  grep -q "^  matrix-gen:" "$WORKFLOW"
}

@test "workflow uses actions/checkout@v4" {
  grep -q "uses: actions/checkout@v4" "$WORKFLOW"
}

@test "workflow references matrix-gen.sh" {
  grep -q "matrix-gen.sh" "$WORKFLOW"
}

@test "referenced script path exists" {
  [ -f "$PROJECT_DIR/matrix-gen.sh" ]
  [ -x "$PROJECT_DIR/matrix-gen.sh" ]
}

@test "fixtures directory referenced by workflow exists" {
  [ -d "$PROJECT_DIR/fixtures" ]
  # At least the default fallback fixture must exist.
  [ -f "$PROJECT_DIR/fixtures/basic-multi-dim.json" ]
}

@test "actionlint passes on the workflow" {
  run actionlint "$WORKFLOW"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
