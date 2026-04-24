#!/usr/bin/env bats
# Test harness for the secret rotation validator.
#
# All behavioral assertions execute through `act push`, which runs the
# .github/workflows/secret-rotation-validator.yml workflow in a Docker
# container. We run act once over all fixtures in setup_file(), save
# act-result.txt, then per-test assertions parse the captured output.

SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
ACT_OUT="${SCRIPT_DIR}/act-result.txt"

setup_file() {
  cd "$SCRIPT_DIR"

  # Reuse a prior successful act run if present. This keeps iteration on the
  # bats assertions cheap and keeps us well under the 3-run budget.
  if [ "${REUSE_ACT:-1}" = "1" ] && [ -s "$ACT_OUT" ] \
      && grep -qE '^ACT_EXIT=0$' "$ACT_OUT" \
      && grep -q 'Job succeeded' "$ACT_OUT"; then
    export ACT_LOG="$ACT_OUT"
    return 0
  fi

  # Run act once over all fixtures; record status + full log to act-result.txt.
  : >"$ACT_OUT"
  {
    echo "===ACT_RUN_BEGIN==="
    date -u +%FT%TZ
  } >>"$ACT_OUT"

  # act reads .actrc in cwd for -P overrides (custom pwsh image).
  if act push --rm --pull=false >>"$ACT_OUT" 2>&1; then
    echo "ACT_EXIT=0" >>"$ACT_OUT"
  else
    echo "ACT_EXIT=$?" >>"$ACT_OUT"
  fi
  echo "===ACT_RUN_END===" >>"$ACT_OUT"

  export ACT_LOG="$ACT_OUT"
}

# Helper: extract a named delimited block from the act log.
extract_block() {
  local name="$1" kind="$2"
  awk -v b="===BEGIN:${name}:${kind}===" -v e="===END:${name}:${kind}===" '
    $0 ~ b {on=1; next}
    $0 ~ e {on=0}
    on {
      # act prefixes each log line with something like
      #   "[workflow/job]   | <content>"
      # Strip everything up to and including the first "| " (or a lone "|").
      if (match($0, /\| /)) {
        print substr($0, RSTART + 2)
      } else if (match($0, /\|$/)) {
        print ""
      } else {
        print
      }
    }
  ' "$ACT_LOG"
}

@test "workflow file exists and is valid YAML structure" {
  run actionlint .github/workflows/secret-rotation-validator.yml
  [ "$status" -eq 0 ]
}

@test "workflow references the real script and fixtures" {
  [ -x secret-rotation.sh ]
  [ -f tests/fixtures/mixed.json ]
  [ -f tests/fixtures/all-ok.json ]
  [ -f tests/fixtures/all-expired.json ]
  run grep -q 'secret-rotation.sh' .github/workflows/secret-rotation-validator.yml
  [ "$status" -eq 0 ]
}

@test "workflow declares expected triggers and permissions" {
  grep -q '^  push:' .github/workflows/secret-rotation-validator.yml
  grep -q '^  pull_request:' .github/workflows/secret-rotation-validator.yml
  grep -q '^  workflow_dispatch:' .github/workflows/secret-rotation-validator.yml
  grep -q 'contents: read' .github/workflows/secret-rotation-validator.yml
}

@test "bash -n syntax check passes" {
  run bash -n secret-rotation.sh
  [ "$status" -eq 0 ]
}

@test "shellcheck passes" {
  run shellcheck secret-rotation.sh
  [ "$status" -eq 0 ]
}

@test "act exited successfully" {
  run grep -E '^ACT_EXIT=0$' "$ACT_LOG"
  [ "$status" -eq 0 ]
}

@test "act log reports Job succeeded" {
  run grep -E 'Job succeeded' "$ACT_LOG"
  [ "$status" -eq 0 ]
}

