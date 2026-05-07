# Test Results Summary

## Totals

| Metric | Value |
|--------|-------|
| Total Tests | 17 |
| Passed | 10 |
| Failed | 5 |
| Skipped | 2 |
| Duration | 36.600s |
| Flaky Tests | 3 |

## Failed Tests

- **PaymentTests::test_payment** — failed in all runs

## Flaky Tests

These tests produced inconsistent results across runs:

- **CartTests::test_checkout** — outcomes: failed,passed
- **APITests::test_create_user** — outcomes: failed,passed
- **AuthTests::test_signup** — outcomes: failed,passed

## Per-Test Results

| Test | Suite | Outcomes |
|------|-------|----------|
| test_checkout | CartTests | failed,passed |
| test_create_user | APITests | failed,passed |
| test_delete_user | APITests | skipped,skipped |
| test_get_users | APITests | passed,passed |
| test_login | AuthTests | passed,passed |
| test_payment | PaymentTests | failed,failed |
| test_refund | PaymentTests | passed |
| test_search | CartTests | passed,passed |
| test_signup | AuthTests | failed,passed |
