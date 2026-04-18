#!/usr/bin/env bats

# TDD tests for label-assigner.sh.
# Rules file format: lines of "pattern:label:priority" (priority defaults to 0).
# Files file format: one changed file path per line. Output: sorted unique labels.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../label-assigner.sh"
    FIXTURE_DIR="$BATS_TEST_DIRNAME/../fixtures"
    TMPDIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TMPDIR"
}

@test "prints usage and exits nonzero when called with no arguments" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "errors when rules file does not exist" {
    echo "foo.txt" > "$TMPDIR/files.txt"
    run "$SCRIPT" "$TMPDIR/missing.conf" "$TMPDIR/files.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"rules file not found"* ]]
}

@test "errors when files file does not exist" {
    echo "docs/**:documentation:10" > "$TMPDIR/rules.conf"
    run "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/missing.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"files file not found"* ]]
}

@test "single file matches single rule -> one label" {
    cat > "$TMPDIR/rules.conf" <<'EOF'
docs/**:documentation:10
EOF
    cat > "$TMPDIR/files.txt" <<'EOF'
docs/guide/intro.md
EOF
    run "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "documentation" ]
}

@test "no match emits empty output with exit 0" {
    cat > "$TMPDIR/rules.conf" <<'EOF'
docs/**:documentation:10
EOF
    cat > "$TMPDIR/files.txt" <<'EOF'
src/foo.rb
EOF
    run "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "globstar matches deep nesting" {
    cat > "$TMPDIR/rules.conf" <<'EOF'
src/api/**:api:20
EOF
    cat > "$TMPDIR/files.txt" <<'EOF'
src/api/v1/users/handler.go
src/web/index.html
EOF
    run "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "api" ]
}

@test "wildcard *.test.* matches test files in any directory" {
    cat > "$TMPDIR/rules.conf" <<'EOF'
**/*.test.*:tests:30
EOF
    cat > "$TMPDIR/files.txt" <<'EOF'
src/api/user.test.js
src/api/user.js
lib/utils.test.ts
EOF
    run "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "tests" ]
}

@test "multiple rules produce multiple labels, sorted by priority desc then name" {
    cat > "$TMPDIR/rules.conf" <<'EOF'
docs/**:documentation:10
src/api/**:api:30
**/*.test.*:tests:20
EOF
    cat > "$TMPDIR/files.txt" <<'EOF'
docs/readme.md
src/api/v1/user.go
src/api/v1/user.test.go
EOF
    run "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
    [ "$status" -eq 0 ]
    # Expected priority order: api(30), tests(20), documentation(10)
    expected=$'api\ntests\ndocumentation'
    [ "$output" = "$expected" ]
}

@test "duplicate label across rules is deduplicated" {
    cat > "$TMPDIR/rules.conf" <<'EOF'
src/**:backend:15
lib/**:backend:15
EOF
    cat > "$TMPDIR/files.txt" <<'EOF'
src/foo.go
lib/bar.go
EOF
    run "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "backend" ]
}

@test "priority defaults to 0 when omitted" {
    cat > "$TMPDIR/rules.conf" <<'EOF'
src/**:low
critical/**:high:99
EOF
    cat > "$TMPDIR/files.txt" <<'EOF'
src/a.txt
critical/b.txt
EOF
    run "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
    [ "$status" -eq 0 ]
    expected=$'high\nlow'
    [ "$output" = "$expected" ]
}

@test "comments and blank lines in rules are ignored" {
    cat > "$TMPDIR/rules.conf" <<'EOF'
# this is a comment
docs/**:documentation:10

# another comment
src/**:source:20
EOF
    cat > "$TMPDIR/files.txt" <<'EOF'
docs/a.md
src/b.js
EOF
    run "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
    [ "$status" -eq 0 ]
    expected=$'source\ndocumentation'
    [ "$output" = "$expected" ]
}

@test "malformed rule line (no label) errors out" {
    cat > "$TMPDIR/rules.conf" <<'EOF'
docs/**
EOF
    echo "docs/a.md" > "$TMPDIR/files.txt"
    run "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"malformed rule"* ]]
}

@test "non-numeric priority errors out" {
    cat > "$TMPDIR/rules.conf" <<'EOF'
docs/**:documentation:high
EOF
    echo "docs/a.md" > "$TMPDIR/files.txt"
    run "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"priority must be an integer"* ]]
}

@test "single star does not cross directory boundaries" {
    cat > "$TMPDIR/rules.conf" <<'EOF'
src/*.go:shallow:5
EOF
    cat > "$TMPDIR/files.txt" <<'EOF'
src/main.go
src/sub/deep.go
EOF
    run "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "shallow" ]
    # matches src/main.go but NOT src/sub/deep.go
}

@test "exact filename match works" {
    cat > "$TMPDIR/rules.conf" <<'EOF'
Dockerfile:docker:5
EOF
    cat > "$TMPDIR/files.txt" <<'EOF'
Dockerfile
src/Dockerfile.build
EOF
    run "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "docker" ]
}

@test "question mark matches single char" {
    cat > "$TMPDIR/rules.conf" <<'EOF'
v?.txt:versioned:1
EOF
    cat > "$TMPDIR/files.txt" <<'EOF'
v1.txt
v12.txt
EOF
    run "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "versioned" ]
}

@test "labels with same priority sort alphabetically" {
    cat > "$TMPDIR/rules.conf" <<'EOF'
docs/**:zebra:10
src/**:alpha:10
lib/**:mango:10
EOF
    cat > "$TMPDIR/files.txt" <<'EOF'
docs/a.md
src/b.js
lib/c.rb
EOF
    run "$SCRIPT" "$TMPDIR/rules.conf" "$TMPDIR/files.txt"
    [ "$status" -eq 0 ]
    expected=$'alpha\nmango\nzebra'
    [ "$output" = "$expected" ]
}

@test "accepts file list from stdin when files path is -" {
    cat > "$TMPDIR/rules.conf" <<'EOF'
docs/**:documentation:10
EOF
    run bash -c "printf 'docs/a.md\ndocs/b.md\n' | $SCRIPT $TMPDIR/rules.conf -"
    [ "$status" -eq 0 ]
    [ "$output" = "documentation" ]
}
