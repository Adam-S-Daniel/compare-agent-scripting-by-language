#!/usr/bin/env bats
# workflow_structure.bats — static checks on the workflow file. Fast, no act.
#
# These assertions guarantee the workflow is well-formed before we spend a
# (expensive) act invocation on it.

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    WF="$PROJECT_ROOT/.github/workflows/environment-matrix-generator.yml"
}

@test "actionlint passes cleanly on the workflow" {
    run actionlint "$WF"
    [ "$status" -eq 0 ]
}

@test "workflow file parses as YAML" {
    # Use python3 -c "import yaml" if available, else jq tojson via yq.
    # python3+yaml is present in the agent environment.
    run python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$WF"
    [ "$status" -eq 0 ]
}

@test "workflow declares push, pull_request and workflow_dispatch triggers" {
    run python3 - "$WF" <<'EOF'
import sys, yaml
wf = yaml.safe_load(open(sys.argv[1]))
# PyYAML interprets the bare key `on:` as the boolean True. Normalize.
on = wf.get("on") if "on" in wf else wf.get(True)
assert on is not None, "no triggers"
for key in ("push", "pull_request", "workflow_dispatch"):
    assert key in on, f"missing trigger {key}"
EOF
    [ "$status" -eq 0 ]
}

@test "workflow defines generate-matrix and run-fixtures jobs" {
    run python3 - "$WF" <<'EOF'
import sys, yaml
wf = yaml.safe_load(open(sys.argv[1]))
jobs = wf["jobs"]
for name in ("generate-matrix", "run-fixtures"):
    assert name in jobs, f"missing job {name}"
EOF
    [ "$status" -eq 0 ]
}

@test "run-fixtures depends on generate-matrix" {
    run python3 - "$WF" <<'EOF'
import sys, yaml
wf = yaml.safe_load(open(sys.argv[1]))
assert wf["jobs"]["run-fixtures"]["needs"] == "generate-matrix"
EOF
    [ "$status" -eq 0 ]
}

@test "workflow uses actions/checkout@v4" {
    grep -q "actions/checkout@v4" "$WF"
}

@test "workflow references matrix-generator.sh" {
    grep -q "matrix-generator.sh" "$WF"
    [ -f "$PROJECT_ROOT/matrix-generator.sh" ]
}

@test "workflow references test-harness.sh and it exists" {
    grep -q "test-harness.sh" "$WF"
    [ -f "$PROJECT_ROOT/test-harness.sh" ]
}

@test "workflow sets read-only permissions" {
    run python3 - "$WF" <<'EOF'
import sys, yaml
wf = yaml.safe_load(open(sys.argv[1]))
assert wf.get("permissions", {}).get("contents") == "read"
EOF
    [ "$status" -eq 0 ]
}

@test "matrix-generator.sh passes shellcheck" {
    run shellcheck "$PROJECT_ROOT/matrix-generator.sh"
    [ "$status" -eq 0 ]
}

@test "test-harness.sh passes shellcheck" {
    run shellcheck "$PROJECT_ROOT/test-harness.sh"
    [ "$status" -eq 0 ]
}

@test "matrix-generator.sh passes bash -n" {
    run bash -n "$PROJECT_ROOT/matrix-generator.sh"
    [ "$status" -eq 0 ]
}
