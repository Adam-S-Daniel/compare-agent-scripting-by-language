#!/usr/bin/env pwsh
# Test harness: spins up an isolated git repo per fixture case, runs `act push --rm`,
# captures the output to act-result.txt, and asserts on exact expected values.
[CmdletBinding()] param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = $PSScriptRoot
$resultFile = Join-Path $here 'act-result.txt'
if (Test-Path $resultFile) { Remove-Item $resultFile -Force }

# --- Workflow structure tests (run before any act invocation) ---------------
Write-Host "=== Workflow structure tests ===" -ForegroundColor Cyan

$wfPath = Join-Path $here '.github/workflows/semantic-version-bumper.yml'
if (-not (Test-Path $wfPath)) { throw "Workflow file missing: $wfPath" }

# actionlint must pass cleanly.
& actionlint $wfPath
if ($LASTEXITCODE -ne 0) { throw "actionlint failed" }
Write-Host "  actionlint: OK"

# Parse YAML — use ConvertFrom-Yaml if available, else fall back to grep-style checks.
$wfText = Get-Content -LiteralPath $wfPath -Raw
foreach ($needle in @('on:', 'push:', 'pull_request:', 'workflow_dispatch:', 'jobs:', 'bump:', 'actions/checkout@v4', 'Invoke-Bump.ps1', 'SemanticVersionBumper.Tests.ps1')) {
    if ($wfText -notmatch [regex]::Escape($needle)) { throw "Workflow missing expected token: $needle" }
}
Write-Host "  required triggers/jobs/steps/refs present: OK"

# Referenced script files must exist on disk.
foreach ($ref in @('Invoke-Bump.ps1', 'SemanticVersionBumper.psm1', 'SemanticVersionBumper.Tests.ps1')) {
    if (-not (Test-Path (Join-Path $here $ref))) { throw "Referenced script not found: $ref" }
}
Write-Host "  referenced scripts exist: OK"

# --- Define the act test cases ----------------------------------------------
# Each case ships a VERSION file + commits.txt fixture. The harness asserts the
# exact expected NEW_VERSION printed by the workflow.
$cases = @(
    @{
        Name     = 'feat-bumps-minor'
        Version  = '1.1.0'
        Commits  = "feat: add user authentication`n---`nchore: tidy up"
        Expected = '1.2.0'
    },
    @{
        Name     = 'fix-bumps-patch'
        Version  = '0.5.4'
        Commits  = "fix: handle null pointer`n---`ndocs: update readme"
        Expected = '0.5.5'
    },
    @{
        Name     = 'breaking-bumps-major'
        Version  = '2.3.7'
        Commits  = "feat!: redesign API`n---`nfix: small thing"
        Expected = '3.0.0'
    }
)

# --- Run each case through `act push --rm` ----------------------------------
function Invoke-ActCase {
    param([hashtable]$Case)

    $tmp = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ("svb_act_" + [Guid]::NewGuid()))
    try {
        # Copy project files into the temp dir.
        Copy-Item (Join-Path $here 'SemanticVersionBumper.psm1')       (Join-Path $tmp 'SemanticVersionBumper.psm1')
        Copy-Item (Join-Path $here 'SemanticVersionBumper.Tests.ps1')  (Join-Path $tmp 'SemanticVersionBumper.Tests.ps1')
        Copy-Item (Join-Path $here 'Invoke-Bump.ps1')                  (Join-Path $tmp 'Invoke-Bump.ps1')
        Copy-Item (Join-Path $here '.actrc')                            (Join-Path $tmp '.actrc')
        New-Item -ItemType Directory -Path (Join-Path $tmp '.github/workflows') -Force | Out-Null
        Copy-Item (Join-Path $here '.github/workflows/semantic-version-bumper.yml') (Join-Path $tmp '.github/workflows/semantic-version-bumper.yml')

        # Write per-case fixture files.
        Set-Content -LiteralPath (Join-Path $tmp 'VERSION')     -Value $Case.Version -NoNewline
        Set-Content -LiteralPath (Join-Path $tmp 'commits.txt') -Value $Case.Commits -NoNewline

        # act needs a git repo to compute event context.
        Push-Location $tmp
        try {
            git init -q
            git config user.email act@example.com
            git config user.name 'act'
            git add -A
            git commit -q -m "fixture: $($Case.Name)"

            Write-Host "--- act push --rm  ($($Case.Name)) ---" -ForegroundColor Yellow
            $output = & act push --rm 2>&1 | Out-String
            $exit = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        # Append delimited output for this case to act-result.txt.
        $delim = "================ CASE: $($Case.Name) (exit=$exit) ================"
        Add-Content -LiteralPath $resultFile -Value $delim
        Add-Content -LiteralPath $resultFile -Value $output
        Add-Content -LiteralPath $resultFile -Value ""

        if ($exit -ne 0) { throw "act exited with $exit for case $($Case.Name)" }
        if ($output -notmatch [regex]::Escape("NEW_VERSION=$($Case.Expected)")) {
            throw "Case $($Case.Name): expected NEW_VERSION=$($Case.Expected), output did not match"
        }
        if ($output -notmatch 'Job succeeded') {
            throw "Case $($Case.Name): no 'Job succeeded' marker in act output"
        }
        Write-Host "  [PASS] $($Case.Name): NEW_VERSION=$($Case.Expected)" -ForegroundColor Green
    } finally {
        Remove-Item -Recurse -Force $tmp
    }
}

Write-Host "`n=== Running act for $($cases.Count) cases ===" -ForegroundColor Cyan
foreach ($c in $cases) { Invoke-ActCase -Case $c }

Write-Host "`nAll cases passed. act-result.txt is at: $resultFile" -ForegroundColor Green