@test "mixed fixture JSON has expected status counts" {
  body=$(extract_block mixed json)
  [ -n "$body" ]
  echo "$body" | jq -e '.counts.expired == 2' >/dev/null
  echo "$body" | jq -e '.counts.warning == 1' >/dev/null
  echo "$body" | jq -e '.counts.ok == 1' >/dev/null
  echo "$body" | jq -e '.counts.total == 4' >/dev/null
  echo "$body" | jq -e '.today == "2026-04-20"' >/dev/null
  echo "$body" | jq -e '.warning_days == 14' >/dev/null
}

@test "mixed fixture classifies each secret correctly" {
  body=$(extract_block mixed json)
  # Exact per-secret expected values (today=2026-04-20, warning=14).
  echo "$body" | jq -e '.secrets[] | select(.name=="prod_api_key") | .status=="expired" and .age_days==201' >/dev/null
  echo "$body" | jq -e '.secrets[] | select(.name=="db_password")  | .status=="expired" and .age_days==95' >/dev/null
  echo "$body" | jq -e '.secrets[] | select(.name=="oauth_secret") | .status=="ok"      and .age_days==10' >/dev/null
  echo "$body" | jq -e '.secrets[] | select(.name=="slack_webhook")| .status=="warning" and .age_days==78 and .days_until_due==2' >/dev/null
}

@test "mixed fixture preserves services list" {
  body=$(extract_block mixed json)
  echo "$body" | jq -e '.secrets[] | select(.name=="prod_api_key") | .services == ["api","web"]' >/dev/null
  echo "$body" | jq -e '.secrets[] | select(.name=="db_password")  | .services == ["db","migrations"]' >/dev/null
}

@test "mixed fixture markdown groups by urgency" {
  body=$(extract_block mixed markdown)
  [ -n "$body" ]
  echo "$body" | grep -q '^# Secret Rotation Report$'
  echo "$body" | grep -q '^- Expired: 2$'
  echo "$body" | grep -q '^- Warning: 1$'
  echo "$body" | grep -q '^- OK: 1$'
  echo "$body" | grep -q '^## Expired$'
  echo "$body" | grep -q '^## Warning$'
  echo "$body" | grep -q '^## OK$'
  # prod_api_key must appear in Expired table (with services column).
  echo "$body" | grep -qE '^\| prod_api_key \| 2025-10-01 \| 90 \| 201 \| -111 \| api, web \|$'
  echo "$body" | grep -qE '^\| slack_webhook \| 2026-02-01 \| 80 \| 78 \| 2 \| notifications \|$'
}

@test "all-ok fixture has no expired or warning secrets" {
  body=$(extract_block all-ok json)
  [ -n "$body" ]
  echo "$body" | jq -e '.counts.expired == 0' >/dev/null
  echo "$body" | jq -e '.counts.warning == 0' >/dev/null
  echo "$body" | jq -e '.counts.ok == 2' >/dev/null
}

@test "all-ok markdown shows empty expired/warning sections" {
  body=$(extract_block all-ok markdown)
  [ -n "$body" ]
  echo "$body" | grep -q '^- Expired: 0$'
  echo "$body" | grep -q '^- Warning: 0$'
  # Empty sections render as "_None._"
  expired_section=$(echo "$body" | awk '/^## Expired/{flag=1; next} /^## /{flag=0} flag')
  [[ "$expired_section" == *"_None._"* ]]
}

@test "all-expired fixture has every secret expired" {
  body=$(extract_block all-expired json)
  [ -n "$body" ]
  echo "$body" | jq -e '.counts.expired == 2' >/dev/null
  echo "$body" | jq -e '.counts.warning == 0' >/dev/null
  echo "$body" | jq -e '.counts.ok == 0' >/dev/null
  echo "$body" | jq -e 'all(.secrets[]; .status == "expired")' >/dev/null
  echo "$body" | jq -e '.secrets[] | select(.name=="ancient_key") | .days_until_due < 0' >/dev/null
}
