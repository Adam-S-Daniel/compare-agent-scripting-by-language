# run-act-tests.ps1
# Act test harness: sets up a temp git repo, runs the workflow via act,
# captures output to act-result.txt, and asserts on exact expected values.

$ErrorActionPreference = 'Stop'
$projectDir   = $PSScriptRoot
$actResultFile = "$projectDir/act-result.txt"

# Expected values for assertions
$expectedPasses = @(
    'PASS: TC1-docs-only',
    'PASS: TC2-api-file',
    'PASS: TC3-test-file',
    'PASS: TC4-multiple-files',
    'PASS: TC5-no-match',
    'PASS: TC6-api-test-file',
    'PASS: TC7-ci-file',
    'ALL_TESTS_PASSED'
)

$tmpDir = "/tmp/pr-label-act-$(Get-Random)"

try {
    # ── Set up isolated git repo ──────────────────────────────────────────────
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    Write-Output "Temp repo: $tmpDir"

    # Copy all project files (includes .github/, *.ps1, *.json, .actrc)
    Get-ChildItem -Path $projectDir -Force | Where-Object {
        $_.Name -notin @('act-result.txt', 'run-act-tests.ps1')
    } | Copy-Item -Destination $tmpDir -Recurse -Force

    Push-Location $tmpDir

    git init -q
    git config user.email "test@example.com"
    git config user.name  "Test Runner"
    git add -A
    git commit -q -m "chore: test commit for act run"

    # ── Run act ───────────────────────────────────────────────────────────────
    Write-Output "Running act push --rm ..."
    $output  = act push --rm --pull=false 2>&1
    $exitCode = $LASTEXITCODE

    # ── Save results ──────────────────────────────────────────────────────────
    $delimiter = "=" * 60
    @(
        $delimiter,
        "ACT RUN: $(Get-Date -Format 'o')",
        "EXIT CODE: $exitCode",
        $delimiter,
        ($output -join "`n"),
        $delimiter
    ) | Set-Content $actResultFile -Encoding UTF8

    Write-Output "act-result.txt written."

    # ── Assertions ────────────────────────────────────────────────────────────
    $outputStr = $output -join "`n"
    $failed    = @()

    if ($exitCode -ne 0) {
        $failed += "act exited with code $exitCode (expected 0)"
    }

    if ($outputStr -notmatch 'Job succeeded') {
        $failed += "Expected 'Job succeeded' in act output"
    }

    foreach ($expected in $expectedPasses) {
        # act prefixes each line with step output markers; use simple substring match
        if ($outputStr -notmatch [regex]::Escape($expected)) {
            $failed += "Missing expected output: '$expected'"
        }
    }

    if ($failed.Count -gt 0) {
        Write-Output "`nFAILED ASSERTIONS:"
        $failed | ForEach-Object { Write-Output "  - $_" }
        Write-Error "Act test harness: $($failed.Count) assertion(s) failed. See act-result.txt."
        exit 1
    }

    Write-Output "`nAll act assertions PASSED."

} finally {
    Pop-Location -ErrorAction SilentlyContinue
    Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
