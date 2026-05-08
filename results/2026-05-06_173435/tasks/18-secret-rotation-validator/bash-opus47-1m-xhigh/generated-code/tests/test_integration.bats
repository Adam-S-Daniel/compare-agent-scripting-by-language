#!/usr/bin/env bats
#
# Integration tests for secret-rotation-validator.sh, executed end-to-end
# through the GitHub Actions workflow via `act push --rm`. Each test:
#   1. Stages a temp git repo with the project files + the fixture data
#   2. Runs the workflow via act
#   3. Asserts exit code 0 and verifies EXACT expected values appear in
#      both the markdown and JSON output that the workflow emits.
#
# The combined output of every act run is appended to act-result.txt in
# the project root.

load helpers/act_helper.bash

# Clear act-result.txt once before any test in this file runs so subsequent
# run_fixture appends compose a single canonical artifact.
setup_file() {
    : > "$(project_root)/act-result.txt"
}

# bats default timeout is plenty for one act run, but defining it here
# documents the expectation that an act run completes in well under
# 300 seconds with the pre-pulled act-ubuntu-pwsh image.

@test "all-ok fixture: workflow succeeds with no expired or warning secrets" {
    run_fixture all-ok

    [ "$status" -eq 0 ]

    # Job-level assertion: act prints "Job succeeded" when the job ends OK.
    assert_in_output 'Job succeeded'

    # Markdown report should report 2 ok, 0 warning, 0 expired.
    assert_in_output 'Summary: 0 expired, 0 warning, 2 ok'
    assert_in_output '## Expired (0)'
    assert_in_output '## Warning (0)'
    assert_in_output '## OK (2)'
    assert_in_output '_None._'

    # Specific OK rows with precomputed days-until-expiry values.
    assert_in_output '| prod_db | 2026-04-15 | 90 | api,worker | 68 |'
    assert_in_output '| staging_api | 2026-05-01 | 60 | staging | 54 |'

    # Reference date and warning window echoed in the report.
    assert_in_output 'Reference date: 2026-05-07'
    assert_in_output 'Warning window: 7 day(s)'

    # JSON output must include the exact summary block.
    assert_in_output '"summary":{"expired":0,"warning":0,"ok":2}'
    assert_in_output '"reference_date":"2026-05-07"'
    assert_in_output '"warning_days":7'

    # JSON validity step in the workflow set this marker.
    assert_in_output 'JSON_OUTPUT_VALID=true'
}

@test "one-expired fixture: legacy_token is expired, current_key is ok" {
    run_fixture one-expired

    [ "$status" -eq 0 ]

    assert_in_output 'Job succeeded'

    assert_in_output 'Summary: 1 expired, 0 warning, 1 ok'
    assert_in_output '## Expired (1)'
    assert_in_output '## Warning (0)'
    assert_in_output '## OK (1)'

    # Negative days_until_expiry signals "this secret expired N days ago".
    assert_in_output '| legacy_token | 2025-01-01 | 30 | legacy-svc | -461 |'
    assert_in_output '| current_key | 2026-04-20 | 60 | api | 43 |'

    # The expired item must NOT appear in the OK section, and vice versa.
    refute_in_output '| legacy_token | 2025-01-01 | 30 | legacy-svc | -461 | (ok)'

    assert_in_output '"summary":{"expired":1,"warning":0,"ok":1}'
    assert_in_output '"name":"legacy_token"'
    assert_in_output '"urgency":"expired"'
    assert_in_output '"days_until_expiry":-461'
    assert_in_output '"days_until_expiry":43'
    assert_in_output '"services":["legacy-svc"]'

    assert_in_output 'JSON_OUTPUT_VALID=true'
}

@test "mixed fixture: 14-day window classifies one of each urgency" {
    run_fixture mixed

    [ "$status" -eq 0 ]

    assert_in_output 'Job succeeded'

    assert_in_output 'Reference date: 2026-05-07'
    assert_in_output 'Warning window: 14 day(s)'
    assert_in_output 'Summary: 1 expired, 1 warning, 1 ok'
    assert_in_output '## Expired (1)'
    assert_in_output '## Warning (1)'
    assert_in_output '## OK (1)'

    # Precomputed days_until_expiry: -432, +3, +88.
    assert_in_output '| expired_key | 2024-12-01 | 90 | legacy | -432 |'
    assert_in_output '| about_to_expire | 2026-04-10 | 30 | payments | 3 |'
    assert_in_output '| freshly_rotated | 2026-05-05 | 90 | api,worker | 88 |'

    # JSON: each urgency bucket has exactly one entry, services arrays
    # split correctly.
    assert_in_output '"summary":{"expired":1,"warning":1,"ok":1}'
    assert_in_output '"warning_days":14'
    assert_in_output '"name":"expired_key","last_rotated":"2024-12-01","policy_days":90,"services":["legacy"],"urgency":"expired","days_until_expiry":-432'
    assert_in_output '"name":"about_to_expire","last_rotated":"2026-04-10","policy_days":30,"services":["payments"],"urgency":"warning","days_until_expiry":3'
    assert_in_output '"name":"freshly_rotated","last_rotated":"2026-05-05","policy_days":90,"services":["api","worker"],"urgency":"ok","days_until_expiry":88'

    assert_in_output 'JSON_OUTPUT_VALID=true'
}
