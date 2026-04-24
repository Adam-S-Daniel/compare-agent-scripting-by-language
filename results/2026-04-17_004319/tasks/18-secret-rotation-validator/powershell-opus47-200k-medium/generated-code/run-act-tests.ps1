# End-to-end harness: runs the workflow through `act` once per fixture case,
# appends all output to act-result.txt, and asserts exact expected values.
#
# Budget: at most 3 `act push` invocations total.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$projectRoot = $PSScriptRoot
$resultFile  = Join-Path $projectRoot 'act-result.txt'
Remove-Item -Force -ErrorAction Ignore $resultFile
New-Item -ItemType File -Path $resultFile | Out-Null

# Test cases — each names a fixture file and the exact summary line that
# the validate job must emit for that input (given REFERENCE_DATE=2026-04-20
# and WARNING_DAYS=14 baked into the workflow).
$cases = @(
    @{
        Name             = 'default'
        Fixture          = 'fixtures/case-default.json'
        ExpectedSummary  = 'SUMMARY total=4 expired=2 warning=1 ok=1'
        ExpectedNames    = @('prod-api-key','gh-deploy-token','stripe-webhook','db-password')
    },
    @{
        Name             = 'all-ok'
        Fixture          = 'fixtures/case-all-ok.json'
        ExpectedSummary  = 'SUMMARY total=2 expired=0 warning=0 ok=2'
        ExpectedNames    = @('fresh-token-a','fresh-token-b')
    },
    @{
        Name             = 'all-expired'
        Fixture          = 'fixtures/case-all-expired.json'
        ExpectedSummary  = 'SUMMARY total=3 expired=3 warning=0 ok=0'
        ExpectedNames    = @('old-ssh-key','old-jwt','old-db-cred')
    }
)

$failures = @()

foreach ($case in $cases) {
    Write-Host "=== Running case: $($case.Name) ===" -ForegroundColor Cyan

    # Build an isolated git repo copy so each case is independent.
    $temp = Join-Path ([System.IO.Path]::GetTempPath()) ("srv-act-" + $case.Name + "-" + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $temp | Out-Null

    # Copy project files (exclude generated artifacts and prior temp noise).
    $exclude = @('act-result.txt','.git')
    Get-ChildItem -Path $projectRoot -Force | Where-Object { $exclude -notcontains $_.Name } | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $temp -Recurse -Force
    }

    # Overwrite the canonical config with this case's fixture.
    Copy-Item -Path (Join-Path $projectRoot $case.Fixture) -Destination (Join-Path $temp 'fixtures/secrets.json') -Force

    Push-Location $temp
    try {
        git init -q
        git config user.email benchmark@example.com
        git config user.name  benchmark
        git add -A
        git commit -q -m "case $($case.Name)"

        $delim = "`n========== CASE: $($case.Name) ==========`n"
        Add-Content -Path $resultFile -Value $delim

        # --pull=false because act-ubuntu-pwsh is built locally and has no registry.
        $actOutput = & act push --rm --pull=false 2>&1
        $exit = $LASTEXITCODE
        $text = ($actOutput | Out-String)
        Add-Content -Path $resultFile -Value $text
        Add-Content -Path $resultFile -Value "--- act exit code: $exit ---"

        # Assertions.
        if ($exit -ne 0) {
            $failures += "[$($case.Name)] act exit=$exit (expected 0)"
        }
        if ($text -notmatch [regex]::Escape($case.ExpectedSummary)) {
            $failures += "[$($case.Name)] missing expected summary: $($case.ExpectedSummary)"
        }
        foreach ($n in $case.ExpectedNames) {
            if ($text -notmatch [regex]::Escape($n)) {
                $failures += "[$($case.Name)] missing secret name in report: $n"
            }
        }
        # Every job must succeed. Job names in the workflow: 'tests' and 'validate'.
        # act prints a "Job succeeded" line for each completed job.
        $jobSuccesses = ([regex]::Matches($text, 'Job succeeded')).Count
        if ($jobSuccesses -lt 2) {
            $failures += "[$($case.Name)] expected >=2 'Job succeeded' lines, got $jobSuccesses"
        }
    } finally {
        Pop-Location
        Remove-Item -Recurse -Force $temp -ErrorAction SilentlyContinue
    }
}

Add-Content -Path $resultFile -Value "`n========== HARNESS SUMMARY ==========`n"
if ($failures.Count -gt 0) {
    Add-Content -Path $resultFile -Value "FAILURES:`n$($failures -join "`n")"
    Write-Host "FAILED:" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    exit 1
} else {
    Add-Content -Path $resultFile -Value "ALL CASES PASSED"
    Write-Host "ALL CASES PASSED" -ForegroundColor Green
}
