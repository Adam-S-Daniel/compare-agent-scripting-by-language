#!/usr/bin/env bats

# Tests for bump-version.sh — a semantic version bumper based on conventional commits.

setup() {
  TEST_DIR="$(mktemp -d)"
  SCRIPT="${BATS_TEST_DIRNAME}/../bump-version.sh"
  cd "$TEST_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "script exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "errors when VERSION file is missing" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"VERSION file"* ]]
}

@test "errors on invalid version format" {
  echo "not-a-version" > VERSION
  echo "feat: x" > commits.txt
  run "$SCRIPT" --version-file VERSION --commits commits.txt
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid"* ]]
}

@test "feat commit bumps minor version" {
  echo "1.2.3" > VERSION
  printf "feat: add login\nchore: cleanup\n" > commits.txt
  run "$SCRIPT" --version-file VERSION --commits commits.txt
  [ "$status" -eq 0 ]
  [[ "$output" == *"1.3.0"* ]]
  [ "$(cat VERSION)" = "1.3.0" ]
}

@test "fix commit bumps patch version" {
  echo "1.2.3" > VERSION
  echo "fix: typo" > commits.txt
  run "$SCRIPT" --version-file VERSION --commits commits.txt
  [ "$status" -eq 0 ]
  [[ "$output" == *"1.2.4"* ]]
  [ "$(cat VERSION)" = "1.2.4" ]
}

@test "breaking change bumps major version" {
  echo "1.2.3" > VERSION
  printf "feat!: redo API\n" > commits.txt
  run "$SCRIPT" --version-file VERSION --commits commits.txt
  [ "$status" -eq 0 ]
  [[ "$output" == *"2.0.0"* ]]
}

@test "BREAKING CHANGE in body bumps major" {
  echo "0.5.1" > VERSION
  printf "feat: new\n\nBREAKING CHANGE: removed old api\n" > commits.txt
  run "$SCRIPT" --version-file VERSION --commits commits.txt
  [ "$status" -eq 0 ]
  [[ "$output" == *"1.0.0"* ]]
}

@test "no relevant commits => patch bump (default)" {
  echo "1.0.0" > VERSION
  printf "chore: deps\ndocs: readme\n" > commits.txt
  run "$SCRIPT" --version-file VERSION --commits commits.txt
  [ "$status" -eq 0 ]
  [[ "$output" == *"1.0.1"* ]]
}

@test "package.json version is updated" {
  cat > package.json <<EOF
{
  "name": "demo",
  "version": "2.4.0",
  "private": true
}
EOF
  echo "feat: new feature" > commits.txt
  run "$SCRIPT" --version-file package.json --commits commits.txt
  [ "$status" -eq 0 ]
  [[ "$output" == *"2.5.0"* ]]
  grep -q '"version": "2.5.0"' package.json
}

@test "changelog is generated" {
  echo "1.0.0" > VERSION
  printf "feat: add A\nfix: bug B\n" > commits.txt
  run "$SCRIPT" --version-file VERSION --commits commits.txt --changelog CHANGELOG.md
  [ "$status" -eq 0 ]
  [ -f CHANGELOG.md ]
  grep -q "1.1.0" CHANGELOG.md
  grep -q "add A" CHANGELOG.md
  grep -q "bug B" CHANGELOG.md
}
