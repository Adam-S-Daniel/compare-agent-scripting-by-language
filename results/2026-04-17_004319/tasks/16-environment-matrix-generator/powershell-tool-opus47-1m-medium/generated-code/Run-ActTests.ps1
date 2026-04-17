#!/usr/bin/env pwsh
# End-to-end harness: runs the workflow under nektos/act for several fixture
# cases, asserts exit codes and exact expected values from the captured output.

[CmdletBinding()] param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root      = $PSScriptRoot
$resultLog = Join-Path $root 'act-result.txt'
if (Test-Path $resultLog) { Remove-Item -LiteralPath $resultLog -Force }

# --- 1. Static workflow checks ---------------------------------------------
$workflow = Join-Path $root '.github/workflows/environment-matrix-generator.yml'
if (-not (Test-Path $workflow)) { throw "Workflow file missing: $workflow" }

# actionlint: must exit 0
& actionlint $workflow
if ($LASTEXITCODE -ne 0) { throw "actionlint failed for $workflow" }
Write-Host "[ok] actionlint passed"

# YAML structure: triggers, jobs, script reference
$wfText = Get-Content -LiteralPath $workflow -Raw
foreach ($needle in @('on:', 'push:', 'pull_request:', 'workflow_dispatch:',
                       'schedule:', 'jobs:', 'generate-matrix:', 'show-summary:',
                       './Generate-Matrix.ps1', 'MatrixGenerator.Tests.ps1',
                       'actions/checkout@v4')) {
    if ($wfText -notmatch [regex]::Escape($needle)) {
        throw "Workflow missing expected token: $needle"
    }
}
foreach ($p in @('Generate-Matrix.ps1', 'MatrixGenerator.psm1', 'MatrixGenerator.Tests.ps1')) {
    if (-not (Test-Path (Join-Path $root $p))) { throw "Referenced script missing: $p" }
}
Write-Host "[ok] workflow structure checks passed"

# --- 2. Test cases for act -------------------------------------------------
# Each case: a fixture path + expected exact substrings from the run output.
$cases = @(
    [pscustomobject]@{
        Name     = 'basic'
        Config   = 'fixtures/basic.json'
        ExpectIn = @(
            'MATRIX-COMBO-COUNT=4',
            '"max-parallel"' -as [string]  # placeholder removed below
        )
    },
    [pscustomobject]@{
        Name     = 'with-rules'
        Config   = 'fixtures/with-rules.json'
        ExpectIn = @(
            'MATRIX-COMBO-COUNT=6',  # 3*2=6, minus 1 exclude, plus 1 include = 6
            '"max-parallel": 3',
            '"fail-fast": false',
            '"experimental": true'
        )
    }
)
# Strip placeholder from basic case (we only use it to keep schema consistent)
$cases[0].ExpectIn = @('MATRIX-COMBO-COUNT=4', '"fail-fast": true')

function Invoke-ActCase {
    param([string]$Name, [string]$Config)

    $work = Join-Path ([System.IO.Path]::GetTempPath()) "act-$Name-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $work | Out-Null
    try {
        # Stage project files into a fresh git repo.
        Copy-Item -Recurse (Join-Path $root '.github')  $work
        Copy-Item -Recurse (Join-Path $root 'fixtures') $work
        Copy-Item (Join-Path $root 'MatrixGenerator.psm1')      $work
        Copy-Item (Join-Path $root 'MatrixGenerator.Tests.ps1') $work
        Copy-Item (Join-Path $root 'Generate-Matrix.ps1')       $work
        Copy-Item (Join-Path $root '.actrc')                    $work

        Push-Location $work
        try {
            & git init -q
            & git config user.email act@example.com
            & git config user.name act
            & git add -A
            & git commit -qm "fixture: $Name"

            $env:CONFIG_PATH_OVERRIDE = $Config
            # Pass the config path via workflow_dispatch input so we exercise it.
            $actOut = & act push --rm --env CONFIG_PATH=$Config 2>&1 | Out-String
            $exit = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        $delim = "===== CASE: $Name (config=$Config exit=$exit) ====="
        Add-Content -LiteralPath $resultLog -Value $delim
        Add-Content -LiteralPath $resultLog -Value $actOut
        Add-Content -LiteralPath $resultLog -Value ''
        return [pscustomobject]@{ Name = $Name; Exit = $exit; Output = $actOut }
    } finally {
        Remove-Item -Recurse -Force -LiteralPath $work -ErrorAction SilentlyContinue
    }
}

$failures = @()
foreach ($c in $cases) {
    Write-Host ""
    Write-Host "=== Running act for case: $($c.Name) ==="
    $r = Invoke-ActCase -Name $c.Name -Config $c.Config

    if ($r.Exit -ne 0) { $failures += "[$($c.Name)] act exited $($r.Exit)" }
    if ($r.Output -notmatch 'Job succeeded') {
        $failures += "[$($c.Name)] missing 'Job succeeded'"
    }
    foreach ($needle in $c.ExpectIn) {
        if ($r.Output -notmatch [regex]::Escape($needle)) {
            $failures += "[$($c.Name)] missing expected substring: $needle"
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "FAILURES:" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
Write-Host ""
Write-Host "All act test cases passed. Output appended to $resultLog" -ForegroundColor Green
