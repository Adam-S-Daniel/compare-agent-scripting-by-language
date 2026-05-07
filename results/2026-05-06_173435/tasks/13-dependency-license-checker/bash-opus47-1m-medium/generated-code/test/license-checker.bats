#!/usr/bin/env bats

# Tests for the dependency license checker.
# We use a mock license lookup file so tests are deterministic.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../license-checker.sh"
    TMP_DIR="$(mktemp -d)"
    export LICENSE_LOOKUP_FILE="$TMP_DIR/licenses.tsv"
    cd "$TMP_DIR"
}

teardown() {
    rm -rf "$TMP_DIR"
}

# Helpers to write fixtures.
write_pkg_json() {
    cat > package.json <<'EOF'
{
  "name": "demo",
  "version": "1.0.0",
  "dependencies": {
    "leftpad": "1.0.0",
    "axios": "0.27.2"
  },
  "devDependencies": {
    "jest": "29.0.0"
  }
}
EOF
}

write_requirements_txt() {
    cat > requirements.txt <<'EOF'
requests==2.28.0
flask>=2.0.0
# a comment line
gpl-package==1.0.0
EOF
}

write_lookup() {
    # name<TAB>license
    cat > "$LICENSE_LOOKUP_FILE" <<'EOF'
leftpad	MIT
axios	MIT
jest	MIT
requests	Apache-2.0
flask	BSD-3-Clause
gpl-package	GPL-3.0
EOF
}

write_config() {
    cat > config.json <<'EOF'
{
  "allow": ["MIT", "Apache-2.0", "BSD-3-Clause"],
  "deny": ["GPL-3.0", "AGPL-3.0"]
}
EOF
}

@test "script exists and is executable" {
    [ -x "$SCRIPT" ]
}

@test "prints usage when no args" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "errors when manifest does not exist" {
    write_config
    run "$SCRIPT" --manifest missing.json --config config.json
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "parses package.json dependencies" {
    write_pkg_json
    write_lookup
    write_config
    run "$SCRIPT" --manifest package.json --config config.json
    [ "$status" -eq 0 ]
    [[ "$output" == *"leftpad"* ]]
    [[ "$output" == *"axios"* ]]
    [[ "$output" == *"jest"* ]]
}

@test "parses requirements.txt dependencies" {
    write_requirements_txt
    write_lookup
    write_config
    run "$SCRIPT" --manifest requirements.txt --config config.json
    # gpl-package will trigger DENIED → exit 2, but parsing should still surface all names.
    [[ "$output" == *"requests"* ]]
    [[ "$output" == *"flask"* ]]
    [[ "$output" == *"gpl-package"* ]]
}

@test "marks allow-listed licenses as APPROVED" {
    write_pkg_json
    write_lookup
    write_config
    run "$SCRIPT" --manifest package.json --config config.json
    [ "$status" -eq 0 ]
    [[ "$output" == *"leftpad"*"MIT"*"APPROVED"* ]]
}

@test "marks deny-listed licenses as DENIED and exits non-zero" {
    write_requirements_txt
    write_lookup
    write_config
    run "$SCRIPT" --manifest requirements.txt --config config.json
    # Exit non-zero when any DENIED found.
    [ "$status" -ne 0 ]
    [[ "$output" == *"gpl-package"*"GPL-3.0"*"DENIED"* ]]
}

@test "marks unknown packages as UNKNOWN" {
    write_pkg_json
    # Lookup missing axios:
    cat > "$LICENSE_LOOKUP_FILE" <<'EOF'
leftpad	MIT
jest	MIT
EOF
    write_config
    run "$SCRIPT" --manifest package.json --config config.json
    [[ "$output" == *"axios"*"UNKNOWN"* ]]
}

@test "supports --output to write report file" {
    write_pkg_json
    write_lookup
    write_config
    run "$SCRIPT" --manifest package.json --config config.json --output report.txt
    [ "$status" -eq 0 ]
    [ -f report.txt ]
    grep -q "leftpad" report.txt
    grep -q "APPROVED" report.txt
}

@test "summary line counts approved/denied/unknown" {
    write_requirements_txt
    write_lookup
    write_config
    run "$SCRIPT" --manifest requirements.txt --config config.json
    [[ "$output" == *"Summary"* ]]
    [[ "$output" == *"approved=2"* ]]
    [[ "$output" == *"denied=1"* ]]
    [[ "$output" == *"unknown=0"* ]]
}

@test "errors when config file missing" {
    write_pkg_json
    run "$SCRIPT" --manifest package.json --config no-config.json
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}
